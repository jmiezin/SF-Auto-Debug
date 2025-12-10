# 🎯 Architecture Unifiée - Gestion d'Erreurs (Apex, LWC, Flow)

## Mon Avis : Approche Hybride Recommandée

**TL;DR :** Service unifié pour la logique métier (Case + Email), mais adaptateurs spécialisés par type d'erreur.

---

## ✅ Pourquoi une Architecture Unifiée ?

### Avantages

1. **Cohérence** : Même format de Case, même structure d'email
2. **Maintenance** : Un seul endroit à modifier pour améliorer le diagnostic
3. **Traçabilité** : Toutes les erreurs au même endroit
4. **ROI** : Réutiliser le code de diagnostic IA

### Risques

1. **Complexité** : Un service trop générique peut devenir difficile à maintenir
2. **Performance** : Contextes différents = prompts différents = moins efficace
3. **Spécificités** : Apex/LWC/Flow ont des besoins différents

---

## 🏗️ Architecture Recommandée : Service Unifié + Adaptateurs

```
┌─────────────────────────────────────────────────────────┐
│         COUCHE UNIFIÉE (Logique Métier)                 │
│  ErrorDiagnosticService (Classe Apex)                   │
│  - Créer Case                                           │
│  - Envoyer Email                                         │
│  - Appeler OpenAI                                        │
│  - Gérer la traçabilité                                  │
└─────────────────────────────────────────────────────────┘
                        ▲
                        │
        ┌───────────────┼───────────────┐
        │               │               │
┌───────┴──────┐ ┌──────┴──────┐ ┌──────┴──────┐
│  ADAPTEUR   │ │  ADAPTEUR   │ │  ADAPTEUR   │
│    APEX     │ │     LWC     │ │    FLOW     │
│             │ │             │ │             │
│ - Catch     │ │ - Catch     │ │ - Fault     │
│ - Format    │ │ - Format    │ │ - Format    │
│ - Context   │ │ - Context   │ │ - Context   │
└─────────────┘ └─────────────┘ └─────────────┘
```

---

## 📋 Structure Proposée

### 1. Service Unifié : `ErrorDiagnosticService`

**Responsabilités :**
- ✅ Créer le Case (format standardisé)
- ✅ Appeler OpenAI avec le bon prompt (selon le type)
- ✅ Envoyer l'email à l'admin
- ✅ Gérer la traçabilité

**Fichier :** `force-app/main/default/classes/ErrorDiagnosticService.cls`

```apex
public with sharing class ErrorDiagnosticService {
    
    public enum ErrorType {
        APEX, LWC, FLOW
    }
    
    /**
     * Méthode principale unifiée
     */
    @InvocableMethod(label='Diagnostic Erreur' 
                     description='Analyse une erreur (Apex/LWC/Flow) et crée un Case')
    public static List<Response> diagnoseAndCreateCase(List<ErrorInfo> errors) {
        List<Response> responses = new List<Response>();
        
        for (ErrorInfo error : errors) {
            try {
                // 1. Construire le contexte selon le type
                DiagnosticContext context = buildContext(error);
                
                // 2. Analyser avec IA (prompt spécialisé)
                DiagnosticResult diagnostic = analyzeWithAI(error, context);
                
                // 3. Créer le Case
                Case newCase = createCase(error, diagnostic);
                
                // 4. Envoyer l'email
                sendEmailToAdmin(newCase, error, diagnostic);
                
                responses.add(new Response(true, newCase.Id, 'Case créé'));
                
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Erreur diagnostic: ' + e.getMessage());
                responses.add(new Response(false, null, e.getMessage()));
            }
        }
        
        return responses;
    }
    
    /**
     * Construit le contexte selon le type d'erreur
     */
    private static DiagnosticContext buildContext(ErrorInfo error) {
        DiagnosticContext context = new DiagnosticContext();
        context.errorType = error.errorType;
        
        if (error.errorType == ErrorType.APEX) {
            context = ApexErrorAdapter.buildContext(error);
        } else if (error.errorType == ErrorType.LWC) {
            context = LWCErrorAdapter.buildContext(error);
        } else if (error.errorType == ErrorType.FLOW) {
            context = FlowErrorAdapter.buildContext(error);
        }
        
        return context;
    }
    
    /**
     * Analyse avec IA (prompt spécialisé selon le type)
     */
    private static DiagnosticResult analyzeWithAI(ErrorInfo error, DiagnosticContext context) {
        String prompt = buildPrompt(error, context);
        String aiResponse = OpenAI_Service.sendPrompt(prompt);
        return parseAIResponse(aiResponse, error);
    }
    
    /**
     * Construit le prompt selon le type d'erreur
     */
    private static String buildPrompt(ErrorInfo error, DiagnosticContext context) {
        if (error.errorType == ErrorType.APEX) {
            return ApexErrorAdapter.buildPrompt(error, context);
        } else if (error.errorType == ErrorType.LWC) {
            return LWCErrorAdapter.buildPrompt(error, context);
        } else if (error.errorType == ErrorType.FLOW) {
            return FlowErrorAdapter.buildPrompt(error, context);
        }
        return '';
    }
    
    // ... méthodes communes (createCase, sendEmailToAdmin, etc.)
}
```

