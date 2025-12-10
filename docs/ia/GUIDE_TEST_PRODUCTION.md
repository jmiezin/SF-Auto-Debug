# 🧪 Guide de Test du Système de Diagnostic IA + Logging

**Date**: 2025-01-09
**Org**: production
**Système**: Unified Diagnostics & Logging

---

## 🎯 TESTS À EFFECTUER

### 1️⃣ TEST UNIVERSAL LOGGER

#### Via Developer Console

**Setup → Developer Console → Debug → Open Execute Anonymous Window**

```apex
// Test 1: Logging simple
UniversalLogger.info('TestProduction', 'testLogger', 'Test du système de logging en production');

// Test 2: Logging avec contexte
Map<String, Object> context = new Map<String, Object>{
    'userId' => UserInfo.getUserId(),
    'timestamp' => System.now(),
    'environment' => 'production'
};
UniversalLogger.debug('TestProduction', 'testLogger', 'Test avec contexte enrichi', context);

// Test 3: Logging d'erreur
try {
    throw new System.NullPointerException();
} catch (Exception e) {
    UniversalLogger.error('TestProduction', 'testLogger', 'Test erreur simulée', e, context);
}

System.debug('✅ Test UniversalLogger terminé');
```

**Résultat attendu dans les logs** :
```
[INFO] [TestProduction] [testLogger] [2025-01-09 22:XX:XX] Test du système de logging en production
  👤 User: Votre Nom (005xxx)

[DEBUG] [TestProduction] [testLogger] [2025-01-09 22:XX:XX] Test avec contexte enrichi
  👤 User: Votre Nom (005xxx)
  📋 Context: {"userId":"005xxx","timestamp":"...","environment":"production"}

[ERROR] [TestProduction] [testLogger] [2025-01-09 22:XX:XX] Test erreur simulée
  ❌ Exception Type: System.NullPointerException
  ❌ Message: Script-thrown exception
  ❌ Line: 14
  👤 User: Votre Nom (005xxx)
  📋 Context: {...}
```

---

### 2️⃣ TEST AZURE KEY VAULT

#### Via Developer Console

```apex
// Test connexion Azure Key Vault
Map<String, String> config = AzureKeyVaultService.getAzureOpenAIConfig();

System.debug('=== AZURE KEY VAULT CONFIG ===');
System.debug('API Key found: ' + (config.get('apiKey') != null && config.get('apiKey') != ''));
System.debug('API Key length: ' + (config.get('apiKey') != null ? config.get('apiKey').length() : 0));
System.debug('Endpoint: ' + config.get('endpoint'));
System.debug('Deployment: ' + config.get('deployment'));
System.debug('===========================');
```

**Résultat attendu** :
```
=== AZURE KEY VAULT CONFIG ===
API Key found: true
API Key length: 32 (ou plus)
Endpoint: https://isonic-openai-eu.openai.azure.com/
Deployment: gpt-4o
===========================
```

**❌ Si erreur** :
- Vérifier que `Azure_AD_Config__mdt` est configuré
- Vérifier les permissions Azure Key Vault pour le Service Principal

---

### 3️⃣ TEST OPENAI SERVICE

#### Via Developer Console

```apex
// Test simple appel OpenAI
try {
    String response = OpenAI_Service.sendPrompt('Réponds uniquement "SYSTEM OK"');
    System.debug('✅ OpenAI Response: ' + response);
} catch (Exception e) {
    System.debug('❌ OpenAI Error: ' + e.getMessage());
    System.debug('Stack: ' + e.getStackTraceString());
}
```

**Résultat attendu** :
```
✅ OpenAI Response: SYSTEM OK
```

**❌ Si erreur** :
- `Unauthorized` → Vérifier l'API Key dans Key Vault
- `Timeout` → Vérifier l'endpoint
- `Deployment not found` → Vérifier le nom du deployment

---

### 4️⃣ TEST DIAGNOSTIC IA - ERREUR APEX

#### Via Developer Console

