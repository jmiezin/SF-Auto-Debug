# 🔧 Configuration Azure OpenAI dans Salesforce

## Comment ça fonctionne ?

### 1. Envoi à Azure OpenAI

**Dans `ErrorDiagnosticService.analyzeWithAI()` :**
```apex
// Ligne 170
String prompt = buildPrompt(error, context);
String aiResponse = OpenAI_Service.sendPrompt(prompt);
```

**Dans `OpenAI_Service.sendPrompt()` :**
```apex
// 1. Récupère la config depuis Custom Metadata
Map<String, String> config = getAzureOpenAIConfig();

// 2. Construit l'endpoint Azure OpenAI
// Format: https://RESOURCE.openai.azure.com/openai/deployments/DEPLOYMENT/chat/completions?api-version=VERSION
String fullEndpoint = endpoint + '/openai/deployments/' + deployment + '/chat/completions?api-version=' + apiVersion;

// 3. Crée la requête HTTP
HttpRequest req = new HttpRequest();
req.setEndpoint(fullEndpoint);
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json');
req.setHeader('api-key', config.get('apiKey')); // Azure utilise 'api-key'

// 4. Envoie le prompt
HttpResponse res = new Http().send(req);

// 5. Parse la réponse
return content; // Texte de la réponse IA
```

---

### 2. Récupération de la réponse

**Structure de la réponse Azure OpenAI :**
```json
{
  "choices": [
    {
      "message": {
        "content": "Réponse de l'IA ici..."
      }
    }
  ]
}
```

**Parsing dans `OpenAI_Service.sendPrompt()` :**
```apex
Map<String, Object> responseMap = JSON.deserializeUntyped(res.getBody());
List<Object> choices = (List<Object>) responseMap.get('choices');
Map<String, Object> firstChoice = (Map<String, Object>) choices[0];
Map<String, Object> message = (Map<String, Object>) firstChoice.get('message');
String content = (String) message.get('content');
return content;
```

**Puis dans `ErrorDiagnosticService.parseAIResponse()` :**
```apex
// Parse le JSON de la réponse IA
Map<String, Object> jsonResponse = JSON.deserializeUntyped(aiResponse);
diagnostic.problem = (String) jsonResponse.get('problem');
diagnostic.rootCause = (String) jsonResponse.get('rootCause');
diagnostic.solution = (String) jsonResponse.get('solution');
// etc.
```

---

## ⚙️ Configuration Requise

### Custom Metadata Type : `GPT_Key__mdt`

**Champs nécessaires :**
- `Key_API__c` (Text) - Clé API Azure OpenAI
- `Endpoint__c` (URL) - Endpoint Azure OpenAI (ex: `https://RESOURCE.openai.azure.com/`)
- `Deployment_Name__c` (Text) - Nom du déploiement (ex: `gpt-4-32k`)
- `API_Version__c` (Text) - Version API (ex: `2024-02-15-preview`)
- `Temperature__c` (Number) - Température (0.0 à 1.0, défaut: 0.1)
- `Max_Tokens__c` (Number) - Tokens max (défaut: 4000)

---

## 📋 Étapes de Configuration

### Étape 1 : Créer le Custom Metadata Type

**Via Setup → Custom Metadata Types :**

1. **Créer Custom Metadata Type :**
   - Label: `GPT Key`
   - Plural Label: `GPT Keys`
   - Object Name: `GPT_Key`

2. **Ajouter les champs :**
   - `Key_API__c` (Text, 255)
   - `Endpoint__c` (URL, 255)
   - `Deployment_Name__c` (Text, 100)
   - `API_Version__c` (Text, 50)
   - `Temperature__c` (Number, 3, 1)
   - `Max_Tokens__c` (Number, 10, 0)

3. **Créer le record :**
   - Developer Name: `OpenAIKey`
   - Label: `OpenAI Key`
   - Remplir tous les champs avec tes credentials Azure OpenAI

---

### Étape 2 : Récupérer tes credentials Azure OpenAI

**Depuis Azure Portal :**

1. Aller sur https://portal.azure.com
2. Trouver ta ressource Azure OpenAI
3. **Endpoint :** Copier l'URL (ex: `https://isonic-ai.openai.azure.com/`)
4. **API Key :** Clés et point de terminaison → Clé 1
5. **Deployment :** Déploiements → Nom de ton déploiement (ex: `gpt-4-32k`)
6. **API Version :** Vérifier dans la doc (ex: `2024-02-15-preview`)

---

### Étape 3 : Créer le record Custom Metadata

**Via Setup → Custom Metadata Types → GPT Key → New :**

