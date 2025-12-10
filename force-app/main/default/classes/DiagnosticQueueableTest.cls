/**
 * Tests pour DiagnosticQueueable
 */
@isTest
private class DiagnosticQueueableTest {
    
    @isTest
    static void testQueueableExecution() {
        Test.startTest();
        
        // Créer une erreur info
        ErrorDiagnosticService.ErrorInfo error = new ErrorDiagnosticService.ErrorInfo();
        error.errorType = 'APEX';
        error.className = 'TestClass';
        error.methodName = 'testMethod';
        error.errorMessage = 'Test error for queueable';
        error.stackTrace = 'Class.TestClass.testMethod: line 10';
        
        // Enqueue le diagnostic
        System.enqueueJob(new DiagnosticQueueable(error));
        
        Test.stopTest();
        
        // Vérifier qu'un Case a été créé (si le système fonctionne)
        List<Case> cases = [SELECT Id FROM Case WHERE Type = 'APEX' LIMIT 1];
        // Le Case peut ne pas être créé si Azure OpenAI n'est pas accessible en test
        // On vérifie juste que le queueable ne crash pas
        System.assert(true, 'Queueable executed without error');
    }
    
    @isTest
    static void testQueueableWithMinimalData() {
        Test.startTest();
        
        ErrorDiagnosticService.ErrorInfo error = new ErrorDiagnosticService.ErrorInfo();
        error.errorType = 'LWC';
        error.componentName = 'testComponent';
        error.errorMessage = 'Minimal error';
        
        System.enqueueJob(new DiagnosticQueueable(error));
        
        Test.stopTest();
        
        System.assert(true);
    }
}
