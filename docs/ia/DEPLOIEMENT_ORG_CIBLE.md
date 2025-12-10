# 🚀 Déploiement dans l'Org Cible (Production)

## Ce qui sera déployé

### Classes Apex
- ✅ `ErrorDiagnosticService.cls` - Service unifié de diagnostic
- ✅ `ApexErrorAdapter.cls` - Adaptateur erreurs Apex
- ✅ `LWCErrorAdapter.cls` - Adaptateur erreurs LWC
- ✅ `FlowErrorAdapter.cls` - Adaptateur erreurs Flow
- ✅ `AzureKeyVaultService.cls` - Service Azure Key Vault
- ✅ `OpenAI_Service.cls` - Service Azure OpenAI (utilise Key Vault)
- ✅ `ErrorDiagnosticServiceTest.cls` - Tests unitaires

### Custom Metadata Types
- ✅ `Azure_AD_Config__mdt` - Configuration Azure AD (Tenant_Id, Client_Id, Client_Secret)
- ✅ `GPT_Key__mdt` - (Optionnel, si tu veux garder comme fallback)

### Flows
- ✅ `Case_Error_Email_Sender.flow-meta.xml` - Envoie email quand Case créé

---

## ⚙️ Configuration dans l'Org Cible

### Étape 1 : Déployer les classes et Custom Metadata

```bash
# Déployer vers production
sf project deploy start \
  --source-dir force-app/main/default/classes \
  --source-dir force-app/main/default/objects \
  --target-org production
```

### Étape 2 : Configurer Azure AD dans Custom Metadata

**Dans Setup → Custom Metadata Types → Azure AD Config → New :**

```
Developer Name: Default
Label: Default Azure AD Config

Tenant_Id__c: [TON_TENANT_ID]
Client_Id__c: [TON_CLIENT_ID]
Client_Secret__c: [TON_CLIENT_SECRET]
```

**Où trouver ces valeurs :**
- Azure Portal → Azure Active Directory → App registrations → Ton app
- Tenant ID : Overview → Tenant ID
- Client ID : Overview → Application (client) ID
- Client Secret : Certificates & secrets → Créer un nouveau secret

### Étape 3 : Vérifier les secrets dans Azure Key Vault

**Dans Azure Portal → Key Vault → Secrets :**

Vérifier que ces secrets existent :
- ✅ `azure-openai-api-key`
- ✅ `azure-openai-endpoint`
- ✅ `azure-openai-deployment` (ou modifier le code pour valeur par défaut)

**Si `azure-openai-deployment` n'existe pas :**

Modifier `AzureKeyVaultService.getAzureOpenAIConfig()` :
```apex
// Au lieu de :
config.put('deployment', getSecret('azure-openai-deployment'));

// Utiliser :
config.put('deployment', 'gpt-4-32k'); // Ou ton deployment par défaut
```

### Étape 4 : Configurer les permissions Key Vault

**Le Service Principal doit avoir accès au Key Vault :**

```bash
# Via Azure CLI
az keyvault set-policy \
  --name kv-isonic-ai-migration \
  --spn [TON_CLIENT_ID] \
  --secret-permissions get list
```

### Étape 5 : Activer le Flow Case_Error_Email_Sender

**Dans Setup → Flows → Case_Error_Email_Sender :**
- Activer le Flow

---

## 🧪 Test dans l'Org Cible

### Test 1 : Récupération depuis Key Vault

**Dans Developer Console :**
```apex
// Test récupération config
Map<String, String> config = AzureKeyVaultService.getAzureOpenAIConfig();
System.debug('API Key: ' + config.get('apiKey'));
System.debug('Endpoint: ' + config.get('endpoint'));
System.debug('Deployment: ' + config.get('deployment'));
```

**Résultat attendu :** Les valeurs depuis Key Vault

### Test 2 : Appel Azure OpenAI

**Dans Developer Console :**
```apex
// Test simple OpenAI
String response = OpenAI_Service.sendPrompt('Réponds simplement "OK"');
System.debug('Réponse: ' + response);
```

**Résultat attendu :** `"OK"` ou réponse similaire

### Test 3 : Diagnostic complet

**Dans Developer Console :**
```apex
// Test diagnostic erreur Flow
ErrorDiagnosticService.ErrorInfo error = new ErrorDiagnosticService.ErrorInfo();
error.errorType = 'FLOW';
error.flowName = 'Test_Flow';
error.flowApiName = 'Test_Flow';
error.errorMessage = 'Test error message';
error.recordId = '001xx000000abc123';
error.objectType = 'Account';

List<ErrorDiagnosticService.Response> responses = 
    ErrorDiagnosticService.diagnoseAndCreateCase(new List<ErrorDiagnosticService.ErrorInfo>{ error });

System.debug('Case créé: ' + responses[0].caseId);
```

**Résultat attendu :** Case créé avec diagnostic IA

---

## 📋 Checklist Déploiement

- [ ] Classes Apex déployées
- [ ] Custom Metadata Types déployés
- [ ] Record `Azure_AD_Config__mdt` créé avec credentials
- [ ] Secrets vérifiés dans Azure Key Vault
- [ ] Permissions Key Vault configurées pour Service Principal
- [ ] Flow `Case_Error_Email_Sender` activé
- [ ] Test récupération Key Vault OK
- [ ] Test OpenAI OK
- [ ] Test diagnostic complet OK

---

## 🔧 Configuration Key Vault URL

**Dans `AzureKeyVaultService.cls` ligne 7 :**

Vérifier que l'URL du Key Vault est correcte :
```apex
private static final String KEYVAULT_URL = 'https://kv-isonic-ai-migration.vault.azure.net/';
```

**Si ton Key Vault a un nom différent :**
- Modifier cette constante avec ton URL

---

## 🎯 Utilisation dans l'Org Cible

### Pour les Flows

**Modifier `Universal_Log_Flow_Error` pour ajouter :**

```
1. Create Error Log (existant)
2. Action Apex: ErrorDiagnosticService.diagnoseAndCreateCase()
   Inputs:
   - errorType: "FLOW"
   - flowName: {!IN_Flow_Name}
   - flowApiName: {!IN_Flow_Name}
   - errorMessage: {!IN_Error_Message}
   - recordId: {!IN_Record_Id}
   - objectType: {!IN_Object_Type}
```

### Pour Apex

**Dans ton code Apex avec Try-Catch :**
```apex
try {
    // Code métier
} catch (Exception e) {
    ErrorDiagnosticService.ErrorInfo error = new ErrorDiagnosticService.ErrorInfo();
    error.errorType = 'APEX';
    error.className = 'QuoteService';
    error.methodName = 'calculateTotal';
    error.errorMessage = e.getMessage();
    error.stackTrace = e.getStackTraceString();
    error.recordId = quoteId;
    error.objectType = 'Quote';
    
    ErrorDiagnosticService.diagnoseAndCreateCase(new List<ErrorDiagnosticService.ErrorInfo>{ error });
    
    throw e;
}
```

---

## ✅ Tout est prêt pour l'org cible !

**Résumé :**
1. ✅ Classes utilisent Azure Key Vault
2. ✅ Configuration via Custom Metadata Azure AD
3. ✅ Secrets récupérés depuis Key Vault
4. ✅ Prêt à déployer dans production

**Prochaine étape :** Déployer et configurer dans l'org cible ! 🚀
