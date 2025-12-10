# 🚀 DÉPLOIEMENT COMPLET - Système Diagnostic IA + Universal Logging

**Date**: 2025-01-09
**Org Source**: `source-dev`
**Org Cible**: `production`

---

## 📦 COMPOSANTS À DÉPLOYER

### Classes Apex (9 classes + tests)

#### 1️⃣ Système de Diagnostic IA
- ✅ `ErrorDiagnosticService.cls` + `ErrorDiagnosticServiceTest.cls`
- ✅ `ApexErrorAdapter.cls`
- ✅ `LWCErrorAdapter.cls`
- ✅ `FlowErrorAdapter.cls`

#### 2️⃣ Universal Logging System ⭐ NOUVEAU
- ✅ `UniversalLogger.cls` + `UniversalLoggerTest.cls`

#### 3️⃣ Intégration Azure
- ✅ `AzureKeyVaultService.cls`
- ✅ `OpenAI_Service.cls`

### LWC

- ✅ `universalLogger` (JavaScript module) ⭐ NOUVEAU

### Custom Metadata Types

- ✅ `Azure_AD_Config__mdt`

### Flows (optionnel)

- ✅ `Case_Error_Email_Sender.flow-meta.xml`

---

## 🎯 ÉTAPE 1 : VÉRIFICATION PRÉ-DÉPLOIEMENT

### 1.1 Vérifier la couverture de tests locale

```bash
# Exécuter les tests localement pour vérifier
sf apex run test \
  --test-level RunLocalTests \
  --target-org production \
  --wait 10 \
  --result-format human
```

**Résultat attendu**: Coverage > 75%

### 1.2 Vérifier les dépendances

```bash
# Vérifier que Custom Metadata Type existe
sf data query \
  --query "SELECT QualifiedApiName FROM EntityDefinition WHERE QualifiedApiName = 'Azure_AD_Config__mdt'" \
  --target-org production
```

---

## 🚀 ÉTAPE 2 : DÉPLOIEMENT DES CLASSES APEX

### 2.1 Déployer toutes les classes en une fois

```bash
sf project deploy start \
  --source-dir force-app/main/default/classes/ErrorDiagnosticService.cls \
  --source-dir force-app/main/default/classes/ErrorDiagnosticServiceTest.cls \
  --source-dir force-app/main/default/classes/ApexErrorAdapter.cls \
  --source-dir force-app/main/default/classes/LWCErrorAdapter.cls \
  --source-dir force-app/main/default/classes/FlowErrorAdapter.cls \
  --source-dir force-app/main/default/classes/UniversalLogger.cls \
  --source-dir force-app/main/default/classes/UniversalLoggerTest.cls \
  --source-dir force-app/main/default/classes/AzureKeyVaultService.cls \
  --source-dir force-app/main/default/classes/OpenAI_Service.cls \
  --target-org production \
  --test-level RunLocalTests \
  --wait 15
```

**⚠️ IMPORTANT**: 
- Le flag `--test-level RunLocalTests` exécute tous les tests
- Attendre 15 minutes max pour le déploiement
- Si échec, vérifier les erreurs de dépendances

### 2.2 Alternative : Déploiement en 2 phases

**Phase 1 : Classes de base**
```bash
sf project deploy start \
  --source-dir force-app/main/default/classes/UniversalLogger.cls \
  --source-dir force-app/main/default/classes/UniversalLoggerTest.cls \
  --source-dir force-app/main/default/classes/AzureKeyVaultService.cls \
  --source-dir force-app/main/default/classes/OpenAI_Service.cls \
  --target-org production \
  --test-level RunSpecifiedTests \
  --tests UniversalLoggerTest \
  --wait 10
```

**Phase 2 : Système de diagnostic**
```bash
sf project deploy start \
  --source-dir force-app/main/default/classes/ErrorDiagnosticService.cls \
  --source-dir force-app/main/default/classes/ErrorDiagnosticServiceTest.cls \
  --source-dir force-app/main/default/classes/ApexErrorAdapter.cls \
  --source-dir force-app/main/default/classes/LWCErrorAdapter.cls \
  --source-dir force-app/main/default/classes/FlowErrorAdapter.cls \
  --target-org production \
  --test-level RunSpecifiedTests \
  --tests ErrorDiagnosticServiceTest \
  --wait 10
```

---

## 🎨 ÉTAPE 3 : DÉPLOIEMENT DU LWC

### 3.1 Déployer universalLogger

```bash
sf project deploy start \
  --source-dir force-app/main/default/lwc/universalLogger \
  --target-org production \
  --wait 5
```

**Résultat attendu**: Déploiement réussi du module JavaScript

