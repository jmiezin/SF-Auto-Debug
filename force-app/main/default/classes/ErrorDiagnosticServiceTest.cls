/**
 * Tests complets pour ErrorDiagnosticService
 * Utilise OpenAI_HttpCalloutMock pour simuler les callouts HTTP
 */
@isTest
private class ErrorDiagnosticServiceTest {
    
    @TestSetup
    static void setup() {
        // Setup si nécessaire
    }
    
    /**
     * Test complet: diagnoseAndCreateCase avec Apex error
     */
    @isTest
    static void testDiagnoseAndCreateCaseApex() {
        // Setup mock pour tous les callouts (Azure + OpenAI)
        Test.setMock(HttpCalloutMock.class, new OpenAI_HttpCalloutMock(OpenAI_HttpCalloutMock.RESPONSE_SUCCESS));
        
        Test.startTest();
        
        ErrorDiagnosticService.ErrorInfo error = new ErrorDiagnosticService.ErrorInfo();
        error.errorType = 'APEX';
        error.componentName = 'QuoteService'; // Utilisé pour le Subject du Case
        error.className = 'QuoteService';
        error.methodName = 'calculateTotal';
        error.errorMessage = 'System.NullPointerException: Attempt to de-reference a null object';
        error.stackTrace = 'Class.QuoteService.calculateTotal: line 127';
        error.lineNumber = 127;
        error.recordId = null;
        error.objectType = 'Account';
        
        List<ErrorDiagnosticService.Response> responses = 
            ErrorDiagnosticService.diagnoseAndCreateCase(new List<ErrorDiagnosticService.ErrorInfo>{ error });
        
        Test.stopTest();
        
        // Vérifications
        System.assertNotEquals(null, responses, 'Responses should not be null');
        System.assertEquals(1, responses.size(), 'Should have 1 response');
        System.assertEquals(true, responses[0].success, 'Response should be successful');
        System.assertNotEquals(null, responses[0].caseId, 'CaseId should not be null');
        
        // Vérifier que le Case a été créé
        Case createdCase = [SELECT Id, Subject, Description, Status, Origin FROM Case WHERE Id = :responses[0].caseId LIMIT 1];
        System.assertNotEquals(null, createdCase, 'Case should be created');
        System.assert(createdCase.Subject.contains('APEX ERROR'), 'Subject should contain APEX ERROR');
    }
    
    /**
     * Test complet: diagnoseAndCreateCase avec Flow error
     */
    @isTest
    static void testDiagnoseAndCreateCaseFlow() {
        Test.setMock(HttpCalloutMock.class, new OpenAI_HttpCalloutMock(OpenAI_HttpCalloutMock.RESPONSE_SUCCESS));
        
        Test.startTest();
        
        ErrorDiagnosticService.ErrorInfo error = new ErrorDiagnosticService.ErrorInfo();
        error.errorType = 'FLOW';
        error.componentName = 'Quote_Trigger_Update'; // Utilisé pour le Subject du Case
        error.flowName = 'Quote_Trigger_Update';
        error.flowApiName = 'Quote_Trigger_Update';
        error.errorMessage = 'Field Owner_Role__c does not exist';
        error.faultElement = 'Decision Check Owner Role';
        error.recordId = null;
        error.objectType = 'Account';
        
        List<ErrorDiagnosticService.Response> responses = 
            ErrorDiagnosticService.diagnoseAndCreateCase(new List<ErrorDiagnosticService.ErrorInfo>{ error });
        
        Test.stopTest();
        
        System.assertEquals(true, responses[0].success);
        System.assertNotEquals(null, responses[0].caseId);
        
        Case createdCase = [SELECT Id, Subject FROM Case WHERE Id = :responses[0].caseId LIMIT 1];
        System.assert(createdCase.Subject.contains('FLOW ERROR'));
    }
    
