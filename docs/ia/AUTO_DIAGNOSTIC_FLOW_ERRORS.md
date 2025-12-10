# 🚨 Auto-Diagnostic Flow Errors - Case + Email Admin

## Objectif

Quand un Flow échoue dans Salesforce :
1. ✅ Créer automatiquement un Case
2. ✅ Analyser l'erreur avec Azure OpenAI
3. ✅ Envoyer un email détaillé à l'admin avec :
   - Diagnostic de l'erreur
   - Cause racine identifiée
   - Proposition de correctif
   - Code/configuration corrigée

---

## 🏗️ Architecture

```
Flow échoue
    ↓
Flow "Flow_Error_Handler" (déclenché automatiquement)
    ↓
Apex: FlowErrorDiagnosticService.analyzeAndCreateCase()
    ↓
├─ Appelle OpenAI pour analyser l'erreur
├─ Crée un Case avec toutes les infos
└─ Envoie email à l'admin avec diagnostic + correctif
```

---

## 📋 Composants à Créer

### 1. Classe Apex : FlowErrorDiagnosticService

**Fichier :** `force-app/main/default/classes/FlowErrorDiagnosticService.cls`

```apex
public with sharing class FlowErrorDiagnosticService {
    
    public class FlowErrorInfo {
        public String flowName;
        public String flowApiName;
        public String errorMessage;
        public String errorType;
        public String stackTrace;
        public String flowXml; // XML du Flow (récupéré via Tooling API)
        public String recordId; // ID du record qui a déclenché le Flow
        public String recordType;
        public List<String> recentLogs; // Derniers logs d'exécution
    }
    
    public class DiagnosticResult {
        public String problem;
        public String rootCause;
        public String solution;
        public String codeFix; // Configuration Flow corrigée si applicable
        public List<String> steps;
        public String severity; // CRITICAL, HIGH, MEDIUM, LOW
    }
    
    /**
     * Méthode principale appelée depuis Flow
     * Crée un Case et envoie l'email avec diagnostic IA
     */
    @InvocableMethod(label='Analyser erreur Flow et créer Case' 
                     description='Analyse une erreur Flow avec IA et crée un Case avec email admin')
    public static List<Response> analyzeAndCreateCase(List<FlowErrorInfo> errors) {
        List<Response> responses = new List<Response>();
        
        for (FlowErrorInfo error : errors) {
            try {
                // 1. Analyser l'erreur avec OpenAI
                DiagnosticResult diagnostic = analyzeErrorWithAI(error);
                
                // 2. Créer le Case
                Case newCase = createCase(error, diagnostic);
                
                // 3. Envoyer l'email à l'admin
                sendEmailToAdmin(newCase, error, diagnostic);
                
                responses.add(new Response(true, newCase.Id, 'Case créé avec succès'));
                
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Erreur lors de l\'analyse: ' + e.getMessage());
                responses.add(new Response(false, null, 'Erreur: ' + e.getMessage()));
            }
        }
        
        return responses;
    }
    
    /**
     * Analyse l'erreur avec Azure OpenAI
     */
    private static DiagnosticResult analyzeErrorWithAI(FlowErrorInfo error) {
        // Construire le prompt pour OpenAI
        String prompt = buildDiagnosticPrompt(error);
        
        // Appeler OpenAI
        String aiResponse = OpenAI_Service.sendPrompt(prompt);
        
        // Parser la réponse
        return parseAIResponse(aiResponse, error);
    }
    
    /**
     * Construit le prompt optimisé pour le diagnostic Flow
     */
    private static String buildDiagnosticPrompt(FlowErrorInfo error) {
        String prompt = 'Tu es un expert Salesforce Flow avec 10+ ans d\'expérience.\n\n';
        prompt += 'Analyse cette erreur Flow et propose un diagnostic précis avec correctif.\n\n';
        
        prompt += '=== INFORMATIONS DU FLOW ===\n';
        prompt += 'Nom: ' + error.flowName + '\n';
        prompt += 'API Name: ' + error.flowApiName + '\n';
        prompt += 'Type d\'erreur: ' + error.errorType + '\n';
        prompt += 'Record déclencheur: ' + error.recordType + ' (' + error.recordId + ')\n\n';
        
        prompt += '=== MESSAGE D\'ERREUR ===\n';
        prompt += error.errorMessage + '\n\n';
        
        if (String.isNotBlank(error.stackTrace)) {
            prompt += '=== STACK TRACE ===\n';
            prompt += error.stackTrace + '\n\n';
        }
        
        if (String.isNotBlank(error.flowXml)) {
            prompt += '=== FLOW XML (extrait autour de l\'erreur) ===\n';
            prompt += error.flowXml + '\n\n';
        }
        
        if (error.recentLogs != null && !error.recentLogs.isEmpty()) {
            prompt += '=== LOGS RÉCENTS ===\n';
            for (String log : error.recentLogs) {
                prompt += log + '\n';
            }
            prompt += '\n';
        }
        
        prompt += '=== INSTRUCTIONS ===\n';
        prompt += 'Réponds en JSON avec cette structure EXACTE:\n';
        prompt += '{\n';
        prompt += '  "problem": "Description claire et concise du problème",\n';
        prompt += '  "rootCause": "Cause racine identifiée avec précision (champ manquant, valeur null, logique incorrecte, etc.)",\n';
        prompt += '  "solution": "Solution recommandée étape par étape",\n';
        prompt += '  "codeFix": "Configuration Flow corrigée si applicable (sinon null). Format: description de la modification à faire dans Flow Builder",\n';
        prompt += '  "steps": ["Étape 1 de correction", "Étape 2", "Étape 3"],\n';
        prompt += '  "severity": "CRITICAL|HIGH|MEDIUM|LOW"\n';
        prompt += '}\n\n';
        prompt += 'Sois précis, actionnable, et adapté à Salesforce Flow.';
        
        return prompt;
    }
    
    /**
     * Parse la réponse OpenAI
     */
    private static DiagnosticResult parseAIResponse(String aiResponse, FlowErrorInfo error) {
        DiagnosticResult result = new DiagnosticResult();
        
        try {
            // Essayer de parser le JSON directement
            Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(aiResponse);
            
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
            
        } catch (Exception e) {
            // Si le parsing échoue, utiliser la réponse brute
            System.debug(LoggingLevel.WARN, 'Impossible de parser JSON, utilisation réponse brute: ' + e.getMessage());
            result.problem = 'Erreur lors du parsing de la réponse IA';
            result.rootCause = error.errorMessage;
            result.solution = aiResponse;
            result.severity = 'MEDIUM';
        }
        
        return result;
    }
    
    /**
     * Crée un Case avec toutes les informations
     */
    private static Case createCase(FlowErrorInfo error, DiagnosticResult diagnostic) {
        Case newCase = new Case();
        
        // Informations de base
        newCase.Subject = '[FLOW ERROR] ' + error.flowName + ' - ' + diagnostic.severity;
        newCase.Description = buildCaseDescription(error, diagnostic);
        newCase.Priority = mapSeverityToPriority(diagnostic.severity);
        newCase.Status = 'New';
        newCase.Origin = 'Automated';
        
        // Champs personnalisés (à créer dans ton org)
        // newCase.Flow_Name__c = error.flowName;
        // newCase.Flow_API_Name__c = error.flowApiName;
        // newCase.Error_Type__c = error.errorType;
        // newCase.Record_ID__c = error.recordId;
        // newCase.Severity__c = diagnostic.severity;
        
        // Assigner à l'admin (récupérer depuis Custom Metadata ou User)
        newCase.OwnerId = getAdminUserId();
        
        insert newCase;
        
        return newCase;
    }
    
    /**
     * Construit la description du Case
     */
    private static String buildCaseDescription(FlowErrorInfo error, DiagnosticResult diagnostic) {
        String description = '=== ERREUR FLOW ===\n\n';
        description += 'Flow: ' + error.flowName + ' (' + error.flowApiName + ')\n';
        description += 'Type d\'erreur: ' + error.errorType + '\n';
        description += 'Record déclencheur: ' + error.recordType + ' (' + error.recordId + ')\n';
        description += 'Date: ' + Datetime.now().format() + '\n\n';
        
        description += '=== MESSAGE D\'ERREUR ===\n';
        description += error.errorMessage + '\n\n';
        
        if (String.isNotBlank(error.stackTrace)) {
            description += '=== STACK TRACE ===\n';
            description += error.stackTrace + '\n\n';
        }
        
        description += '=== DIAGNOSTIC IA ===\n\n';
        description += 'PROBLÈME:\n' + diagnostic.problem + '\n\n';
        description += 'CAUSE RACINE:\n' + diagnostic.rootCause + '\n\n';
        description += 'SOLUTION:\n' + diagnostic.solution + '\n\n';
        
        if (String.isNotBlank(diagnostic.codeFix)) {
            description += 'CORRECTIF:\n' + diagnostic.codeFix + '\n\n';
        }
        
        if (diagnostic.steps != null && !diagnostic.steps.isEmpty()) {
            description += 'ÉTAPES DE CORRECTION:\n';
            Integer stepNum = 1;
            for (String step : diagnostic.steps) {
                description += stepNum + '. ' + step + '\n';
                stepNum++;
            }
        }
        
        return description;
    }
    
    /**
     * Envoie l'email à l'admin avec le diagnostic
     */
    private static void sendEmailToAdmin(Case newCase, FlowErrorInfo error, DiagnosticResult diagnostic) {
        // Récupérer l'email de l'admin
        String adminEmail = getAdminEmail();
        if (String.isBlank(adminEmail)) {
            System.debug(LoggingLevel.WARN, 'Email admin non configuré, email non envoyé');
            return;
        }
        
        // Construire le corps de l'email
        String emailBody = buildEmailBody(newCase, error, diagnostic);
        
        // Créer l'email
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[] { adminEmail });
        email.setSubject('[URGENT] Erreur Flow: ' + error.flowName + ' - ' + diagnostic.severity);
        email.setHtmlBody(emailBody);
        email.setPlainTextBody(convertHtmlToPlainText(emailBody));
        
        // Optionnel: Attacher le Case
        email.setWhatId(newCase.Id);
        
        // Envoyer
        try {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
            System.debug('Email envoyé à l\'admin: ' + adminEmail);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Erreur envoi email: ' + e.getMessage());
        }
    }
    
    /**
     * Construit le corps HTML de l'email
     */
    private static String buildEmailBody(Case newCase, FlowErrorInfo error, DiagnosticResult diagnostic) {
        String html = '<html><body style="font-family: Arial, sans-serif;">';
        
        // Header
        html += '<div style="background-color: #f44336; color: white; padding: 20px;">';
        html += '<h1 style="margin: 0;">🚨 Erreur Flow Détectée</h1>';
        html += '</div>';
        
        // Informations du Case
        html += '<div style="padding: 20px; background-color: #f5f5f5;">';
        html += '<h2>Case #' + newCase.CaseNumber + '</h2>';
        html += '<p><strong>Lien:</strong> <a href="' + URL.getSalesforceBaseUrl().toExternalForm() + '/' + newCase.Id + '">Voir le Case</a></p>';
        html += '</div>';
        
        // Informations du Flow
        html += '<div style="padding: 20px;">';
        html += '<h2>📋 Informations du Flow</h2>';
        html += '<table style="width: 100%; border-collapse: collapse;">';
        html += '<tr><td style="padding: 10px; border: 1px solid #ddd;"><strong>Flow:</strong></td><td style="padding: 10px; border: 1px solid #ddd;">' + error.flowName + '</td></tr>';
        html += '<tr><td style="padding: 10px; border: 1px solid #ddd;"><strong>API Name:</strong></td><td style="padding: 10px; border: 1px solid #ddd;">' + error.flowApiName + '</td></tr>';
        html += '<tr><td style="padding: 10px; border: 1px solid #ddd;"><strong>Type d\'erreur:</strong></td><td style="padding: 10px; border: 1px solid #ddd;">' + error.errorType + '</td></tr>';
        html += '<tr><td style="padding: 10px; border: 1px solid #ddd;"><strong>Record déclencheur:</strong></td><td style="padding: 10px; border: 1px solid #ddd;">' + error.recordType + ' (' + error.recordId + ')</td></tr>';
        html += '<tr><td style="padding: 10px; border: 1px solid #ddd;"><strong>Date:</strong></td><td style="padding: 10px; border: 1px solid #ddd;">' + Datetime.now().format() + '</td></tr>';
        html += '</table>';
        html += '</div>';
        
        // Message d'erreur
        html += '<div style="padding: 20px; background-color: #fff3cd;">';
        html += '<h2>❌ Message d\'Erreur</h2>';
        html += '<pre style="background-color: #f8f9fa; padding: 15px; border-radius: 5px; overflow-x: auto;">' + escapeHtml(error.errorMessage) + '</pre>';
        html += '</div>';
        
        // Diagnostic IA
        html += '<div style="padding: 20px;">';
        html += '<h2>🤖 Diagnostic IA</h2>';
        
        html += '<div style="margin-bottom: 20px;">';
        html += '<h3 style="color: #d32f2f;">Problème Identifié</h3>';
        html += '<p style="background-color: #ffebee; padding: 15px; border-left: 4px solid #d32f2f;">' + escapeHtml(diagnostic.problem) + '</p>';
        html += '</div>';
        
        html += '<div style="margin-bottom: 20px;">';
        html += '<h3 style="color: #f57c00;">Cause Racine</h3>';
        html += '<p style="background-color: #fff3e0; padding: 15px; border-left: 4px solid #f57c00;">' + escapeHtml(diagnostic.rootCause) + '</p>';
        html += '</div>';
        
        html += '<div style="margin-bottom: 20px;">';
        html += '<h3 style="color: #1976d2;">Solution Recommandée</h3>';
        html += '<p style="background-color: #e3f2fd; padding: 15px; border-left: 4px solid #1976d2;">' + escapeHtml(diagnostic.solution) + '</p>';
        html += '</div>';
        
        if (String.isNotBlank(diagnostic.codeFix)) {
            html += '<div style="margin-bottom: 20px;">';
            html += '<h3 style="color: #388e3c;">Correctif Proposé</h3>';
            html += '<pre style="background-color: #e8f5e9; padding: 15px; border-left: 4px solid #388e3c; overflow-x: auto;">' + escapeHtml(diagnostic.codeFix) + '</pre>';
            html += '</div>';
        }
        
        if (diagnostic.steps != null && !diagnostic.steps.isEmpty()) {
            html += '<div style="margin-bottom: 20px;">';
            html += '<h3 style="color: #7b1fa2;">Étapes de Correction</h3>';
            html += '<ol style="background-color: #f3e5f5; padding: 20px 40px; border-left: 4px solid #7b1fa2;">';
            for (String step : diagnostic.steps) {
                html += '<li style="margin-bottom: 10px;">' + escapeHtml(step) + '</li>';
            }
            html += '</ol>';
            html += '</div>';
        }
        
        html += '</div>';
        
        // Footer
        html += '<div style="padding: 20px; background-color: #f5f5f5; text-align: center; color: #666;">';
        html += '<p>Ce message a été généré automatiquement par le système de diagnostic Flow.</p>';
        html += '<p>Case #' + newCase.CaseNumber + ' | ' + Datetime.now().format() + '</p>';
        html += '</div>';
        
        html += '</body></html>';
        
        return html;
    }
    
    /**
     * Utilitaires
     */
    private static String escapeHtml(String input) {
        if (String.isBlank(input)) return '';
        return input.replace('&', '&amp;')
                   .replace('<', '&lt;')
                   .replace('>', '&gt;')
                   .replace('"', '&quot;')
                   .replace('\'', '&#39;')
                   .replace('\n', '<br>');
    }
    
    private static String convertHtmlToPlainText(String html) {
        // Version simplifiée - enlever les balises HTML
        return html.replaceAll('<[^>]+>', '').replace('&nbsp;', ' ');
    }
    
    private static String mapSeverityToPriority(String severity) {
        if (severity == 'CRITICAL') return 'High';
        if (severity == 'HIGH') return 'High';
        if (severity == 'MEDIUM') return 'Medium';
        return 'Low';
    }
    
    private static Id getAdminUserId() {
        // Récupérer depuis Custom Metadata ou User
        // Exemple: User admin = [SELECT Id FROM User WHERE Email = 'admin@example.com' LIMIT 1];
        // return admin.Id;
        
        // Par défaut: Queue ou User système
        return UserInfo.getUserId(); // À adapter selon tes besoins
    }
    
    private static String getAdminEmail() {
        // Récupérer depuis Custom Metadata
        // Exemple: Admin_Config__mdt config = [SELECT Admin_Email__c FROM Admin_Config__mdt LIMIT 1];
        // return config.Admin_Email__c;
        
        // Par défaut
        return UserInfo.getUserEmail(); // À adapter selon tes besoins
    }
    
    /**
     * Classe de réponse pour InvocableMethod
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
}
```