**Test complet avec création de Case** :

```apex
// Simuler une erreur Apex
ErrorDiagnosticService.ErrorInfo error = new ErrorDiagnosticService.ErrorInfo();
error.errorType = 'APEX';
error.componentName = 'TestProductionDiagnostic';
error.className = 'QuoteService';
error.methodName = 'calculateTotal';
error.errorMessage = 'System.NullPointerException: Attempt to de-reference a null object';
error.stackTrace = 'Class.QuoteService.calculateTotal: line 127, column 1\nClass.QuoteController.processQuote: line 45';
error.lineNumber = 127;
error.recordId = null;
error.objectType = 'Quote';

// Lancer le diagnostic
List<ErrorDiagnosticService.Response> responses = 
    ErrorDiagnosticService.diagnoseAndCreateCase(new List<ErrorDiagnosticService.ErrorInfo>{ error });

// Afficher le résultat
System.debug('=== RÉSULTAT DIAGNOSTIC ===');
System.debug('Success: ' + responses[0].success);
System.debug('CaseId: ' + responses[0].caseId);
System.debug('Message: ' + responses[0].message);
System.debug('=========================');

// Récupérer le Case créé
if (responses[0].success) {
    Case diagnosticCase = [
        SELECT Id, CaseNumber, Subject, Description, Priority, Status, Type, OwnerId
        FROM Case 
        WHERE Id = :responses[0].caseId 
        LIMIT 1
    ];
    
    System.debug('=== CASE CRÉÉ ===');
    System.debug('Case Number: ' + diagnosticCase.CaseNumber);
    System.debug('Subject: ' + diagnosticCase.Subject);
    System.debug('Priority: ' + diagnosticCase.Priority);
    System.debug('Status: ' + diagnosticCase.Status);
    System.debug('Type: ' + diagnosticCase.Type);
    System.debug('================');
}
```

**Résultat attendu** :
```
=== RÉSULTAT DIAGNOSTIC ===
Success: true
CaseId: 500xxxxxxxxxxxxx
Message: Case créé avec succès
=========================

=== CASE CRÉÉ ===
Case Number: 00001234
Subject: [APEX ERROR] TestProductionDiagnostic - MEDIUM
Priority: Medium
Status: New
Type: APEX
================
```

**Vérification dans Salesforce UI** :
1. Aller dans Cases
2. Chercher le Case créé (numéro affiché)
3. Vérifier le Feed du Case → **Diagnostic IA doit être posté**

---

### 5️⃣ TEST DIAGNOSTIC IA - ERREUR FLOW

#### Via Developer Console

```apex
ErrorDiagnosticService.ErrorInfo error = new ErrorDiagnosticService.ErrorInfo();
error.errorType = 'FLOW';
error.componentName = 'Test_Flow_Diagnostic';
error.flowName = 'Quote_Trigger_Update';
error.flowApiName = 'Quote_Trigger_Update';
error.errorMessage = 'The flow failed to access the value for myVariable_current.Owner_Role__c because it hasn\'t been set or assigned.';
error.faultElement = 'Decision_Check_Owner_Role';
error.recordId = null;
error.objectType = 'Quote';

List<ErrorDiagnosticService.Response> responses = 
    ErrorDiagnosticService.diagnoseAndCreateCase(new List<ErrorDiagnosticService.ErrorInfo>{ error });

System.debug('CaseId: ' + responses[0].caseId);

// Voir le diagnostic
Case c = [SELECT Subject, Description FROM Case WHERE Id = :responses[0].caseId];
System.debug('Subject: ' + c.Subject);
```

**Résultat attendu** :
```
CaseId: 500xxxxxxxxxxxxx
Subject: [FLOW ERROR] Test_Flow_Diagnostic - HIGH
```

---

### 6️⃣ TEST DIAGNOSTIC IA - ERREUR LWC (via LWC)

#### Dans un LWC de test

**Créer un fichier temporaire** : `testDiagnostic.js`

