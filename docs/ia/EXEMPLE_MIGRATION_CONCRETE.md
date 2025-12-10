# 🔄 Exemple Concret : Migration vers AuraExceptionHandler

**Classe** : `isquote_QuoteLineItemController`  
**Méthode** : `createQuoteLineItems`

---

## ❌ AVANT : Code actuel (supposé)

```apex
public with sharing class isquote_QuoteLineItemController {
    
    @AuraEnabled
    public static Map<String, Object> createQuoteLineItems(Map<String, Object> configuration) {
        try {
            // Extraire les données
            String quoteId = (String)configuration.get('quoteId');
            String bundleId = (String)configuration.get('bundleId');
            String bundleGroupId = (String)configuration.get('bundleGroupId');
            List<Object> features = (List<Object>)configuration.get('features');
            
            // Créer les lignes de devis
            List<QuoteLineItem> linesToInsert = new List<QuoteLineItem>();
            
            for (Object featureObj : features) {
                Map<String, Object> feature = (Map<String, Object>)featureObj;
                List<Object> options = (List<Object>)feature.get('options');
                
                for (Object optionObj : options) {
                    Map<String, Object> option = (Map<String, Object>)optionObj;
                    
                    QuoteLineItem line = new QuoteLineItem();
                    line.QuoteId = quoteId;
                    line.Product2Id = (String)option.get('productId');
                    line.Quantity = (Decimal)option.get('quantity');
                    line.UnitPrice = (Decimal)option.get('unitPrice');
                    line.isquote_BundleGroupId__c = bundleGroupId;
                    line.isquote_IsOptional__c = (Boolean)option.get('isOptional');
                    line.isquote_Condition__c = (String)option.get('condition');
                    
                    linesToInsert.add(line);
                }
            }
            
            // Insérer les lignes
            insert linesToInsert;
            
            // Retourner le résultat
            return new Map<String, Object>{
                'success' => true,
                'bundleGroupId' => bundleGroupId,
                'linesCreated' => linesToInsert.size()
            };
            
        } catch (Exception e) {
            // ❌ PROBLÈME: Stack trace perdu pour le LWC
            System.debug(LoggingLevel.ERROR, 'Error: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack: ' + e.getStackTraceString());
            throw new AuraHandledException(e.getMessage());
        }
    }
}
```

**Problèmes** :
- ❌ Stack trace perdu quand l'exception arrive au LWC
- ❌ Pas de Case créé automatiquement
- ❌ Pas de diagnostic IA
- ❌ Logging basique (juste System.debug)

---

## ✅ APRÈS : Code migré vers AuraExceptionHandler

```apex
public with sharing class isquote_QuoteLineItemController {
    
    @AuraEnabled
    public static Map<String, Object> createQuoteLineItems(Map<String, Object> configuration) {
        try {
            // Extraire les données
            String quoteId = (String)configuration.get('quoteId');
            String bundleId = (String)configuration.get('bundleId');
            String bundleGroupId = (String)configuration.get('bundleGroupId');
            List<Object> features = (List<Object>)configuration.get('features');
            
            // Créer les lignes de devis
            List<QuoteLineItem> linesToInsert = new List<QuoteLineItem>();
            
            for (Object featureObj : features) {
                Map<String, Object> feature = (Map<String, Object>)featureObj;
                List<Object> options = (List<Object>)feature.get('options');
                
                for (Object optionObj : options) {
                    Map<String, Object> option = (Map<String, Object>)optionObj;
                    
                    QuoteLineItem line = new QuoteLineItem();
                    line.QuoteId = quoteId;
                    line.Product2Id = (String)option.get('productId');
                    line.Quantity = (Decimal)option.get('quantity');
                    line.UnitPrice = (Decimal)option.get('unitPrice');
                    line.isquote_BundleGroupId__c = bundleGroupId;
                    line.isquote_IsOptional__c = (Boolean)option.get('isOptional');
                    line.isquote_Condition__c = (String)option.get('condition');
                    
                    linesToInsert.add(line);
                }
            }
            
            // Insérer les lignes
            insert linesToInsert;
            
            // Retourner le résultat
            return new Map<String, Object>{
                'success' => true,
                'bundleGroupId' => bundleGroupId,
                'linesCreated' => linesToInsert.size()
            };
            
        } catch (Exception e) {
            // ✅ SOLUTION: AuraExceptionHandler
            throw AuraExceptionHandler.handle(
                e,
                'isquote_QuoteLineItemController',
                'createQuoteLineItems',
                new Map<String, Object>{
                    'configuration' => configuration,
                    'quoteId' => (String)configuration.get('quoteId'),
                    'bundleId' => (String)configuration.get('bundleId'),
                    'bundleGroupId' => (String)configuration.get('bundleGroupId'),
                    'featuresCount' => ((List<Object>)configuration.get('features'))?.size()
                },
                (String)configuration.get('quoteId'),
                'Quote'
            );
        }
    }
}
```

