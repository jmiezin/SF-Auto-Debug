/**
 * Mock HttpCallout pour tester OpenAI_Service et ErrorDiagnosticService
 * Simule les réponses d'Azure OpenAI sans faire de vrais callouts
 */
@isTest
global class OpenAI_HttpCalloutMock implements HttpCalloutMock {
    
    private String responseType;
    
    /**
     * Types de réponses possibles
     */
    public static final String RESPONSE_SUCCESS = 'SUCCESS';
    public static final String RESPONSE_ERROR = 'ERROR';
    public static final String RESPONSE_MALFORMED = 'MALFORMED';
    public static final String RESPONSE_AZURE_AUTH = 'AZURE_AUTH';
    
    /**
     * Constructeur
     */
    public OpenAI_HttpCalloutMock(String responseType) {
        this.responseType = responseType;
    }
    
    /**
     * Implémentation de HttpCalloutMock.respond
     */
    global HTTPResponse respond(HTTPRequest req) {
        HTTPResponse res = new HTTPResponse();
        res.setHeader('Content-Type', 'application/json');
        
        // Mock pour Azure AD Token
        if (req.getEndpoint().contains('oauth2/v2.0/token')) {
            return mockAzureAuthResponse(res);
        }
        
        // Mock pour Azure Key Vault
        if (req.getEndpoint().contains('vault.azure.net')) {
            return mockKeyVaultResponse(req, res);
        }
        
        // Mock pour OpenAI
        if (req.getEndpoint().contains('openai.azure.com')) {
            return mockOpenAIResponse(res);
        }
        
        // Default fallback
        res.setStatusCode(404);
        res.setBody('{"error": "Not found"}');
        return res;
    }
    
    /**
     * Mock réponse Azure AD OAuth
     */
    private HTTPResponse mockAzureAuthResponse(HTTPResponse res) {
        res.setStatusCode(200);
        res.setBody('{"access_token": "mock_access_token_12345", "token_type": "Bearer", "expires_in": 3600}');
        return res;
    }
    
    /**
     * Mock réponse Azure Key Vault
     */
    private HTTPResponse mockKeyVaultResponse(HTTPRequest req, HTTPResponse res) {
        res.setStatusCode(200);
        
        if (req.getEndpoint().contains('azure-openai-api-key')) {
            res.setBody('{"value": "mock_api_key_12345"}');
        } else if (req.getEndpoint().contains('azure-openai-endpoint')) {
            res.setBody('{"value": "https://mock-openai.openai.azure.com/"}');
        } else if (req.getEndpoint().contains('azure-openai-deployment')) {
            res.setBody('{"value": "gpt-4o"}');
        } else {
            res.setBody('{"value": "mock_value"}');
        }
        
        return res;
    }
    
    /**
     * Mock réponse OpenAI selon le type
     */
    private HTTPResponse mockOpenAIResponse(HTTPResponse res) {
        if (responseType == RESPONSE_SUCCESS) {
            res.setStatusCode(200);
            res.setBody(getMockSuccessResponse());
        } else if (responseType == RESPONSE_MALFORMED) {
            res.setStatusCode(200);
            res.setBody(getMockMalformedResponse());
        } else if (responseType == RESPONSE_ERROR) {
            res.setStatusCode(500);
            res.setBody('{"error": {"message": "Internal server error", "type": "server_error"}}');
        } else {
            // Default: success
            res.setStatusCode(200);
            res.setBody(getMockSuccessResponse());
        }
        
        return res;
    }
    
    /**
     * Réponse OpenAI bien formée (JSON valide)
     */
    private String getMockSuccessResponse() {
        return '{'
            + '"choices": [{'
            + '  "message": {'
            + '    "role": "assistant",'
            + '    "content": "{\\"problem\\": \\"Test problem\\", \\"rootCause\\": \\"Test root cause\\", \\"solution\\": \\"Test solution\\", \\"codeFix\\": \\"// Test code fix\\", \\"steps\\": [\\"Step 1\\", \\"Step 2\\"], \\"severity\\": \\"MEDIUM\\"}"'
            + '  },'
            + '  "finish_reason": "stop",'
            + '  "index": 0'
            + '}],'
            + '"usage": {"prompt_tokens": 100, "completion_tokens": 50, "total_tokens": 150}'
            + '}';
    }
    
    /**
     * Réponse OpenAI malformée (JSON avec backticks markdown)
     */
    private String getMockMalformedResponse() {
        return '{'
            + '"choices": [{'
            + '  "message": {'
            + '    "role": "assistant",'
            + '    "content": "```json\\n{\\"problem\\": \\"Test problem with markdown\\", \\"rootCause\\": \\"Test root cause\\", \\"solution\\": \\"Test solution\\", \\"codeFix\\": \\"// Test code fix\\", \\"steps\\": [\\"Step 1\\", \\"Step 2\\"], \\"severity\\": \\"HIGH\\"}\\n```"'
            + '  },'
            + '  "finish_reason": "stop",'
            + '  "index": 0'
            + '}]'
            + '}';
    }
}
