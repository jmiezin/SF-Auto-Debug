/**
 * Adaptateur spécialisé pour les erreurs LWC
 * Formate le contexte et construit le prompt optimisé pour Lightning Web Components
 */
public class LWCErrorAdapter {
    
    /**
     * Construit le contexte pour une erreur LWC
     */
    public static ErrorDiagnosticService.DiagnosticContext buildContext(ErrorDiagnosticService.ErrorInfo error) {
        ErrorDiagnosticService.DiagnosticContext context = new ErrorDiagnosticService.DiagnosticContext();
        context.errorType = ErrorDiagnosticService.ErrorType.LWC;
        
        // Informations du composant
        context.componentName = error.componentName;
        context.jsCode = error.jsCode;
        context.metadata = error.metadata;
        
        // Analyser le type d'erreur
        if (String.isNotBlank(error.errorMessage)) {
            String errorMsg = error.errorMessage.toLowerCase();
            if (errorMsg.contains('cannot read property') || errorMsg.contains('undefined')) {
                context.errorCategory = 'NULL_POINTER';
            } else if (errorMsg.contains('network') || errorMsg.contains('fetch')) {
                context.errorCategory = 'NETWORK_ERROR';
            } else if (errorMsg.contains('permission') || errorMsg.contains('access')) {
                context.errorCategory = 'PERMISSION_ERROR';
            } else if (errorMsg.contains('record') && errorMsg.contains('not found')) {
                context.errorCategory = 'RECORD_NOT_FOUND';
            }
        }
        
        return context;
    }
    
