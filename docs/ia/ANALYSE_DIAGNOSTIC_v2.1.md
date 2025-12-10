# 🔬 Analyse Diagnostic IA v2.1

**Date** : 2025-12-10  
**Test** : Single diagnostic avec contextData enrichi

---

## 📊 RÉSULTAT DU TEST

### Réponse IA Brute
- **Longueur** : 2233 caractères
- **Format** : JSON valide ✅
- **Parsing** : Réussi ✅

### Code Fix Généré

```javascript
// Dans handleSave(), AVANT l'appel createQuoteLineItems, ajouter:
if (!this.bundleGroupId) {
    this.showToast('Erreur', 'Le groupe de bundle (bundleGroupId) est requis pour enregistrer les lignes de devis.', 'error');
    return;
}

// Ajouter une méthode showToast pour afficher les messages d'erreur:
showToast(title, message, variant) {
    const evt = new ShowToastEvent({
        title: title,
        message: message,
        variant: variant
    });
    this.dispatchEvent(evt);
}
```

---

## ✅ CE QUI FONCTIONNE

| Critère | Status | Note |
|---------|--------|------|
| JSON valide | ✅ | OK |
| Méthode Apex identifiée | ✅ | `createQuoteLineItems` |
| Cause racine | ✅ | bundleGroupId null |
| Validation proposée | ✅ | Check côté client |
| ShowToastEvent | ✅ | Mentionné |

---

## ❌ CE QUI NE FONCTIONNE PAS

| Critère | Status | Attendu | Obtenu |
|---------|--------|---------|--------|
| Import @salesforce/apex | ❌ | `import createQuoteLineItems from '@salesforce/apex/isquote_QuoteLineItemController.createQuoteLineItems';` | Absent |
| Import ShowToastEvent | ❌ | `import { ShowToastEvent } from 'lightning/platformShowToastEvent';` | Absent |
| Patch minimal | ❌ | 3-5 lignes | Méthode complète (10+ lignes) |
| Utilisation apexClass | ❌ | Extraire de contextData | Pas utilisé |
| Utilisation apexMethod | ❌ | Extraire de contextData | Pas utilisé |
| Format lisible | ❌ | Vraies nouvelles lignes | `\\n` échappés |

---

## 🔍 ANALYSE DU PROBLÈME

### ContextData envoyé
```json
{
    "bundleGroupId": null,
    "action": "handleSave",
    "apexClass": "isquote_QuoteLineItemController",  // ✅ ENVOYÉ
    "apexMethod": "createQuoteLineItems",            // ✅ ENVOYÉ
    ...
}
```

### Ce que le prompt demande
```
"Si possible, extrais le nom de la méthode Apex du stackTrace ou 
contextData (ex: createQuoteLineItems)"
```

### Ce que l'IA a fait
- ✅ A bien identifié `createQuoteLineItems` (dans le texte)
- ❌ N'a PAS généré l'import correspondant
- ❌ N'a PAS utilisé `apexClass` du contextData

---

## 💡 HYPOTHÈSES

### 1. Instruction "Si possible" trop faible
Le prompt dit "Si possible" → L'IA considère que c'est optionnel

### 2. Conflit entre "patch minimal" et "code complet"
Le prompt demande :
- "Patch minimal" (3-5 lignes)
- "Code complet et fonctionnel"

➡️ **Contradiction** : L'IA ne sait pas quoi choisir

### 3. Format JSON échappe les backslashes
`\\n` au lieu de vraies nouvelles lignes rend le code illisible

### 4. IA ne voit pas assez d'exemples
Le prompt ne montre PAS d'exemple concret avec imports

---

## 🎯 SOLUTIONS PROPOSÉES

### Solution A : Prompt avec EXEMPLE concret

Ajouter dans le prompt :

```
EXEMPLE DE CORRECTIF ATTENDU:

// 1. IMPORTS (EN HAUT DU FICHIER)
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createQuoteLineItems from '@salesforce/apex/isquote_QuoteLineItemController.createQuoteLineItems';

// 2. VALIDATION (Dans handleSave(), AVANT l'appel Apex)
if (!this.bundleGroupId) {
    this.dispatchEvent(new ShowToastEvent({
        title: 'Erreur',
        message: 'Le bundleGroupId est requis',
        variant: 'error'
    }));
    return;
}
```

### Solution B : Séparer imports et code

Modifier la structure JSON :

```json
{
  "imports": [
    "import { ShowToastEvent } from 'lightning/platformShowToastEvent';",
    "import createQuoteLineItems from '@salesforce/apex/APEX_CLASS.APEX_METHOD';"
  ],
  "codeFix": "if (!this.bundleGroupId) { ... }",
  ...
}
```

### Solution C : Instructions OBLIGATOIRES

Remplacer "Si possible" par :

```
OBLIGATOIRE:
- Extrais apexClass du contextData (ex: "isquote_QuoteLineItemController")
- Extrais apexMethod du contextData (ex: "createQuoteLineItems")
- Génère l'import: import APEX_METHOD from '@salesforce/apex/APEX_CLASS.APEX_METHOD';
```

### Solution D : Format template

```
Le codeFix doit TOUJOURS suivre ce format:

// === IMPORTS À AJOUTER EN HAUT DU FICHIER ===
import ...

// === CODE À AJOUTER DANS handleSave() ===
if (!this.bundleGroupId) { ... }
```

---

## 📊 QUALITÉ PAR VERSION

| Version | Qualité | Problèmes principaux |
|---------|---------|---------------------|
| v1.0 (déc) | 4/10 | Code fetch() invalide, pas de contexte |
| v2.0 (jan) | 6/10 | Code Salesforce, mais imports manquants |
| **v2.1 (actuel)** | **7/10** | **JSON valide, mais pas de patch minimal ni imports** |
| v2.2 (cible) | 9-10/10 | Imports corrects + patch minimal |

---

## 🎯 PROCHAINE ÉTAPE RECOMMANDÉE

**Implémenter Solution A + C** :
1. Ajouter un EXEMPLE concret dans le prompt
2. Rendre l'extraction apexClass/apexMethod OBLIGATOIRE
3. Utiliser un template strict pour le format

**Impact estimé** : +2 points → **9/10**

---

**Date d'analyse** : 2025-12-10  
**Analysé par** : Cursor AI Assistant  
**Prochaine révision** : Après implémentation v2.2
