/**
 * Adaptateur spécialisé pour les erreurs Flow
 * Formate le contexte et construit le prompt optimisé pour Salesforce Flow
 */
public class FlowErrorAdapter {
    
    /**
     * Construit le contexte pour une erreur Flow
     */
    public static ErrorDiagnosticService.DiagnosticContext buildContext(ErrorDiagnosticService.ErrorInfo error) {
        ErrorDiagnosticService.DiagnosticContext context = new ErrorDiagnosticService.DiagnosticContext();
        context.errorType = ErrorDiagnosticService.ErrorType.FLOW;
        
        // Informations du Flow
        context.flowName = error.flowName;
        String flowApiNameValue = String.isNotBlank(error.flowApiName) ? error.flowApiName : '';
        if (String.isNotBlank(flowApiNameValue)) {
            context.flowApiName = flowApiNameValue;
        }
        context.faultElement = error.faultElement;
        
        // Récupérer le Flow XML (via Tooling API ou cache)
        if (String.isNotBlank(flowApiNameValue)) {
            context.flowXml = getFlowXML(flowApiNameValue);
        }
        
        return context;
    }
    
    /**
     * Construit le prompt spécialisé pour Flow
     */
    public static String buildPrompt(ErrorDiagnosticService.ErrorInfo error, ErrorDiagnosticService.DiagnosticContext context) {
        String prompt = 'Tu es un expert Salesforce Flow avec 10+ ans d\'expérience.\n\n';
        prompt += 'Analyse cette erreur Flow et propose un diagnostic précis avec correctif.\n\n';
        
        prompt += '=== INFORMATIONS DU FLOW ===\n';
        if (String.isNotBlank(context.flowName)) {
            prompt += 'Flow: ' + context.flowName + '\n';
        }
        String flowApiNameValue = String.isNotBlank(error.flowApiName) ? error.flowApiName : '';
        if (String.isNotBlank(flowApiNameValue)) {
            prompt += 'API Name: ' + flowApiNameValue + '\n';
        }
        if (String.isNotBlank(context.faultElement)) {
            prompt += 'Élément en erreur: ' + context.faultElement + '\n';
        }
        if (String.isNotBlank(error.objectType)) {
            prompt += 'Objet déclencheur: ' + error.objectType + '\n';
        }
        if (String.isNotBlank(error.recordId)) {
            prompt += 'Record ID: ' + error.recordId + '\n';
        }
        prompt += '\n';
        
        prompt += '=== MESSAGE D\'ERREUR ===\n';
        prompt += error.errorMessage + '\n\n';
        
        if (String.isNotBlank(error.stackTrace)) {
            prompt += '=== STACK TRACE ===\n';
            prompt += error.stackTrace + '\n\n';
        }
        
        if (String.isNotBlank(context.flowXml)) {
            prompt += '=== FLOW XML (extrait autour de l\'erreur) ===\n';
            prompt += context.flowXml + '\n\n';
        }
        
        if (String.isNotBlank(error.contextData)) {
            prompt += '=== CONTEXTE ADDITIONNEL ===\n';
            prompt += error.contextData + '\n\n';
        }
        
        prompt += '=== INSTRUCTIONS ===\n';
        prompt += 'Réponds en JSON avec cette structure EXACTE:\n';
        prompt += '{\n';
        prompt += '  "problem": "Description claire et concise du problème",\n';
        prompt += '  "rootCause": "Cause racine identifiée (champ manquant, valeur null, logique incorrecte, subflow inexistant, etc.)",\n';
        prompt += '  "solution": "Solution recommandée étape par étape",\n';
        prompt += '  "codeFix": "Configuration Flow corrigée si applicable (sinon null). Format: description détaillée de la modification à faire dans Flow Builder",\n';
        prompt += '  "steps": ["Étape 1 de correction", "Étape 2", "Étape 3"],\n';
        prompt += '  "severity": "CRITICAL|HIGH|MEDIUM|LOW"\n';
        prompt += '}\n\n';
        prompt += 'Sois précis, actionnable, et adapté à Salesforce Flow Builder.';
        
        return prompt;
    }
    
    /**
     * Récupère le Flow XML via Tooling API
     * Note: Pour l'instant, retourne null (à implémenter si nécessaire)
     */
    private static String getFlowXML(String flowApiName) {
        // TODO: Implémenter récupération via Tooling API
        // Pour l'instant, retourner null
        // L'utilisateur pourra ajouter le Flow XML manuellement dans le Case si nécessaire
        
        // Exemple de code (à décommenter et adapter):
        /*
        try {
            String query = 'SELECT Metadata FROM FlowDefinition WHERE DeveloperName = \'' + 
                          String.escapeSingleQuotes(flowApiName) + '\' LIMIT 1';
            // Utiliser Tooling API pour récupérer le Flow XML
            // ...
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Impossible de récupérer le Flow XML: ' + e.getMessage());
        }
        */
        
        return null;
    }
}