---

### 2. Flow : Flow_Error_Handler

**Déclenchement :** Automatique quand un Flow échoue (via Platform Event ou autre mécanisme)

**Structure :**
```
1. Get Records → Récupérer les infos de l'erreur Flow
2. Apex Action → FlowErrorDiagnosticService.analyzeAndCreateCase()
   Inputs:
   - flowName: {!$Flow.FailedFlowName}
   - flowApiName: {!$Flow.FailedFlowApiName}
   - errorMessage: {!$Flow.ErrorMessage}
   - errorType: {!$Flow.ErrorType}
   - recordId: {!$Record.Id}
   - recordType: {!$Record.Type}
3. (Optionnel) Send Email → Confirmation
```

**Note :** Salesforce ne permet pas de capturer directement les erreurs de Flow. Il faut utiliser :
- **Platform Events** : Publier un événement quand un Flow échoue
- **Scheduled Flow** : Vérifier périodiquement les logs d'erreur
- **Apex Trigger** : Intercepter les erreurs si le Flow appelle Apex

---

### 3. Alternative : Flow qui surveille les erreurs

**Flow :** `Flow_Error_Monitor`

**Déclenchement :** Scheduled (toutes les heures)

**Logique :**
```
1. Get Records → FlowInterview (via Tooling API ou logs)
   WHERE Status = 'Failed' AND CreatedDate = LAST_HOUR
2. Loop → Pour chaque Flow en erreur
   ├─ Get Records → Récupérer détails du Flow
   ├─ Get Records → Récupérer logs d'erreur
   └─ Apex Action → FlowErrorDiagnosticService.analyzeAndCreateCase()
```

