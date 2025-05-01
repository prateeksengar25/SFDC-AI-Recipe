/**
 * @description Selector class for retrieving activity-related records (Tasks, Events, and Emails)
 * Implements the Selector layer of the Enterprise Design Pattern
 */
public with sharing class ActivitySelector {
    /**
     * @description Retrieves recent Tasks associated with an Account
     * @param accountId The ID of the Account to get Tasks for
     * @param limitCount Maximum number of Tasks to retrieve
     * @return List of Task records ordered by CreatedDate descending
     */
    public static List<Task> getRecentTasks(Id accountId, Integer limitCount) {
        return [
            SELECT Subject, Description, Status, CreatedDate, What.Name 
            FROM Task 
            WHERE WhatId = :accountId 
            ORDER BY CreatedDate DESC 
            LIMIT :limitCount
        ];
    }
    
    /**
     * @description Retrieves recent Events associated with an Account
     * @param accountId The ID of the Account to get Events for
     * @param limitCount Maximum number of Events to retrieve
     * @return List of Event records ordered by CreatedDate descending
     */
    public static List<Event> getRecentEvents(Id accountId, Integer limitCount) {
        return [
            SELECT Subject, Description, ActivityDateTime, What.Name 
            FROM Event 
            WHERE WhatId = :accountId 
            ORDER BY CreatedDate DESC 
            LIMIT :limitCount
        ];
    }
    
    /**
     * @description Retrieves recent EmailMessages associated with an Account
     * @param accountId The ID of the Account to get Emails for
     * @param limitCount Maximum number of Emails to retrieve
     * @return List of EmailMessage records ordered by CreatedDate descending
     */
    public static List<EmailMessage> getRecentEmails(Id accountId, Integer limitCount) {
        return [
            SELECT Subject, TextBody, CreatedDate, RelatedTo.Name 
            FROM EmailMessage 
            WHERE RelatedToId = :accountId 
            ORDER BY CreatedDate DESC 
            LIMIT :limitCount
        ];
    }
} 