/**
 * Adaptateur spécialisé pour les erreurs Apex
 * Formate le contexte et construit le prompt optimisé pour Apex
 */
public class ApexErrorAdapter {
    
    /**
     * Construit le contexte pour une erreur Apex
     */
    public static ErrorDiagnosticService.DiagnosticContext buildContext(ErrorDiagnosticService.ErrorInfo error) {
        ErrorDiagnosticService.DiagnosticContext context = new ErrorDiagnosticService.DiagnosticContext();
        context.errorType = ErrorDiagnosticService.ErrorType.APEX;
        
        // Extraire info du stack trace Apex
        // Format: Class.QuoteService.calculateTotal: line 127
        if (String.isNotBlank(error.stackTrace)) {
            context.className = extractClassName(error.stackTrace);
            context.methodName = extractMethodName(error.stackTrace);
            context.lineNumber = extractLineNumber(error.stackTrace);
        } else {
            // Utiliser les valeurs directes si disponibles
            context.className = error.className;
            context.methodName = error.methodName;
            context.lineNumber = error.lineNumber;
        }
        
        // Récupérer le code source autour de la ligne d'erreur
        if (String.isNotBlank(context.className) && context.lineNumber != null) {
            context.sourceCode = getSourceCodeAroundLine(context.className, context.lineNumber);
        }
        
        return context;
    }
    
    /**
     * Construit le prompt spécialisé pour Apex
     */
    public static String buildPrompt(ErrorDiagnosticService.ErrorInfo error, ErrorDiagnosticService.DiagnosticContext context) {
        String prompt = 'Tu es un expert Apex Salesforce avec 10+ ans d\'expérience.\n\n';
        prompt += 'Analyse cette erreur Apex et propose un diagnostic précis avec correctif.\n\n';
        
        prompt += '=== INFORMATIONS DE L\'ERREUR ===\n';
        if (String.isNotBlank(context.className)) {
            prompt += 'Classe: ' + context.className + '\n';
        }
        if (String.isNotBlank(context.methodName)) {
            prompt += 'Méthode: ' + context.methodName + '\n';
        }
        if (context.lineNumber != null) {
            prompt += 'Ligne: ' + context.lineNumber + '\n';
        }
        prompt += '\n';
        
        prompt += '=== MESSAGE D\'ERREUR ===\n';
        prompt += error.errorMessage + '\n\n';
        
        if (String.isNotBlank(error.stackTrace)) {
            prompt += '=== STACK TRACE ===\n';
            prompt += error.stackTrace + '\n\n';
        }
        
        if (String.isNotBlank(context.sourceCode)) {
            prompt += '=== CODE SOURCE (autour de la ligne d\'erreur) ===\n';
            prompt += context.sourceCode + '\n\n';
        }
        
        if (String.isNotBlank(error.contextData)) {
            prompt += '=== CONTEXTE ADDITIONNEL ===\n';
            prompt += error.contextData + '\n\n';
        }
        
        prompt += '=== INSTRUCTIONS ===\n';
        prompt += 'Réponds en JSON avec cette structure EXACTE:\n';
        prompt += '{\n';
        prompt += '  "problem": "Description claire et concise du problème",\n';
        prompt += '  "rootCause": "Cause racine identifiée avec précision (variable null, champ manquant, requête SOQL incorrecte, etc.)",\n';
        prompt += '  "solution": "Solution recommandée étape par étape",\n';
        prompt += '  "codeFix": "Code Apex corrigé si applicable (sinon null). Format: code Apex complet avec la correction",\n';
        prompt += '  "steps": ["Étape 1 de correction", "Étape 2", "Étape 3"],\n';
        prompt += '  "severity": "CRITICAL|HIGH|MEDIUM|LOW"\n';
        prompt += '}\n\n';
        prompt += 'Sois précis, actionnable, et adapté à Apex Salesforce.';
        
        return prompt;
    }
    
    /**
     * Extrait le nom de la classe du stack trace
     */
    private static String extractClassName(String stackTrace) {
        if (String.isBlank(stackTrace)) return null;
        
        // Format: Class.ClassName.methodName: line X
        Pattern p = Pattern.compile('Class\\.([^.]+)\\.');
        Matcher m = p.matcher(stackTrace);
        if (m.find()) {
            return m.group(1);
        }
        return null;
    }
    
    /**
     * Extrait le nom de la méthode du stack trace
     */
    private static String extractMethodName(String stackTrace) {
        if (String.isBlank(stackTrace)) return null;
        
        // Format: Class.ClassName.methodName: line X
        Pattern p = Pattern.compile('Class\\.[^.]+\\.([^:]+):');
        Matcher m = p.matcher(stackTrace);
        if (m.find()) {
            return m.group(1);
        }
        return null;
    }
    
    /**
     * Extrait le numéro de ligne du stack trace
     */
    private static Integer extractLineNumber(String stackTrace) {
        if (String.isBlank(stackTrace)) return null;
        
        // Format: line 127
        Pattern p = Pattern.compile('line (\\d+)');
        Matcher m = p.matcher(stackTrace);
        if (m.find()) {
            return Integer.valueOf(m.group(1));
        }
        return null;
    }
    
    /**
     * Récupère le code source autour de la ligne d'erreur
     * Note: Cette méthode nécessite l'accès au code source via Tooling API
     * Pour l'instant, retourne null (à implémenter si nécessaire)
     */
    private static String getSourceCodeAroundLine(String className, Integer lineNumber) {
        // TODO: Implémenter récupération via Tooling API
        // Pour l'instant, retourner null
        // L'utilisateur pourra ajouter le code manuellement dans le Case si nécessaire
        return null;
    }
}
