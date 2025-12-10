# 🐛 Assistant de Débogage IA - Salesforce

## Problème

Quand un Flow, Apex ou LWC plante dans Salesforce, tu dois :
1. Lire les logs (illisibles)
2. Chercher dans la doc Salesforce
3. Tester différentes solutions
4. Perdre 2-4h par bug

**Solution :** Assistant IA intégré dans Salesforce qui analyse les erreurs et propose des solutions.

---

## 🎯 Cas d'Usage Concrets

### 1. 🔴 Flow qui échoue silencieusement

**Scénario :** Flow `Quote_Trigger_Update` ne fait rien, aucune erreur visible.

**Avec IA :**
```
1. Ouvrir le Flow dans Salesforce
2. Cliquer "Analyser avec IA"
3. L'IA lit le Flow XML + les logs
4. Réponse : "Problème détecté : Champ 'Owner_Role__c' n'existe pas. 
                Le Flow s'arrête silencieusement à la décision ligne 45.
                Solution : Vérifier existence du champ ou utiliser ISBLANK()"
```

**Gain :** 2h → 5min

---

### 2. ⚡ Exception Apex incompréhensible

**Scénario :** Erreur Apex : `System.NullPointerException: Attempt to de-reference a null object`

**Avec IA :**
```
1. Copier le stack trace complet
2. Coller dans LWC "Debug Assistant"
3. L'IA analyse le code Apex + stack trace
4. Réponse : "Ligne 127 dans QuoteService.cls : 
                account.Owner.Name est null car account.Owner n'est pas chargé.
                Solution : Ajouter 'Owner.Name' dans la requête SOQL ligne 45"
```

**Gain :** 1h → 2min

---

### 3. 💡 LWC qui ne s'affiche pas

**Scénario :** LWC `iscpq_bundleSelector` ne s'affiche pas, aucune erreur console.

**Avec IA :**
```
1. Ouvrir la page LWC dans Salesforce
2. Cliquer "Déboguer avec IA"
3. L'IA lit le code JS + métadonnées + logs
4. Réponse : "Problème : @api recordId est null car le LWC n'est pas sur un record.
                Vérifier que le LWC est bien sur une page record ou utiliser 
                @wire(getRecord) pour charger les données."
```

**Gain :** 3h → 10min

---

## 🏗️ Architecture Technique

### Composant 1 : LWC Debug Assistant

**Fichier :** `force-app/main/default/lwc/aiDebugAssistant/aiDebugAssistant.js`

```javascript
import { LightningElement, api, track } from 'lwc';
import analyzeError from '@salesforce/apex/AIDebugService.analyzeError';

export default class AIDebugAssistant extends LightningElement {
    @api errorType; // 'FLOW', 'APEX', 'LWC'
    @api errorDetails; // Stack trace, logs, etc.
    @track analysis;
    @track loading = false;

    handleAnalyze() {
        this.loading = true;
        
        analyzeError({
            errorType: this.errorType,
            errorDetails: this.errorDetails,
            context: this.getContext() // Code source, métadonnées, etc.
        })
        .then(result => {
            this.analysis = JSON.parse(result);
            this.loading = false;
        })
        .catch(error => {
            console.error('Erreur analyse IA:', error);
        });
    }

    getContext() {
        // Récupère le contexte selon le type d'erreur
        if (this.errorType === 'FLOW') {
            return {
                flowName: this.flowName,
                flowXml: this.flowXml, // Récupéré via API
                recentLogs: this.recentLogs
            };
        }
        // ... autres types
    }
}
```

---

### Composant 2 : Classe Apex AIDebugService

**Fichier :** `force-app/main/default/classes/AIDebugService.cls`

