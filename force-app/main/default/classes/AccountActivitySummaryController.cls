/**
 * @description Controller class for the Account Activity Summary LWC
 * Coordinates between the UI, domain, and service layers
 */
public with sharing class AccountActivitySummaryController {
    private static final Integer ACTIVITY_LIMIT = 10;
    
    /**
     * @description Response wrapper class for activity summary
     */
    public class ActivitySummaryResponse {
        @AuraEnabled public String summary;
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Integer statusCode;
    }
    
    /**
     * @description Retrieves recent activities for an Account
     * @param accountId The ID of the Account to get activities for
     * @return List of Activity records sorted by date
     * @throws AuraHandledException if accountId is null or if there's an error fetching activities
     */
    @AuraEnabled
    public static List<Activity> getAccountActivities(Id accountId) {
        if (accountId == null) {
            throw new AuraHandledException('Account ID is required');
        }
        
        try {
            List<Activity> activities = new List<Activity>();
            
            // Get and process Tasks
            List<Task> tasks = ActivitySelector.getRecentTasks(accountId, ACTIVITY_LIMIT);
            activities.addAll(Activity.createFromTasks(tasks));
            
            // Get and process Events
            List<Event> events = ActivitySelector.getRecentEvents(accountId, ACTIVITY_LIMIT);
            activities.addAll(Activity.createFromEvents(events));
            
            // Get and process Emails
            List<EmailMessage> emails = ActivitySelector.getRecentEmails(accountId, ACTIVITY_LIMIT);
            activities.addAll(Activity.createFromEmails(emails));
            
            // Sort all activities by date
            return Activity.sortByDate(activities);
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching activities: ' + e.getMessage());
        }
    }
    
    /**
     * @description Generates a summary of account activities using the Gemini API
     * @param accountId The ID of the Account to summarize activities for
     * @return ActivitySummaryResponse containing the summary or error information
     */
    @AuraEnabled
    public static ActivitySummaryResponse generateActivitySummary(Id accountId) {
        ActivitySummaryResponse response = new ActivitySummaryResponse();
        
        if (accountId == null) {
            response.isSuccess = false;
            response.errorMessage = 'Account ID is required';
            return response;
        }
        
        try {
            List<Activity> activities = getAccountActivities(accountId);
            if (activities.isEmpty()) {
                response.isSuccess = true;
                response.summary = 'No activities found for this account.';
                return response;
            }
            
            // Create the prompt
            String prompt = createPrompt(activities);
            
            // Prepare the request body
            Map<String, Object> requestBody = new Map<String, Object>{
                'contents' => new List<Map<String, Object>>{
                    new Map<String, Object>{
                        'parts' => new List<Map<String, Object>>{
                            new Map<String, Object>{
                                'text' => prompt
                            }
                        }
                    }
                }
            };
            
            // Call Gemini API
            Map<String, Object> apiResponse = GeminiService.callGeminiAPI(JSON.serialize(requestBody));
            Integer statusCode = (Integer)apiResponse.get('statusCode');
            response.statusCode = statusCode;
            
            if (statusCode == 200) {
                String responseBody = (String)apiResponse.get('body');
                Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(responseBody);
                if (responseMap.containsKey('candidates')) {
                    List<Object> candidates = (List<Object>)responseMap.get('candidates');
                    if (!candidates.isEmpty()) {
                        Map<String, Object> candidate = (Map<String, Object>)candidates[0];
                        Map<String, Object> content = (Map<String, Object>)candidate.get('content');
                        List<Object> parts = (List<Object>)content.get('parts');
                        if (!parts.isEmpty()) {
                            Map<String, Object> part = (Map<String, Object>)parts[0];
                            response.summary = (String)part.get('text');
                            response.isSuccess = true;
                            return response;
                        }
                    }
                }
                response.isSuccess = false;
                response.errorMessage = 'Invalid response format from Gemini API';
            } else {
                response.isSuccess = false;
                response.errorMessage = 'Error: ' + statusCode + ' ' + apiResponse.get('status') + '\nResponse: ' + apiResponse.get('body');
                if (statusCode == 401) {
                    response.errorMessage += ' - Authentication failed. Please check your API key configuration.';
                }
            }
        } catch (Exception e) {
            response.isSuccess = false;
            response.errorMessage = 'Error generating summary: ' + e.getMessage();
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
} 