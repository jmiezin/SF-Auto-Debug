/**
 * Service Unifié de Diagnostic d'Erreurs avec IA
 * Gère les erreurs Apex, LWC et Flow de manière cohérente
 * Crée un Case avec diagnostic IA, l'email sera envoyé automatiquement par le Case
 */
public with sharing class ErrorDiagnosticService {
    
    public enum ErrorType {
        APEX, LWC, FLOW
    }
    
    /**
     * Classe wrapper pour les informations d'erreur
     */
    public class ErrorInfo {
        @InvocableVariable(label='Type d\'erreur' required=true)
        public String errorType; // 'APEX', 'LWC', 'FLOW'
        
        @InvocableVariable(label='Nom du composant/flow/classe')
        public String componentName;
        
        @InvocableVariable(label='Message d\'erreur' required=true)
        public String errorMessage;
        
        @InvocableVariable(label='Stack trace')
        public String stackTrace;
        
        @InvocableVariable(label='ID du record déclencheur')
        public String recordId;
        
        @InvocableVariable(label='Type d\'objet')
        public String objectType;
        
        // Spécifique Flow
        @InvocableVariable(label='Nom du Flow')
        public String flowName;
        
        @InvocableVariable(label='API Name du Flow')
        public String flowApiName;
        
        @InvocableVariable(label='Élément en erreur')
        public String faultElement;
        
        // Spécifique Apex
        @InvocableVariable(label='Nom de la classe')
        public String className;
        
        @InvocableVariable(label='Nom de la méthode')
        public String methodName;
        
        @InvocableVariable(label='Numéro de ligne')
        public Integer lineNumber;
        
        // Spécifique LWC
        @InvocableVariable(label='Code JavaScript')
        public String jsCode;
        
        @InvocableVariable(label='Métadonnées LWC')
        public String metadata;
        
        // Contexte additionnel (JSON string)
        @InvocableVariable(label='Données contextuelles (JSON)')
        public String contextData;
    }
    
    /**
     * Classe de réponse
     */
    public class Response {
        @InvocableVariable
        public Boolean success;
        
        @InvocableVariable
        public String caseId;
        
        @InvocableVariable
        public String message;
        
        public Response(Boolean success, String caseId, String message) {
            this.success = success;
            this.caseId = caseId;
            this.message = message;
        }
    }
    
    /**
     * Classe pour le contexte de diagnostic (public pour les adaptateurs)
     */
    public class DiagnosticContext {
        public ErrorType errorType;
        public String className;
        public String methodName;
        public Integer lineNumber;
        public String sourceCode;
        public String componentName;
        public String jsCode;
        public String metadata;
        public String flowName;
        public String flowApiName;
        public String flowXml;
        public String faultElement;
        public String errorCategory;
    }
    
    /**
     * Classe pour le résultat du diagnostic IA (public pour les adaptateurs)
     */
    public class DiagnosticResult {
        public String problem;
        public String rootCause;
        public String solution;
        public String codeFix;
        public List<String> steps;
        public String severity; // CRITICAL, HIGH, MEDIUM, LOW
    }
    
    /**
     * Méthode principale invocable depuis Flow
     */
    @InvocableMethod(label='Diagnostic Erreur avec IA' 
                     description='Analyse une erreur (Apex/LWC/Flow) avec IA et crée un Case')
    public static List<Response> diagnoseAndCreateCase(List<ErrorInfo> errors) {
        List<Response> responses = new List<Response>();
        
        for (ErrorInfo error : errors) {
            try {
                // 1. Construire le contexte selon le type
                DiagnosticContext context = buildContext(error);
                
                // 2. Analyser avec IA (prompt spécialisé)
                DiagnosticResult diagnostic = analyzeWithAI(error, context);
                
                // 3. Créer le Case (l'email sera envoyé automatiquement par le Case)
                Case newCase = createCase(error, diagnostic, context);
                
                responses.add(new Response(true, newCase.Id, 'Case créé avec succès'));
                
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Erreur lors du diagnostic: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
                responses.add(new Response(false, null, 'Erreur: ' + e.getMessage()));
            }
        }
        
        return responses;
    }
    
    /**
     * Méthode @AuraEnabled pour appels depuis LWC
     */
    @AuraEnabled
    public static String diagnoseLWCError(String componentName, String errorMessage, String stackTrace, String recordId, String objectType, String contextData) {
        System.debug(LoggingLevel.INFO, '🔧 [DIAGNOSTIC APEX] diagnoseLWCError appelé');
        System.debug(LoggingLevel.INFO, '🔧 [DIAGNOSTIC APEX] Component: ' + componentName);
        System.debug(LoggingLevel.INFO, '🔧 [DIAGNOSTIC APEX] RecordId: ' + recordId);
        
        try {
            ErrorInfo error = new ErrorInfo();
            error.errorType = 'LWC';
            error.componentName = componentName;
            error.errorMessage = errorMessage;
            error.stackTrace = stackTrace != null ? stackTrace : '';
            error.recordId = recordId;
            error.objectType = objectType;
            error.contextData = contextData;
            
            System.debug(LoggingLevel.INFO, '🔧 [DIAGNOSTIC APEX] Appel à diagnoseAndCreateCase...');
            List<Response> responses = diagnoseAndCreateCase(new List<ErrorInfo>{ error });
            
            System.debug(LoggingLevel.INFO, '🔧 [DIAGNOSTIC APEX] Réponses reçues: ' + (responses != null ? responses.size() : 0));
            
            if (responses != null && !responses.isEmpty() && responses[0].success) {
                System.debug(LoggingLevel.INFO, '✅ [DIAGNOSTIC APEX] Case créé: ' + responses[0].caseId);
                return responses[0].caseId;
            } else {
                System.debug(LoggingLevel.WARN, '⚠️ [DIAGNOSTIC APEX] Aucun Case créé (success=false ou responses vide)');
                return null;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '❌ [DIAGNOSTIC APEX] Erreur lors du diagnostic LWC: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, '❌ [DIAGNOSTIC APEX] StackTrace: ' + e.getStackTraceString());
            throw new AuraHandledException('Erreur lors du diagnostic: ' + e.getMessage());
        }
    }
    
    /**
     * Construit le contexte selon le type d'erreur
     */
    private static DiagnosticContext buildContext(ErrorInfo error) {
        DiagnosticContext context = new DiagnosticContext();
        
        if (error.errorType == 'APEX') {
            context = ApexErrorAdapter.buildContext(error);
        } else if (error.errorType == 'LWC') {
            context = LWCErrorAdapter.buildContext(error);
        } else if (error.errorType == 'FLOW') {
            context = FlowErrorAdapter.buildContext(error);
        }
        
        return context;
    }
    
    /**
     * Analyse avec IA (prompt spécialisé selon le type)
     */
    private static DiagnosticResult analyzeWithAI(ErrorInfo error, DiagnosticContext context) {
        String prompt = buildPrompt(error, context);
        
        // Appeler OpenAI
        String aiResponse = OpenAI_Service.sendPrompt(prompt);
        
        // ✅ NOUVEAU : Logger la réponse COMPLÈTE pour debug
        System.debug('🤖 [DIAGNOSTIC] ===== RÉPONSE IA BRUTE COMPLÈTE =====');
        System.debug(aiResponse);
        System.debug('🤖 [DIAGNOSTIC] ===== FIN RÉPONSE IA =====');
        System.debug('🤖 [DIAGNOSTIC] Longueur réponse: ' + (aiResponse != null ? aiResponse.length() : 0) + ' caractères');
        
        // Parser la réponse
        return parseAIResponse(aiResponse, error);
    }
    
    /**
     * Construit le prompt selon le type d'erreur
     */
    private static String buildPrompt(ErrorInfo error, DiagnosticContext context) {
        if (error.errorType == 'APEX') {
            return ApexErrorAdapter.buildPrompt(error, context);
        } else if (error.errorType == 'LWC') {
            return LWCErrorAdapter.buildPrompt(error, context);
        } else if (error.errorType == 'FLOW') {
            return FlowErrorAdapter.buildPrompt(error, context);
        }
        return '';
    }
    
    /**
     * Parse la réponse OpenAI avec gestion robuste du JSON
     */
    private static DiagnosticResult parseAIResponse(String aiResponse, ErrorInfo error) {
        DiagnosticResult result = new DiagnosticResult();
        
        try {
            // Nettoyer la réponse : enlever les backticks markdown si présents
            String cleanedResponse = aiResponse.trim();
            
            // Enlever ```json au début
            if (cleanedResponse.startsWith('```json')) {
                cleanedResponse = cleanedResponse.substring(7).trim();
            } else if (cleanedResponse.startsWith('```')) {
                cleanedResponse = cleanedResponse.substring(3).trim();
            }
            
            // Enlever ``` à la fin
            if (cleanedResponse.endsWith('```')) {
                cleanedResponse = cleanedResponse.substring(0, cleanedResponse.length() - 3).trim();
            }
            
            // Essayer d'extraire le JSON même s'il y a du texte avant/après
            String jsonString = extractJSON(cleanedResponse);
            
            if (String.isBlank(jsonString)) {
                throw new JSONException('Aucun JSON trouvé dans la réponse');
            }
            
            // Essayer de parser le JSON nettoyé
            Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(jsonString);
            
            result.problem = (String) jsonResponse.get('problem');
            result.rootCause = (String) jsonResponse.get('rootCause');
            result.solution = (String) jsonResponse.get('solution');
            result.codeFix = (String) jsonResponse.get('codeFix');
            result.severity = (String) jsonResponse.get('severity');
            
            // Parser les steps
            if (jsonResponse.containsKey('steps')) {
                List<Object> stepsObj = (List<Object>) jsonResponse.get('steps');
                result.steps = new List<String>();
                for (Object step : stepsObj) {
                    result.steps.add(String.valueOf(step));
                }
            }
            
            System.debug(LoggingLevel.INFO, '✅ [DIAGNOSTIC] JSON parsé avec succès');
            
        } catch (Exception e) {
            // Si le parsing échoue, essayer d'extraire les informations manuellement
            System.debug(LoggingLevel.WARN, '⚠️ [DIAGNOSTIC] Erreur parsing JSON: ' + e.getMessage());
            System.debug(LoggingLevel.WARN, '⚠️ [DIAGNOSTIC] StackTrace: ' + e.getStackTraceString());
            
            // Essayer d'extraire les champs manuellement avec regex
            result = extractFieldsManually(aiResponse, error);
        }
        
        // Valeurs par défaut si manquantes
        if (String.isBlank(result.severity)) {
            result.severity = 'MEDIUM';
        }
        if (result.steps == null) {
            result.steps = new List<String>();
        }
        
        return result;
    }
    
    /**
     * Extrait le JSON d'une chaîne qui peut contenir du texte avant/après
     */
    private static String extractJSON(String input) {
        // Chercher le premier { et le dernier } équilibré
        Integer startIdx = input.indexOf('{');
        if (startIdx == -1) {
            return null;
        }
        
        // Compter les accolades pour trouver la fin du JSON
        Integer braceCount = 0;
        Integer endIdx = -1;
        
        for (Integer i = startIdx; i < input.length(); i++) {
            String charAt = input.substring(i, i + 1);
            if (charAt == '{') {
                braceCount++;
            } else if (charAt == '}') {
                braceCount--;
                if (braceCount == 0) {
                    endIdx = i;
                    break;
                }
            }
        }
        
        if (endIdx == -1) {
            return null;
        }
        
        return input.substring(startIdx, endIdx + 1);
    }
    
    /**
     * Extrait les champs manuellement si le parsing JSON échoue
     */
    private static DiagnosticResult extractFieldsManually(String aiResponse, ErrorInfo error) {
        DiagnosticResult result = new DiagnosticResult();
        
        // Essayer d'extraire les champs avec des patterns regex simples
        Pattern problemPattern = Pattern.compile('"problem"\\s*:\\s*"([^"]+)"');
        Pattern rootCausePattern = Pattern.compile('"rootCause"\\s*:\\s*"([^"]+)"');
        Pattern solutionPattern = Pattern.compile('"solution"\\s*:\\s*"([^"]+)"');
        Pattern severityPattern = Pattern.compile('"severity"\\s*:\\s*"([^"]+)"');
        
        Matcher problemMatcher = problemPattern.matcher(aiResponse);
        if (problemMatcher.find()) {
            result.problem = problemMatcher.group(1);
        }
        
        Matcher rootCauseMatcher = rootCausePattern.matcher(aiResponse);
        if (rootCauseMatcher.find()) {
            result.rootCause = rootCauseMatcher.group(1);
        }
        
        Matcher solutionMatcher = solutionPattern.matcher(aiResponse);
        if (solutionMatcher.find()) {
            result.solution = solutionMatcher.group(1);
        }
        
        Matcher severityMatcher = severityPattern.matcher(aiResponse);
        if (severityMatcher.find()) {
            result.severity = severityMatcher.group(1);
        }
        
        // Extraire codeFix (peut contenir plusieurs lignes et backticks)
        // Note: Apex Pattern ne supporte pas MULTILINE/DOTALL, on utilise une approche différente
        Pattern codeFixPattern = Pattern.compile('"codeFix"\\s*:\\s*"([^"]*(?:\\\\.[^"]*)*)"');
        Matcher codeFixMatcher = codeFixPattern.matcher(aiResponse);
        if (codeFixMatcher.find()) {
            result.codeFix = codeFixMatcher.group(1).replace('\\n', '\n').replace('\\"', '"');
        } else {
            // Essayer d'extraire le code entre backticks après "codeFix"
            Pattern codeFixAltPattern = Pattern.compile('"codeFix"\\s*:\\s*"([^"]*)"');
            Matcher codeFixAltMatcher = codeFixAltPattern.matcher(aiResponse);
            if (codeFixAltMatcher.find()) {
                result.codeFix = codeFixAltMatcher.group(1);
            }
        }
        
        // Si toujours rien trouvé, utiliser la réponse brute
        if (String.isBlank(result.problem)) {
            result.problem = 'Erreur lors du parsing de la réponse IA';
            result.rootCause = error.errorMessage;
            result.solution = aiResponse.length() > 10000 ? aiResponse.substring(0, 10000) + '...' : aiResponse;
            result.severity = 'MEDIUM';
            result.steps = new List<String>{ 'Vérifier manuellement la réponse IA dans le Case' };
        }
        
        return result;
    }
    
    /**
     * Crée un Case avec toutes les informations
     * L'email sera envoyé automatiquement par un Flow/Trigger sur Case
     */
    private static Case createCase(ErrorInfo error, DiagnosticResult diagnostic, DiagnosticContext context) {
        Case newCase = new Case();
        
        // Informations de base
        newCase.Subject = '[' + error.errorType + ' ERROR] ' + 
                         (String.isNotBlank(error.componentName) ? error.componentName : 'Erreur') + 
                         ' - ' + diagnostic.severity;
        
        newCase.Description = buildCaseDescription(error, diagnostic, context);
        newCase.Priority = mapSeverityToPriority(diagnostic.severity);
        newCase.Status = 'New';
        newCase.Origin = 'Automated';
        
        // Type d'erreur dans la description (pour filtrage)
        newCase.Type = error.errorType;
        
        // ✅ RecordType Debug
        newCase.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Debug').getRecordTypeId();
        
        // ✅ NOUVEAU: Champs custom pour debug
        newCase.put('Error_Source__c', error.errorType);
        newCase.put('Component__c', error.errorType == 'LWC' ? error.componentName : error.errorType == 'APEX' ? error.className : error.flowName);
        newCase.put('Method__c', error.methodName);
        newCase.put('Severity__c', diagnostic.severity);
        newCase.put('User__c', UserInfo.getUserId());
        newCase.put('Error_Message__c', error.errorMessage);
        newCase.put('Raw_Error__c', error.stackTrace);
        newCase.put('Context__c', error.contextData);
        newCase.put('Error_Json__c', JSON.serializePretty(diagnostic));
        newCase.put('Error_Signature__c', generateErrorSignature(error));
        newCase.put('Environment__c', getEnvironment());
        newCase.put('Release_Tag__c', getReleaseTag());
        
        // Assigner à l'admin (récupérer depuis Custom Metadata ou User)
        newCase.OwnerId = getAdminUserId();

        // ✅ AMÉLIORATION v2.3: Lier au record (Account uniquement pour l'instant)
        // Note: WhatId pourrait être utilisé pour Quote/Opportunity si supporté par l'org
        if (String.isNotBlank(error.recordId) && error.objectType == 'Account') {
            try {
                newCase.AccountId = error.recordId;
                System.debug(LoggingLevel.INFO, '✅ [DIAGNOSTIC] AccountId défini: ' + error.recordId);
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, '⚠️ [DIAGNOSTIC] Impossible de lier AccountId: ' + e.getMessage());
            }
        }
        
        insert newCase;
        
        // Poster le diagnostic dans le Feed du Case
        postDiagnosticToFeed(newCase.Id, error, diagnostic, context);
        
        return newCase;
    }
    
    /**
     * Poste le diagnostic IA dans le Feed du Case
     */
    private static void postDiagnosticToFeed(Id caseId, ErrorInfo error, DiagnosticResult diagnostic, DiagnosticContext context) {
        try {
            // Construire le message pour le feed (format plus concis)
            String feedMessage = buildFeedMessage(error, diagnostic, context);
            
            // Créer le post via ConnectApi
            ConnectApi.FeedItemInput feedItemInput = new ConnectApi.FeedItemInput();
            ConnectApi.MessageBodyInput messageBodyInput = new ConnectApi.MessageBodyInput();
            ConnectApi.TextSegmentInput textSegmentInput = new ConnectApi.TextSegmentInput();
            
            textSegmentInput.text = feedMessage;
            messageBodyInput.messageSegments = new List<ConnectApi.MessageSegmentInput>{ textSegmentInput };
            feedItemInput.body = messageBodyInput;
            feedItemInput.subjectId = caseId;
            
            ConnectApi.FeedElement feedElement = ConnectApi.ChatterFeeds.postFeedElement(
                Network.getNetworkId(),
                feedItemInput
            );
            
            System.debug(LoggingLevel.INFO, '✅ [DIAGNOSTIC] Post créé dans le Feed: ' + feedElement.id);
            
        } catch (Exception e) {
            // Ne pas faire échouer la création du Case si le post échoue
            System.debug(LoggingLevel.ERROR, '❌ [DIAGNOSTIC] Erreur lors de la création du post Feed: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, '❌ [DIAGNOSTIC] StackTrace: ' + e.getStackTraceString());
        }
    }
    
    /**
     * Construit le message pour le Feed (format concis)
     */
    private static String buildFeedMessage(ErrorInfo error, DiagnosticResult diagnostic, DiagnosticContext context) {
        // ✅ NOUVEAU v2.3: Template optimisé selon suggestions GPT
        String message = '─────────────────────────────────────────────\n';
        message += '🧠 **DIAGNOSTIC IA AUTOMATIQUE**\n';
        message += '─────────────────────────────────────────────\n\n';

        // Informations essentielles en une ligne
        message += '**Type:** ' + error.errorType;
        
        if (error.errorType == 'LWC' && String.isNotBlank(error.componentName)) {
            message += ' | **Composant:** ' + error.componentName;
            if (String.isNotBlank(error.methodName)) {
                message += ' | **Méthode:** ' + error.methodName;
            }
        } else if (error.errorType == 'APEX' && String.isNotBlank(error.className)) {
            message += ' | **Classe:** ' + error.className;
            if (String.isNotBlank(error.methodName)) {
                message += ' | **Méthode:** ' + error.methodName;
            }
        } else if (error.errorType == 'FLOW' && String.isNotBlank(error.flowName)) {
            message += ' | **Flow:** ' + error.flowName;
        }
        message += '\n';

        if (String.isNotBlank(error.recordId)) {
            message += '**Record:** ' + error.objectType + ' (' + error.recordId + ')\n';
        }
        
        // ✅ NOUVEAU: Ajouter User info
        message += '**User:** ' + UserInfo.getName() + ' (' + UserInfo.getUserEmail() + ')\n';
        message += '\n─────────────────────────────────────────────\n\n';

        message += '❗ **Problème**\n\n' + diagnostic.problem + '\n\n';
        message += '🔍 **Cause Racine**\n\n' + diagnostic.rootCause + '\n\n';
        message += '🛠️ **Solution Recommandée**\n\n' + diagnostic.solution;

        if (String.isNotBlank(diagnostic.codeFix)) {
            message += '\n\n─────────────────────────────────────────────\n\n';
            message += '🧩 **Correctif Proposé**\n\n```\n' + diagnostic.codeFix + '\n```';
        }

        if (diagnostic.steps != null && !diagnostic.steps.isEmpty()) {
            message += '\n\n─────────────────────────────────────────────\n\n';
            message += '📋 **Étapes de Correction**\n\n';
            Integer stepNum = 1;
            for (String step : diagnostic.steps) {
                message += stepNum + '. ' + step + '\n';
                stepNum++;
            }
        }
        
        message += '\n─────────────────────────────────────────────\n';
        message += '💡 *Diagnostic généré automatiquement par Azure OpenAI + ErrorDiagnosticService*\n';
        message += '─────────────────────────────────────────────';
        
        // Limiter à 10000 caractères (limite max Salesforce FeedItem.Body)
        if (message.length() > 10000) {
            message = message.substring(0, 9997) + '...';
        }
        
        return message;
    }
    
    /**
     * Construit la description complète du Case
     */
    private static String buildCaseDescription(ErrorInfo error, DiagnosticResult diagnostic, DiagnosticContext context) {
        // ✅ NOUVEAU v2.3: Description structurée selon template GPT
        String description = '=== TECH INFO ===\n\n';
        
        description += 'Source: ' + error.errorType + '\n';

        if (error.errorType == 'APEX') {
            description += 'Component: ' + (String.isNotBlank(error.className) ? error.className : 'N/A') + '\n';
            description += 'Method: ' + (String.isNotBlank(error.methodName) ? error.methodName : 'N/A') + '\n';
            if (error.lineNumber != null) {
                description += 'Line: ' + error.lineNumber + '\n';
            }
        } else if (error.errorType == 'LWC') {
            description += 'Component: ' + (String.isNotBlank(error.componentName) ? error.componentName : 'N/A') + '\n';
            description += 'Method: ' + (String.isNotBlank(error.methodName) ? error.methodName : 'N/A') + '\n';
        } else if (error.errorType == 'FLOW') {
            description += 'Flow: ' + (String.isNotBlank(error.flowName) ? error.flowName : 'N/A') + '\n';
            description += 'API Name: ' + (String.isNotBlank(error.flowApiName) ? error.flowApiName : 'N/A') + '\n';
            if (String.isNotBlank(error.faultElement)) {
                description += 'Failed Element: ' + error.faultElement + '\n';
            }
        }

        if (String.isNotBlank(error.recordId)) {
            description += 'Record: ' + error.objectType + ' (' + error.recordId + ')\n';
        }
        
        description += 'User: ' + UserInfo.getName() + ' (' + UserInfo.getUserEmail() + ')\n';
        description += 'Date: ' + Datetime.now().format('yyyy-MM-dd HH:mm:ss') + '\n\n';
        
        description += '=== ERROR ===\n\n';
        description += 'Message: ' + error.errorMessage + '\n\n';

        if (String.isNotBlank(error.stackTrace)) {
            description += 'Stacktrace (first 1000 chars):\n' + error.stackTrace.left(1000) + '\n\n';
        }
        
        description += '─────────────────────────────────────────────\n';
        description += '💡 Diagnostic IA disponible dans le Feed du Case\n';
        description += '─────────────────────────────────────────────';
        
        return description;
    }
    
    /**
     * Utilitaires
     */
    private static String mapSeverityToPriority(String severity) {
        if (severity == 'CRITICAL') return 'High';
        if (severity == 'HIGH') return 'High';
        if (severity == 'MEDIUM') return 'Medium';
        return 'Low';
    }
    
    /**
     * Génère une signature unique pour regrouper les erreurs identiques
     */
    private static String generateErrorSignature(ErrorInfo error) {
        String signature = error.errorType + '|' + 
                          (String.isNotBlank(error.componentName) ? error.componentName : error.className) + '|' +
                          (String.isNotBlank(error.methodName) ? error.methodName : '') + '|' +
                          (String.isNotBlank(error.errorMessage) ? error.errorMessage.left(100) : '');
        return EncodingUtil.convertToHex(Crypto.generateDigest('MD5', Blob.valueOf(signature))).left(40);
    }
    
    /**
     * Détecte l'environnement (DEV/UAT/PROD) selon l'org
     */
    private static String getEnvironment() {
        String orgId = UserInfo.getOrganizationId();
        String orgName = UserInfo.getOrganizationName();
        
        // Détecter selon le nom de l'org ou l'ID
        if (orgName.containsIgnoreCase('sandbox') || orgName.containsIgnoreCase('dev')) {
            return 'DEV';
        } else if (orgName.containsIgnoreCase('uat') || orgName.containsIgnoreCase('preprod')) {
            return 'UAT';
        }
        
        // Par défaut: PROD
        return 'PROD';
    }
    
    /**
     * Récupère le tag de release (à personnaliser selon votre CI/CD)
     */
    private static String getReleaseTag() {
        // TODO: Intégrer avec votre système CI/CD pour récupérer le tag
        // Pour l'instant, retourner une version basée sur la date
        return 'v' + Datetime.now().format('yyyy.MM.dd');
    }
    
    private static Id getAdminUserId() {
        // Récupérer depuis Custom Metadata ou User
        // Exemple: User admin = [SELECT Id FROM User WHERE Email = 'admin@example.com' LIMIT 1];
        // return admin.Id;
        
        // Par défaut: User actuel ou Queue
        return UserInfo.getUserId(); // À adapter selon tes besoins
    }
}