```apex
public with sharing class AIDebugService {
    
    public class DebugRequest {
        public String errorType;
        public String errorDetails;
        public Map<String, Object> context;
    }
    
    public class DebugResponse {
        public String problem;
        public String rootCause;
        public String solution;
        public String codeFix;
        public List<String> steps;
    }
    
    @AuraEnabled
    public static String analyzeError(String errorType, String errorDetails, Map<String, Object> context) {
        
        // Construire le prompt pour OpenAI
        String prompt = buildPrompt(errorType, errorDetails, context);
        
        // Appeler OpenAI
        String aiResponse = OpenAI_Service.sendPrompt(prompt);
        
        // Parser la réponse JSON
        DebugResponse response = parseAIResponse(aiResponse);
        
        return JSON.serialize(response);
    }
    
    private static String buildPrompt(String errorType, String errorDetails, Map<String, Object> context) {
        String prompt = 'Tu es un expert Salesforce. Analyse cette erreur et propose une solution.\n\n';
        
        prompt += 'Type d\'erreur: ' + errorType + '\n\n';
        prompt += 'Détails de l\'erreur:\n' + errorDetails + '\n\n';
        
        if (errorType == 'FLOW') {
            prompt += 'Flow XML:\n' + context.get('flowXml') + '\n\n';
            prompt += 'Logs récents:\n' + context.get('recentLogs') + '\n\n';
        }
        else if (errorType == 'APEX') {
            prompt += 'Code Apex:\n' + context.get('apexCode') + '\n\n';
            prompt += 'Stack trace:\n' + errorDetails + '\n\n';
        }
        else if (errorType == 'LWC') {
            prompt += 'Code JavaScript:\n' + context.get('jsCode') + '\n\n';
            prompt += 'Erreurs console:\n' + errorDetails + '\n\n';
        }
        
        prompt += 'Réponds en JSON avec cette structure:\n';
        prompt += '{\n';
        prompt += '  "problem": "Description du problème",\n';
        prompt += '  "rootCause": "Cause racine identifiée",\n';
        prompt += '  "solution": "Solution recommandée",\n';
        prompt += '  "codeFix": "Code corrigé si applicable",\n';
        prompt += '  "steps": ["Étape 1", "Étape 2", ...]\n';
        prompt += '}';
        
        return prompt;
    }
    
    private static DebugResponse parseAIResponse(String aiResponse) {
        // Parser la réponse JSON d'OpenAI
        // Gérer les cas où OpenAI ne retourne pas du JSON pur
        try {
            return (DebugResponse) JSON.deserialize(aiResponse, DebugResponse.class);
        } catch (Exception e) {
            // Fallback : parser manuellement
            DebugResponse response = new DebugResponse();
            response.problem = 'Erreur lors du parsing de la réponse IA';
            response.solution = aiResponse; // Afficher la réponse brute
            return response;
        }
    }
}
```

---

## 📋 Cas d'Usage Détaillés

### Cas 1 : Flow qui échoue

**Flow :** `Quote_Trigger_Update`

**Erreur :** Flow ne s'exécute pas, aucune trace dans les logs.

**Utilisation :**
```
1. Ouvrir Setup → Flows → Quote_Trigger_Update
2. Cliquer "Debug avec IA"
3. Le système récupère :
   - Le Flow XML complet
   - Les 10 derniers logs d'exécution
   - Les champs référencés
4. Envoie à OpenAI avec prompt spécialisé
5. Réponse IA :
   {
     "problem": "Le Flow s'arrête à la décision 'Check Owner Role' car le champ Owner_Role__c n'existe pas",
     "rootCause": "Champ personnalisé Owner_Role__c supprimé ou non déployé",
     "solution": "Vérifier l'existence du champ ou modifier la logique pour utiliser un champ existant",
     "codeFix": "Remplacer {!$Record.Owner_Role__c} par {!$Record.Owner.Profile.Name}",
     "steps": [
       "1. Vérifier si Owner_Role__c existe dans Setup → Object Manager → Quote → Fields",
       "2. Si non, modifier le Flow pour utiliser Owner.Profile.Name",
       "3. Tester avec un record Quote"
     ]
   }
```

---

### Cas 2 : Exception Apex

**Classe :** `QuoteService.cls`

**Erreur :**
```
System.NullPointerException: Attempt to de-reference a null object
Class.QuoteService.calculateTotal: line 127, column 1
```

**Utilisation :**
```
1. Copier le stack trace complet
2. Ouvrir QuoteService.cls dans VS Code/Cursor
3. Copier le code autour de la ligne 127
4. Coller dans LWC Debug Assistant
5. Sélectionner "APEX" comme type
6. Réponse IA :
   {
     "problem": "Ligne 127 tente d'accéder à account.Owner.Name mais account.Owner est null",
     "rootCause": "La requête SOQL ligne 45 ne charge pas la relation Owner",
     "solution": "Ajouter Owner dans le SELECT de la requête SOQL",
     "codeFix": "SELECT Id, Name, Owner.Name FROM Account WHERE Id = :accountId",
     "steps": [
       "1. Modifier la requête SOQL ligne 45",
       "2. Ajouter 'Owner.Name' dans le SELECT",
       "3. Tester avec un Account qui a un Owner"
     ]
   }
```

---

### Cas 3 : LWC qui ne fonctionne pas

