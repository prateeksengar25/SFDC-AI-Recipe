import { LightningElement, api, track } from 'lwc';
import generateActivitySummary from '@salesforce/apex/AccountActivitySummaryController.generateActivitySummary';

export default class AccountActivitySummary extends LightningElement {
    @api recordId;
    @track summary;
    @track error;
    @track isLoading = false;

    get hasNoContent() {
        return !this.summary && !this.error && !this.isLoading;
    }

    async handleSummarize() {
        if (!this.recordId) {
            this.error = 'Account ID is not available';
            return;
        }

        this.isLoading = true;
        this.error = null;
        this.summary = null;

        try {
            const result = await generateActivitySummary({ accountId: this.recordId });
            
            if (result.isSuccess) {
                this.summary = result.summary;
            } else {
                this.error = result.errorMessage || 'Failed to generate summary';
                if (result.statusCode === 401) {
                    this.error += '\nPlease check your OAuth configuration in the Named Credential settings.';
                }
            }
        } catch (error) {
            this.error = error.body?.message || 'An error occurred while generating the summary';
            console.error('Error generating summary:', error);
        } finally {
            this.isLoading = false;
        }
    }
} 