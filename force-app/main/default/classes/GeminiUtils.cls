/**
 * @description Utility class for Gemini AI API operations
 * This class provides helper methods for interacting with the Gemini AI service
 */
public with sharing class GeminiUtils {
    /**
     * @description Retrieves a list of available Gemini AI models
     * Makes an HTTP GET request to the Gemini API to fetch available models
     * @return String JSON response containing available models or error message
     * @example
     * String models = GeminiUtils.listAvailableModels();
     * System.debug(models);
     */
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