**LWC :** `iscpq_bundleSelector`

**Problème :** Le composant ne s'affiche pas, erreur console : `Cannot read property 'recordId' of undefined`

**Utilisation :**
```
1. Ouvrir la page où le LWC est utilisé
2. Ouvrir DevTools → Console
3. Copier l'erreur complète
4. Ouvrir iscpq_bundleSelector.js
5. Coller code + erreur dans Debug Assistant
6. Sélectionner "LWC"
7. Réponse IA :
   {
     "problem": "this.recordId est undefined car le LWC n'est pas sur une page record",
     "rootCause": "Le LWC utilise @api recordId mais n'est pas utilisé sur une page record",
     "solution": "Utiliser @wire(getRecord) pour charger les données ou vérifier le contexte",
     "codeFix": "@wire(getRecord, { recordId: '$recordId', fields: [...] }) wiredRecord({error, data}) { ... }",
     "steps": [
       "1. Vérifier que le LWC est bien sur une page record",
       "2. Si oui, utiliser @wire(getRecord) pour charger les données",
       "3. Si non, modifier la logique pour fonctionner sans recordId"
     ]
   }
```

---

## 🚀 Implémentation Pratique

### Étape 1 : Améliorer OpenAI_Service

**Fichier :** `force-app/main/default/classes/OpenAI_Service.cls`

```apex
public with sharing class OpenAI_Service {
    
    // Méthode existante
    public static String sendPrompt(String userPrompt) {
        // ... code existant
    }
    
    // NOUVELLE méthode spécialisée pour le débogage
    public static String analyzeSalesforceError(
        String errorType, 
        String errorMessage, 
        String stackTrace,
        String sourceCode,
        Map<String, String> context
    ) {
        String prompt = buildDebugPrompt(errorType, errorMessage, stackTrace, sourceCode, context);
        return sendPrompt(prompt);
    }
    
    private static String buildDebugPrompt(
        String errorType, 
        String errorMessage, 
        String stackTrace,
        String sourceCode,
        Map<String, String> context
    ) {
        String prompt = 'Tu es un expert Salesforce avec 10+ ans d\'expérience.\n\n';
        prompt += 'Analyse cette erreur Salesforce et propose une solution précise.\n\n';
        
        prompt += 'TYPE D\'ERREUR: ' + errorType + '\n\n';
        prompt += 'MESSAGE D\'ERREUR:\n' + errorMessage + '\n\n';
        
        if (String.isNotBlank(stackTrace)) {
            prompt += 'STACK TRACE:\n' + stackTrace + '\n\n';
        }
        
        if (String.isNotBlank(sourceCode)) {
            prompt += 'CODE SOURCE (autour de la ligne d\'erreur):\n' + sourceCode + '\n\n';
        }
        
        if (context != null && !context.isEmpty()) {
            prompt += 'CONTEXTE ADDITIONNEL:\n';
            for (String key : context.keySet()) {
                prompt += key + ': ' + context.get(key) + '\n';
            }
            prompt += '\n';
        }
        
        prompt += 'RÉPONDS EN JSON AVEC CETTE STRUCTURE:\n';
        prompt += '{\n';
        prompt += '  "problem": "Description claire du problème",\n';
        prompt += '  "rootCause": "Cause racine identifiée avec précision",\n';
        prompt += '  "solution": "Solution recommandée étape par étape",\n';
        prompt += '  "codeFix": "Code corrigé si applicable (sinon null)",\n';
        prompt += '  "steps": ["Étape 1", "Étape 2", "Étape 3"],\n';
        prompt += '  "relatedDocs": ["Lien doc Salesforce si applicable"]\n';
        prompt += '}\n\n';
        prompt += 'Sois précis, concis, et actionnable.';
        
        return prompt;
    }
}
```

---

### Étape 2 : Créer le LWC Debug Assistant

**Fichier :** `force-app/main/default/lwc/aiDebugAssistant/aiDebugAssistant.html`

