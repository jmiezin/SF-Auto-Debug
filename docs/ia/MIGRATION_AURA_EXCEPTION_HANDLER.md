# 🔄 Migration vers AuraExceptionHandler

**Objectif** : Capturer le stack trace Apex AVANT le wrapper AuraHandledException

**Bénéfice** : Diagnostics IA précis au lieu de "Script-thrown exception"

---

## 🎯 PRINCIPE

### Problème actuel
```apex
catch (Exception e) {
    throw new AuraHandledException(e.getMessage()); // ❌ Stack trace perdu
}
```

### Solution
```apex
catch (Exception e) {
    throw AuraExceptionHandler.handle(e, className, methodName, context);
    // ✅ Stack trace capturé + Case créé + Logging
}
```

---

## 📊 CLASSES À MIGRER

### 1. Identifier tous les @AuraEnabled methods

```bash
# Dans terminal
cd "/Users/jonathanmiezin/Desktop/IS Migration"
grep -r "@AuraEnabled" force-app/main/default/classes/ -A 10 | grep "throw new AuraHandledException"
```

### 2. Lister les fichiers concernés

**Exemple de fichiers probables** :
- `isquote_QuoteLineService.cls`
- `isquote_BundleConfiguratorController.cls`
- `isquote_PricingService.cls`
- Tous les controllers LWC custom

---

## 🔧 PATTERN DE MIGRATION

### Pattern Simple (sans recordId)

**AVANT** :
```apex
@AuraEnabled
public static String doSomething(String param) {
    try {
        // Logique métier
        return 'success';
    } catch (Exception e) {
        throw new AuraHandledException(e.getMessage());
    }
}
```

**APRÈS** :
```apex
@AuraEnabled
public static String doSomething(String param) {
    try {
        // Logique métier
        return 'success';
    } catch (Exception e) {
        throw AuraExceptionHandler.handle(
            e,
            'MyClassName',
            'doSomething',
            new Map<String, Object>{ 'param' => param }
        );
    }
}
```

### Pattern avec RecordId

**AVANT** :
```apex
@AuraEnabled
public static void updateAccount(String accountId, Map<String, Object> data) {
    try {
        Account acc = [SELECT Id FROM Account WHERE Id = :accountId];
        // ... update logic
        update acc;
    } catch (Exception e) {
        throw new AuraHandledException(e.getMessage());
    }
}
```

**APRÈS** :
```apex
@AuraEnabled
public static void updateAccount(String accountId, Map<String, Object> data) {
    try {
        Account acc = [SELECT Id FROM Account WHERE Id = :accountId];
        // ... update logic
        update acc;
    } catch (Exception e) {
        throw AuraExceptionHandler.handle(
            e,
            'AccountService',
            'updateAccount',
            new Map<String, Object>{ 
                'accountId' => accountId,
                'data' => data
            },
            accountId,  // recordId
            'Account'   // objectType
        );
    }
}
```

### Pattern avec données sensibles

**⚠️ Attention** : Ne pas logger de données sensibles (mots de passe, tokens, etc.)

```apex
@AuraEnabled
public static void processPayment(String cardNumber, Decimal amount) {
    try {
        // Process payment
    } catch (Exception e) {
        throw AuraExceptionHandler.handle(
            e,
            'PaymentService',
            'processPayment',
            new Map<String, Object>{ 
                'amount' => amount,
                'cardLast4' => cardNumber.right(4)  // ✅ Seulement les 4 derniers chiffres
                // ❌ PAS le numéro complet
            }
        );
    }
}
```

---

## 📋 CHECKLIST DE MIGRATION

### Phase 1 : Préparation
- [ ] Déployer `AuraExceptionHandler.cls` + test
- [ ] Vérifier que `UniversalLogger` est déployé
- [ ] Vérifier que `ErrorDiagnosticService` est opérationnel

### Phase 2 : Migration par priorité

**Priorité 1 (CRITIQUE)** :
- [ ] Classes utilisées par les LWC principaux (configurateur, pricing)
- [ ] Classes avec beaucoup d'erreurs en production

**Priorité 2 (IMPORTANT)** :
- [ ] Tous les controllers LWC
- [ ] Services métier critiques

