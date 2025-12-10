# 🎯 Guide : Améliorer la Qualité des Diagnostics IA

**Problème** : Le diagnostic IA est trop générique ("Script-thrown exception")

**Solution** : Capturer le VRAI stack trace Apex avec Debug Logs

---

## ❌ POURQUOI LE DIAGNOSTIC EST GÉNÉRIQUE ?

### Problème : AuraHandledException masque l'erreur Apex

```apex
// Dans la classe Apex appelée depuis LWC
public static void createQuoteLineItems(Map<String, Object> configuration) {
    try {
        // ... code métier
        insert quoteLines; // ❌ Erreur DML ici
    } catch (Exception e) {
        // ❌ Le vrai stack trace est perdu ici
        throw new AuraHandledException(e.getMessage());
        // Le LWC ne reçoit que "Script-thrown exception"
    }
}
```

**Résultat** :
- ✅ LWC reçoit une erreur
- ❌ LWC ne voit PAS le vrai stack trace Apex
- ❌ Diagnostic IA générique car informations limitées

---

## ✅ SOLUTION 1 : Activer les Debug Logs (RECOMMANDÉ)

### Étape 1 : Activer Debug Logs

**Setup → Debug Logs → New**

1. **Traced Entity Type** : User
2. **Select User** : TON utilisateur
3. **Start Time** : Now
4. **Expiration Time** : 1 hour
5. **Debug Level** : Create new level:
   - Apex Code: **FINEST**
   - Database: **FINEST**
   - System: **DEBUG**
   - Workflow: **DEBUG**

### Étape 2 : Reproduire l'erreur

1. Aller dans le configurateur de bundle
2. Essayer de sauvegarder la configuration
3. Attendre l'erreur

### Étape 3 : Lire le Debug Log

**Setup → Debug Logs → View**

**Chercher** :
```
❌ [ERROR] 
EXCEPTION_THROWN
DML_EXCEPTION
VALIDATION_RULE
FIELD_CUSTOM_VALIDATION_EXCEPTION
```

**Exemple de log révélateur** :
```
13:45:12.045 (45123456)|EXCEPTION_THROWN|[127]|System.DmlException: Insert failed. 
First exception on row 0; first error: FIELD_CUSTOM_VALIDATION_EXCEPTION, 
Le champ Prix ne peut pas être négatif: [-100]
```

### Étape 4 : Créer un Case manuel avec le VRAI stack trace

**Une fois le vrai stack trace identifié**, tu peux :

**Option A** : Copier le stack trace complet dans le Case existant

**Option B** : Relancer le diagnostic avec les vraies infos :

```apex
ErrorDiagnosticService.ErrorInfo error = new ErrorDiagnosticService.ErrorInfo();
error.errorType = 'APEX';
error.componentName = 'isquote_bundleConfigurator';
error.className = 'isquote_QuoteLineService'; // ✅ Classe réelle
error.methodName = 'createQuoteLineItems'; // ✅ Méthode réelle
error.errorMessage = 'System.DmlException: Insert failed. First exception on row 0; first error: FIELD_CUSTOM_VALIDATION_EXCEPTION, Le champ Prix ne peut pas être négatif: [-100]'; // ✅ Vrai message
error.stackTrace = 'Class.isquote_QuoteLineService.createQuoteLineItems: line 127, column 1'; // ✅ Vrai stack trace
error.lineNumber = 127;
error.recordId = '0Q0Jv000009TjuDKAS';
error.objectType = 'Quote';

List<ErrorDiagnosticService.Response> responses = 
    ErrorDiagnosticService.diagnoseAndCreateCase(new List<ErrorDiagnosticService.ErrorInfo>{ error });

System.debug('Case amélioré: ' + responses[0].caseId);
```

**Résultat attendu** : Diagnostic IA beaucoup plus précis !

---

## ✅ SOLUTION 2 : Améliorer le Logging Apex (PERMANENT)

### Modifier la classe Apex appelée