---

### 2. Adaptateur Apex : `ApexErrorAdapter`

**Responsabilités :**
- ✅ Formater les erreurs Apex (stack trace, ligne, classe)
- ✅ Construire le prompt spécialisé Apex
- ✅ Récupérer le code source autour de l'erreur

**Fichier :** `force-app/main/default/classes/ApexErrorAdapter.cls`

```apex
public class ApexErrorAdapter {
    
    public static DiagnosticContext buildContext(ErrorInfo error) {
        DiagnosticContext context = new DiagnosticContext();
        
        // Extraire info du stack trace Apex
        // Ex: Class.QuoteService.calculateTotal: line 127
        context.className = extractClassName(error.stackTrace);
        context.methodName = extractMethodName(error.stackTrace);
        context.lineNumber = extractLineNumber(error.stackTrace);
        
        // Récupérer le code source (via Tooling API ou cache)
        context.sourceCode = getSourceCodeAroundLine(context.className, context.lineNumber);
        
        return context;
    }
    
    public static String buildPrompt(ErrorInfo error, DiagnosticContext context) {
        String prompt = 'Tu es un expert Apex Salesforce.\n\n';
        prompt += 'Analyse cette erreur Apex:\n\n';
        prompt += 'Classe: ' + context.className + '\n';
        prompt += 'Méthode: ' + context.methodName + '\n';
        prompt += 'Ligne: ' + context.lineNumber + '\n';
        prompt += 'Erreur: ' + error.errorMessage + '\n';
        prompt += 'Stack trace: ' + error.stackTrace + '\n\n';
        prompt += 'Code autour de la ligne:\n' + context.sourceCode + '\n\n';
        prompt += 'Identifie la cause et propose un correctif.';
        
        return prompt;
    }
    
    // ... méthodes utilitaires
}
```

---

### 3. Adaptateur LWC : `LWCErrorAdapter`

**Responsabilités :**
- ✅ Formater les erreurs JavaScript (console errors, network errors)
- ✅ Construire le prompt spécialisé LWC
- ✅ Récupérer le code JS du composant

**Fichier :** `force-app/main/default/classes/LWCErrorAdapter.cls`

```apex
public class LWCErrorAdapter {
    
    public static DiagnosticContext buildContext(ErrorInfo error) {
        DiagnosticContext context = new DiagnosticContext();
        
        // Extraire info de l'erreur LWC
        context.componentName = error.componentName;
        context.jsCode = getLWCJavaScriptCode(error.componentName);
        context.metadata = getLWCMetadata(error.componentName);
        
        // Analyser le type d'erreur
        if (error.errorMessage.contains('Cannot read property')) {
            context.errorCategory = 'NULL_POINTER';
        } else if (error.errorMessage.contains('Network')) {
            context.errorCategory = 'NETWORK_ERROR';
        }
        
        return context;
    }
    
    public static String buildPrompt(ErrorInfo error, DiagnosticContext context) {
        String prompt = 'Tu es un expert Lightning Web Components.\n\n';
        prompt += 'Analyse cette erreur LWC:\n\n';
        prompt += 'Composant: ' + context.componentName + '\n';
        prompt += 'Erreur: ' + error.errorMessage + '\n';
        prompt += 'Code JavaScript:\n' + context.jsCode + '\n\n';
        prompt += 'Identifie pourquoi le composant ne fonctionne pas et propose un correctif.';
        
        return prompt;
    }
}
```

---

### 4. Adaptateur Flow : `FlowErrorAdapter`

**Responsabilités :**
- ✅ Formater les erreurs Flow (fault message, élément)
- ✅ Construire le prompt spécialisé Flow
- ✅ Récupérer le Flow XML

**Fichier :** `force-app/main/default/classes/FlowErrorAdapter.cls`