    /**
     * Construit le prompt spécialisé pour LWC
     */
    public static String buildPrompt(ErrorDiagnosticService.ErrorInfo error, ErrorDiagnosticService.DiagnosticContext context) {
        String prompt = 'Tu es un expert Lightning Web Components (LWC) Salesforce avec 10+ ans d\'expérience.\n\n';
        prompt += 'Analyse cette erreur LWC et propose un diagnostic précis avec correctif.\n\n';
        prompt += '⚠️ CONTEXTE SALESFORCE UNIQUEMENT:\n';
        prompt += '- Utilise UNIQUEMENT du code Salesforce LWC valide (imports @salesforce/apex, pas de fetch() ni REST APIs externes)\n';
        prompt += '- Les appels serveur se font via méthodes Apex importées: import method from \'@salesforce/apex/ClassName.methodName\'\n';
        prompt += '- Utilise @wire pour les requêtes, méthodes imperatives pour les mutations\n';
        prompt += '- Génère du code qui COMPILE dans Salesforce (pas du JavaScript générique)\n\n';
        
        prompt += '=== INFORMATIONS DU COMPOSANT ===\n';
        if (String.isNotBlank(context.componentName)) {
            prompt += 'Composant: ' + context.componentName + '\n';
        }
        prompt += '\n';
        
        prompt += '=== MESSAGE D\'ERREUR ===\n';
        prompt += error.errorMessage + '\n\n';
        
        if (String.isNotBlank(error.stackTrace)) {
            prompt += '=== STACK TRACE ===\n';
            prompt += error.stackTrace + '\n\n';
        }
        
        if (String.isNotBlank(context.jsCode)) {
            prompt += '=== CODE JAVASCRIPT ===\n';
            prompt += context.jsCode + '\n\n';
        }
        
        if (String.isNotBlank(context.metadata)) {
            prompt += '=== MÉTADONNÉES LWC ===\n';
            prompt += context.metadata + '\n\n';
        }
        
        if (String.isNotBlank(error.contextData)) {
            prompt += '=== CONTEXTE ADDITIONNEL ===\n';
            prompt += error.contextData + '\n\n';
        }
        
        if (String.isNotBlank(context.errorCategory)) {
            prompt += '=== CATÉGORIE D\'ERREUR ===\n';
            prompt += context.errorCategory + '\n\n';
        }
        
        prompt += '=== INSTRUCTIONS ===\n';
        prompt += 'Tu dois analyser cette erreur en profondeur et fournir un diagnostic COMPLET avec correctif concret.\n\n';
        prompt += 'IMPORTANT:\n';
        prompt += '- Si le stack trace est incomplet ou générique (ex: "Script-thrown exception"), ANALYSE EN PROFONDEUR:\n';
        prompt += '  * Le contextData JSON contient configurationData, componentState, metadata, errorDetails\n';
        prompt += '  * Cherche les pageErrors (validation DML) et fieldErrors (champs requis manquants)\n';
        prompt += '  * Identifie les propriétés null, undefined ou invalides dans les données envoyées\n';
        prompt += '  * Vérifie bundleGroupId, quoteId, selectedOptions pour des valeurs manquantes\n';
        prompt += '- Identifie la cause EXACTE (ex: "bundleGroupId est null" pas "données invalides")\n';
        prompt += '- Propose un correctif SALESFORCE LWC valide avec:\n';
        prompt += '  * Imports @salesforce/apex corrects\n';
        prompt += '  * Appels Apex via méthodes importées (pas fetch())\n';
        prompt += '  * Gestion d\'erreur avec .catch(error => { ... })\n';
        prompt += '  * Validation côté client AVANT l\'appel serveur\n\n';
        prompt += 'Réponds UNIQUEMENT en JSON valide avec cette structure EXACTE:\n';
        prompt += '{\n';
        prompt += '  "problem": "Description claire et concise du problème (2-3 phrases)",\n';
        prompt += '  "rootCause": "Cause racine identifiée en détail (propriété null, validation DML échouée, données manquantes, etc.) - SOIS SPÉCIFIQUE",\n';
        prompt += '  "solution": "Solution recommandée étape par étape avec actions concrètes",\n';
        prompt += '  "codeFix": "Code fix au format OBLIGATOIRE ci-dessous - ATTENTION: METTRE UNE VIRGULE APRES CE CHAMP",\n';
        prompt += '  "steps": ["Étape 1", "Étape 2", "Étape 3"],\n';
        prompt += '  "severity": "CRITICAL|HIGH|MEDIUM|LOW"\n';
        prompt += '}\n\n';
        prompt += '⚠️ FORMAT OBLIGATOIRE pour codeFix (MAX 10 LIGNES):\n';
        prompt += '1. EXTRAIS apexClass et apexMethod du contextData JSON\n';
        prompt += '2. GÉNÈRE UNIQUEMENT les imports + validation (PAS toute la méthode)\n';
        prompt += '3. TOTAL: 8-10 lignes MAXIMUM\n\n';
        prompt += 'EXEMPLE EXACT (À SUIVRE STRICTEMENT):\n';
        prompt += '// === IMPORTS (en haut du fichier) ===\\n';
        prompt += 'import { ShowToastEvent } from \\\'lightning/platformShowToastEvent\\\';\\n';
        prompt += 'import APEX_METHOD from \\\'@salesforce/apex/APEX_CLASS.APEX_METHOD\\\';\\n\\n';
        prompt += '// === Dans ACTION(), AVANT l\\\'appel Apex ===\\n';
        prompt += 'if (!this.PROPRIETE) {\\n';
        prompt += '    this.dispatchEvent(new ShowToastEvent({ title: \\\'Erreur\\\', message: \\\'...\\\', variant: \\\'error\\\' }));\\n';
        prompt += '    return;\\n';
        prompt += '}\\n';
        prompt += '\n';
        prompt += 'RÈGLES STRICTES:\n';
        prompt += '- Réponds UNIQUEMENT le JSON, sans texte avant ou après\n';
        prompt += '- OBLIGATOIRE: Mets une VIRGULE après le champ "codeFix"\n';
        prompt += '- OBLIGATOIRE: Extrais apexClass du contextData (ex: "isquote_QuoteLineItemController")\n';
        prompt += '- OBLIGATOIRE: Extrais apexMethod du contextData (ex: "createQuoteLineItems")\n';
        prompt += '- OBLIGATOIRE: Extrais action du contextData (ex: "handleSave")\n';
        prompt += '- Utilise ces valeurs pour générer les imports et le code\n';
        prompt += '- Échappe tous les guillemets simples avec \\\\\\\'\n';
        prompt += '- Échappe tous les sauts de ligne avec \\\\n\n';
        prompt += '- Ne mets PAS de backticks markdown (```) dans le JSON\n';
        prompt += '- CRITIQUE: codeFix = 8-10 lignes MAX (imports + validation UNIQUEMENT)\n';
        prompt += '- NE MONTRE PAS toute la méthode, UNIQUEMENT ce qu\\\'il faut AJOUTER\n';
        prompt += '- NE génère PAS le .then() et .catch(), juste la validation AVANT l\\\'appel\n';
        prompt += 'Sois précis, actionnable, et adapté à Lightning Web Components Salesforce.';
        
        return prompt;
    }
}