**AVANT** (logging basique) :
```apex
@AuraEnabled
public static void createQuoteLineItems(Map<String, Object> configuration) {
    try {
        List<QuoteLineItem> lines = buildQuoteLines(configuration);
        insert lines;
    } catch (Exception e) {
        throw new AuraHandledException(e.getMessage()); // ❌ Stack trace perdu
    }
}
```

**APRÈS** (logging enrichi) :
```apex
@AuraEnabled
public static void createQuoteLineItems(Map<String, Object> configuration) {
    try {
        List<QuoteLineItem> lines = buildQuoteLines(configuration);
        insert lines;
    } catch (Exception e) {
        // ✅ Logger AVANT de wrapper
        UniversalLogger.error(
            'isquote_QuoteLineService',
            'createQuoteLineItems',
            'Erreur lors de la création des lignes de devis',
            e,
            new Map<String, Object>{
                'configuration' => configuration,
                'linesCount' => lines?.size(),
                'quoteId' => (String)configuration.get('quoteId')
            }
        );
        
        // ✅ Diagnostic IA automatique
        ErrorDiagnosticService.ErrorInfo error = new ErrorDiagnosticService.ErrorInfo();
        error.errorType = 'APEX';
        error.className = 'isquote_QuoteLineService';
        error.methodName = 'createQuoteLineItems';
        error.errorMessage = e.getMessage();
        error.stackTrace = e.getStackTraceString();
        error.recordId = (String)configuration.get('quoteId');
        error.objectType = 'Quote';
        error.contextData = JSON.serialize(configuration);
        
        ErrorDiagnosticService.diagnoseAndCreateCase(new List<ErrorDiagnosticService.ErrorInfo>{ error });
        
        // Wrapper pour le LWC
        throw new AuraHandledException(e.getMessage());
    }
}
```

**Avantages** :
- ✅ Stack trace complet dans les logs
- ✅ Diagnostic IA automatique avec vraies infos
- ✅ Case créé même si LWC ne peut pas le faire
- ✅ Contexte complet pour debugging

---

## ✅ SOLUTION 3 : Améliorer le Prompt (DÉJÀ FAIT)

**Changements déployés dans `LWCErrorAdapter.cls`** :

```diff
+ ⚠️ CONTEXTE SALESFORCE UNIQUEMENT:
+ - Utilise UNIQUEMENT du code Salesforce LWC valide
+ - Les appels serveur se font via méthodes Apex importées
+ - Génère du code qui COMPILE dans Salesforce

+ - Si le stack trace est incomplet ("Script-thrown exception"), ANALYSE EN PROFONDEUR:
+   * Le contextData JSON contient configurationData, componentState, metadata
+   * Cherche les pageErrors (validation DML) et fieldErrors
+   * Identifie les propriétés null, undefined ou invalides
+ - Identifie la cause EXACTE (ex: "bundleGroupId est null")
+ - Propose un correctif SALESFORCE LWC valide avec imports @salesforce/apex
```

**Résultat** : 
- ✅ L'IA ne génèrera plus de `fetch()` 
- ✅ L'IA analysera le contextData en profondeur
- ✅ Diagnostic plus précis même avec stack trace générique

---

## 🧪 TESTER LE NOUVEAU PROMPT

### Test 1 : Reproduire l'erreur du bundle

1. Aller dans le configurateur de bundle
2. **AVANT** : Activer Debug Logs
3. Déclencher l'erreur de sauvegarde
4. **APRÈS** : Vérifier le nouveau diagnostic

**Résultat attendu** :
- Code fix utilise `import createQuoteLineItems from '@salesforce/apex/...'`
- Analyse mentionne les données du contextData
- Root cause plus spécifique

### Test 2 : Comparer ancien vs nouveau diagnostic

**Ancien diagnostic** (que tu as montré) :
```
❌ PROBLÈME: erreur générique 'Script-thrown exception'
🔧 CORRECTIF: fetch('/api/saveQuoteLines', { ... })  // ❌ Pas Salesforce
```

