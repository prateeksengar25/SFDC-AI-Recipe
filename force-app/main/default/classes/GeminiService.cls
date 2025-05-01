/**
 * @description Service class for interacting with the Gemini API
 * Implements the Service layer of the Enterprise Design Pattern
 * Handles API calls and response processing
 */
public with sharing class GeminiService {
    /**
     * @description Response wrapper class for Gemini API calls
     */
    public class GeminiResponse {
        @AuraEnabled public String summary;
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Integer statusCode;
    }

    /**
     * @description Generates a summary of activities using the Gemini API
     * @param activities List of activities to summarize
     * @return GeminiResponse containing the summary or error information
     */
    public static GeminiResponse generateSummary(List<Activity> activities) {
        GeminiResponse response = new GeminiResponse();
        try {
            String prompt = createPrompt(activities);
            HttpRequest req = new HttpRequest();
            String endpoint = GeminiConfig.getModelEndpoint();
            System.debug('Endpoint: ' + endpoint);
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            
            Map<String, String> headers = GeminiConfig.getAuthHeaders();
            for (String key : headers.keySet()) {
                req.setHeader(key, headers.get(key));
            }
            
            String requestBody = JSON.serialize(new Map<String, Object>{
                'contents' => new List<Map<String, Object>>{
                    new Map<String, Object>{
                        'parts' => new List<Map<String, Object>>{
                            new Map<String, Object>{
                                'text' => prompt
                            }
                        }
                    }
                }
            });
            
            System.debug('Request Body: ' + requestBody);
            req.setBody(requestBody);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('Response Status: ' + res.getStatusCode());
            System.debug('Response Body: ' + res.getBody());
            
            response.statusCode = res.getStatusCode();
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                response.summary = extractSummary(responseMap);
                response.isSuccess = true;
            } else {
                response.isSuccess = false;
                response.errorMessage = 'Error: ' + res.getStatusCode() + ' ' + res.getStatus() + '\nResponse: ' + res.getBody();
                if (res.getStatusCode() == 401) {
                    response.errorMessage += ' - Authentication failed. Please check your API key configuration.';
                }
            }
        } catch (Exception e) {
            response.isSuccess = false;
            response.errorMessage = 'Exception: ' + e.getMessage() + '\nStack Trace: ' + e.getStackTraceString();
        }
        return response;
    }
    
    /**
     * @description Creates a prompt for the Gemini API based on activities
     * @param activities List of activities to include in the prompt
     * @return Formatted prompt string
     */
    private static String createPrompt(List<Activity> activities) {
        if (activities == null || activities.isEmpty()) {
            return 'No activities found for this account.';
        }
        
        String prompt = 'Please provide a concise summary of the following account activities. ' +
                       'Focus on key information and patterns. Format the response in a clear, ' +
                       'easy-to-read manner. Here are the activities:\n\n';
        
        for (Activity activity : activities) {
            prompt += 'Type: ' + activity.type + '\n';
            prompt += 'Subject: ' + activity.subject + '\n';
            prompt += 'Date: ' + activity.activityDate + '\n';
            prompt += 'Status: ' + activity.status + '\n';
            if (String.isNotBlank(activity.description)) {
                prompt += 'Description: ' + activity.description + '\n';
            }
            prompt += '---\n';
        }
        
        prompt += '\nPlease provide a comprehensive summary that highlights important patterns, ' +
                 'key interactions, and any notable information from these activities.';
        
        return prompt;
    }
    
    /**
     * @description Extracts the summary text from the Gemini API response
     * @param responseMap The parsed JSON response from the API
     * @return The extracted summary text or an error message
     */
    private static String extractSummary(Map<String, Object> responseMap) {
        if (responseMap == null) {
            return 'Unable to parse response from Gemini API';
        }
        
        if (responseMap.containsKey('candidates')) {
            List<Object> candidates = (List<Object>)responseMap.get('candidates');
            if (!candidates.isEmpty()) {
                Map<String, Object> candidate = (Map<String, Object>)candidates[0];
                Map<String, Object> content = (Map<String, Object>)candidate.get('content');
                List<Object> parts = (List<Object>)content.get('parts');
                if (!parts.isEmpty()) {
                    Map<String, Object> part = (Map<String, Object>)parts[0];
                    return (String)part.get('text');
                }
            }
        }
        return 'Unable to generate summary from response';
    }
} 