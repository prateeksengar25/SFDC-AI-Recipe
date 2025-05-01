import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import updateOutreachStatus from '@salesforce/apex/LeadSLAHandler.updateOutreachStatus';

// Lead fields
const LAST_INBOUND_FIELD = 'Lead.Last_Inbound_Date_Time__c';
const FIRST_QUALIFIED_FIELD = 'Lead.First_Qualified_Activity__c';
const OUTREACH_FIELD = 'Lead.Outreach_Performed__c';

export default class ProgressRings extends LightningElement {
    @api recordId;
    @track progressPercentage = 0;
    @track SLAMet = false;
    @track isOutreachPerformed = false;

    @wire(getRecord, { recordId: '$recordId', fields: [LAST_INBOUND_FIELD, FIRST_QUALIFIED_FIELD, OUTREACH_FIELD] })
    wiredLead({ error, data }) {
        console.log('Wire service triggered');
        if (data) {
            console.log('Lead data received:', JSON.stringify(data));
            this.calculateSLA(data);
        } else if (error) {
            console.error('Error loading lead data:', error);
        }
    }

    calculateSLA(data) {
        console.log('Starting SLA calculation');
        const lastInbound = getFieldValue(data, LAST_INBOUND_FIELD);
        const firstQualified = getFieldValue(data, FIRST_QUALIFIED_FIELD);
        this.isOutreachPerformed = getFieldValue(data, OUTREACH_FIELD);

        console.log('Field values:', {
            lastInbound,
            firstQualified,
            isOutreachPerformed: this.isOutreachPerformed
        });

        if (this.isOutreachPerformed) {
            console.log('Outreach already performed, SLA met');
            this.SLAMet = true;
            return;
        }

        if (lastInbound) {
            const lastInboundDate = new Date(lastInbound);
            const now = new Date();
            let timeDiff;

            console.log('Last Inbound Date:', lastInboundDate);
            console.log('Current Date:', now);

            if (firstQualified) {
                const firstQualifiedDate = new Date(firstQualified);
                console.log('First Qualified Date:', firstQualifiedDate);
                timeDiff = (firstQualifiedDate.getTime() - lastInboundDate.getTime()) / (1000 * 60); // Convert to minutes
                console.log('Time difference with First Qualified (minutes):', timeDiff);
                this.SLAMet = timeDiff <= 30;
                console.log('SLA Met (First Qualified):', this.SLAMet);
            } else {
                timeDiff = (now.getTime() - lastInboundDate.getTime()) / (1000 * 60); // Convert to minutes
                console.log('Time difference with Current Time (minutes):', timeDiff);
            }

            this.progressPercentage = Math.min((timeDiff / 30) * 100, 100);
            console.log('Final Progress Percentage:', this.progressPercentage);
            console.log('Current Ring State:', {
                showFirstRing: this.showFirstRing,
                showSecondRing: this.showSecondRing,
                showThirdRing: this.showThirdRing,
                SLAMet: this.SLAMet
            });
        } else {
            console.log('No Last Inbound Date available');
        }
    }

    get showFirstRing() {
        const result = this.progressPercentage >= 0 && 
               this.progressPercentage <= 74 && 
               !this.SLAMet;
        console.log('showFirstRing calculated:', result);
        return result;
    }

    get showSecondRing() {
        const result = this.progressPercentage >= 75 && 
               this.progressPercentage <= 99;
        console.log('showSecondRing calculated:', result);
        return result;
    }

    get showThirdRing() {
        const result = this.progressPercentage >= 100 && 
               !this.SLAMet;
        console.log('showThirdRing calculated:', result);
        return result;
    }

    get SLAMet() {
        return this.SLAMet;
    }

    handleProgressChange(event) {
        this.progressPercentage = parseInt(event.target.value, 10);
    }

    async handleOutreachConfirmation() {
        console.log('Outreach confirmation initiated');
        const result = await this.showConfirmationDialog();
        if (result) {
            try {
                console.log('Updating outreach status for lead:', this.recordId);
                await updateOutreachStatus({ leadId: this.recordId });
                this.isOutreachPerformed = true;
                this.SLAMet = true;
                console.log('Outreach status updated successfully');
                this.showToast('Success', 'Outreach status updated successfully', 'success');
            } catch (error) {
                console.error('Error updating outreach status:', error);
                this.showToast('Error', 'Failed to update outreach status', 'error');
            }
        } else {
            console.log('Outreach confirmation cancelled');
        }
    }

    showConfirmationDialog() {
        return new Promise((resolve) => {
            const result = window.confirm('Are you sure you want to confirm this outreach?');
            console.log('Confirmation dialog result:', result);
            resolve(result);
        });
    }

    showToast(title, message, variant) {
        console.log('Showing toast:', { title, message, variant });
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