**Bénéfices** :
- ✅ Stack trace complet capturé dans Debug Logs
- ✅ Case créé automatiquement avec diagnostic IA
- ✅ Logging structuré avec UniversalLogger
- ✅ Contexte complet préservé
- ✅ Message user-friendly pour le LWC

---

## 📊 CE QUI SE PASSE QUAND UNE ERREUR SURVIENT

### Scénario : Product2Id manquant

**Erreur réelle** :
```
System.DmlException: Insert failed. First exception on row 0; 
first error: REQUIRED_FIELD_MISSING, Required fields are missing: [Product2Id]
```

### AVANT (ancien code)

1. **Dans Apex** : `System.debug(LoggingLevel.ERROR, 'Error: Required fields are missing: [Product2Id]')`
2. **LWC reçoit** : `"Script-thrown exception"` ❌
3. **Diagnostic IA** : Générique ("erreur générique...") ❌
4. **Résultat** : Tu dois activer Debug Logs manuellement pour trouver le vrai problème ❌

### APRÈS (avec AuraExceptionHandler)

1. **Dans Apex** :
   ```
   [ERROR] [isquote_QuoteLineItemController] [createQuoteLineItems] 
   Erreur dans méthode @AuraEnabled
     ❌ Exception Type: System.DmlException
     ❌ Message: Insert failed. First exception on row 0; 
                  first error: REQUIRED_FIELD_MISSING, 
                  Required fields are missing: [Product2Id]
     ❌ Line: 45
     ❌ Stack Trace: Class.isquote_QuoteLineItemController.createQuoteLineItems: line 45
     👤 User: Jonathan Miezin (005xxx)
     📋 Context: {
       "quoteId": "0Q0xxx",
       "bundleId": "01txxx",
       "bundleGroupId": null,
       "featuresCount": 5
     }
   ```

2. **LWC reçoit** : `"Required fields are missing: [Product2Id]"` ✅

3. **Case créé automatiquement** avec diagnostic IA :
   ```
   🤖 DIAGNOSTIC IA AUTOMATIQUE
   
   ❌ PROBLÈME:
   Le champ Product2Id est manquant lors de la création des QuoteLineItems. 
   L'erreur se produit à la ligne 45 de isquote_QuoteLineItemController.createQuoteLineItems.
   
   🔍 CAUSE RACINE:
   Dans la boucle de création des QuoteLineItems, la propriété 'productId' n'est pas 
   présente dans les données de l'option, ce qui entraîne Product2Id = null.
   Vérifier que le LWC envoie bien productId dans chaque option du payload.
   
   ✅ SOLUTION:
   1. Vérifier côté LWC que option.get('productId') retourne une valeur valide
   2. Ajouter une validation côté Apex AVANT l'insertion
   3. Vérifier que les features loadées contiennent bien Product2Id
   
   🔧 CORRECTIF:
   // Côté Apex - Validation AVANT insert
   for (Object optionObj : options) {
       Map<String, Object> option = (Map<String, Object>)optionObj);
       String productId = (String)option.get('productId');
       
       // ✅ VALIDATION
       if (String.isBlank(productId)) {
           throw new AuraHandledException(
               'Product ID manquant pour l\'option: ' + option.get('name')
           );
       }
       
       QuoteLineItem line = new QuoteLineItem();
       line.Product2Id = productId;
       // ... rest of code
   }
   ```

4. **Résultat** : Tu as immédiatement le problème exact ET la solution ✅

---

## 🎯 ÉTAPES DE MIGRATION

### 1. Récupérer la classe depuis production

```bash
cd "/Users/jonathanmiezin/Desktop/IS Migration"

# Récupérer la classe
sf project retrieve start \
  --metadata ApexClass:isquote_QuoteLineItemController \
  --target-org production
```

### 2. Modifier le catch block

**Chercher** :
```apex
catch (Exception e) {
    System.debug(...);
    throw new AuraHandledException(e.getMessage());
}
```

**Remplacer par** :
```apex
catch (Exception e) {
    throw AuraExceptionHandler.handle(
        e,
        'isquote_QuoteLineItemController',
        'createQuoteLineItems',
        new Map<String, Object>{
            'configuration' => configuration,
            'quoteId' => (String)configuration.get('quoteId')
        },
        (String)configuration.get('quoteId'),
        'Quote'
    );
}
```

### 3. Déployer

```bash
sf project deploy start \
  --source-dir force-app/main/default/classes/isquote_QuoteLineItemController.cls \
  --target-org production \
  --wait 5
```

### 4. Tester

1. Ouvrir le configurateur de bundle
2. Essayer de sauvegarder (avec une erreur volontaire si besoin)
3. Vérifier qu'un Case est créé
4. Vérifier le diagnostic IA dans le Feed du Case

---

## 📋 CHECKLIST

- [ ] Classe récupérée depuis production
- [ ] Catch block modifié
- [ ] Classe déployée
- [ ] Test effectué
- [ ] Case vérifié
- [ ] Diagnostic IA vérifié

---

**Date** : 2025-01-09  
**Status** : Prêt à migrer
