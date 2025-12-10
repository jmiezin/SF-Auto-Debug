/**
 * Tests pour AuraExceptionHandler
 */
@isTest
private class AuraExceptionHandlerTest {
    
    @isTest
    static void testHandleException() {
        Test.startTest();
        
        try {
            // Simuler une erreur Apex qui sera catchée
            Account acc = new Account(); // Required fields missing
            insert acc;
        } catch (Exception e) {
            // Catch l'exception du handler
            try {
                throw AuraExceptionHandler.handle(
                    e,
                    'TestClass',
                    'testMethod',
                    new Map<String, Object>{ 'key' => 'value' }
                );
            } catch (AuraHandledException auraEx) {
                System.assertNotEquals(null, auraEx);
                System.assertNotEquals(null, auraEx.getMessage());
            }
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testHandleWithRecordId() {
        Test.startTest();
        
        try {
            insert new Account(); // Error: required field missing
        } catch (Exception e) {
            try {
                throw AuraExceptionHandler.handle(
                    e,
                    'TestClass',
                    'testMethod',
                    new Map<String, Object>{ 'accountData' => 'test' },
                    '001xx000000abc',
                    'Account'
                );
            } catch (AuraHandledException auraEx) {
                System.assertNotEquals(null, auraEx);
            }
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testUserFriendlyMessage() {
        Test.startTest();
        
        try {
            Account acc = new Account();
            insert acc;
        } catch (Exception e) {
            try {
                throw AuraExceptionHandler.handle(
                    e,
                    'TestClass',
                    'testMethod',
                    null
                );
            } catch (AuraHandledException auraEx) {
                // Le message doit être nettoyé
                String message = auraEx.getMessage();
                System.assertNotEquals(null, message);
                System.assert(!message.contains('Insert failed.'), 'Message should be cleaned');
            }
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testHandleNullContext() {
        Test.startTest();
        
        try {
            insert new Contact(); // Required fields missing
        } catch (Exception e) {
            try {
                throw AuraExceptionHandler.handle(
                    e,
                    'TestClass',
                    'testMethod',
                    null,
                    null,
                    null
                );
            } catch (AuraHandledException auraEx) {
                System.assertNotEquals(null, auraEx);
            }
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testDmlExceptionCleaning() {
        Test.startTest();
        
        try {
            // Force une DML exception avec message détaillé
            Account acc = new Account();
            insert acc;
        } catch (DmlException e) {
            try {
                throw AuraExceptionHandler.handle(
                    e,
                    'TestClass',
                    'testDml',
                    new Map<String, Object>{ 'test' => 'value' }
                );
            } catch (AuraHandledException auraEx) {
                String msg = auraEx.getMessage();
                System.assertNotEquals(null, msg);
                // Vérifier que le message est nettoyé
                System.assert(!msg.startsWith('Insert failed.'), 'DML message should be cleaned');
            }
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testMultipleExceptionTypes() {
        Test.startTest();
        
        // Test 1: NullPointerException
        try {
            String s = null;
            s.toLowerCase();
        } catch (Exception e) {
            try {
                throw AuraExceptionHandler.handle(e, 'Test', 'nullPointer', null);
            } catch (AuraHandledException auraEx) {
                System.assertNotEquals(null, auraEx);
            }
        }
        
        // Test 2: Exception with recordId and objectType
        try {
            insert new Opportunity(); // Required fields missing
        } catch (Exception e) {
            try {
                throw AuraExceptionHandler.handle(
                    e, 
                    'Test', 
                    'createOpp', 
                    new Map<String, Object>{ 'oppName' => 'test' },
                    '006xx000000abc1',
                    'Opportunity'
                );
            } catch (AuraHandledException auraEx) {
                System.assertNotEquals(null, auraEx);
            }
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testContextDataSerialization() {
        Test.startTest();
        
        try {
            insert new Contact();
        } catch (Exception e) {
            // Test avec contexte complexe
            Map<String, Object> complexContext = new Map<String, Object>{
                'string' => 'value',
                'number' => 123,
                'boolean' => true,
                'list' => new List<String>{ 'a', 'b' },
                'map' => new Map<String, Object>{ 'nested' => 'value' }
            };
            
            try {
                throw AuraExceptionHandler.handle(
                    e,
                    'TestClass',
                    'complexContext',
                    complexContext,
                    '003xx000000abc',
                    'Contact'
                );
            } catch (AuraHandledException auraEx) {
                System.assertNotEquals(null, auraEx);
            }
        }
        
        Test.stopTest();
    }
}
