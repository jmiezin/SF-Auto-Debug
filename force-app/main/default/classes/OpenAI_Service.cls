/**
 * Service Azure OpenAI pour Salesforce
 * Récupère les credentials depuis Azure Key Vault
 */
public with sharing class OpenAI_Service {

    public class ChatRequest {
        public String model;
        public List<Map<String, String>> messages;
        public Decimal temperature;
        public Integer max_tokens;
    }

    /**
     * Récupère la configuration Azure OpenAI depuis Azure Key Vault
     */
    private static Map<String, String> getAzureOpenAIConfig() {
        return AzureKeyVaultService.getAzureOpenAIConfig();
    }

    /**
     * Envoie un prompt à Azure OpenAI et récupère la réponse
     * @param userPrompt Le prompt à envoyer
     * @return La réponse de l'IA
     */
    public static String sendPrompt(String userPrompt) {
        // 1. Récupérer la configuration Azure OpenAI depuis Key Vault
        Map<String, String> config = getAzureOpenAIConfig();
        
        // 2. Construire l'endpoint Azure OpenAI
        // Format: https://RESOURCE.openai.azure.com/openai/deployments/DEPLOYMENT_NAME/chat/completions?api-version=API_VERSION
        String endpoint = config.get('endpoint');
        String deployment = config.get('deployment');
        String apiVersion = config.get('apiVersion');
        
        // Nettoyer l'endpoint (enlever le / final si présent)
        if (endpoint.endsWith('/')) {
            endpoint = endpoint.substring(0, endpoint.length() - 1);
        }
        
        String fullEndpoint = endpoint + '/openai/deployments/' + deployment + '/chat/completions?api-version=' + apiVersion;
        
        // 3. Créer la requête HTTP
        HttpRequest req = new HttpRequest();
        req.setEndpoint(fullEndpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('api-key', config.get('apiKey')); // Azure OpenAI utilise 'api-key' au lieu de 'Authorization: Bearer'
        req.setTimeout(120000); // 120 secondes timeout
        
        // 4. Construire le body de la requête
        ChatRequest body = new ChatRequest();
        body.model = deployment; // Pour Azure OpenAI, on utilise le deployment name
        body.messages = new List<Map<String, String>>{
            new Map<String, String>{ 'role' => 'user', 'content' => userPrompt }
        };
        body.temperature = Decimal.valueOf(config.get('temperature'));
        body.max_tokens = Integer.valueOf(config.get('maxTokens'));
        
        req.setBody(JSON.serialize(body));
        
        // 5. Envoyer la requête
        HttpResponse res = new Http().send(req);
        
        // 6. Vérifier la réponse
        if (res.getStatusCode() != 200) {
            String errorMsg = 'Azure OpenAI Error (' + res.getStatusCode() + '): ' + res.getBody();
            System.debug(LoggingLevel.ERROR, errorMsg);
            throw new CalloutException(errorMsg);
        }
        
        // 7. Parser la réponse
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        
        // Structure de la réponse Azure OpenAI:
        // {
        //   "choices": [
        //     {
        //       "message": {
        //         "content": "Réponse de l'IA"
        //       }
        //     }
        //   ]
        // }
        
        List<Object> choices = (List<Object>) responseMap.get('choices');
        if (choices == null || choices.isEmpty()) {
            throw new CalloutException('Azure OpenAI Error: No choices in response');
        }
        
        Map<String, Object> firstChoice = (Map<String, Object>) choices[0];
        Map<String, Object> message = (Map<String, Object>) firstChoice.get('message');
        String content = (String) message.get('content');
        
        if (String.isBlank(content)) {
            throw new CalloutException('Azure OpenAI Error: Empty response content');
        }
        
        return content;
    }
    
    /**
     * Version avec gestion d'erreur améliorée et logging
     */
    public static String sendPromptWithLogging(String userPrompt) {
        try {
            System.debug(LoggingLevel.INFO, '🤖 [OpenAI] Envoi du prompt à Azure OpenAI...');
            System.debug(LoggingLevel.DEBUG, '🤖 [OpenAI] Prompt length: ' + userPrompt.length() + ' caractères');
            
            String response = sendPrompt(userPrompt);
            
            System.debug(LoggingLevel.INFO, '✅ [OpenAI] Réponse reçue');
            System.debug(LoggingLevel.DEBUG, '✅ [OpenAI] Response length: ' + response.length() + ' caractères');
            
            return response;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '❌ [OpenAI] Erreur: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, '❌ [OpenAI] Stack trace: ' + e.getStackTraceString());
            throw e;
        }
    }
}
