# 🤖 Prompt Complet pour GPT - Système de Diagnostic et Logging

## Contexte : Organisation Salesforce avec Migration Complexe

Je travaille sur une migration Salesforce complexe avec :
- **Org source** : `source-dev` (lecture seule)
- **Org cible** : `production` (déploiement)
- **Technologies** : Apex, Lightning Web Components (LWC), Flows, Custom Metadata
- **Domaine métier** : Configuration de bundles produits sur des devis (CPQ-like)

---

## 🎯 Système Mis en Place

### 1. Système de Diagnostic Automatique avec IA (Azure OpenAI)

**Objectif** : Diagnostiquer automatiquement les erreurs Apex, LWC et Flow avec génération de Cases Salesforce contenant des diagnostics IA détaillés.

#### Architecture

**Classe principale** : `ErrorDiagnosticService.cls`
- Service unifié pour tous les types d'erreurs (Apex, LWC, Flow)
- Intégration avec Azure OpenAI pour génération de diagnostics
- Création automatique de Cases Salesforce avec diagnostic IA
- Post automatique dans le Feed du Case avec le diagnostic

**Adaptateurs spécialisés** :
- `ApexErrorAdapter.cls` : Pour erreurs Apex (stack traces, lignes de code)
- `LWCErrorAdapter.cls` : Pour erreurs Lightning Web Components
- `FlowErrorAdapter.cls` : Pour erreurs Flow (faultElement, faultMessage)

**Méthodes principales** :
```apex
// Pour Flow (depuis Flow avec Fault Path)
@InvocableMethod
public static List<Response> diagnoseAndCreateCase(List<ErrorInfo> errors)

// Pour LWC (depuis JavaScript)
@AuraEnabled
public static String diagnoseLWCError(
    String componentName, 
    String errorMessage, 
    String stackTrace, 
    String recordId, 
    String objectType, 
    String contextData
)
```

#### Flux de Diagnostic

1. **Capture d'erreur** :
   - Flow : Via Fault Path → `$Flow.FaultMessage`, `$Flow.FaultElement`
   - LWC : Via `.catch()` dans JavaScript → Extraction complète des détails
   - Apex : Via `try-catch` → Exception avec stack trace complet

2. **Enrichissement du contexte** :
   - Extraction de tous les détails disponibles (pageErrors, fieldErrors, outputErrors)
   - Ajout du contexte métier (recordId, données envoyées, état du composant)
   - Stack trace complet (JavaScript + Apex si disponible)

3. **Appel IA** :
   - Construction d'un prompt spécialisé selon le type d'erreur
   - Appel à Azure OpenAI via `OpenAI_Service.sendPrompt()`
   - Parsing de la réponse JSON avec fallback robuste

4. **Création du Case** :
   - Case automatique avec priorité selon sévérité
   - Description complète avec diagnostic IA
   - Post automatique dans le Feed du Case

#### Format du Diagnostic IA

Le prompt demande à l'IA de répondre en JSON avec :
```json
{
  "problem": "Description claire du problème",
  "rootCause": "Cause racine identifiée en détail",
  "solution": "Solution recommandée étape par étape",
  "codeFix": "Code corrigé complet (Apex ou JavaScript)",
  "steps": ["Étape 1", "Étape 2", "Étape 3"],
  "severity": "CRITICAL|HIGH|MEDIUM|LOW"
}
```

#### Problèmes Résolus

1. **Parsing JSON robuste** :
   - Extraction du JSON même avec texte avant/après
   - Fallback avec regex si parsing échoue
   - Gestion des backticks markdown dans le codeFix

2. **Enrichissement du contexte LWC** :
   - Extraction complète de pageErrors, fieldErrors, outputErrors
   - Stack trace enrichi avec tous les détails disponibles
   - Configuration complète envoyée à Apex incluse dans le contexte

3. **Post dans le Feed** :
   - Utilisation de `ConnectApi.ChatterFeeds.postFeedElement()`
   - Format markdown pour lisibilité
   - Diagnostic visible directement dans le Feed du Case

---

### 2. Standard de Logging Universel

**Objectif** : Standardiser tous les logs dans l'org Salesforce (Apex, LWC, Flow) avec format uniforme.

#### Classe Apex : `UniversalLogger.cls`

**Format standardisé** :
```
[LEVEL] [COMPONENT] [METHOD] [TIMESTAMP] Message
  👤 User: Name (UserId)
  📋 Context: {...}
```

**Niveaux** : DEBUG, INFO, WARN, ERROR