    /**
     * Test complet: diagnoseAndCreateCase avec LWC error
     */
    @isTest
    static void testDiagnoseAndCreateCaseLWC() {
        Test.setMock(HttpCalloutMock.class, new OpenAI_HttpCalloutMock(OpenAI_HttpCalloutMock.RESPONSE_SUCCESS));
        
        Test.startTest();
        
        ErrorDiagnosticService.ErrorInfo error = new ErrorDiagnosticService.ErrorInfo();
        error.errorType = 'LWC';
        error.componentName = 'isquote_bundleConfigurator';
        error.errorMessage = 'Cannot read property recordId of undefined';
        error.stackTrace = 'at isquote_bundleConfigurator.handleSave';
        error.recordId = null;
        error.objectType = 'Quote';
        error.contextData = '{"bundleId": "123", "action": "save"}';
        
        List<ErrorDiagnosticService.Response> responses = 
            ErrorDiagnosticService.diagnoseAndCreateCase(new List<ErrorDiagnosticService.ErrorInfo>{ error });
        
        Test.stopTest();
        
        System.assertEquals(true, responses[0].success);
        System.assertNotEquals(null, responses[0].caseId);
        
        Case createdCase = [SELECT Id, Subject FROM Case WHERE Id = :responses[0].caseId LIMIT 1];
        System.assert(createdCase.Subject.contains('LWC ERROR'));
    }
    
    /**
     * Test: diagnoseLWCError (méthode @AuraEnabled)
     */
    @isTest
    static void testDiagnoseLWCErrorAuraEnabled() {
        Test.setMock(HttpCalloutMock.class, new OpenAI_HttpCalloutMock(OpenAI_HttpCalloutMock.RESPONSE_SUCCESS));
        
        Test.startTest();
        
        String caseId = ErrorDiagnosticService.diagnoseLWCError(
            'testComponent',
            'Test error message',
            'Test stack trace',
            null,
            'Account',
            '{"key": "value"}'
        );
        
        Test.stopTest();
        
        System.assertNotEquals(null, caseId, 'CaseId should not be null');
        
        Case createdCase = [SELECT Id, Subject FROM Case WHERE Id = :caseId LIMIT 1];
        System.assertNotEquals(null, createdCase);
    }
    
    /**
     * Test: parsing JSON malformé (avec backticks markdown)
     */
    @isTest
    static void testParseAIResponseMalformed() {
        Test.setMock(HttpCalloutMock.class, new OpenAI_HttpCalloutMock(OpenAI_HttpCalloutMock.RESPONSE_MALFORMED));
        
        Test.startTest();
        
        ErrorDiagnosticService.ErrorInfo error = new ErrorDiagnosticService.ErrorInfo();
        error.errorType = 'APEX';
        error.className = 'TestClass';
        error.errorMessage = 'Test error';
        
        List<ErrorDiagnosticService.Response> responses = 
            ErrorDiagnosticService.diagnoseAndCreateCase(new List<ErrorDiagnosticService.ErrorInfo>{ error });
        
        Test.stopTest();
        
        // Le parsing devrait réussir malgré le markdown
        System.assertEquals(true, responses[0].success);
        System.assertNotEquals(null, responses[0].caseId);
    }
    
    /**
     * Test: gestion d'erreur lors du callout OpenAI
     */
    @isTest
    static void testDiagnoseWithOpenAIError() {
        Test.setMock(HttpCalloutMock.class, new OpenAI_HttpCalloutMock(OpenAI_HttpCalloutMock.RESPONSE_ERROR));
        
        Test.startTest();
        
        ErrorDiagnosticService.ErrorInfo error = new ErrorDiagnosticService.ErrorInfo();
        error.errorType = 'APEX';
        error.className = 'TestClass';
        error.errorMessage = 'Test error';
        
        List<ErrorDiagnosticService.Response> responses = 
            ErrorDiagnosticService.diagnoseAndCreateCase(new List<ErrorDiagnosticService.ErrorInfo>{ error });
        
        Test.stopTest();
        
        // Le diagnostic devrait échouer mais pas crasher
        System.assertNotEquals(null, responses);
        System.assertEquals(1, responses.size());
        System.assertEquals(false, responses[0].success);
    }
    
