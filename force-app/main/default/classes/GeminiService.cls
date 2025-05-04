/**
 * @description Service class for interacting with the Gemini API
 * Implements the Service layer of the Enterprise Design Pattern
 * Handles only the API call mechanics
 */
public with sharing class GeminiService {
    /**
     * @description Makes a raw API call to Gemini AI
     * @param requestBody The complete request body to send to Gemini
     * @return Map<String, Object> containing the response status code and body
     * @throws AuraHandledException if the API call fails
     */
    @AuraEnabled
    public static Map<String, Object> callGeminiAPI(String requestBody) {
        try {
            HttpRequest req = new HttpRequest();
            String endpoint = GeminiConfig.getModelEndpoint();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            
            Map<String, String> headers = GeminiConfig.getAuthHeaders();
            for (String key : headers.keySet()) {
                req.setHeader(key, headers.get(key));
            }
            
            req.setBody(requestBody);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            return new Map<String, Object>{
                'statusCode' => res.getStatusCode(),
                'status' => res.getStatus(),
                'body' => res.getBody()
            };
        } catch (Exception e) {
            throw new AuraHandledException('Error calling Gemini API: ' + e.getMessage());
        }
    }
} 