**Méthodes disponibles** :
```apex
// Depuis Apex
UniversalLogger.debug(component, method, message, context);
UniversalLogger.info(component, method, message, context);
UniversalLogger.warn(component, method, message, context);
UniversalLogger.error(component, method, message, exception, context);

// Depuis LWC/Aura (via @AuraEnabled)
UniversalLogger.logFromClient(level, component, method, message, contextJson);

// Depuis Flow (via @InvocableMethod)
UniversalLogger.logFromFlow(inputs);
```

#### Module JavaScript : `universalLogger.js`

**Usage dans LWC** :
```javascript
import log from 'c/universalLogger';

log.debug('myComponent', 'handleClick', 'Button clicked', { buttonId: 'save' });
log.info('myComponent', 'handleSave', 'Saving data', { recordId: this.recordId });
log.error('myComponent', 'handleSave', 'Save failed', error, { recordId: this.recordId });
```

**Fonctionnalités** :
- Logging automatique vers Salesforce Debug Logs
- Logging console JavaScript en parallèle
- Enrichissement automatique des erreurs (pageErrors, fieldErrors, stack traces)

#### Intégration Flow

**Action Apex** : `UniversalLogger.logFromFlow`

**Inputs** :
- `level` : DEBUG, INFO, WARN, ERROR
- `component` : Nom du Flow (ex: `{!$Flow.Label}`)
- `method` : Nom de l'action/élément
- `message` : Message à logger
- `contextJson` : JSON string avec données contextuelles

---

## 🔧 Problèmes Techniques Résolus

### Problème 1 : Diagnostic IA avec peu d'informations

**Symptôme** : Le diagnostic IA retournait "CORRECTIF PROPOSÉ: null" car le stack trace était générique ("Script-thrown exception").

**Solution** :
1. Enrichissement du contexte envoyé à l'IA :
   - Configuration complète envoyée à Apex
   - État complet du composant LWC
   - Métadonnées (optionMetadata, selectedOptions)
   - Features complètes avec toutes les options

2. Amélioration du prompt IA :
   - Instructions strictes pour toujours proposer un correctif
   - Analyse du contexte même avec stack trace incomplet
   - Focus sur pageErrors/fieldErrors pour identifier la cause

3. Parsing robuste :
   - Extraction du JSON même avec texte avant/après
   - Fallback avec regex si parsing échoue
   - Gestion des backticks markdown dans le codeFix

### Problème 2 : Logs insuffisants pour débogage

**Symptôme** : Les logs étaient trop génériques, difficile de déboguer les erreurs.

**Solution** :
1. Standard de logging universel :
   - Format uniforme pour toute l'org
   - Contexte automatique (user, timestamp)
   - Support pour tous les types (Apex, LWC, Flow)

2. Enrichissement des logs d'erreur :
   - Extraction complète de pageErrors, fieldErrors, outputErrors
   - Stack trace enrichi avec tous les détails
   - Configuration complète incluse dans le contexte

3. Logs niveau "FINEST" :
   - Tous les détails disponibles capturés
   - Raw error body inclus
   - Métadonnées complètes du composant

### Problème 3 : Diagnostic visible uniquement dans Description du Case

**Symptôme** : Le diagnostic IA était dans la Description mais pas visible dans le Feed.

**Solution** :
- Post automatique dans le Feed du Case via `ConnectApi.ChatterFeeds.postFeedElement()`
- Format markdown pour lisibilité
- Diagnostic visible directement dans le Feed

---

## 📊 Architecture Technique

### Stack Technique

- **Salesforce** : API v65.0
- **Apex** : Classes avec `@AuraEnabled`, `@InvocableMethod`
- **LWC** : Lightning Web Components avec JavaScript ES6+
- **Flow** : Salesforce Flow avec Fault Paths
- **IA** : Azure OpenAI (via Custom Metadata `Azure_AD_Config__mdt`)

### Intégrations

1. **Azure OpenAI** :
   - Configuration via Custom Metadata Type
   - Service `OpenAI_Service` pour appels API
   - Prompts spécialisés selon type d'erreur

2. **Salesforce Cases** :
   - Création automatique avec diagnostic IA
   - Priorité selon sévérité (CRITICAL → High, etc.)
   - Post automatique dans le Feed

3. **Debug Logs** :
   - Tous les logs standardisés apparaissent dans Debug Logs
   - Format uniforme pour recherche facile
   - Contexte utilisateur automatique

---

## 🎯 Cas d'Usage Concrets

### Cas 1 : Erreur LWC lors de la sauvegarde d'un bundle

**Scénario** : L'utilisateur configure un bundle produit et clique sur "Sauvegarder". Une erreur se produit côté serveur.

