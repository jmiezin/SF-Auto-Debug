# ⚡ Configuration Rapide Azure AD pour Salesforce

## ✅ Client ID identifié
**Client ID Backend :** `43f37542-9391-4525-8e08-bea1e60d58db`

---

## 🔧 Étape 1 : Vérifier/Grant accès au Key Vault

### Vérifier les permissions actuelles

```bash
# Vérifier si l'app a déjà accès
az role assignment list \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/isonic-ai-rg/providers/Microsoft.KeyVault/vaults/kv-isonic-ai-migration" \
  --query "[?contains(principalId, '43f37542-9391-4525-8e08-bea1e60d58db')]"
```

### Donner accès si nécessaire

```bash
# Grant "Key Vault Secrets User" role
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee "43f37542-9391-4525-8e08-bea1e60d58db" \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/isonic-ai-rg/providers/Microsoft.KeyVault/vaults/kv-isonic-ai-migration"
```

**Ou via Azure Portal :**
1. Key Vault `kv-isonic-ai-migration` → Access control (IAM)
2. Add → Add role assignment
3. Role : **Key Vault Secrets User**
4. Assign access to : **Managed identity** ou **User, group, or service principal**
5. Select : Chercher `43f37542-9391-4525-8e08-bea1e60d58db` ou le nom de ton app backend
6. Save

---

## 🔑 Étape 2 : Récupérer les credentials dans Azure Portal

### 1. Tenant ID

**Azure Portal → Azure Active Directory → Overview**
- Copier le **Tenant ID** (GUID)

### 2. Client ID

✅ **Déjà identifié :** `43f37542-9391-4525-8e08-bea1e60d58db`

**Azure Portal → Azure Active Directory → App registrations → Ton app backend**
- Overview → **Application (client) ID** → Vérifier que c'est bien `43f37542-9391-4525-8e08-bea1e60d58db`

### 3. Client Secret

**Azure Portal → Azure Active Directory → App registrations → Ton app backend**

1. **Certificates & secrets** (menu gauche)
2. **Client secrets** (onglet)
3. **+ New client secret**
   - Description : `Salesforce Key Vault Access`
   - Expires : `24 months` (ou selon ta politique)
   - **Add**
4. **⚠️ IMPORTANT :** Copier immédiatement la **Value** (affichée une seule fois !)
   - Format : `abc123~xyz789...`

---

## 📝 Étape 3 : Configurer dans Salesforce

### Créer le Custom Metadata Record

**Setup → Custom Metadata Types → Azure AD Config → Manage Azure AD Config → New**

```
Developer Name: Default
Label: Default Azure AD Config

Tenant_Id__c: [COLLER_TON_TENANT_ID]
Client_Id__c: 43f37542-9391-4525-8e08-bea1e60d58db
Client_Secret__c: [COLLER_LE_CLIENT_SECRET_GÉNÉRÉ]
Key_Vault_URL__c: https://kv-isonic-ai-migration.vault.azure.net/
```

**Note :** `Key_Vault_URL__c` est optionnel (valeur par défaut déjà dans le code)

---

## 🧪 Étape 4 : Tester la configuration

### Test 1 : Récupération depuis Key Vault

**Developer Console → Execute Anonymous Window :**

```apex
try {
    Map<String, String> config = AzureKeyVaultService.getAzureOpenAIConfig();
    System.debug('✅ Config récupérée:');
    System.debug('  - API Key: ' + (String.isNotBlank(config.get('apiKey')) ? 'OK' : 'MANQUANT'));
    System.debug('  - Endpoint: ' + config.get('endpoint'));
    System.debug('  - Deployment: ' + config.get('deployment'));
} catch (Exception e) {
    System.debug('❌ Erreur: ' + e.getMessage());
    System.debug('Stack: ' + e.getStackTraceString());
}
```

### Test 2 : Appel Azure OpenAI complet

```apex
try {
    String response = OpenAI_Service.sendPrompt('Réponds simplement "OK"');
    System.debug('✅ Réponse OpenAI: ' + response);
} catch (Exception e) {
    System.debug('❌ Erreur: ' + e.getMessage());
}
```

---

## ✅ Checklist

- [ ] App backend a accès au Key Vault `kv-isonic-ai-migration` (role "Key Vault Secrets User")
- [ ] Tenant ID récupéré depuis Azure AD
- [ ] Client ID confirmé : `43f37542-9391-4525-8e08-bea1e60d58db`
- [ ] Client Secret créé et copié
- [ ] Custom Metadata `Azure_AD_Config__mdt` créé dans Salesforce avec les 3 valeurs
- [ ] Test récupération config OK
- [ ] Test appel OpenAI OK

---

## 🐛 Troubleshooting

### Erreur : "Azure AD Token Error (401)"

- Vérifier que le **Client Secret** est correct (pas expiré)
- Vérifier que le **Tenant ID** est correct
- Vérifier que le **Client ID** correspond bien à l'app backend

### Erreur : "Azure Key Vault Error (403)"

- Vérifier que l'app `43f37542-9391-4525-8e08-bea1e60d58db` a bien le role **Key Vault Secrets User** sur le Key Vault
- Vérifier que le Key Vault est bien `kv-isonic-ai-migration`

### Erreur : "Secret not found"

- Vérifier que les secrets existent dans Key Vault :
  - `azure-openai-api-key`
  - `azure-openai-endpoint`
  - `azure-openai-deployment` (optionnel)

---

**Une fois configuré, tout est prêt ! 🚀**
