import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
import attachClientPlanPDF from '@salesforce/apex/ClientPlanAttachController.attachClientPlanPDF';

const STATE = { IDLE: 'idle', LOADING: 'loading', SUCCESS: 'success', ERROR: 'error' };

export default class GenerateClientPlanPDF extends NavigationMixin(LightningElement) {
    @api recordId;

    state = STATE.IDLE;
    contentDocumentId;
    errorMessage;

    get isIdle()    { return this.state === STATE.IDLE; }
    get isLoading() { return this.state === STATE.LOADING; }
    get isSuccess() { return this.state === STATE.SUCCESS; }
    get isError()   { return this.state === STATE.ERROR; }

    async handleGenerate() {
        this.state = STATE.LOADING;
        try {
            this.contentDocumentId = await attachClientPlanPDF({ accountId: this.recordId });
            this.state = STATE.SUCCESS;
        } catch (e) {
            this.errorMessage = e?.body?.message || 'An unexpected error occurred. Please try again.';
            this.state = STATE.ERROR;
        }
    }

    handleViewFile() {
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: { pageName: 'filePreview' },
            state: {
                recordIds: this.contentDocumentId,
                selectedRecordId: this.contentDocumentId
            }
        });
        this.handleCancel();
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}
