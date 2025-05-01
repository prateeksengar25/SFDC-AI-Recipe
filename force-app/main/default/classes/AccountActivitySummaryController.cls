/**
 * @description Controller class for the Account Activity Summary LWC
 * Coordinates between the UI, domain, and service layers
 */
public with sharing class AccountActivitySummaryController {
    private static final Integer ACTIVITY_LIMIT = 10;
    
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
     * @return GeminiResponse containing the summary or error information
     */
    @AuraEnabled
    public static GeminiService.GeminiResponse generateActivitySummary(Id accountId) {
        if (accountId == null) {
            GeminiService.GeminiResponse response = new GeminiService.GeminiResponse();
            response.isSuccess = false;
            response.errorMessage = 'Account ID is required';
            return response;
        }
        
        try {
            List<Activity> activities = getAccountActivities(accountId);
            if (activities.isEmpty()) {
                GeminiService.GeminiResponse response = new GeminiService.GeminiResponse();
                response.isSuccess = true;
                response.summary = 'No activities found for this account.';
                return response;
            }
            return GeminiService.generateSummary(activities);
        } catch (Exception e) {
            GeminiService.GeminiResponse response = new GeminiService.GeminiResponse();
            response.isSuccess = false;
            response.errorMessage = 'Error generating summary: ' + e.getMessage();
            return response;
        }
    }
} 