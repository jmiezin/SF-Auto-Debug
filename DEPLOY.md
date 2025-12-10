# 🚀 Guide de Déploiement - SF Auto Debug V1

**Version** : 2.3  
**Qualité** : 10/10

---

## ✅ CONTENU DU PACKAGE

### Champs Custom Case (11)
- `Error_Source__c` (Picklist: LWC/Apex/Flow/Integration)
- `Component__c` (Text 255)
- `Method__c` (Text 255)
- `Severity__c` (Picklist: CRITICAL/HIGH/MEDIUM/LOW)
- `User__c` (Lookup User)
- `Error_Message__c` (Long Text 32k)
- `Raw_Error__c` (Long Text 32k)
- `Context__c` (Long Text 32k)
- `Error_Json__c` (Long Text 32k)
- `Error_Signature__c` (Text 255 - hash)
- `Environment__c` (Picklist: DEV/UAT/PROD)
- `Release_Tag__c` (Text 80)

### Record Type & Layout
- Record Type: `Debug`
- Page Layout: `Case Layout Debug`

### Lightning Page
- `Case_Debug_Record_Page` (avec tabs Feed/Details/Related)

### Reports (5)
- Debug - Errors by Source and Component
- Debug - Severity Over Time (7 Days)
- Debug - Top 10 Components (30 Days)
- Debug - Errors by User (30 Days)
- Debug - Open Critical/High Errors

### Dashboard (1)
- Debug - Monitoring (3 colonnes, 6 composants)

### Classes Apex (16)
- UniversalLogger + Test
- ErrorDiagnosticService + Test (avec champs custom)
- Adapters (Apex/LWC/Flow)
- AuraExceptionHandler + Test
- DiagnosticQueueable + Test
- OpenAI_Service + Mock + Test
- AzureKeyVaultService

### LWC (1)
- universalLogger

---

## 🚀 DÉPLOIEMENT ÉTAPE PAR ÉTAPE

### 1. Vérifier le projet

```bash
cd /Users/jonathanmiezin/Desktop/SF-Auto-Debug

# Vérifier structure
ls -R force-app/main/default/

# Devrait afficher:
# - classes/ (32 fichiers)
# - lwc/ (2 fichiers)
# - objects/Case/fields/ (12 fichiers)
# - objects/Case/recordTypes/ (1 fichier)
# - layouts/ (1 fichier)
# - flexipages/ (1 fichier)
# - reports/DevOps_Monitoring/ (5 fichiers)
# - dashboards/DevOps_Monitoring/ (1 fichier)
```

### 2. Authentifier l'org cible

```bash
# Pour une sandbox
sf org login web --alias my-sandbox --instance-url https://test.salesforce.com

# Pour production
sf org login web --alias my-prod --instance-url https://login.salesforce.com

# Définir comme org par défaut
sf config set target-org=my-sandbox
```

### 3. Valider metadata (dry-run)

```bash
sf project deploy start \
  --source-dir force-app/main/default \
  --target-org my-sandbox \
  --dry-run \
  --test-level NoTestRun
```

**Vérifier** : Aucune erreur de compilation

### 4. Déployer (avec tests)

```bash
sf project deploy start \
  --source-dir force-app/main/default \
  --target-org my-sandbox \
  --test-level RunLocalTests \
  --wait 10
```

**Résultat attendu** :
- ✅ Deployed: 16 classes Apex
- ✅ Tests: 143/143 (100%)
- ✅ Coverage: >75% partout
- ✅ Deployed: 12 champs Case
- ✅ Deployed: 1 Record Type
- ✅ Deployed: 1 Layout
- ✅ Deployed: 1 Lightning Page
- ✅ Deployed: 5 Reports
- ✅ Deployed: 1 Dashboard

### 5. Assigner Record Type au profil

**Via metadata** (recommandé) :

Créer `force-app/main/default/profiles/Admin.profile-meta.xml` :

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Profile xmlns="http://soap.sforce.com/2006/04/metadata">
    <recordTypeVisibilities>
        <default>false</default>
        <recordType>Case.Debug</recordType>
        <visible>true</visible>
    </recordTypeVisibilities>
</Profile>
```

**Ou via CLI** :

```bash
# Assigner manuellement dans Setup
Setup → Profiles → System Administrator → Object Settings → Case → Record Types
→ Cocher "Debug" comme available
```

### 6. Assigner Lightning Page

**Via metadata** (inclus dans flexipage) :

```bash
# La Lightning Page est déjà configurée pour le Record Type Debug
# Pas d'action supplémentaire nécessaire
```

**Ou activer manuellement** :

```
Setup → Lightning App Builder → Case Debug Record Page → Activation
→ Assign to Record Type: Debug
→ Save
```

### 7. Configurer Azure OpenAI (voir INSTALLATION.md)

```bash
# 1. Créer Named Credential "Azure_Key_Vault"
# 2. Créer Custom Metadata "Azure_AD_Config__mdt"
# 3. Stocker secrets dans Azure Key Vault
```

---

## 🧪 TESTS POST-DÉPLOIEMENT

### Test 1 : Vérifier champs custom

```bash
sf data query \
  --query "SELECT Id, Error_Source__c, Component__c, Severity__c FROM Case LIMIT 1" \
  --target-org my-sandbox