```
Developer Name: OpenAIKey
Label: OpenAI Key

Key_API__c: sk-xxxxxxxxxxxxxxxxxxxxx
Endpoint__c: https://isonic-ai.openai.azure.com/
Deployment_Name__c: gpt-4-32k
API_Version__c: 2024-02-15-preview
Temperature__c: 0.1
Max_Tokens__c: 4000
```

---

## 🧪 Test de la Configuration

### Test simple depuis Developer Console

```apex
// Tester la connexion Azure OpenAI
String testPrompt = 'Réponds simplement "OK" si tu reçois ce message.';
String response = OpenAI_Service.sendPrompt(testPrompt);
System.debug('Réponse: ' + response);
```

**Résultat attendu :** `"OK"` ou une réponse similaire

---

### Test avec ErrorDiagnosticService

```apex
// Créer une erreur de test
ErrorDiagnosticService.ErrorInfo error = new ErrorDiagnosticService.ErrorInfo();
error.errorType = 'APEX';
error.className = 'TestClass';
error.methodName = 'testMethod';
error.errorMessage = 'Test error message';
error.stackTrace = 'Class.TestClass.testMethod: line 10';

// Appeler le diagnostic
List<ErrorDiagnosticService.Response> responses = 
    ErrorDiagnosticService.diagnoseAndCreateCase(new List<ErrorDiagnosticService.ErrorInfo>{ error });

System.debug('Case créé: ' + responses[0].caseId);
```

---

## 🔍 Vérification du Flux Complet

### 1. Vérifier que Custom Metadata existe

```apex
GPT_Key__mdt config = [SELECT Key_API__c, Endpoint__c, Deployment_Name__c 
                        FROM GPT_Key__mdt 
                        WHERE DeveloperName = 'OpenAIKey' 
                        LIMIT 1];
System.debug('Config: ' + config);
```

### 2. Vérifier l'endpoint construit

Dans `OpenAI_Service.sendPrompt()`, ajouter un debug :
```apex
System.debug('Endpoint complet: ' + fullEndpoint);
```

**Format attendu :**
```
https://RESOURCE.openai.azure.com/openai/deployments/DEPLOYMENT_NAME/chat/completions?api-version=2024-02-15-preview
```

### 3. Vérifier la réponse HTTP

Dans `OpenAI_Service.sendPrompt()`, ajouter :
```apex
System.debug('Status Code: ' + res.getStatusCode());
System.debug('Response Body: ' + res.getBody());
```

---

## ❌ Erreurs Courantes

### Erreur 401 (Unauthorized)

**Cause :** Clé API incorrecte ou manquante

**Solution :**
- Vérifier que `Key_API__c` est bien rempli dans Custom Metadata
- Vérifier que la clé API est valide dans Azure Portal
- Vérifier que le header `api-key` est bien envoyé

### Erreur 404 (Not Found)

**Cause :** Endpoint ou deployment incorrect

**Solution :**
- Vérifier le format de l'endpoint (doit finir par `/`)
- Vérifier que le `Deployment_Name__c` existe dans Azure
- Vérifier que l'API version est correcte

### Erreur 400 (Bad Request)

**Cause :** Format de la requête incorrect

**Solution :**
- Vérifier que le body JSON est correct
- Vérifier que les champs `temperature` et `max_tokens` sont valides

### Timeout

**Cause :** Requête trop longue

**Solution :**
- Augmenter le timeout dans `HttpRequest.setTimeout()`
- Réduire `Max_Tokens__c` dans Custom Metadata

---

## ✅ Checklist de Configuration

- [ ] Custom Metadata Type `GPT_Key__mdt` créé
- [ ] Tous les champs ajoutés (Key_API__c, Endpoint__c, etc.)
- [ ] Record `OpenAIKey` créé avec tes credentials
- [ ] Test simple depuis Developer Console OK
- [ ] Test avec ErrorDiagnosticService OK
- [ ] Case créé avec diagnostic IA

---

## 📊 Flux Complet

```
1. Flow/Apex/LWC échoue
   ↓
2. ErrorDiagnosticService.diagnoseAndCreateCase()
   ↓
3. buildPrompt() → Construit le prompt spécialisé
   ↓
4. OpenAI_Service.sendPrompt(prompt)
   ├─ Récupère config depuis GPT_Key__mdt
   ├─ Construit endpoint Azure OpenAI
   ├─ Envoie requête HTTP POST
   └─ Parse la réponse JSON
   ↓
5. parseAIResponse() → Extrait problem, rootCause, solution, etc.
   ↓
6. createCase() → Crée le Case avec diagnostic IA
   ↓
7. Case créé → Flow Case_Error_Email_Sender envoie email (optionnel)
```

---

**Tout est prêt !** Il ne reste plus qu'à configurer le Custom Metadata avec tes credentials Azure OpenAI. 🚀