```javascript
import { LightningElement } from 'lwc';
import diagnoseLWCError from '@salesforce/apex/ErrorDiagnosticService.diagnoseLWCError';

export default class TestDiagnostic extends LightningElement {
    
    async connectedCallback() {
        try {
            // Simuler une erreur
            const caseId = await diagnoseLWCError({
                componentName: 'testDiagnostic',
                errorMessage: 'Cannot read property recordId of undefined',
                stackTrace: 'at testDiagnostic.handleClick (testDiagnostic.js:15:20)',
                recordId: null,
                objectType: 'Quote',
                contextData: JSON.stringify({
                    action: 'testDiagnostic',
                    timestamp: new Date().toISOString(),
                    userAgent: navigator.userAgent
                })
            });
            
            console.log('✅ Case créé:', caseId);
        } catch (error) {
            console.error('❌ Erreur:', error);
        }
    }
}
```

**OU via Developer Console (sans LWC)** :

```apex
// Appeler directement la méthode diagnoseLWCError
String caseId = ErrorDiagnosticService.diagnoseLWCError(
    'testDiagnosticLWC',
    'Cannot read property recordId of undefined',
    'at testDiagnostic.handleClick (testDiagnostic.js:15:20)',
    null,
    'Quote',
    '{"action":"test","timestamp":"2025-01-09T22:00:00Z"}'
);

System.debug('CaseId créé: ' + caseId);

// Vérifier le Case
Case lwcCase = [SELECT Subject, Description FROM Case WHERE Id = :caseId];
System.debug('Subject: ' + lwcCase.Subject);
```

---

### 7️⃣ TEST LOGGING DEPUIS LWC

#### Dans un LWC existant (ex: isquote_bundleConfigurator)

**Ajouter temporairement dans `connectedCallback()`** :

```javascript
import log from 'c/universalLogger';

connectedCallback() {
    // Test logging
    log.info('isquote_bundleConfigurator', 'connectedCallback', 'Test logging depuis production', {
        recordId: this.recordId,
        bundleId: this.bundleId,
        environment: 'production'
    });
    
    // ... reste du code
}
```

**Résultat** : Vérifier dans Debug Logs que le log apparaît avec le bon format.

---

## 🧪 TEST COMPLET DE BOUT EN BOUT

### Scénario : Simuler une vraie erreur dans un Flow

1. **Créer un Flow de test** :
   - Setup → Flows → New Flow
   - Type: Record-Triggered Flow
   - Object: Account
   - Trigger: After Update
   
2. **Ajouter un élément qui va échouer** :
   - Get Records: Chercher un champ qui n'existe pas
   - Ex: Get field `NonExistentField__c`

3. **Ajouter Fault Path** :
   - Sur l'élément, ajouter Fault Connector
   - Action Apex: `ErrorDiagnosticService.diagnoseAndCreateCase`
   - Mapper les champs :
     - errorType: "FLOW"
     - flowName: {!$Flow.Label}
     - errorMessage: {!$Flow.FaultMessage}
     - faultElement: {!$Flow.CurrentElement}

4. **Activer le Flow**

5. **Déclencher l'erreur** :
   - Modifier un Account
   - Vérifier qu'un Case est créé automatiquement
   - Vérifier le diagnostic IA dans le Feed

---

## 📊 VÉRIFICATIONS POST-TEST

### 1. Vérifier les Cases créés

```sql
SELECT Id, CaseNumber, Subject, Type, Priority, Status, CreatedDate, OwnerId
FROM Case
WHERE Type IN ('APEX', 'FLOW', 'LWC')
  AND CreatedDate = TODAY
ORDER BY CreatedDate DESC
```

### 2. Vérifier les FeedItems (diagnostics IA)

```sql
SELECT Id, ParentId, Body, CreatedDate, CreatedById
FROM FeedItem
WHERE ParentId IN (
    SELECT Id FROM Case WHERE Type IN ('APEX', 'FLOW', 'LWC') AND CreatedDate = TODAY
)
ORDER BY CreatedDate DESC
```

