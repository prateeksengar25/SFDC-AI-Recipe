public with sharing class GeminiUtils {
    @AuraEnabled
    public static String listAvailableModels() {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(GeminiConfig.getListModelsEndpoint());
            req.setMethod('GET');
            
            Map<String, String> headers = GeminiConfig.getAuthHeaders();
            for (String key : headers.keySet()) {
                req.setHeader(key, headers.get(key));
            }
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                return res.getBody();
            } else {
                return 'Error: ' + res.getStatusCode() + ' ' + res.getStatus() + '\nResponse: ' + res.getBody();
            }
        } catch (Exception e) {
            return 'Exception: ' + e.getMessage() + '\nStack Trace: ' + e.getStackTraceString();
        }
    }
} 