/**
 * @description Configuration class for Gemini AI API integration
 * This class manages API endpoints, authentication, and settings for the Gemini AI service
 */
public with sharing class GeminiConfig {
    /** @description Named credential for Gemini API authentication */
    private static final String NAMED_CREDENTIAL = 'Gemini_API';
    /** @description API version for Gemini endpoints */
    private static final String API_VERSION = 'v1';
    /** @description Name of the Gemini model to use */
    private static final String MODEL_NAME = 'gemini-1.5-flash';
    
    /**
     * @description Gets the base URL for Gemini API calls using named credential
     * @return String The base URL for API calls
     */
    public static String getBaseUrl() {
        return 'callout:' + NAMED_CREDENTIAL;
    }
    
    /**
     * @description Gets the endpoint URL for listing available Gemini models
     * @return String The complete endpoint URL for listing models
     * @throws AuraHandledException if Gemini API key is not configured
     */
    public static String getListModelsEndpoint() {
        Gemini_Settings__c settings = Gemini_Settings__c.getOrgDefaults();
        if (settings == null || String.isBlank(settings.API_Key__c)) {
            throw new AuraHandledException('Gemini API Key is not configured. Please contact your administrator.');
        }
        return getBaseUrl() + '/v1/models?key=' + settings.API_Key__c;
    }
    
    /**
     * @description Gets the endpoint URL for generating content with the specified model
     * @return String The complete endpoint URL for content generation
     * @throws AuraHandledException if Gemini API key is not configured
     */
    public static String getModelEndpoint() {
        Gemini_Settings__c settings = Gemini_Settings__c.getOrgDefaults();
        if (settings == null || String.isBlank(settings.API_Key__c)) {
            throw new AuraHandledException('Gemini API Key is not configured. Please contact your administrator.');
        }
        return getBaseUrl() + '/v1/models/' + MODEL_NAME + ':generateContent?key=' + settings.API_Key__c;
    }
    
    /**
     * @description Gets the authentication headers required for Gemini API calls
     * @return Map<String, String> Map containing required HTTP headers
     */
    public static Map<String, String> getAuthHeaders() {
        return new Map<String, String>{
            'Content-Type' => 'application/json'
        };
    }
} 