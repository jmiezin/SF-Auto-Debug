# 🚀 Guide d'Utilisation - Error Diagnostic Service

## Architecture Créée

✅ **Service Unifié** : `ErrorDiagnosticService`  
✅ **Adaptateurs Spécialisés** : `ApexErrorAdapter`, `LWCErrorAdapter`, `FlowErrorAdapter`  
✅ **Tests** : `ErrorDiagnosticServiceTest`

---

## 📋 Utilisation

### 1. Pour les Flows

**Dans ton Flow avec Fault Path :**

```
Flow avec erreur
    ↓
Fault Path
    ↓
Action Apex: ErrorDiagnosticService.diagnoseAndCreateCase()
    Inputs:
    - errorType: "FLOW"
    - flowName: {!$Flow.Label}
    - flowApiName: {!$Flow.ApiName}
    - errorMessage: {!$Flow.FaultMessage}
    - faultElement: {!$Flow.FaultElement}
    - recordId: {!$Record.Id}
    - objectType: {!$Record.ObjectType}
```

**Exemple concret :**

Modifier `Universal_Log_Flow_Error` pour ajouter l'appel au diagnostic :

```
1. Create Error Log (existant)
2. Action Apex: ErrorDiagnosticService.diagnoseAndCreateCase()
   - errorType: "FLOW"
   - flowName: {!IN_Flow_Name}
   - errorMessage: {!IN_Error_Message}
   - recordId: {!IN_Record_Id}
   - objectType: {!IN_Object_Type}
```

---

### 2. Pour Apex

**Dans ton code Apex avec Try-Catch :**

```apex
try {
    // Code métier
} catch (Exception e) {
    // Créer ErrorInfo
    ErrorDiagnosticService.ErrorInfo error = new ErrorDiagnosticService.ErrorInfo();
    error.errorType = 'APEX';
    error.className = 'QuoteService';
    error.methodName = 'calculateTotal';
    error.errorMessage = e.getMessage();
    error.stackTrace = e.getStackTraceString();
    error.lineNumber = e.getLineNumber();
    error.recordId = quoteId;
    error.objectType = 'Quote';
    
    // Appeler le diagnostic
    List<ErrorDiagnosticService.Response> responses = 
        ErrorDiagnosticService.diagnoseAndCreateCase(new List<ErrorDiagnosticService.ErrorInfo>{ error });
    
    // Re-throw l'erreur
    throw e;
}
```

**Version simplifiée (méthode helper) :**

```apex
public class ErrorHelper {
    public static void logError(Exception e, String className, String methodName, String recordId, String objectType) {
        ErrorDiagnosticService.ErrorInfo error = new ErrorDiagnosticService.ErrorInfo();
        error.errorType = 'APEX';
        error.className = className;
        error.methodName = methodName;
        error.errorMessage = e.getMessage();
        error.stackTrace = e.getStackTraceString();
        error.lineNumber = e.getLineNumber();
        error.recordId = recordId;
        error.objectType = objectType;
        
        ErrorDiagnosticService.diagnoseAndCreateCase(new List<ErrorDiagnosticService.ErrorInfo>{ error });
    }
}

// Utilisation
try {
    // Code
} catch (Exception e) {
    ErrorHelper.logError(e, 'QuoteService', 'calculateTotal', quoteId, 'Quote');
    throw e;
}
```

---

### 3. Pour LWC

**Dans ton LWC JavaScript :**

```javascript
import { LightningElement } from 'lwc';
import diagnoseError from '@salesforce/apex/ErrorDiagnosticService.diagnoseAndCreateCase';

export default class MyComponent extends LightningElement {
    
    handleError(error) {
        const errorInfo = {
            errorType: 'LWC',
            componentName: 'myComponent',
            errorMessage: error.message,
            stackTrace: error.stack,
            recordId: this.recordId,
            objectType: 'Quote',
            jsCode: this.getSourceCode(), // Optionnel
            contextData: JSON.stringify({
                userId: this.userId,
                quoteId: this.recordId
            })
        };
        
        diagnoseError({ errors: [errorInfo] })
            .then(result => {
                console.log('Case créé:', result[0].caseId);
            })
            .catch(err => {
                console.error('Erreur diagnostic:', err);
            });
    }
}
```

**Dans ton Apex appelé depuis LWC :**

```apex
@AuraEnabled
public static void myMethod(String recordId) {
    try {
        // Code métier
    } catch (Exception e) {
        // Créer ErrorInfo
        ErrorDiagnosticService.ErrorInfo error = new ErrorDiagnosticService.ErrorInfo();
        error.errorType = 'LWC';
        error.componentName = 'myComponent';
        error.errorMessage = e.getMessage();
        error.stackTrace = e.getStackTraceString();
        error.recordId = recordId;
        error.objectType = 'Quote';
        
        // Appeler le diagnostic
        ErrorDiagnosticService.diagnoseAndCreateCase(new List<ErrorDiagnosticService.ErrorInfo>{ error });
        
        throw new AuraHandledException('Erreur: ' + e.getMessage());
    }
}
```

---

## 📧 Configuration Email Automatique

### Flow : Case_Error_Email_Sender

**Déclenchement :** Case créé avec `Origin = 'Automated'`

**Structure :**
```
1. Get Records → Case actuel
   WHERE Id = {!$Record.Id} AND Origin = 'Automated'
2. Decision → Vérifier que Type n'est pas vide
   - Outcome TRUE: Type = 'APEX' ou 'LWC' ou 'FLOW'
   - Outcome FALSE: Arrêter
3. Get Records → Récupérer email admin
   (depuis Custom Metadata ou User)
4. Send Email → Envoyer email avec description du Case
   - To: {!AdminEmail}
   - Subject: {!$Record.Subject}
   - Body: {!$Record.Description}
```

