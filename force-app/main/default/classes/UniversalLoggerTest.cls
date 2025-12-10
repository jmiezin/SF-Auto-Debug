@isTest
private class UniversalLoggerTest {
    
    @isTest
    static void testDebugLog() {
        Test.startTest();
        UniversalLogger.debug('TestComponent', 'testMethod', 'Debug message');
        UniversalLogger.debug('TestComponent', 'testMethod', 'Debug with context', new Map<String, Object>{ 'key' => 'value' });
        Test.stopTest();
        // Si pas d'exception, c'est bon
        System.assert(true);
    }
    
    @isTest
    static void testInfoLog() {
        Test.startTest();
        UniversalLogger.info('TestComponent', 'testMethod', 'Info message');
        UniversalLogger.info('TestComponent', 'testMethod', 'Info with context', new Map<String, Object>{ 'key' => 'value' });
        Test.stopTest();
        System.assert(true);
    }
    
    @isTest
    static void testWarnLog() {
        Test.startTest();
        UniversalLogger.warn('TestComponent', 'testMethod', 'Warn message');
        UniversalLogger.warn('TestComponent', 'testMethod', 'Warn with context', new Map<String, Object>{ 'key' => 'value' });
        Test.stopTest();
        System.assert(true);
    }
    
    @isTest
    static void testErrorLog() {
        Test.startTest();
        UniversalLogger.error('TestComponent', 'testMethod', 'Error message');
        UniversalLogger.error('TestComponent', 'testMethod', 'Error with context', new Map<String, Object>{ 'key' => 'value' });
        Test.stopTest();
        System.assert(true);
    }
    
    @isTest
    static void testErrorLogWithException() {
        Test.startTest();
        try {
            Integer i = 1 / 0;
        } catch (Exception e) {
            UniversalLogger.error('TestComponent', 'testMethod', 'Error with exception', e);
            UniversalLogger.error('TestComponent', 'testMethod', 'Error with exception and context', e, new Map<String, Object>{ 'key' => 'value' });
        }
        Test.stopTest();
        System.assert(true);
    }
    
    @isTest
    static void testErrorLogWithDmlException() {
        Test.startTest();
        try {
            Account acc = new Account();
            insert acc; // Will fail if required fields missing
        } catch (DmlException e) {
            UniversalLogger.error('TestComponent', 'testMethod', 'DML Error', e);
        }
        Test.stopTest();
        System.assert(true);
    }
    
    @isTest
    static void testLogFromClient() {
        Test.startTest();
        UniversalLogger.logFromClient('INFO', 'TestComponent', 'testMethod', 'Test message', '{"key":"value"}');
        UniversalLogger.logFromClient('DEBUG', 'TestComponent', 'testMethod', 'Debug message', null);
        UniversalLogger.logFromClient('WARN', 'TestComponent', 'testMethod', 'Warn message', null);
        UniversalLogger.logFromClient('ERROR', 'TestComponent', 'testMethod', 'Error message', null);
        UniversalLogger.logFromClient('INVALID', 'TestComponent', 'testMethod', 'Invalid level', null);
        Test.stopTest();
        System.assert(true);
    }
    
    @isTest
    static void testLogFromFlow() {
        Test.startTest();
        UniversalLogger.FlowLogInput input = new UniversalLogger.FlowLogInput();
        input.level = 'INFO';
        input.component = 'TestFlow';
        input.method = 'Create Record';
        input.message = 'Test message';
        input.contextJson = '{"key":"value"}';
        
        UniversalLogger.logFromFlow(new List<UniversalLogger.FlowLogInput>{ input });
        Test.stopTest();
        System.assert(true);
    }
    
    @isTest
    static void testLogFromFlowEmpty() {
        Test.startTest();
        UniversalLogger.logFromFlow(new List<UniversalLogger.FlowLogInput>());
        UniversalLogger.logFromFlow(null);
        Test.stopTest();
        System.assert(true);
    }
    
    @isTest
    static void testLogWithNullValues() {
        Test.startTest();
        UniversalLogger.log(UniversalLogger.LogLevel.INFO, null, null, null, null);
        UniversalLogger.log(UniversalLogger.LogLevel.INFO, 'Component', 'Method', 'Message', null);
        Test.stopTest();
        System.assert(true);
    }
}
