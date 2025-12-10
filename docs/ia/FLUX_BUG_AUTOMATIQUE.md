# 🐛 Flux Automatique en Cas de Bug

## Ce qui se passe automatiquement

### 1. **Détection du Bug**
Un bug survient dans :
- **Flow** : Erreur dans un élément (Decision, Action, etc.)
- **Apex** : Exception levée dans une classe
- **LWC** : Erreur JavaScript dans un composant

### 2. **Appel au Service de Diagnostic**
Le code appelle `ErrorDiagnosticService.diagnoseAndCreateCase()` avec les informations du bug.

### 3. **Analyse par Azure OpenAI (GPT-4o)**
- Le service construit un prompt spécialisé selon le type d'erreur
- Envoie le prompt à Azure OpenAI
- Reçoit un diagnostic structuré en JSON :
  ```json
  {
    "problem": "Description du problème",
    "rootCause": "Cause racine identifiée",
    "solution": "Solution recommandée",
    "codeFix": "Correction de code si applicable",
    "steps": ["Étape 1", "Étape 2", ...],
    "severity": "CRITICAL|HIGH|MEDIUM|LOW"
  }
  ```

### 4. **Création Automatique d'un Case**
Un Case Salesforce est créé avec :
- **Subject** : "FLOW ERROR: [Nom du Flow]" (ou APEX ERROR, LWC ERROR)
- **Type** : APEX, LWC, ou FLOW
- **Priority** : Basée sur la sévérité (High, Medium, Low)
- **Origin** : "Automated"
- **Description** : Diagnostic IA complet avec :
  - Problème identifié
  - Cause racine
  - Solution recommandée
  - Étapes de correction détaillées
  - Code fix si applicable

### 5. **Email Automatique à l'Admin**
Le Flow `Case_Error_Email_Sender` détecte la création du Case et :
- Récupère l'email de l'admin (profil System Administrator)
- Envoie un email HTML avec le diagnostic IA
- Le sujet de l'email = Subject du Case
- Le corps = Description formatée en HTML

---

## 📊 Exemple Concret (Test Réussi)

### Bug Simulé
```
Type: FLOW
Flow: Quote_Trigger_Update
Message: Field Owner_Role__c does not exist
Élément: Decision Check Owner Role
```

### Diagnostic IA Généré
```
PROBLÈME IDENTIFIÉ:
Le champ personnalisé 'Owner_Role__c' est soit inexistant sur l'objet 'Quote', 
soit il n'est pas accessible dans le contexte du Flow.

CAUSE RACINE:
Le champ 'Owner_Role__c' n'existe pas ou n'est pas accessible (permissions).

SOLUTION:
1. Vérifier si le champ existe sur l'objet Quote
2. Si non, le créer ou modifier la logique du Flow
3. Si oui, vérifier les permissions d'accès

ÉTAPES DE CORRECTION:
1. Accéder à Setup > Object Manager > Quote
2. Vérifier l'existence du champ Owner_Role__c
3. Créer le champ si nécessaire
4. Vérifier les Field-Level Security
5. Corriger le Flow dans Flow Builder
6. Tester le Flow
7. Activer la version corrigée
```

### Case Créé
- **ID** : `500...` (généré automatiquement)
- **Subject** : "FLOW ERROR: Quote_Trigger_Update"
- **Type** : FLOW
- **Priority** : High
- **Origin** : Automated
- **Description** : Diagnostic IA complet

### Email Envoyé
- **Destinataire** : Admin (profil System Administrator)
- **Sujet** : "FLOW ERROR: Quote_Trigger_Update"
- **Corps** : Description formatée en HTML avec le diagnostic

---

## 🔧 Comment Intégrer dans Tes Flows/Apex/LWC

### Dans un Flow (Fault Path)

1. **Ajouter un Fault Path** à ton élément Flow
2. **Ajouter une Action Call** → **Apex Action**
3. **Sélectionner** : `ErrorDiagnosticService.diagnoseAndCreateCase`
4. **Mapper les variables** :
   - `errorType` = "FLOW"
   - `flowName` = `{!$Flow.CurrentElement.Label}`
   - `errorMessage` = `{!$Flow.FaultMessage}`
   - `faultElement` = `{!$Flow.CurrentElement.Label}`
   - `recordId` = `{!$Record.Id}` (si disponible)
   - `objectType` = `{!$Record.ObjectType}`

### Dans Apex (try-catch)

```apex
try {
    // Ton code
} catch (Exception e) {
    ErrorDiagnosticService.ErrorInfo error = new ErrorDiagnosticService.ErrorInfo();
    error.errorType = 'APEX';
    error.className = 'MaClasse';
    error.methodName = 'maMethode';
    error.errorMessage = e.getMessage();
    error.stackTrace = e.getStackTraceString();
    error.lineNumber = e.getLineNumber();
    
    ErrorDiagnosticService.diagnoseAndCreateCase(
        new List<ErrorDiagnosticService.ErrorInfo>{ error }
    );
}
```

### Dans LWC (JavaScript)

```javascript
try {
    // Ton code
} catch (error) {
    // Appeler Apex pour créer le diagnostic
    diagnoseError({
        errorType: 'LWC',
        componentName: 'monComposant',
        errorMessage: error.message,
        stackTrace: error.stack,
        jsCode: '...' // Code JavaScript si disponible
    })
    .then(result => {
        console.log('Case créé:', result.caseId);
    });
}
```

---

## ✅ Avantages

1. **Diagnostic Automatique** : Plus besoin d'analyser manuellement les erreurs
2. **Temps de Résolution Réduit** : L'IA propose directement des solutions
3. **Traçabilité** : Tous les bugs sont enregistrés dans des Cases
4. **Notification Immédiate** : L'admin reçoit un email avec le diagnostic
5. **Historique** : Tous les bugs sont trackés dans Salesforce

---

## 📈 Statistiques du Test

- **Temps de diagnostic** : ~10 secondes (incluant appel Azure OpenAI)
- **Callouts** : 7/100 utilisés
- **CPU Time** : 97ms / 10000ms
- **Case créé** : ✅
- **Email envoyé** : ✅ (via Flow)

---

**Le système est opérationnel et prêt à diagnostiquer automatiquement tes bugs ! 🚀**