**Priorité 3 (NORMAL)** :
- [ ] Utilitaires
- [ ] Helpers

### Phase 3 : Validation
- [ ] Tester chaque méthode migrée
- [ ] Vérifier qu'un Case est créé en cas d'erreur
- [ ] Vérifier le diagnostic IA dans le Feed du Case

---

## 🧪 TEST DE MIGRATION

### Après migration d'une classe

**1. Déclencher volontairement une erreur** :

```apex
// Dans Developer Console
try {
    MyMigratedClass.myMethod('invalid-data');
} catch (Exception e) {
    System.debug('Error caught: ' + e.getMessage());
}
```

**2. Vérifier** :

```sql
-- Case créé ?
SELECT Id, CaseNumber, Subject, Description 
FROM Case 
WHERE Type = 'APEX' 
AND CreatedDate = TODAY 
ORDER BY CreatedDate DESC 
LIMIT 1

-- Feed avec diagnostic ?
SELECT Id, Body 
FROM FeedItem 
WHERE ParentId IN (
    SELECT Id FROM Case WHERE Type = 'APEX' AND CreatedDate = TODAY
)
ORDER BY CreatedDate DESC 
LIMIT 1
```

**3. Vérifier dans Debug Logs** :

```
[ERROR] [MyClassName] [myMethod] Erreur dans méthode @AuraEnabled
  ❌ Exception Type: System.DmlException
  ❌ Message: Insert failed...
  ❌ Stack Trace: Class.MyClassName.myMethod: line 45
```

---

## 📊 SUIVI DE MIGRATION

### Tableau de suivi

| Classe | Méthodes @AuraEnabled | Migrée ? | Testée ? | Date |
|--------|----------------------|----------|----------|------|
| isquote_QuoteLineService | createQuoteLineItems | ✅ | ✅ | 2025-01-10 |
| isquote_PricingService | calculatePrice | ⏳ | ❌ | - |
| AccountController | updateAccount | ❌ | ❌ | - |

### Commande pour compter les méthodes restantes

```bash
# Méthodes NON migrées
grep -r "throw new AuraHandledException" force-app/main/default/classes/ | wc -l

# Méthodes migrées
grep -r "AuraExceptionHandler.handle" force-app/main/default/classes/ | wc -l
```

---

## 💡 BONNES PRATIQUES

### 1. Context Data Minimal mais Complet

```apex
new Map<String, Object>{
    'recordId' => recordId,           // ✅ ID du record
    'action' => 'update',             // ✅ Action effectuée
    'fieldsModified' => fieldsChanged // ✅ Champs modifiés
    // ❌ PAS tout l'objet si volumineux
}
```

### 2. ClassName et MethodName Exacts

```apex
throw AuraExceptionHandler.handle(
    e,
    'isquote_QuoteLineService',      // ✅ Nom exact de la classe
    'createQuoteLineItems',          // ✅ Nom exact de la méthode
    context
);
```

### 3. ObjectType Standard

```apex
'Account', 'Contact', 'Opportunity', 'Quote', 'Case'
// Pas 'account' ou 'ACCOUNT' - utiliser le nom API exact
```

---

## 🚨 ATTENTION

### Ne PAS migrer immédiatement si :

1. **Méthode critique en production** : Tester d'abord en sandbox
2. **Volume élevé d'appels** : Risque de limite de Queueable (vérifier)
3. **Données sensibles** : Nettoyer le context avant de logger

### Alternative pour volume élevé

Si une méthode est appelée >100 fois/jour, utiliser un flag :

```apex
private static final Boolean ENABLE_DIAGNOSTIC = true; // Config

catch (Exception e) {
    if (ENABLE_DIAGNOSTIC) {
        throw AuraExceptionHandler.handle(...);
    } else {
        // Logging uniquement
        UniversalLogger.error(...);
        throw new AuraHandledException(e.getMessage());
    }
}
```

---

## 📞 SUPPORT

Si problème pendant la migration :
1. Vérifier les Debug Logs
2. Vérifier que AuraExceptionHandler est déployé
3. Vérifier les limites Queueable (max 50/transaction)

---

**Date de création** : 2025-01-09
**Version** : 1.0
**Auteur** : Salesforce Diagnostics System
