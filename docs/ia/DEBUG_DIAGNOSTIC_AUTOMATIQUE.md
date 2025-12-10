# 🔍 Debug Diagnostic Automatique

## Comment vérifier si le diagnostic se déclenche

### 1. Ouvrir la Console du Navigateur

**Dans Chrome :**
1. F12 ou Cmd+Option+I (Mac) / Ctrl+Shift+I (Windows)
2. Onglet **Console**
3. Filtre : Cherche `[DIAGNOSTIC]` ou `[ERROR]`

### 2. Créer une erreur

1. Va sur un Quote
2. Configure un bundle
3. Clique sur "Sauvegarder"
4. Si erreur → Regarde la console

### 3. Logs à chercher

**Si le diagnostic démarre :**
```
🔧 [DIAGNOSTIC] Démarrage du diagnostic automatique...
🔧 [DIAGNOSTIC] Component: isquote_bundleConfigurator
🔧 [DIAGNOSTIC] RecordId: 0Q0Jv000009TjuDKAS
🔧 [DIAGNOSTIC] Appel à diagnoseLWCError...
```

**Si le diagnostic réussit :**
```
✅ [DIAGNOSTIC] Case créé avec diagnostic IA: 500...
✅ [DIAGNOSTIC] Vérifie le Case dans Salesforce: 500...
```

**Si le diagnostic échoue :**
```
❌ [DIAGNOSTIC] Erreur lors du diagnostic: ...
❌ [DIAGNOSTIC] Error body: ...
❌ [DIAGNOSTIC] Error message: ...
```

---

## Vérifier dans Salesforce

**Setup → Cases → All Open Cases**

Cherche un Case avec :
- Subject : `[LWC ERROR] isquote_bundleConfigurator`
- Origin : `Automated`
- Type : `LWC`

---

## Si ça ne fonctionne pas

### Vérifier que le code est déployé

```bash
# Vérifier la méthode @AuraEnabled
sf project retrieve start --metadata "ApexClass:ErrorDiagnosticService" --target-org production

# Vérifier le composant LWC
sf project retrieve start --metadata "LightningComponentBundle:isquote_bundleConfigurator" --target-org production
```

### Vérifier les permissions

- Le profil utilisateur doit avoir accès à `ErrorDiagnosticService`
- Vérifier les Field-Level Security sur Case

---

**Ouvre la console du navigateur et teste ! Les logs te diront exactement ce qui se passe. 🔍**
