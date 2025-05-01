public class ActivityWrapper {
    @AuraEnabled public String type;
    @AuraEnabled public String subject;
    @AuraEnabled public String description;
    @AuraEnabled public String status;
    @AuraEnabled public Datetime activityDate;
    @AuraEnabled public String relatedTo;
    
    public ActivityWrapper(String type, String subject, String description, String status, Datetime activityDate, String relatedTo) {
        this.type = type;
        this.subject = subject;
        this.description = description;
        this.status = status;
        this.activityDate = activityDate;
        this.relatedTo = relatedTo;
    }
} 