### 3. Vérifier les Debug Logs

**Setup → Debug Logs → View**

Filtrer sur :
- `[INFO]` pour les logs info
- `[ERROR]` pour les logs erreur
- `[DEBUG]` pour les logs debug
- `🔧 [DIAGNOSTIC]` pour les logs de diagnostic

---

## 🚨 TROUBLESHOOTING

### Problème : Pas de Case créé

**Vérifier** :
1. Azure Key Vault accessible ?
   ```apex
   Map<String, String> config = AzureKeyVaultService.getAzureOpenAIConfig();
   System.debug(config);
   ```

2. OpenAI répond ?
   ```apex
   String response = OpenAI_Service.sendPrompt('test');
   System.debug(response);
   ```

3. Logs d'erreur dans Debug Logs ?
   - Chercher `❌ [DIAGNOSTIC]`

### Problème : Case créé mais pas de diagnostic dans le Feed

**Vérifier** :
1. Chatter activé sur l'objet Case ?
   - Setup → Chatter Settings → Enable Feed Tracking for Case

2. Permissions de l'utilisateur système ?
   - L'utilisateur doit pouvoir poster dans Chatter

3. Logs d'erreur ?
   ```
   ❌ [DIAGNOSTIC] Erreur lors de la création du post Feed
   ```

### Problème : Diagnostic IA vide ou "null"

**Vérifier** :
1. Parsing JSON ?
   - Logs : `⚠️ [DIAGNOSTIC] Erreur parsing JSON`
   
2. Réponse OpenAI malformée ?
   - Vérifier les logs de `parseAIResponse()`

3. Prompt envoyé correct ?
   - Ajouter debug avant appel OpenAI

---

## 📋 CHECKLIST DE VALIDATION COMPLÈTE

### Système de Logging
- [ ] UniversalLogger.info() fonctionne
- [ ] UniversalLogger.debug() avec contexte fonctionne
- [ ] UniversalLogger.error() avec exception fonctionne
- [ ] Format des logs conforme au standard
- [ ] Logging depuis LWC fonctionne

### Intégration Azure
- [ ] Azure Key Vault retourne les secrets
- [ ] API Key valide et non vide
- [ ] Endpoint correct
- [ ] Deployment name correct

### Service OpenAI
- [ ] Appel OpenAI réussit
- [ ] Réponse valide et parsable
- [ ] Gestion d'erreurs fonctionne

### Diagnostic IA
- [ ] Diagnostic Apex crée un Case
- [ ] Diagnostic Flow crée un Case
- [ ] Diagnostic LWC crée un Case
- [ ] Subject du Case correct
- [ ] Priority mappée selon severity
- [ ] Diagnostic IA dans le Feed du Case
- [ ] Format JSON du diagnostic valide

### Tests Automatisés
- [ ] ErrorDiagnosticServiceTest: 11/11 ✅
- [ ] UniversalLoggerTest: 10/10 ✅
- [ ] Coverage >75% sur toutes les classes

---

## 🎯 TESTS RECOMMANDÉS PAR ENVIRONNEMENT

### Sandbox / Dev
- ✅ Tous les tests ci-dessus
- ✅ Tests avec vraies erreurs
- ✅ Tests de charge (multiple errors)

### Production
- ✅ Test UniversalLogger uniquement
- ✅ Test Azure Key Vault (sans créer de Case)
- ⚠️ Test diagnostic complet **UNE SEULE FOIS** pour validation
- ❌ **NE PAS** créer de multiples Cases de test

---

## 📞 CONTACT

En cas de problème :
1. Vérifier les Debug Logs
2. Vérifier la doc `/docs/logging/STANDARD_LOGGING.md`
3. Consulter le System Prompt `/docs/logging/SYSTEM_PROMPT_DIAGNOSTICS_ASSISTANT.md`

---

**Date de création** : 2025-01-09
**Version** : 1.0
**Auteur** : Salesforce Diagnostics System