**Flux** :
1. LWC capture l'erreur dans `.catch()`
2. Extraction complète des détails (pageErrors, fieldErrors, stack trace)
3. Appel à `diagnoseLWCError()` avec contexte enrichi
4. Création automatique d'un Case avec diagnostic IA
5. Post dans le Feed du Case avec le diagnostic formaté
6. Logs standardisés dans Debug Logs

**Résultat** : Case créé avec diagnostic IA détaillé, correctif proposé, visible dans le Feed.

### Cas 2 : Erreur Flow lors d'une opération DML

**Scénario** : Un Flow échoue lors de la création d'un record (validation DML).

**Flux** :
1. Flow Fault Path capte l'erreur
2. Appel à `diagnoseAndCreateCase()` depuis le Flow
3. Diagnostic IA avec `faultElement` et `faultMessage`
4. Case créé avec diagnostic spécifique au Flow
5. Logs standardisés via `UniversalLogger.logFromFlow()`

**Résultat** : Case créé avec diagnostic IA spécifique au Flow, élément en erreur identifié.

### Cas 3 : Erreur Apex dans une méthode métier

**Scénario** : Une méthode Apex échoue avec une exception.

**Flux** :
1. `try-catch` capture l'exception
2. Appel à `UniversalLogger.error()` avec exception et contexte
3. Optionnel : Appel à `diagnoseAndCreateCase()` pour diagnostic IA
4. Logs standardisés dans Debug Logs

**Résultat** : Logs détaillés dans Debug Logs, optionnellement Case avec diagnostic IA.

---

## 📈 Métriques et Observabilité

### Logs Standardisés

- **Format uniforme** : Facilite la recherche dans Debug Logs
- **Contexte automatique** : User, timestamp, données contextuelles
- **Niveaux** : DEBUG, INFO, WARN, ERROR

### Diagnostic IA

- **Cases créés** : Automatiquement avec diagnostic IA
- **Feed posts** : Diagnostic visible dans le Feed
- **Correctifs proposés** : Code corrigé inclus dans le diagnostic

---

## 🔮 Améliorations Futures Possibles

1. **Dashboard de monitoring** :
   - Visualisation des erreurs par type
   - Taux de résolution des Cases
   - Métriques de diagnostic IA

2. **Amélioration du diagnostic IA** :
   - Appel depuis Apex avant wrapper dans AuraHandledException
   - Accès au vrai stack trace Apex
   - Analyse du code source réel

3. **Intégration avec outils externes** :
   - Webhooks vers Slack/Teams
   - Intégration avec outils de monitoring
   - Export des métriques

4. **Apprentissage automatique** :
   - Détection de patterns d'erreurs récurrents
   - Suggestions préventives
   - Amélioration des prompts IA basée sur l'historique

---

## 📝 Questions pour GPT

1. **Architecture** : Comment améliorer l'architecture actuelle pour une meilleure scalabilité ?
2. **Performance** : Comment optimiser les appels IA pour réduire la latence ?
3. **Qualité** : Comment améliorer la qualité des diagnostics IA avec peu d'informations ?
4. **Observabilité** : Quelles métriques supplémentaires ajouter pour mieux comprendre les erreurs ?
5. **Intégration** : Comment intégrer ce système avec d'autres outils de monitoring/alerting ?
6. **Best practices** : Quelles sont les meilleures pratiques pour le logging et le diagnostic d'erreurs dans Salesforce ?

---

## 🔗 Fichiers Clés

- `/force-app/main/default/classes/ErrorDiagnosticService.cls` : Service principal de diagnostic
- `/force-app/main/default/classes/LWCErrorAdapter.cls` : Adaptateur LWC
- `/force-app/main/default/classes/UniversalLogger.cls` : Logger universel
- `/force-app/main/default/lwc/universalLogger/universalLogger.js` : Module JavaScript
- `/docs/logging/STANDARD_LOGGING.md` : Documentation du standard de logging
- `/docs/ia/ARCHITECTURE_UNIFIEE_ERRORS.md` : Architecture du système de diagnostic

---

## 💡 Points Clés à Retenir

1. **Système unifié** : Un seul système pour tous les types d'erreurs (Apex, LWC, Flow)
2. **Diagnostic IA automatique** : Cases créés automatiquement avec diagnostic détaillé
3. **Logging standardisé** : Format uniforme pour toute l'org
4. **Enrichissement du contexte** : Tous les détails disponibles capturés pour meilleur diagnostic
5. **Intégration native Salesforce** : Utilisation des APIs natives (ConnectApi, Debug Logs, Cases)

---

**Date de création** : 2025-01-09
**Version** : 1.0
**Auteur** : Système de diagnostic et logging Salesforce
