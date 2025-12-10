# 📋 Standard de Logging Universel

Standard de logging unifié pour toute l'org Salesforce (LWC, Aura, Apex, Flow)

---

## 🎯 Format Standardisé

**Format :**
```
[LEVEL] [COMPONENT] [METHOD] [TIMESTAMP] Message
  👤 User: Name (UserId)
  📋 Context: {...}
```

**Niveaux :**
- `DEBUG` : Informations de débogage détaillées
- `INFO` : Informations générales
- `WARN` : Avertissements
- `ERROR` : Erreurs avec stack trace complet

---

## 📚 Utilisation

### 1. Depuis Apex

```apex
// Import
import UniversalLogger;

// Log simple
UniversalLogger.info('QuoteService', 'calculateTotal', 'Calculating total for quote');

// Log avec contexte
Map<String, Object> context = new Map<String, Object>{
    'quoteId' => quoteId,
    'lineItemsCount' => 5
};
UniversalLogger.info('QuoteService', 'calculateTotal', 'Calculating total', context);

// Log d'erreur avec exception
try {
    // Code
} catch (Exception e) {
    UniversalLogger.error('QuoteService', 'calculateTotal', 'Error calculating total', e, context);
    throw e;
}
```

**Méthodes disponibles :**
- `UniversalLogger.debug(component, method, message, context)`
- `UniversalLogger.info(component, method, message, context)`
- `UniversalLogger.warn(component, method, message, context)`
- `UniversalLogger.error(component, method, message, exception, context)`

---

### 2. Depuis LWC

```javascript
// Import
import log from 'c/universalLogger';

// Log simple
log.info('myComponent', 'handleClick', 'Button clicked');

// Log avec contexte
log.info('myComponent', 'handleSave', 'Saving data', {
    recordId: this.recordId,
    data: this.formData
});

// Log d'erreur
.catch(error => {
    log.error('myComponent', 'handleSave', 'Save failed', error, {
        recordId: this.recordId,
        formData: this.formData
    });
});
```

**Méthodes disponibles :**
- `log.debug(component, method, message, context)`
- `log.info(component, method, message, context)`
- `log.warn(component, method, message, context)`
- `log.error(component, method, message, error, context)`

---

### 3. Depuis Flow

**Action Apex : UniversalLogger.logFromFlow**

**Inputs :**
- `level` : DEBUG, INFO, WARN, ou ERROR
- `component` : Nom du Flow (ex: `{!$Flow.Label}`)
- `method` : Nom de l'action/élément (ex: "Create Record")
- `message` : Message à logger
- `contextJson` : JSON string avec données contextuelles (optionnel)

**Exemple dans Flow :**
```
Action: UniversalLogger.logFromFlow
  level: "INFO"
  component: {!$Flow.Label}
  method: "Create Quote"
  message: "Creating quote for account {!$Record.AccountId}"
  contextJson: "{ \"accountId\": \"{!$Record.AccountId}\", \"recordId\": \"{!$Record.Id}\" }"
```

---

## 🔍 Exemples Complets

### Apex - Gestion d'erreur complète

```apex
@AuraEnabled
public static Map<String, Object> createQuoteLineItems(ConfigurationWrapper config) {
    UniversalLogger.info('QuoteLineItemController', 'createQuoteLineItems', 'Starting', 
        new Map<String, Object>{ 'config' => JSON.serialize(config) });
    
    try {
        // Code métier
        UniversalLogger.debug('QuoteLineItemController', 'createQuoteLineItems', 
            'Processing ' + config.features.size() + ' features');
        
        // ...
        
        UniversalLogger.info('QuoteLineItemController', 'createQuoteLineItems', 
            'Successfully created ' + lineItems.size() + ' line items');
        
        return result;
    } catch (DmlException e) {
        Map<String, Object> errorContext = new Map<String, Object>{
            'quoteId' => config.quoteId,
            'bundleId' => config.bundleId,
            'dmlFields' => e.getDmlFieldNames(0),
            'dmlMessage' => e.getDmlMessage(0)
        };
        UniversalLogger.error('QuoteLineItemController', 'createQuoteLineItems', 
            'DML error creating line items', e, errorContext);
        throw new AuraHandledException('Error: ' + e.getDmlMessage(0));
    } catch (Exception e) {
        UniversalLogger.error('QuoteLineItemController', 'createQuoteLineItems', 
            'Unexpected error', e, new Map<String, Object>{ 'config' => JSON.serialize(config) });
        throw new AuraHandledException('Error: ' + e.getMessage());
    }
}
```

### LWC - Gestion d'erreur complète

```javascript
import { LightningElement, api } from 'lwc';
import log from 'c/universalLogger';
import createQuoteLineItems from '@salesforce/apex/QuoteLineItemController.createQuoteLineItems';

export default class MyComponent extends LightningElement {
    @api recordId;
    
    handleSave() {
        log.info('myComponent', 'handleSave', 'Starting save', {
            recordId: this.recordId
        });
        
        const config = this.buildConfig();
        
        createQuoteLineItems({ configuration: config })
            .then(result => {
                log.info('myComponent', 'handleSave', 'Save successful', {
                    recordId: this.recordId,
                    result: result
                });
            })
            .catch(error => {
                log.error('myComponent', 'handleSave', 'Save failed', error, {
                    recordId: this.recordId,
                    config: config
                });
            });
    }
}
```

---

## ✅ Bonnes Pratiques

1. **Toujours inclure component et method** : Facilite le filtrage dans Debug Logs
2. **Utiliser le bon niveau** :
   - `DEBUG` : Détails techniques pour développement
   - `INFO` : Événements métier importants
   - `WARN` : Situations suspectes mais non bloquantes
   - `ERROR` : Erreurs avec contexte complet
3. **Ajouter du contexte** : Toujours inclure les IDs, données importantes
4. **Logs d'erreur complets** : Toujours logger l'exception avec contexte
5. **Ne pas logger de données sensibles** : Pas de mots de passe, tokens, etc.

---

## 🔍 Recherche dans Debug Logs

**Filtres recommandés :**
- Par composant : `[INFO] [QuoteService]`
- Par méthode : `[ERROR] [QuoteService] [calculateTotal]`
- Par niveau : `[ERROR]` ou `[WARN]`
- Par utilisateur : Chercher `👤 User:`

---

## 📝 Migration

Pour migrer du code existant :

1. **Remplacer System.debug** :
   ```apex
   // Avant
   System.debug('Creating quote');
   
   // Après
   UniversalLogger.info('QuoteService', 'createQuote', 'Creating quote');
   ```

2. **Remplacer console.log** :
   ```javascript
   // Avant
   console.log('Button clicked');
   
   // Après
   log.info('myComponent', 'handleClick', 'Button clicked');
   ```

3. **Améliorer les logs d'erreur** :
   ```apex
   // Avant
   System.debug(LoggingLevel.ERROR, 'Error: ' + e.getMessage());
   
   // Après
   UniversalLogger.error('MyClass', 'myMethod', 'Operation failed', e, context);
   ```