---

## ⚙️ ÉTAPE 4 : CONFIGURATION AZURE AD

### 4.1 Déployer Custom Metadata Type (si pas déjà fait)

```bash
sf project deploy start \
  --source-dir force-app/main/default/objects/Azure_AD_Config__mdt \
  --target-org production \
  --wait 5
```

### 4.2 Créer le record de configuration

**Option A : Via UI**

1. Setup → Custom Metadata Types
2. Azure AD Config → Manage Records
3. New → Créer record "Default"

```
Developer Name: Default
Label: Default Azure AD Config

Tenant_Id__c: [TON_TENANT_ID]
Client_Id__c: [TON_CLIENT_ID]  
Client_Secret__c: [TON_CLIENT_SECRET]
```

**Option B : Via CLI (si metadata record existe dans source)**

```bash
sf project deploy start \
  --source-dir force-app/main/default/customMetadata \
  --target-org production \
  --wait 5
```

---

## 🔐 ÉTAPE 5 : CONFIGURATION AZURE KEY VAULT

### 5.1 Vérifier les secrets dans Azure Portal

**Aller dans Azure Portal → Key Vault → kv-isonic-ai-migration → Secrets**

Vérifier que ces secrets existent :
- ✅ `azure-openai-api-key`
- ✅ `azure-openai-endpoint`
- ✅ `azure-openai-deployment` (ou utiliser valeur par défaut dans le code)

### 5.2 Configurer les permissions

```bash
# Donner accès au Service Principal Salesforce
az keyvault set-policy \
  --name kv-isonic-ai-migration \
  --spn [TON_CLIENT_ID] \
  --secret-permissions get list
```

### 5.3 Vérifier l'URL du Key Vault

**Dans `AzureKeyVaultService.cls` ligne 7** :
```apex
private static final String KEYVAULT_URL = 'https://kv-isonic-ai-migration.vault.azure.net/';
```

Si ton Key Vault a un nom différent, mettre à jour avant déploiement.

---

## 🧪 ÉTAPE 6 : TESTS POST-DÉPLOIEMENT

### 6.1 Test UniversalLogger depuis Developer Console

```apex
// Test logging Apex
UniversalLogger.info('TestComponent', 'testMethod', 'Test message from production');
UniversalLogger.error('TestComponent', 'testMethod', 'Test error', 
    new System.NullPointerException(), 
    new Map<String, Object>{ 'key' => 'value' }
);

// Vérifier les logs
System.debug('✅ UniversalLogger fonctionne');
```

### 6.2 Test récupération Azure Key Vault

```apex
// Test connexion Key Vault
Map<String, String> config = AzureKeyVaultService.getAzureOpenAIConfig();
System.debug('API Key: ' + (config.get('apiKey') != null ? 'FOUND' : 'MISSING'));
System.debug('Endpoint: ' + config.get('endpoint'));
System.debug('Deployment: ' + config.get('deployment'));
```

**Résultat attendu**: 
```
API Key: FOUND
Endpoint: https://your-endpoint.openai.azure.com/
Deployment: gpt-4-32k
```

### 6.3 Test OpenAI Service

```apex
// Test appel OpenAI
String response = OpenAI_Service.sendPrompt('Réponds simplement "OK"');
System.debug('Réponse OpenAI: ' + response);
```

**Résultat attendu**: Réponse valide d'OpenAI

### 6.4 Test diagnostic complet

```apex
// Test diagnostic erreur Flow
ErrorDiagnosticService.ErrorInfo error = new ErrorDiagnosticService.ErrorInfo();
error.errorType = 'FLOW';
error.flowName = 'Test_Flow';
error.flowApiName = 'Test_Flow';
error.errorMessage = 'Test error for diagnostic system';
error.recordId = null;
error.objectType = 'Account';

List<ErrorDiagnosticService.Response> responses = 
    ErrorDiagnosticService.diagnoseAndCreateCase(
        new List<ErrorDiagnosticService.ErrorInfo>{ error }
    );

System.debug('✅ Case créé: ' + responses[0].caseId);
System.debug('✅ Diagnostic: ' + responses[0].message);

// Vérifier le Case créé
Case c = [SELECT Id, Subject, Description FROM Case WHERE Id = :responses[0].caseId LIMIT 1];
System.debug('Case Subject: ' + c.Subject);
```

**Résultat attendu**: 
- Case créé automatiquement
- Diagnostic IA dans le Feed du Case
- Subject contient "🔴 Erreur Flow"

### 6.5 Test logging depuis LWC (via navigateur)

**Ouvrir Developer Console navigateur**, puis dans un LWC :