```html
<template>
    <lightning-card title="🤖 Assistant de Débogage IA" icon-name="utility:bug">
        <div class="slds-p-around_medium">
            <!-- Sélection type d'erreur -->
            <lightning-combobox
                label="Type d'erreur"
                value={errorType}
                options={errorTypes}
                onchange={handleTypeChange}>
            </lightning-combobox>
            
            <!-- Zone de texte pour coller l'erreur -->
            <lightning-textarea
                label="Détails de l'erreur (stack trace, logs, etc.)"
                value={errorDetails}
                onchange={handleDetailsChange}
                placeholder="Colle ici ton erreur complète...">
            </lightning-textarea>
            
            <!-- Bouton analyser -->
            <lightning-button
                label="Analyser avec IA"
                onclick={handleAnalyze}
                variant="brand"
                class="slds-m-top_small">
            </lightning-button>
            
            <!-- Résultat -->
            <template if:true={analysis}>
                <div class="slds-m-top_large">
                    <lightning-card title="Analyse IA">
                        <div class="slds-p-around_medium">
                            <h3 class="slds-text-heading_small">Problème identifié</h3>
                            <p>{analysis.problem}</p>
                            
                            <h3 class="slds-text-heading_small slds-m-top_medium">Cause racine</h3>
                            <p>{analysis.rootCause}</p>
                            
                            <h3 class="slds-text-heading_small slds-m-top_medium">Solution</h3>
                            <p>{analysis.solution}</p>
                            
                            <template if:true={analysis.codeFix}>
                                <h3 class="slds-text-heading_small slds-m-top_medium">Code corrigé</h3>
                                <pre class="slds-box slds-theme_shade">{analysis.codeFix}</pre>
                            </template>
                            
                            <template if:true={analysis.steps}>
                                <h3 class="slds-text-heading_small slds-m-top_medium">Étapes</h3>
                                <ul>
                                    <template for:each={analysis.steps} for:item="step">
                                        <li key={step}>{step}</li>
                                    </template>
                                </ul>
                            </template>
                        </div>
                    </lightning-card>
                </div>
            </template>
        </div>
    </lightning-card>
</template>
```

---

### Étape 3 : Ajouter dans une App ou Page

**Option A : LWC sur une page dédiée**
- Créer une page Lightning "Debug Assistant"
- Ajouter le LWC `aiDebugAssistant`
- Accessible via App Launcher

**Option B : Action Quick dans Setup**
- Créer une action Lightning dans Setup
- Ouvrir depuis n'importe où

**Option C : Intégré dans Flow Builder**
- Ajouter une action Apex dans Flow
- Appeler `AIDebugService.analyzeError()`
- Afficher le résultat dans une variable

---

## 💡 Exemples de Prompts Optimisés

### Pour les Flows

```
Tu es un expert Salesforce Flow. Analyse ce Flow qui échoue.

Flow: {flowName}
Erreur: {errorMessage}
Logs: {recentLogs}

Identifie:
1. À quelle étape le Flow s'arrête
2. Pourquoi (champ manquant, valeur null, logique incorrecte)
3. Comment corriger

Réponds en JSON avec problem, rootCause, solution, codeFix, steps.
```

### Pour Apex

```
Tu es un expert Apex Salesforce. Analyse cette exception.

Classe: {className}
Méthode: {methodName}
Ligne: {lineNumber}
Erreur: {errorMessage}
Stack trace: {stackTrace}
Code autour de la ligne: {codeSnippet}

Identifie:
1. Quelle variable est null
2. Pourquoi (pas chargée dans SOQL, pas initialisée, etc.)
3. Comment corriger le code

Réponds en JSON avec problem, rootCause, solution, codeFix, steps.
```

### Pour LWC

```
Tu es un expert Lightning Web Components. Analyse cette erreur LWC.

Composant: {componentName}
Erreur: {errorMessage}
Code JavaScript: {jsCode}
Métadonnées: {metadata}

Identifie:
1. Quelle propriété/méthode cause l'erreur
2. Pourquoi (null, undefined, mauvaise utilisation de @api/@wire)
3. Comment corriger

Réponds en JSON avec problem, rootCause, solution, codeFix, steps.
```

---

## 📊 ROI Estimé

| Type de Bug | Temps Sans IA | Temps Avec IA | Gain |
|-------------|---------------|---------------|------|
| Flow qui échoue | 2h | 5min | **96%** |
| Exception Apex | 1h | 2min | **97%** |
| LWC qui ne marche pas | 3h | 10min | **94%** |
| Erreur de configuration | 30min | 3min | **90%** |

**Par mois (10 bugs) :** 65h → 3h = **62h gagnées**

---

## 🎯 Prochaines Étapes

1. ✅ Améliorer `OpenAI_Service` avec méthode spécialisée
2. ✅ Créer `AIDebugService` Apex
3. ✅ Créer LWC `aiDebugAssistant`
4. ✅ Tester avec un vrai bug Flow
5. ✅ Déployer dans l'org

**Veux-tu que je commence par implémenter un de ces composants ?**