**Nouveau diagnostic attendu** :
```
❌ PROBLÈME: Erreur lors de la sauvegarde des lignes de devis. 
   Le bundleGroupId est null alors qu'il est requis en mode reconfiguration.
🔍 CAUSE RACINE: Le composant LWC envoie bundleGroupId: null dans configurationData 
   alors que isReconfigurationMode est true.
🔧 CORRECTIF:
import createQuoteLineItems from '@salesforce/apex/isquote_QuoteLineService.createQuoteLineItems';

handleSave() {
    // ✅ Validation avant appel
    if (this.isReconfigurationMode && !this.bundleGroupId) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Erreur',
            message: 'Le bundleGroupId est requis en mode reconfiguration',
            variant: 'error'
        }));
        return;
    }
    
    const config = {
        quoteId: this.recordId,
        bundleId: this.bundleId,
        bundleGroupId: this.bundleGroupId,  // ✅ Sera défini
        features: this.buildFeaturesData()
    };
    
    createQuoteLineItems({ configuration: config })
        .then(result => { /* success */ })
        .catch(error => { /* error handling */ });
}
```

---

## 📊 COMPARAISON DES MÉTHODES

| Méthode | Effort | Qualité Diagnostic | Permanent |
|---------|--------|-------------------|-----------|
| **Debug Logs** | Faible | ⭐⭐⭐⭐⭐ Excellent | Non (manuel) |
| **Logging Apex amélioré** | Moyen | ⭐⭐⭐⭐⭐ Excellent | ✅ Oui |
| **Prompt amélioré** | Nul (déjà fait) | ⭐⭐⭐ Bon | ✅ Oui |

---

## 🎯 RECOMMANDATION

### Court terme (MAINTENANT)
1. ✅ Activer Debug Logs sur ton user
2. ✅ Reproduire l'erreur du bundle
3. ✅ Lire le vrai stack trace dans les Debug Logs
4. ✅ Créer un Case manuel avec les vraies infos

### Moyen terme (PROCHAINE SEMAINE)
1. ✅ Modifier `isquote_QuoteLineService.createQuoteLineItems()` pour logger AVANT le throw
2. ✅ Ajouter diagnostic IA automatique dans le catch
3. ✅ Tester avec une vraie erreur

### Long terme (AMÉLIORATION CONTINUE)
1. ✅ Migrer tous les `@AuraEnabled` methods vers le pattern de logging enrichi
2. ✅ Monitorer la qualité des diagnostics IA
3. ✅ Ajuster les prompts selon les cas d'usage

---

## 🔍 EXEMPLE DE DEBUG LOG À CHERCHER

Quand tu ouvres un Debug Log, cherche ces patterns :

### Pattern 1 : DML Exception
```
EXCEPTION_THROWN|[127]|System.DmlException: Insert failed
FIELD_CUSTOM_VALIDATION_EXCEPTION
REQUIRED_FIELD_MISSING
DUPLICATE_VALUE
```

### Pattern 2 : Null Pointer
```
EXCEPTION_THROWN|[45]|System.NullPointerException
Attempt to de-reference a null object
```

### Pattern 3 : Validation Rule
```
VALIDATION_FORMULA
VALIDATION_FAIL
Error: Prix ne peut pas être négatif
```

### Pattern 4 : Stack Trace complet
```
Class.isquote_QuoteLineService.createQuoteLineItems: line 127, column 1
Class.isquote_QuoteLineService.buildQuoteLines: line 89, column 1
Class.isquote_BundleConfiguratorController.saveConfiguration: line 23, column 1
```

---

## 💡 ASTUCE : Filtre Debug Logs

**Dans Developer Console** :

1. Ouvrir le Debug Log
2. Filter: `EXCEPTION|ERROR|FATAL`
3. Ctrl+F : Chercher "EXCEPTION_THROWN"

**Résultat** : Tu vois directement toutes les erreurs sans le bruit

---

## 📞 SUPPORT

Si après avoir suivi ce guide le diagnostic reste générique :

1. Partager le Debug Log complet
2. Partager le contextData envoyé au diagnostic
3. Vérifier que LWCErrorAdapter amélioré est bien déployé

---

**Date de création** : 2025-01-09
**Version** : 1.0
**Lié à** : GUIDE_TEST_PRODUCTION.md
