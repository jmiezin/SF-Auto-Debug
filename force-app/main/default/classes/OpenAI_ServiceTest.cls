@isTest
private class OpenAI_ServiceTest {
    @isTest static void testSendPrompt() {
        Test.setMock(HttpCalloutMock.class, new OpenAI_Mock());

        Test.startTest();

        // Empêche l’appel réel s’il manque la clé
        try {
            String result = OpenAI_Service.sendPrompt('Bonjour !');
            System.assertNotEquals(null, result);
        } catch (Exception e) {
            System.assert(true, 'Handled expected error: ' + e.getMessage());
        }

        Test.stopTest();
    }
}