# 📦 Guide d'Installation - SF Auto Debug V1

**Version** : 2.3  
**Durée** : 30-45 minutes

---

## ✅ Prérequis

### Salesforce
- Org Salesforce (Production, Sandbox ou Scratch)
- API Version 65.0 minimum
- Profil System Administrator

### Azure
- Souscription Azure active
- Azure AD App Registration
- Azure OpenAI Service (GPT-4o)
- Azure Key Vault

### Outils
- Salesforce CLI (sf v2.0+)
- Git
- Visual Studio Code (recommandé)

---

## 🚀 Installation Étape par Étape

### 1. Cloner le Repository

```bash
git clone https://github.com/YOUR_ORG/SF-Auto-Debug.git
cd SF-Auto-Debug
```

### 2. Authentifier Salesforce Org

```bash
sf org login web --alias my-org --set-default
```

### 3. Déployer les Métadonnées

```bash
sf project deploy start \
  --source-dir force-app/main/default \
  --target-org my-org \
  --test-level RunLocalTests \
  --wait 10
```

**Résultat attendu** : 143/143 tests passent ✅

### 4. Configurer Azure (voir docs/ia/DEPLOIEMENT_COMPLET_PRODUCTION.md)

#### 4.1 Azure AD App Registration

```bash
# Dans Azure Portal
1. Azure AD → App registrations → New registration
2. Nom: "Salesforce-ErrorDiagnostic"
3. Supported account types: Single tenant
4. Redirect URI: (laisser vide)
5. Register
6. Noter: Application (client) ID et Directory (tenant) ID
7. Certificates & secrets → New client secret → Noter la valeur
```

#### 4.2 Azure OpenAI

```bash
1. Créer Azure OpenAI resource
2. Déployer modèle GPT-4o
3. Noter: Endpoint et Model Deployment Name
```

#### 4.3 Azure Key Vault

```bash
1. Créer Key Vault
2. Access policies → Add → Select principal: App Registration créée
3. Secret permissions: Get, List
4. Ajouter secrets:
   - openai-endpoint: https://YOUR-RESOURCE.openai.azure.com/
   - openai-deployment: gpt-4o
   - openai-api-version: 2024-02-15-preview
```

### 5. Configurer Salesforce

#### 5.1 Named Credential

```
Setup → Named Credentials → New Legacy
Name: Azure_Key_Vault
URL: https://YOUR-KEYVAULT.vault.azure.net
Identity Type: Named Principal
Authentication Protocol: OAuth 2.0
Scope: https://vault.azure.net/.default
```

#### 5.2 Custom Metadata

Exécuter dans Anonymous Apex :

```apex
Azure_AD_Config__mdt config = new Azure_AD_Config__mdt();
config.DeveloperName = 'Default';
config.Tenant_Id__c = 'YOUR_TENANT_ID';
config.Client_Id__c = 'YOUR_CLIENT_ID';
config.Client_Secret__c = 'YOUR_CLIENT_SECRET';
config.Key_Vault_Name__c = 'YOUR_KEYVAULT_NAME';

// Note: Insert via Metadata API ou manuellement dans Setup
```

### 6. Tester l'Installation

```bash
sf apex run --file tests/test_diagnostic.apex --target-org my-org
```

**Vérifier** :
1. Un Case est créé avec sujet `[LWC ERROR] ...`
2. Le Feed contient un diagnostic IA
3. Le diagnostic a des imports corrects

---

## ✅ Vérification Finale

### Checklist

- [ ] 143/143 tests passent
- [ ] Coverage >75% partout
- [ ] Azure Key Vault accessible
- [ ] OpenAI Service répond
- [ ] Case de test créé avec diagnostic
- [ ] Diagnostic a des imports corrects
- [ ] Code fix est actionnable

---

## 🐛 Troubleshooting

### Erreur: "Named Credential not found"

➡️ Vérifier que la Named Credential est bien créée et nommée `Azure_Key_Vault`

### Erreur: "Key Vault access denied"

➡️ Vérifier que l'App Registration a les permissions Get/List sur les secrets

### Tests échouent

➡️ Vérifier que tous les fichiers ont été déployés :

```bash
sf project deploy report --target-org my-org
```

### Diagnostic ne se génère pas

➡️ Activer Debug Logs et vérifier les erreurs dans les logs

---

## 📞 Support

Pour toute question :
- Consulter `/docs/ia/README_SYSTEME_DIAGNOSTIC.md`
- Lire `/docs/ia/GUIDE_TEST_PRODUCTION.md`
- Vérifier `/docs/ia/DEPLOIEMENT_COMPLET_PRODUCTION.md`

---

**Installation terminée !** 🎉

Temps total : ~30-45 minutes  
Qualité : 10/10  
Prêt pour production ✅
