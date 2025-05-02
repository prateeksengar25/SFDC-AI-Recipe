import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import extractExpenseDetails from '@salesforce/apex/ExpenseExtractorController.extractExpenseDetails';
import createExpenseLineItems from '@salesforce/apex/ExpenseExtractorController.createExpenseLineItems';

export default class ExpenseExtractor extends LightningElement {
    @api recordId; // Expense Report record ID
    @track isLoading = false;
    @track error;
    @track extractedData;
    
    // Accepted file formats for upload
    acceptedFormats = ['.pdf', '.png', '.jpg', '.jpeg'];

    /**
     * Handles file upload completion
     * @param {Event} event - The upload finished event
     */
    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles.length > 0) {
            this.isLoading = true;
            this.error = null;
            
            // Create a simple object with just the required fields
            const params = {
                contentVersionId: uploadedFiles[0].contentVersionId,
                expenseReportId: this.recordId
            };
            
            console.log('Calling extractExpenseDetails with params:', JSON.stringify(params));
            
            // Call the Apex method with the parameters
            extractExpenseDetails({
                contentVersionId: params.contentVersionId,
                expenseReportId: params.expenseReportId
            })
                .then(result => {
                    console.log('extractExpenseDetails result:', result);
                    this.extractedData = result;
                    this.showToast('Success', 'Expense details extracted successfully', 'success');
                })
                .catch(error => {
                    console.error('Error in handleUploadFinished:', error);
                    this.error = error.body?.message || 'An error occurred while extracting expense details';
                    this.showToast('Error', this.error, 'error');
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }
    }

    /**
     * Handles acceptance of extracted data
     * Creates expense line items from the extracted data
     */
    async handleAccept() {
        try {
            this.isLoading = true;
            
            console.log('Starting handleAccept');
            console.log('Record ID:', this.recordId);
            console.log('Extracted Data:', JSON.stringify(this.extractedData));
            
            if (!this.extractedData || !this.recordId) {
                const errorMsg = 'Missing required data: ' + 
                    (!this.recordId ? 'recordId is missing. ' : '') +
                    (!this.extractedData ? 'extractedData is missing.' : '');
                console.error(errorMsg);
                this.showToast('Error', errorMsg, 'error');
                return;
            }

            // Create the parameters object
            const params = {
                expenseReportId: this.recordId,
                extractedData: this.extractedData
            };

            console.log('Parameters being sent to Apex:', JSON.stringify(params));

            // Call the Apex method with wrapped parameters
            const result = await createExpenseLineItems({ params: params });
            console.log('Result from createExpenseLineItems:', JSON.stringify(result));

            if (result && result.isSuccess) {
                this.showToast('Success', result.message || 'Expense line items created successfully', 'success');
                this.extractedData = null;
                // Refresh the view to show new line items
                this.dispatchEvent(new CustomEvent('refresh'));
            } else {
                const errorMsg = result?.errorMessage || 'Unknown error occurred';
                console.error('Error from createExpenseLineItems:', errorMsg);
                this.error = errorMsg;
                this.showToast('Error', this.error, 'error');
            }
        } catch (error) {
            console.error('Exception in handleAccept:', error);
            console.error('Error details:', JSON.stringify(error));
            this.error = error.body?.message || 'An error occurred while creating expense line items';
            this.showToast('Error', this.error, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Handles rejection of extracted data
     * Clears the extracted data from view
     */
    handleReject() {
        this.extractedData = null;
        this.showToast('Info', 'Expense details rejected', 'info');
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

    resetComponent() {
        this.extractedData = null;
        this.error = null;
    }
} 