```apex
public class FlowErrorAdapter {
    
    public static DiagnosticContext buildContext(ErrorInfo error) {
        DiagnosticContext context = new DiagnosticContext();
        
        // Récupérer le Flow XML (via Tooling API)
        context.flowName = error.flowName;
        context.flowXml = getFlowXML(error.flowApiName);
        context.faultElement = error.faultElement;
        
        return context;
    }
    
    public static String buildPrompt(ErrorInfo error, DiagnosticContext context) {
        String prompt = 'Tu es un expert Salesforce Flow.\n\n';
        prompt += 'Analyse cette erreur Flow:\n\n';
        prompt += 'Flow: ' + context.flowName + '\n';
        prompt += 'Élément en erreur: ' + context.faultElement + '\n';
        prompt += 'Erreur: ' + error.errorMessage + '\n';
        prompt += 'Flow XML (extrait):\n' + context.flowXml + '\n\n';
        prompt += 'Identifie pourquoi le Flow échoue et propose un correctif.';
        
        return prompt;
    }
}
```

---

## 🎯 Utilisation dans chaque contexte

### Apex : Try-Catch avec appel unifié

```apex
try {
    // Code métier
} catch (Exception e) {
    ErrorDiagnosticService.diagnoseAndCreateCase(new List<ErrorInfo>{
        new ErrorInfo(
            ErrorType.APEX,
            'QuoteService.calculateTotal',
            e.getMessage(),
            e.getStackTraceString(),
            'Quote',
            recordId
        )
    });
    throw e; // Re-throw pour ne pas masquer l'erreur
}
```

### LWC : Catch dans le JS, appel Apex

```javascript
// Dans le LWC
handleError(error) {
    analyzeError({
        errorType: 'LWC',
        componentName: 'iscpq_bundleSelector',
        errorMessage: error.message,
        stackTrace: error.stack,
        recordId: this.recordId
    })
    .then(result => {
        console.log('Case créé:', result.caseId);
    });
}
```

### Flow : Fault Path avec Action Apex

```
Flow avec Fault Path
    ↓
Action Apex: ErrorDiagnosticService.diagnoseAndCreateCase()
    Inputs:
    - errorType: "FLOW"
    - flowName: {!$Flow.Label}
    - errorMessage: {!$Flow.FaultMessage}
    - faultElement: {!$Flow.FaultElement}
```

---

## 💡 Avantages de cette Architecture

### ✅ Réutilisabilité
- Service unifié pour Case + Email
- Adaptateurs spécialisés pour chaque type

### ✅ Maintenabilité
- Un seul endroit pour améliorer le diagnostic
- Prompts spécialisés = meilleure qualité

### ✅ Extensibilité
- Facile d'ajouter un nouveau type (ex: Process Builder)
- Chaque adaptateur est indépendant

### ✅ Performance
- Prompts optimisés par type = meilleures réponses IA
- Pas de surcharge inutile

---

## 📊 Comparaison : Unifié vs Séparé

| Aspect | Unifié Simple | Unifié + Adaptateurs | Séparé |
|--------|---------------|---------------------|--------|
| **Code** | 1 classe | 4 classes | 3 classes |
| **Maintenance** | ⚠️ Difficile | ✅ Facile | ⚠️ 3x le travail |
| **Qualité IA** | ⚠️ Moyenne | ✅ Excellente | ✅ Excellente |
| **Cohérence** | ✅ Parfaite | ✅ Parfaite | ❌ Risque |
| **Performance** | ✅ OK | ✅ Optimale | ✅ Optimale |

**Verdict :** Unifié + Adaptateurs = Meilleur compromis

---

## 🚀 Plan d'Implémentation

### Phase 1 : Service Unifié (1 semaine)
1. ✅ Créer `ErrorDiagnosticService` avec méthodes communes
2. ✅ Créer `ErrorInfo` wrapper unifié
3. ✅ Tester avec un type (ex: Flow)

### Phase 2 : Adaptateurs (1 semaine)
1. ✅ Créer `FlowErrorAdapter`
2. ✅ Créer `ApexErrorAdapter`
3. ✅ Créer `LWCErrorAdapter`

### Phase 3 : Intégration (1 semaine)
1. ✅ Intégrer dans Flow (Fault Paths)
2. ✅ Intégrer dans Apex (Try-Catch)
3. ✅ Intégrer dans LWC (Error handlers)

### Phase 4 : Amélioration (continue)
1. ✅ Affiner les prompts selon retours
2. ✅ Ajouter métriques (temps de résolution)
3. ✅ Dashboard des erreurs

---

## 🎓 Mon Conseil Final

**✅ OUI à l'architecture unifiée, MAIS avec adaptateurs spécialisés**

**Pourquoi ?**
- Service unifié = Cohérence + Maintenance facile
- Adaptateurs = Qualité IA optimale + Performance

**Structure recommandée :**
```
ErrorDiagnosticService (unifié)
├── ApexErrorAdapter (spécialisé)
├── LWCErrorAdapter (spécialisé)
└── FlowErrorAdapter (spécialisé)
```

**Résultat :** Le meilleur des deux mondes 🎯

---

**Veux-tu que je crée cette architecture complète maintenant ?**
