# 🔐 Configuration Azure Key Vault dans Salesforce

## Comment ça fonctionne maintenant

### 1. Envoi à Azure OpenAI

**Dans `ErrorDiagnosticService.analyzeWithAI()` :**
```apex
String aiResponse = OpenAI_Service.sendPrompt(prompt);
```

**Dans `OpenAI_Service.sendPrompt()` :**
```apex
// 1. Récupère config depuis Azure Key Vault
Map<String, String> config = AzureKeyVaultService.getAzureOpenAIConfig();

// 2. Construit endpoint Azure OpenAI
String fullEndpoint = endpoint + '/openai/deployments/' + deployment + '/chat/completions?api-version=' + apiVersion;

// 3. Envoie HTTP POST avec header 'api-key'
HttpRequest req = new HttpRequest();
req.setHeader('api-key', config.get('apiKey'));
```

### 2. Récupération depuis Azure Key Vault

**Dans `AzureKeyVaultService.getAzureOpenAIConfig()` :**
```apex
// Récupère chaque secret depuis Key Vault
config.put('apiKey', getSecret('azure-openai-api-key'));
config.put('endpoint', getSecret('azure-openai-endpoint'));
config.put('deployment', getSecret('azure-openai-deployment'));
```

**Dans `AzureKeyVaultService.getSecret()` :**
```apex
// 1. Récupère token Azure AD
String accessToken = getAzureAccessToken();

// 2. Appelle API REST Key Vault
String endpoint = KEYVAULT_URL + 'secrets/' + secretName + '?api-version=7.4';
HttpRequest req = new HttpRequest();
req.setHeader('Authorization', 'Bearer ' + accessToken);

// 3. Parse la réponse JSON
Map<String, Object> response = JSON.deserializeUntyped(res.getBody());
return (String) response.get('value');
```

---

## ⚙️ Configuration Requise

### 1. Custom Metadata Type : `Azure_AD_Config__mdt`

**Pour l'authentification Azure AD (Service Principal) :**

**Champs nécessaires :**
- `Tenant_Id__c` (Text) - Tenant ID Azure AD
- `Client_Id__c` (Text) - Client ID du Service Principal
- `Client_Secret__c` (Text) - Client Secret du Service Principal

**Record à créer :**
- Developer Name: `Default`
- Remplir avec tes credentials Azure AD

---

### 2. Secrets dans Azure Key Vault

**Vérifier que ces secrets existent dans ton Key Vault :**
- ✅ `azure-openai-api-key`
- ✅ `azure-openai-endpoint`
- ✅ `azure-openai-deployment`

**Si le secret `azure-openai-deployment` n'existe pas :**
- Soit le créer dans Key Vault
- Soit modifier `AzureKeyVaultService.getAzureOpenAIConfig()` pour utiliser une valeur par défaut

---

## 🔧 Configuration Azure AD Service Principal

### Étape 1 : Créer Service Principal dans Azure

```bash
# Via Azure CLI
az ad sp create-for-rbac --name "salesforce-keyvault-access" \
  --role contributor \
  --scopes /subscriptions/SUBSCRIPTION_ID/resourceGroups/RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/KEYVAULT_NAME
```

**Résultat :**
- `appId` → Client_Id__c
- `password` → Client_Secret__c
- `tenant` → Tenant_Id__c

### Étape 2 : Donner accès au Key Vault

```bash
# Donner permission "Key Vault Secrets User" au Service Principal
az keyvault set-policy --name KEYVAULT_NAME \
  --spn CLIENT_ID \
  --secret-permissions get list
```

### Étape 3 : Créer Custom Metadata dans Salesforce

**Via Setup → Custom Metadata Types → Azure AD Config → New :**

```
Developer Name: Default
Label: Default Azure AD Config

Tenant_Id__c: 44e6ba08-8f3b-4778-8546-ea2fac65a45c
Client_Id__c: c8eadd4a-8593-4d9a-91db-2df041bc5977
Client_Secret__c: ton-client-secret
```

---

## 🧪 Test

### Test récupération depuis Key Vault

```apex
// Dans Developer Console
Map<String, String> config = AzureKeyVaultService.getAzureOpenAIConfig();
System.debug('API Key: ' + config.get('apiKey'));
System.debug('Endpoint: ' + config.get('endpoint'));
System.debug('Deployment: ' + config.get('deployment'));
```

### Test complet OpenAI

```apex
String response = OpenAI_Service.sendPrompt('Réponds "OK"');
System.debug('Réponse: ' + response);
```

---

## 📊 Flux Complet

```
1. ErrorDiagnosticService.diagnoseAndCreateCase()
   ↓
2. OpenAI_Service.sendPrompt(prompt)
   ↓
3. AzureKeyVaultService.getAzureOpenAIConfig()
   ├─ getSecret('azure-openai-api-key')
   │  └─ getAzureAccessToken() → OAuth2 Azure AD
   │  └─ Appelle Key Vault REST API
   ├─ getSecret('azure-openai-endpoint')
   └─ getSecret('azure-openai-deployment')
   ↓
4. Construit endpoint Azure OpenAI
   ↓
5. Envoie HTTP POST avec api-key
   ↓
6. Reçoit réponse JSON
   ↓
7. Parse et retourne le texte
```

---

## ✅ Checklist

- [ ] Service Principal Azure AD créé
- [ ] Permissions Key Vault configurées pour le Service Principal
- [ ] Custom Metadata `Azure_AD_Config__mdt` créé avec credentials
- [ ] Secrets dans Key Vault vérifiés :
  - [ ] `azure-openai-api-key`
  - [ ] `azure-openai-endpoint`
  - [ ] `azure-openai-deployment`
- [ ] Test récupération config OK
- [ ] Test OpenAI OK

---

**Tout est prêt !** Il faut juste configurer le Service Principal Azure AD et le Custom Metadata. 🚀
