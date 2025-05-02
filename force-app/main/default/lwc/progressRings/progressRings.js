import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import updateOutreachStatus from '@salesforce/apex/LeadSLAHandler.updateOutreachStatus';

// Lead fields used for SLA calculation
const LAST_INBOUND_FIELD = 'Lead.Last_Inbound_Date_Time__c';
const FIRST_QUALIFIED_FIELD = 'Lead.First_Qualified_Activity__c';
const OUTREACH_FIELD = 'Lead.Outreach_Performed__c';

export default class ProgressRings extends LightningElement {
    // Record ID passed from the parent component
    @api recordId;
    
    // Tracked properties for the component state
    @track progressPercentage = 0;
    @track SLAMet = false;
    @track isOutreachPerformed = false;

    /**
     * Wire service to get Lead record data
     * Automatically updates when record changes
     */
    @wire(getRecord, { recordId: '$recordId', fields: [LAST_INBOUND_FIELD, FIRST_QUALIFIED_FIELD, OUTREACH_FIELD] })
    wiredLead({ error, data }) {
        if (data) {
            this.calculateSLA(data);
        } else if (error) {
            // Handle error loading lead data
            this.showToast('Error', 'Failed to load lead data', 'error');
        }
    }

    /**
     * Calculates SLA status and progress percentage based on:
     * - Last Inbound Date Time
     * - First Qualified Activity
     * - Outreach Performed status
     */
    calculateSLA(data) {
        // Get field values from the record
        const lastInbound = getFieldValue(data, LAST_INBOUND_FIELD);
        const firstQualified = getFieldValue(data, FIRST_QUALIFIED_FIELD);
        this.isOutreachPerformed = getFieldValue(data, OUTREACH_FIELD);

        // If outreach is already performed, SLA is met
        if (this.isOutreachPerformed) {
            this.SLAMet = true;
            return;
        }

        // Calculate time difference if Last Inbound Date exists
        if (lastInbound) {
            const lastInboundDate = new Date(lastInbound);
            const now = new Date();
            let timeDiff;

            if (firstQualified) {
                // Calculate time difference between First Qualified and Last Inbound
                const firstQualifiedDate = new Date(firstQualified);
                timeDiff = (firstQualifiedDate.getTime() - lastInboundDate.getTime()) / (1000 * 60); // Convert to minutes
                this.SLAMet = timeDiff <= 30; // SLA is met if time difference is 30 minutes or less
            } else {
                // Calculate time difference between current time and Last Inbound
                timeDiff = (now.getTime() - lastInboundDate.getTime()) / (1000 * 60); // Convert to minutes
            }

            // Calculate progress percentage (max 100%)
            this.progressPercentage = Math.min((timeDiff / 30) * 100, 100);
        }
    }

    /**
     * Determines if first ring should be shown
     * Shows when progress is 0-74% and SLA is not met
     */
    get showFirstRing() {
        return this.progressPercentage >= 0 && 
               this.progressPercentage <= 74 && 
               !this.SLAMet;
    }

    /**
     * Determines if second ring should be shown
     * Shows when progress is 75-99%
     */
    get showSecondRing() {
        return this.progressPercentage >= 75 && 
               this.progressPercentage <= 99;
    }

    /**
     * Determines if third ring should be shown
     * Shows when progress is 100% or more and SLA is not met
     */
    get showThirdRing() {
        return this.progressPercentage >= 100 && 
               !this.SLAMet;
    }

    /**
     * Handles the outreach confirmation process
     * Shows confirmation dialog and updates outreach status if confirmed
     */
    async handleOutreachConfirmation() {
        const result = await this.showConfirmationDialog();
        if (result) {
            try {
                await updateOutreachStatus({ leadId: this.recordId });
                this.isOutreachPerformed = true;
                this.SLAMet = true;
                this.showToast('Success', 'Outreach status updated successfully', 'success');
            } catch (error) {
                this.showToast('Error', 'Failed to update outreach status', 'error');
            }
        }
    }

    /**
     * Shows a confirmation dialog for outreach
     * @returns {Promise<boolean>} User's confirmation choice
     */
    showConfirmationDialog() {
        return new Promise((resolve) => {
            const result = window.confirm('Are you sure you want to confirm this outreach?');
            resolve(result);
        });
    }

    /**
     * Shows a toast message
     * @param {string} title - Toast title
     * @param {string} message - Toast message
     * @param {string} variant - Toast variant (success, error, warning, info)
     */
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    ////Logic to calculate the SLA based on Last_Inbound_Date_Time__c and First_Qualified_Activity__c
    //Response_Time__c (Number)
    //Outreach_Performed__c (Checkbox)

}