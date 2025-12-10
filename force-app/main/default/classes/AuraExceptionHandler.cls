/**
 * Helper pour gérer les exceptions dans les méthodes @AuraEnabled
 * Capture automatiquement le stack trace AVANT le wrapper AuraHandledException
 * 
 * Usage:
 * catch (Exception e) {
 *     throw AuraExceptionHandler.handle(e, 'ClassName', 'methodName', contextData);
 * }
 */
public class AuraExceptionHandler {
    
    /**
     * Gère une exception Apex appelée depuis un LWC
     * - Logger avec UniversalLogger
     * - Créer diagnostic IA automatique
     * - Wrapper dans AuraHandledException
     * 
     * @param e Exception à gérer
     * @param className Nom de la classe Apex
     * @param methodName Nom de la méthode
     * @param contextData Données de contexte (configuration, recordId, etc.)
     * @return AuraHandledException à throw
     */
    public static AuraHandledException handle(
        Exception e, 
        String className, 
        String methodName, 
        Map<String, Object> contextData
    ) {
        return handle(e, className, methodName, contextData, null, null);
    }
    
    /**
     * Gère une exception avec Record ID et Object Type
     */
    public static AuraHandledException handle(
        Exception e, 
        String className, 
        String methodName, 
        Map<String, Object> contextData,
        String recordId,
        String objectType
    ) {
        // 1. Logger avec UniversalLogger
        UniversalLogger.error(
            className,
            methodName,
            'Erreur dans méthode @AuraEnabled',
            e,
            contextData
        );
        
        // 2. Créer diagnostic IA automatique
        ErrorDiagnosticService.ErrorInfo error = new ErrorDiagnosticService.ErrorInfo();
        error.errorType = 'APEX';
        error.componentName = className;
        error.className = className;
        error.methodName = methodName;
        error.errorMessage = e.getMessage();
        error.stackTrace = e.getStackTraceString();
        error.recordId = recordId;
        error.objectType = objectType;
        error.contextData = contextData != null ? JSON.serialize(contextData) : null;
        
        // 3. Créer Case automatique
        if (Test.isRunningTest()) {
            // En test : synchrone pour coverage
            try {
                ErrorDiagnosticService.diagnoseAndCreateCase(
                    new List<ErrorDiagnosticService.ErrorInfo>{ error }
                );
            } catch (Exception diagEx) {
                // Silent fail dans les tests
                System.debug(LoggingLevel.WARN, 'Diagnostic skipped in test: ' + diagEx.getMessage());
            }
        } else {
            // En production : async pour ne pas bloquer
            System.enqueueJob(new DiagnosticQueueable(error));
        }
        
        // 4. Retourner exception pour le LWC
        return new AuraHandledException(buildUserFriendlyMessage(e));
    }
    
    /**
     * Construit un message user-friendly depuis l'exception
     */
    private static String buildUserFriendlyMessage(Exception e) {
        String message = e.getMessage();
        
        // Si DML Exception, extraire le vrai message
        if (e instanceof DmlException) {
            DmlException dmlEx = (DmlException) e;
            if (dmlEx.getNumDml() > 0) {
                message = dmlEx.getDmlMessage(0);
            }
        }
        
        // Nettoyer les préfixes techniques
        if (message.startsWith('Insert failed.')) {
            message = message.substringAfter('first error: ');
            if (message.contains(',')) {
                message = message.substringAfter(',').trim();
            }
        }
        
        return message;
    }
    
}