```javascript
import log from 'c/universalLogger';

// Dans une méthode
log.info('myComponent', 'connectedCallback', 'Component loaded');
log.error('myComponent', 'handleSave', 'Save failed', error, { recordId: this.recordId });
```

**Vérifier dans Debug Logs Salesforce** que les logs apparaissent avec le bon format.

---

## 📊 ÉTAPE 7 : VÉRIFICATION FINALE

### Checklist de validation

```bash
# 1. Vérifier que toutes les classes sont déployées
sf data query \
  --query "SELECT Name, Status FROM ApexClass WHERE Name LIKE '%Diagnostic%' OR Name LIKE '%Logger%' OR Name LIKE '%ErrorAdapter%'" \
  --target-org production

# 2. Vérifier la couverture de tests
sf apex get test \
  --code-coverage \
  --target-org production

# 3. Vérifier le LWC
sf data query \
  --query "SELECT DeveloperName FROM LightningComponentBundle WHERE DeveloperName = 'universalLogger'" \
  --target-org production
```

**Résultats attendus** :
- ✅ 9 classes Apex déployées
- ✅ Code coverage > 75%
- ✅ LWC universalLogger déployé

---

## 📋 CHECKLIST COMPLÈTE

### Avant déploiement
- [ ] Tests locaux passent (>75% coverage)
- [ ] Orgs connectées (`source-dev`, `production`)
- [ ] Azure Key Vault configuré avec secrets
- [ ] Service Principal a accès au Key Vault
- [ ] URL Key Vault vérifiée dans le code

### Déploiement
- [ ] Classes Apex déployées (ErrorDiagnosticService + adapters)
- [ ] UniversalLogger déployé (Apex + LWC)
- [ ] Services Azure déployés (KeyVault + OpenAI)
- [ ] Custom Metadata Type déployé
- [ ] Record Azure_AD_Config créé avec credentials
- [ ] LWC universalLogger déployé

### Tests post-déploiement
- [ ] UniversalLogger.info() fonctionne
- [ ] AzureKeyVaultService récupère les secrets
- [ ] OpenAI_Service répond correctement
- [ ] ErrorDiagnosticService crée un Case
- [ ] Diagnostic IA apparaît dans le Feed du Case
- [ ] Logging LWC fonctionne (test navigateur)

### Documentation
- [ ] Utilisateurs informés du nouveau système
- [ ] Guide d'utilisation partagé (STANDARD_LOGGING.md)
- [ ] Flow mis à jour pour utiliser UniversalLogger

---

## 🎯 UTILISATION DANS PRODUCTION

### Pour les développeurs Apex

```apex
// Remplacer System.debug() par :
UniversalLogger.info('MyClass', 'myMethod', 'Operation completed', contextData);
UniversalLogger.error('MyClass', 'myMethod', 'Operation failed', exception, contextData);
```

### Pour les développeurs LWC

```javascript
// Importer le logger
import log from 'c/universalLogger';

// Remplacer console.log() par :
log.info('myComponent', 'myMethod', 'Operation completed', { data: value });
log.error('myComponent', 'myMethod', 'Operation failed', error, { recordId: this.recordId });
```

### Pour les Flows

**Ajouter une Action Apex "Universal Logger"** :
- Component: Universal Logger
- Inputs: level, component, method, message, contextJson
- Utiliser dans les Fault Paths

---

## 🚨 ROLLBACK EN CAS DE PROBLÈME

### Si le déploiement échoue

```bash
# Vérifier les erreurs
sf project deploy report --target-org production

# Rollback (si nécessaire)
# Supprimer les classes problématiques via UI Setup → Apex Classes
```

### Si les tests échouent

1. Identifier le test en échec
2. Corriger dans le repo local
3. Redéployer uniquement la classe corrigée

```bash
sf project deploy start \
  --source-dir force-app/main/default/classes/ClassToFix.cls \
  --target-org production \
  --test-level RunSpecifiedTests \
  --tests ClassToFixTest \
  --wait 10
```

---

## ✅ DÉPLOIEMENT TERMINÉ !

**Système complet déployé** :
- ✅ Diagnostic IA automatique sur erreurs Apex/LWC/Flow
- ✅ Logging standardisé dans toute l'org
- ✅ Intégration Azure OpenAI + Key Vault
- ✅ Création automatique de Cases avec diagnostic
- ✅ Feed enrichi avec analyse IA

**Prochaines étapes** :
1. Former les développeurs au nouveau standard de logging
2. Migrer progressivement les `System.debug()` vers `UniversalLogger`
3. Monitorer les Cases créés automatiquement
4. Ajuster les prompts IA si nécessaire

🚀 **Le système est opérationnel en production !**
