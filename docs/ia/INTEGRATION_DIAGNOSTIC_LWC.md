# 🔧 Intégration Diagnostic Automatique dans LWC

## Problème
Quand tu crées une vraie erreur dans Salesforce (comme dans le bundle), le diagnostic ne se déclenche pas automatiquement car il faut l'intégrer dans le code qui gère les erreurs.

## Solution : Intégrer dans `isquote_bundleConfigurator`

### Étape 1 : Ajouter l'import dans le LWC

Dans `isquote_bundleConfigurator.js`, ajouter en haut avec les autres imports :

```javascript
import diagnoseLWCError from '@salesforce/apex/ErrorDiagnosticService.diagnoseLWCError';
```

### Étape 2 : Modifier le catch du handleSave

Remplacer le bloc `.catch()` actuel (ligne ~1404) par :

```javascript
.catch(error => {
    console.error('❌ [ERROR] Save failed:', error.body?.message || error.message);
    this.showToast('Erreur', 'Impossible de sauvegarder la configuration: ' + (error.body?.message || error.message), 'error');
    
    // 🔧 NOUVEAU : Diagnostic automatique avec IA
    const errorMessage = 'Impossible de sauvegarder la configuration: ' + (error.body?.message || error.message);
    const stackTrace = error.body?.stackTrace || error.stack || '';
    const contextData = JSON.stringify({
        bundleId: this.bundleId,
        bundleName: this.bundleName,
        quoteId: this.recordId,
        action: 'handleSave',
        featuresCount: this.features?.length || 0
    });
    
    // Appel asynchrone au diagnostic (ne bloque pas l'utilisateur)
    diagnoseLWCError({
        componentName: 'isquote_bundleConfigurator',
        errorMessage: errorMessage,
        stackTrace: stackTrace,
        recordId: this.recordId,
        objectType: 'Quote',
        contextData: contextData
    })
    .then(caseId => {
        if (caseId) {
            console.log('✅ [DIAGNOSTIC] Case créé avec diagnostic IA: ' + caseId);
        }
    })
    .catch(diagnosticError => {
        console.error('❌ [DIAGNOSTIC] Erreur lors du diagnostic:', diagnosticError);
        // Ne pas bloquer l'utilisateur si le diagnostic échoue
    });
});
```

### Étape 3 : Déployer

1. Déployer la classe `ErrorDiagnosticService` (avec la nouvelle méthode `@AuraEnabled`)
2. Déployer le composant LWC modifié

---

## Résultat

Maintenant, quand une erreur survient lors de la sauvegarde du bundle :
1. ✅ L'erreur est affichée à l'utilisateur (toast)
2. ✅ Un Case est automatiquement créé avec diagnostic IA
3. ✅ Un email est envoyé à l'admin avec le diagnostic

---

## Fichiers à modifier

- ✅ `force-app/main/default/classes/ErrorDiagnosticService.cls` → Méthode `@AuraEnabled` ajoutée
- ⏳ `force-app/main/default/lwc/isquote_bundleConfigurator/isquote_bundleConfigurator.js` → À modifier (voir étape 2)

---

**Une fois intégré, chaque erreur réelle déclenchera automatiquement le diagnostic IA ! 🚀**
