# 📋 Résumé Configuration Azure OpenAI

## ✅ Ce qui est fait

1. **`OpenAI_Service.cls`** modifié pour Azure OpenAI
   - Utilise l'endpoint Azure OpenAI (pas OpenAI standard)
   - Header `api-key` au lieu de `Authorization: Bearer`
   - Format endpoint: `https://RESOURCE.openai.azure.com/openai/deployments/DEPLOYMENT/chat/completions?api-version=VERSION`

2. **`ErrorDiagnosticService.cls`** appelle `OpenAI_Service.sendPrompt()`
   - Ligne 171 : `String aiResponse = OpenAI_Service.sendPrompt(prompt);`
   - Ligne 194 : Parse la réponse JSON

3. **Custom Metadata Type `GPT_Key__mdt`** existe déjà
   - À vérifier : a-t-il tous les champs nécessaires ?

---

## 🔧 Comment ça fonctionne

### Envoi à Azure OpenAI

```
ErrorDiagnosticService.analyzeWithAI()
    ↓
buildPrompt() → Construit prompt spécialisé (Apex/LWC/Flow)
    ↓
OpenAI_Service.sendPrompt(prompt)
    ↓
1. Récupère config depuis GPT_Key__mdt
2. Construit endpoint: https://RESOURCE.openai.azure.com/openai/deployments/DEPLOYMENT/chat/completions?api-version=VERSION
3. Envoie HTTP POST avec header 'api-key'
4. Reçoit réponse JSON
5. Parse et retourne le texte de la réponse
```

### Récupération de la réponse

```
Réponse Azure OpenAI (JSON):
{
  "choices": [{
    "message": {
      "content": "Réponse IA ici..."
    }
  }]
}

OpenAI_Service.sendPrompt() extrait:
→ content = "Réponse IA ici..."

ErrorDiagnosticService.parseAIResponse() parse:
→ diagnostic.problem
→ diagnostic.rootCause
→ diagnostic.solution
→ diagnostic.codeFix
→ diagnostic.steps
→ diagnostic.severity
```

---

## ⚙️ Configuration Requise

### Custom Metadata Type : `GPT_Key__mdt`

**Champs nécessaires :**
- ✅ `Key_API__c` (Text) - Clé API Azure OpenAI
- ✅ `Endpoint__c` (URL) - Endpoint Azure (ex: `https://RESOURCE.openai.azure.com/`)
- ✅ `Deployment_Name__c` (Text) - Nom du déploiement (ex: `gpt-4-32k`)
- ✅ `API_Version__c` (Text) - Version API (ex: `2024-02-15-preview`)
- ✅ `Temperature__c` (Number) - Température (0.1)
- ✅ `Max_Tokens__c` (Number) - Tokens max (4000)

**Record à créer :**
- Developer Name: `OpenAIKey`
- Remplir tous les champs avec tes credentials Azure OpenAI

---

## 🧪 Test Rapide

**Dans Developer Console :**

```apex
// Test simple
String response = OpenAI_Service.sendPrompt('Réponds "OK"');
System.debug('Réponse: ' + response);
```

**Résultat attendu :** `"OK"` ou réponse similaire

---

## 📊 Flux Complet

```
1. Flow échoue
   ↓
2. Universal_Log_Flow_Error appelé
   ↓
3. ErrorDiagnosticService.diagnoseAndCreateCase()
   ↓
4. buildPrompt() → Prompt spécialisé Flow
   ↓
5. OpenAI_Service.sendPrompt()
   ├─ Récupère GPT_Key__mdt
   ├─ Construit endpoint Azure
   ├─ Envoie HTTP POST
   └─ Parse réponse JSON
   ↓
6. parseAIResponse() → DiagnosticResult
   ↓
7. createCase() → Case avec diagnostic IA
```

---

**Tout est prêt !** Il faut juste :
1. Vérifier que `GPT_Key__mdt` a tous les champs
2. Créer le record `OpenAIKey` avec tes credentials Azure
3. Tester !
