/**
 * Service pour récupérer les secrets depuis Azure Key Vault
 * Utilise l'API REST Azure Key Vault avec authentification OAuth2
 */
public with sharing class AzureKeyVaultService {
    
    /**
     * Récupère l'URL du Key Vault depuis Custom Metadata
     * Fallback sur valeur par défaut si non configuré
     */
    private static String getKeyVaultUrl() {
        try {
            Azure_AD_Config__mdt config = [
                SELECT Key_Vault_URL__c
                FROM Azure_AD_Config__mdt
                WHERE DeveloperName = 'Default'
                LIMIT 1
            ];
            if (String.isNotBlank(config.Key_Vault_URL__c)) {
                return config.Key_Vault_URL__c;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Key_Vault_URL__c non configuré, utilisation valeur par défaut');
        }
        // Valeur par défaut
        return 'https://kv-isonic-ai-migration.vault.azure.net/';
    }
    
    /**
     * Récupère un secret depuis Azure Key Vault
     * @param secretName Nom du secret (ex: 'azure-openai-api-key')
     * @return Valeur du secret
     */
    public static String getSecret(String secretName) {
        // Construire l'URL de l'API REST Azure Key Vault
        // Format: https://VAULT_NAME.vault.azure.net/secrets/SECRET_NAME?api-version=7.4
        String keyVaultUrl = getKeyVaultUrl();
        // S'assurer que l'URL se termine par /
        if (!keyVaultUrl.endsWith('/')) {
            keyVaultUrl += '/';
        }
        String endpoint = keyVaultUrl + 'secrets/' + secretName + '?api-version=7.4';
        
        // Récupérer le token d'accès Azure AD
        String accessToken = getAzureAccessToken();
        
        // Créer la requête HTTP
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(30000);
        
        // Envoyer la requête
        HttpResponse res = new Http().send(req);
        
        if (res.getStatusCode() != 200) {
            throw new CalloutException('Azure Key Vault Error (' + res.getStatusCode() + '): ' + res.getBody());
        }
        
        // Parser la réponse
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        String secretValue = (String) responseMap.get('value');
        
        return secretValue;
    }
    
    /**
     * Récupère le token d'accès Azure AD via OAuth2 Client Credentials
     * Note: Nécessite une Named Credential configurée pour Azure AD
     * Ou utiliser un Service Principal avec client_id/client_secret
     */
    private static String getAzureAccessToken() {
        // Option 1: Utiliser Named Credential (recommandé)
        // Si tu as configuré une Named Credential pour Azure AD:
        // return getTokenFromNamedCredential();
        
        // Option 2: Utiliser Service Principal (client_id + client_secret)
        // Récupérer depuis Custom Metadata ou Protected Custom Settings
        return getTokenFromServicePrincipal();
    }
    
    /**
     * Récupère le token via Service Principal (client_id + client_secret)
     */
    private static String getTokenFromServicePrincipal() {
        // Récupérer les credentials depuis Custom Metadata
        Azure_AD_Config__mdt config = [
            SELECT Tenant_Id__c, Client_Id__c, Client_Secret__c
            FROM Azure_AD_Config__mdt
            WHERE DeveloperName = 'Default'
            LIMIT 1
        ];
        
        // Endpoint OAuth2 Azure AD
        String tokenEndpoint = 'https://login.microsoftonline.com/' + config.Tenant_Id__c + '/oauth2/v2.0/token';
        
        // Construire le body de la requête
        String body = 'grant_type=client_credentials'
                    + '&client_id=' + EncodingUtil.urlEncode(config.Client_Id__c, 'UTF-8')
                    + '&client_secret=' + EncodingUtil.urlEncode(config.Client_Secret__c, 'UTF-8')
                    + '&scope=https://vault.azure.net/.default';
        
        // Créer la requête
        HttpRequest req = new HttpRequest();
        req.setEndpoint(tokenEndpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(body);
        req.setTimeout(30000);
        
        // Envoyer la requête
        HttpResponse res = new Http().send(req);
        
        if (res.getStatusCode() != 200) {
            throw new CalloutException('Azure AD Token Error (' + res.getStatusCode() + '): ' + res.getBody());
        }
        
        // Parser la réponse
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        String accessToken = (String) responseMap.get('access_token');
        
        return accessToken;
    }
    
    /**
     * Récupère la configuration Azure OpenAI depuis Key Vault
     */
    public static Map<String, String> getAzureOpenAIConfig() {
        Map<String, String> config = new Map<String, String>();
        
        try {
            config.put('apiKey', getSecret('azure-openai-api-key'));
            config.put('endpoint', getSecret('azure-openai-endpoint'));
            
            // Deployment peut être dans Key Vault ou valeur par défaut
            try {
                // Essayer d'abord avec le nom exact dans Key Vault
                config.put('deployment', getSecret('azure-openai-deployment-name'));
            } catch (Exception e) {
                try {
                    // Fallback sur l'ancien nom
                    config.put('deployment', getSecret('azure-openai-deployment'));
                } catch (Exception e2) {
                    System.debug(LoggingLevel.INFO, 'azure-openai-deployment non trouvé dans Key Vault, utilisation valeur par défaut');
                    config.put('deployment', 'gpt-4-32k'); // Valeur par défaut
                }
            }
            
            config.put('apiVersion', '2024-02-15-preview'); // Par défaut
            config.put('temperature', '0.1'); // Par défaut
            config.put('maxTokens', '4000'); // Par défaut
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Erreur récupération config Azure OpenAI depuis Key Vault: ' + e.getMessage());
            throw new CalloutException('Impossible de récupérer la configuration Azure OpenAI depuis Key Vault: ' + e.getMessage());
        }
        
        return config;
    }
}
