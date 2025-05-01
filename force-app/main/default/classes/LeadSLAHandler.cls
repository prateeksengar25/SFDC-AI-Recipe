public with sharing class LeadSLAHandler {
    @AuraEnabled
    public static void updateOutreachStatus(Id leadId) {
        try {
            Lead leadToUpdate = new Lead(
                Id = leadId,
                Outreach_Performed__c = true
            );
            
            update leadToUpdate;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating outreach status: ' + e.getMessage());
        }
    }
} 