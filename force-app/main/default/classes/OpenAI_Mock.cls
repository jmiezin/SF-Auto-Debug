@isTest
global class OpenAI_Mock implements HttpCalloutMock {
    global HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"choices":[{"message":{"role":"assistant","content":"Hello from mock!"}}]}');
        res.setStatusCode(200);
        return res;
    }
}