public with sharing class GeminiConfig {
    private static final String NAMED_CREDENTIAL = 'Gemini_API';
    private static final String API_VERSION = 'v1';
    private static final String MODEL_NAME = 'gemini-1.5-flash';
    
    public static String getBaseUrl() {
        return 'callout:' + NAMED_CREDENTIAL;
    }
    
    public static String getListModelsEndpoint() {
        Gemini_Settings__c settings = Gemini_Settings__c.getOrgDefaults();
        if (settings == null || String.isBlank(settings.API_Key__c)) {
            throw new AuraHandledException('Gemini API Key is not configured. Please contact your administrator.');
        }
        return getBaseUrl() + '/v1/models?key=' + settings.API_Key__c;
    }
    
    public static String getModelEndpoint() {
        Gemini_Settings__c settings = Gemini_Settings__c.getOrgDefaults();
        if (settings == null || String.isBlank(settings.API_Key__c)) {
            throw new AuraHandledException('Gemini API Key is not configured. Please contact your administrator.');
        }
        return getBaseUrl() + '/v1/models/' + MODEL_NAME + ':generateContent?key=' + settings.API_Key__c;
    }
    
    public static Map<String, String> getAuthHeaders() {
        return new Map<String, String>{
            'Content-Type' => 'application/json'
        };
    }
} 