---

### 4. Custom Metadata : Admin_Config__mdt

**Pour configurer l'email admin :**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>Admin Email</label>
    <protected>false</protected>
    <values>
        <field>Admin_Email__c</field>
        <value>admin@isonic.ai</value>
    </values>
</CustomMetadata>
```

---

## 🚀 Utilisation

### Scénario 1 : Flow échoue

1. Flow `Quote_Trigger_Update` échoue sur un record Quote
2. Flow `Flow_Error_Handler` détecte l'erreur
3. Appelle `FlowErrorDiagnosticService.analyzeAndCreateCase()`
4. **Résultat :**
   - ✅ Case créé avec toutes les infos
   - ✅ Email envoyé à admin@isonic.ai avec :
     - Diagnostic IA complet
     - Cause racine identifiée
     - Solution proposée
     - Correctif détaillé

### Scénario 2 : Email reçu par l'admin

**Sujet :** `[URGENT] Erreur Flow: Quote_Trigger_Update - CRITICAL`

**Contenu :**
```
🚨 Erreur Flow Détectée

Case #00001234
Lien: https://isonic.my.salesforce.com/500xx0000abc123

📋 Informations du Flow
Flow: Quote_Trigger_Update
API Name: Quote_Trigger_Update
Type d'erreur: Field Not Found
Record déclencheur: Quote (0Q0xx000000abc123)