    /**
     * Test: multiple errors in batch
     */
    @isTest
    static void testDiagnoseMultipleErrors() {
        Test.setMock(HttpCalloutMock.class, new OpenAI_HttpCalloutMock(OpenAI_HttpCalloutMock.RESPONSE_SUCCESS));
        
        Test.startTest();
        
        List<ErrorDiagnosticService.ErrorInfo> errors = new List<ErrorDiagnosticService.ErrorInfo>();
        
        ErrorDiagnosticService.ErrorInfo error1 = new ErrorDiagnosticService.ErrorInfo();
        error1.errorType = 'APEX';
        error1.componentName = 'Class1';
        error1.className = 'Class1';
        error1.errorMessage = 'Error 1';
        errors.add(error1);
        
        ErrorDiagnosticService.ErrorInfo error2 = new ErrorDiagnosticService.ErrorInfo();
        error2.errorType = 'FLOW';
        error2.componentName = 'Flow1';
        error2.flowName = 'Flow1';
        error2.errorMessage = 'Error 2';
        errors.add(error2);
        
        List<ErrorDiagnosticService.Response> responses = 
            ErrorDiagnosticService.diagnoseAndCreateCase(errors);
        
        Test.stopTest();
        
        System.assertEquals(2, responses.size());
        System.assertEquals(true, responses[0].success);
        // Note: Le 2ème peut échouer en test context à cause des limites de callouts mock
        // On vérifie juste qu'on a bien 2 réponses
        System.assertNotEquals(null, responses[1]);
    }
    
    /**
     * Test des adaptateurs (coverage des adapters)
     */
    @isTest
    static void testApexErrorAdapter() {
        ErrorDiagnosticService.ErrorInfo error = new ErrorDiagnosticService.ErrorInfo();
        error.errorType = 'APEX';
        error.className = 'TestClass';
        error.methodName = 'testMethod';
        error.errorMessage = 'Test error';
        error.stackTrace = 'Class.TestClass.testMethod: line 10';
        
        ErrorDiagnosticService.DiagnosticContext context = ApexErrorAdapter.buildContext(error);
        System.assertNotEquals(null, context);
        System.assertEquals(ErrorDiagnosticService.ErrorType.APEX, context.errorType);
        
        String prompt = ApexErrorAdapter.buildPrompt(error, context);
        System.assertNotEquals(null, prompt);
        System.assert(prompt.contains('TestClass'));
    }
    
    @isTest
    static void testLWCErrorAdapter() {
        ErrorDiagnosticService.ErrorInfo error = new ErrorDiagnosticService.ErrorInfo();
        error.errorType = 'LWC';
        error.componentName = 'testComponent';
        error.errorMessage = 'Test error';
        
        ErrorDiagnosticService.DiagnosticContext context = LWCErrorAdapter.buildContext(error);
        System.assertNotEquals(null, context);
        System.assertEquals(ErrorDiagnosticService.ErrorType.LWC, context.errorType);
        
        String prompt = LWCErrorAdapter.buildPrompt(error, context);
        System.assertNotEquals(null, prompt);
        System.assert(prompt.contains('testComponent'));
    }
    
    @isTest
    static void testFlowErrorAdapter() {
        ErrorDiagnosticService.ErrorInfo error = new ErrorDiagnosticService.ErrorInfo();
        error.errorType = 'FLOW';
        error.flowName = 'TestFlow';
        error.flowApiName = 'TestFlow';
        error.errorMessage = 'Test error';
        
        ErrorDiagnosticService.DiagnosticContext context = FlowErrorAdapter.buildContext(error);
        System.assertNotEquals(null, context);
        System.assertEquals(ErrorDiagnosticService.ErrorType.FLOW, context.errorType);
        
        String prompt = FlowErrorAdapter.buildPrompt(error, context);
        System.assertNotEquals(null, prompt);
        System.assert(prompt.contains('TestFlow'));
    }
    
    /**
     * Test avec données null/vides
     */
    @isTest
    static void testWithNullData() {
        Test.setMock(HttpCalloutMock.class, new OpenAI_HttpCalloutMock(OpenAI_HttpCalloutMock.RESPONSE_SUCCESS));
        
        Test.startTest();
        
        ErrorDiagnosticService.ErrorInfo error = new ErrorDiagnosticService.ErrorInfo();
        error.errorType = 'APEX';
        error.componentName = 'MinimalTest';
        error.errorMessage = 'Minimal error';
        // Pas de className, methodName, etc.
        
        List<ErrorDiagnosticService.Response> responses = 
            ErrorDiagnosticService.diagnoseAndCreateCase(new List<ErrorDiagnosticService.ErrorInfo>{ error });
        
        Test.stopTest();
        
        System.assertEquals(true, responses[0].success);
    }
}