**Créer le Flow :**

1. Setup → Flows → New Flow
2. Record-Triggered Flow
3. Object: Case
4. Trigger: A record is created
5. Conditions: `Origin = 'Automated'`
6. Ajouter les éléments ci-dessus

---

## 🎯 Exemples Concrets

### Exemple 1 : Flow Quote_Trigger_Update échoue

**Scénario :** Flow échoue car champ `Owner_Role__c` n'existe pas

**Résultat :**
- ✅ Case créé avec diagnostic IA complet
- ✅ Email envoyé automatiquement à l'admin
- ✅ Diagnostic : "Champ Owner_Role__c manquant"
- ✅ Solution : "Utiliser Owner.Profile.Name à la place"
- ✅ Correctif : "Modifier la décision dans Flow Builder..."

---

### Exemple 2 : Apex QuoteService.calculateTotal échoue

**Scénario :** NullPointerException ligne 127

**Résultat :**
- ✅ Case créé avec diagnostic IA
- ✅ Diagnostic : "account.Owner.Name est null"
- ✅ Solution : "Ajouter Owner.Name dans la requête SOQL"
- ✅ Code corrigé : "SELECT Id, Name, Owner.Name FROM Account..."

---

### Exemple 3 : LWC iscpq_bundleSelector échoue

**Scénario :** "Cannot read property 'recordId' of undefined"

**Résultat :**
- ✅ Case créé avec diagnostic IA
- ✅ Diagnostic : "this.recordId est undefined"
- ✅ Solution : "Utiliser @wire(getRecord) pour charger les données"
- ✅ Code corrigé : "@wire(getRecord, { recordId: '$recordId' })..."

---

## 🔧 Configuration

### Custom Metadata : Admin_Config__mdt

**Créer pour configurer l'email admin :**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>Admin Email</label>
    <protected>false</protected>
    <values>
        <field>Admin_Email__c</field>
        <value>admin@isonic.ai</value>
    </values>
</CustomMetadata>
```

**Modifier `ErrorDiagnosticService.getAdminUserId()` :**

```apex
private static Id getAdminUserId() {
    // Option 1: Custom Metadata
    // Admin_Config__mdt config = [SELECT Admin_User_Id__c FROM Admin_Config__mdt LIMIT 1];
    // return config.Admin_User_Id__c;
    
    // Option 2: User par email
    // User admin = [SELECT Id FROM User WHERE Email = 'admin@isonic.ai' LIMIT 1];
    // return admin.Id;
    
    // Option 3: Queue
    // Group queue = [SELECT Id FROM Group WHERE Type = 'Queue' AND Name = 'Support' LIMIT 1];
    // return queue.Id;
    
    // Par défaut: User actuel
    return UserInfo.getUserId();
}
```

---

## 📊 Structure du Case Créé

**Subject :** `[APEX ERROR] QuoteService - CRITICAL`

**Description :**
```
=== INFORMATIONS DE L'ERREUR ===
Type: APEX
Classe: QuoteService
Méthode: calculateTotal
Ligne: 127
Record déclencheur: Quote (0Q0xx000000abc123)
Date: 2025-01-XX XX:XX:XX

=== MESSAGE D'ERREUR ===
System.NullPointerException: Attempt to de-reference a null object

=== STACK TRACE ===
Class.QuoteService.calculateTotal: line 127

=== DIAGNOSTIC IA ===

PROBLÈME IDENTIFIÉ:
Ligne 127 tente d'accéder à account.Owner.Name mais account.Owner est null.

CAUSE RACINE:
La requête SOQL ligne 45 ne charge pas la relation Owner.

SOLUTION RECOMMANDÉE:
1. Modifier la requête SOQL ligne 45
2. Ajouter 'Owner.Name' dans le SELECT
3. Tester avec un Account qui a un Owner

CORRECTIF PROPOSÉ:
SELECT Id, Name, Owner.Name FROM Account WHERE Id = :accountId

ÉTAPES DE CORRECTION:
1. Ouvrir QuoteService.cls
2. Trouver la requête SOQL ligne 45
3. Ajouter Owner.Name dans le SELECT
4. Tester avec un Account
```

---

## ✅ Checklist de Déploiement

- [ ] Déployer les classes Apex
  - `ErrorDiagnosticService`
  - `ApexErrorAdapter`
  - `LWCErrorAdapter`
  - `FlowErrorAdapter`
  - `ErrorDiagnosticServiceTest`

- [ ] Configurer Custom Metadata
  - Créer `Admin_Config__mdt` avec email admin
  - Modifier `getAdminUserId()` si nécessaire

- [ ] Créer Flow `Case_Error_Email_Sender`
  - Déclenché sur Case créé avec `Origin = 'Automated'`
  - Envoie email avec description du Case

- [ ] Modifier Flow `Universal_Log_Flow_Error`
  - Ajouter action Apex `ErrorDiagnosticService.diagnoseAndCreateCase()`

- [ ] Tester avec une erreur Flow volontaire

- [ ] Intégrer dans code Apex existant (optionnel)

- [ ] Intégrer dans LWC existants (optionnel)

---

## 🎓 Prochaines Étapes

1. **Déployer les classes** dans ton org
2. **Créer le Flow** `Case_Error_Email_Sender`
3. **Tester** avec une erreur Flow
4. **Vérifier** que le Case est créé et l'email envoyé
5. **Intégrer progressivement** dans tes Flows/Apex/LWC

---

**C'est prêt !** 🚀