❌ Message d'Erreur
Field Owner_Role__c does not exist on Quote object

🤖 Diagnostic IA

Problème Identifié
Le Flow tente d'accéder au champ Owner_Role__c qui n'existe pas sur l'objet Quote.

Cause Racine
Le champ personnalisé Owner_Role__c a été supprimé ou n'a pas été déployé dans cette org.

Solution Recommandée
1. Vérifier si le champ existe dans Setup → Object Manager → Quote → Fields
2. Si non, modifier le Flow pour utiliser un champ existant (ex: Owner.Profile.Name)
3. Tester avec un record Quote

Correctif Proposé
Dans Flow Builder, modifier la décision "Check Owner Role":
- Remplacer {!$Record.Owner_Role__c} par {!$Record.Owner.Profile.Name}
- Ou ajouter une vérification ISBLANK() avant utilisation

Étapes de Correction
1. Ouvrir Setup → Flows → Quote_Trigger_Update
2. Trouver la décision "Check Owner Role"
3. Modifier la condition pour utiliser Owner.Profile.Name
4. Activer le Flow
5. Tester avec un record Quote
```

---

## 📊 Champs Custom sur Case (Optionnel)

Pour mieux organiser les Cases :

```xml
<!-- Case.Flow_Name__c (Text) -->
<!-- Case.Flow_API_Name__c (Text) -->
<!-- Case.Error_Type__c (Picklist: Field Not Found, Null Pointer, Validation Error, etc.) -->
<!-- Case.Severity__c (Picklist: CRITICAL, HIGH, MEDIUM, LOW) -->
<!-- Case.Record_ID__c (Text) -->
```

---

## 🎯 Prochaines Étapes

1. ✅ Créer la classe `FlowErrorDiagnosticService`
2. ✅ Créer le Flow `Flow_Error_Handler`
3. ✅ Configurer Custom Metadata pour email admin
4. ✅ Tester avec une erreur Flow volontaire
5. ✅ Déployer en production

**Veux-tu que je crée ces fichiers maintenant ?**