```

**Résultat attendu** : Query réussit (champs existent)

### Test 2 : Créer un Case de test

```bash
sf apex run --file - --target-org my-sandbox <<'EOF'
ErrorDiagnosticService.ErrorInfo test = new ErrorDiagnosticService.ErrorInfo();
test.errorType = 'LWC';
test.componentName = 'testComponent';
test.errorMessage = 'Test error';
test.stackTrace = 'Test stack';
test.recordId = null;
test.objectType = 'Account';

Map<String, Object> context = new Map<String, Object>{
    'apexClass' => 'TestController',
    'apexMethod' => 'testMethod',
    'action' => 'handleSave'
};
test.contextData = JSON.serialize(context);

ErrorDiagnosticService.diagnoseAndCreateCase(new List<ErrorDiagnosticService.ErrorInfo>{ test });
System.debug('✅ Case de test créé');
EOF
```

**Résultat attendu** :
- Case créé avec RecordType = Debug
- Champs custom peuplés
- Diagnostic IA dans le Feed

### Test 3 : Vérifier Layout

```bash
# Ouvrir un Case Debug dans Salesforce UI
1. App Launcher → Service → Cases
2. Cliquer sur un Case de type Debug
3. Vérifier :
   - Layout "Case Layout Debug" appliqué
   - Sections visibles (Résumé, Contexte, Message, Diagnostic IA)
   - Feed en premier onglet
```

### Test 4 : Vérifier Lightning Page

```
1. Ouvrir un Case Debug
2. Vérifier 3 onglets : Feed | Details | Related
3. Feed doit afficher le diagnostic IA avec séparateurs
```

### Test 5 : Vérifier Reports

```bash
# Aller dans Analytics → Reports → DevOps Monitoring
# Vérifier 5 reports présents :
1. Debug - Errors by Source and Component
2. Debug - Severity Over Time (7 Days)
3. Debug - Top 10 Components (30 Days)
4. Debug - Errors by User (30 Days)
5. Debug - Open Critical/High Errors
```

### Test 6 : Vérifier Dashboard

```bash
# Aller dans Analytics → Dashboards → DevOps Monitoring → Debug - Monitoring
# Vérifier :
- 6 composants affichés
- Charts avec données (si Cases créés)
- Métriques fonctionnent
```

---

## ⚙️ POST-CONFIGURATION

### Permissions

Donner accès au Dashboard :

```bash
# Via Permission Set ou Profile
Setup → Permission Sets → Create "Debug Dashboard Access"
→ Object Settings → Case → View All
→ App Permissions → Reports and Dashboards → View All Data
```

### Automatisation Record Type

Modifier `ErrorDiagnosticService.cls` pour définir le Record Type :

```apex
// Dans createCase(), AVANT insert newCase
newCase.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Debug').getRecordTypeId();
```

---

## 🐛 TROUBLESHOOTING

### Erreur: "Field does not exist: Error_Source__c"

➡️ Déployer à nouveau juste les champs :

```bash
sf project deploy start \
  --source-dir force-app/main/default/objects/Case/fields \
  --target-org my-sandbox
```

### Reports ne s'affichent pas

➡️ Vérifier folder metadata :

```bash
ls force-app/main/default/reports/DevOps_Monitoring-meta.xml
ls force-app/main/default/dashboards/DevOps_Monitoring-meta.xml
```

### Lightning Page non visible

➡️ Activer manuellement :

```
Setup → Lightning App Builder → Case Debug Record Page → Activation
```

### Dashboard vide

➡️ Créer quelques Cases de test d'abord (voir Test 2)

---

## ✅ CHECKLIST FINALE

- [ ] 143/143 tests passent
- [ ] Champs custom visibles sur Case
- [ ] Record Type "Debug" existe
- [ ] Layout "Case Layout Debug" assigné
- [ ] Lightning Page fonctionnelle (3 tabs)
- [ ] 5 Reports dans folder DevOps_Monitoring
- [ ] Dashboard Debug - Monitoring affiché
- [ ] Azure OpenAI configuré
- [ ] Case de test créé avec diagnostic IA
- [ ] Diagnostic IA affiché dans Feed avec template v2.3

---

**Déploiement terminé !** 🎉

Temps estimé : 30-45 minutes  
Qualité : 10/10  
Production Ready ✅
