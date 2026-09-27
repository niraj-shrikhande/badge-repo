import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getRelatedDocuments from '@salesforce/apex/ProcessNavigatorController.getRelatedDocuments';

const ACTION = {
    CREATE_RECORD:         'Create_Record',
    UPDATE_RECORD:         'Update_Record',
    VIEW_RELATED_RECORDS:  'View_Related_Records',
    VIEW_DOCUMENTS:        'View_Documents',
    CREATE_TASK:           'Create_Task',
    CREATE_EVENT:          'Create_Event',
    LAUNCH_FLOW:           'Launch_Flow',
    VIEW_HIERARCHY:        'View_Hierarchy'
};

export default class ProcessStepModal extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;
    @api step;

    @track documents = [];
    @track docError;
    @track isSaving = false;

    // ── Wire for documents ────────────────────────────────────────────────────

    @wire(getRelatedDocuments, { recordId: '$recordId' })
    wiredDocs({ data, error }) {
        if (data) {
            this.documents = data;
            this.docError = undefined;
        } else if (error) {
            this.docError = error?.body?.message || 'Unable to load documents.';
        }
    }

    // ── Getters: action type flags ────────────────────────────────────────────

    get isCreateRecord()        { return this.step?.actionType === ACTION.CREATE_RECORD; }
    get isUpdateRecord()        { return this.step?.actionType === ACTION.UPDATE_RECORD; }
    get isViewRelatedRecords()  { return this.step?.actionType === ACTION.VIEW_RELATED_RECORDS; }
    get isViewDocuments()       { return this.step?.actionType === ACTION.VIEW_DOCUMENTS; }
    get isCreateTask()          { return this.step?.actionType === ACTION.CREATE_TASK; }
    get isCreateEvent()         { return this.step?.actionType === ACTION.CREATE_EVENT; }
    get isLaunchFlow()          { return this.step?.actionType === ACTION.LAUNCH_FLOW; }
    get isViewHierarchy()       { return this.step?.actionType === ACTION.VIEW_HIERARCHY; }

    get modalTitle() {
        return this.step?.label || 'Process Step';
    }

    get helpText() {
        return this.step?.helpText || '';
    }

    // Fields to display on the edit/view form — from Layout_Fields__c (comma-separated).
    // Returned as objects so the template can iterate and key each field; each is
    // rendered explicitly via lightning-input-field / lightning-output-field, which
    // (unlike lightning-record-form) guarantees the exact configured fields appear.
    get layoutFieldNames() {
        if (!this.step?.layoutFields) return [];
        return this.step.layoutFields
            .split(',')
            .map(f => f.trim())
            .filter(f => f.length > 0)
            .map(f => ({ fieldName: f }));
    }

    get hasLayoutFields() {
        return this.layoutFieldNames.length > 0;
    }

    get targetObject() {
        return this.step?.targetObjectApiName || this.objectApiName;
    }

    get hasDocuments() {
        return this.documents.length > 0;
    }

    get flowApiName() {
        return this.step?.flowApiName;
    }

    get flowInputVariables() {
        return [{ name: 'recordId', type: 'String', value: this.recordId }];
    }

    // ── Event handlers ────────────────────────────────────────────────────────

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleSaveSuccess() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: 'Record saved successfully.',
            variant: 'success'
        }));
        this._fireAction('record_saved');
    }

    handleSaveError(event) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error saving record',
            message: event.detail?.detail || 'An error occurred.',
            variant: 'error'
        }));
    }

    handleFlowStatusChange(event) {
        if (event.detail.status === 'FINISHED') {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Flow completed',
                message: this.step.label + ' completed successfully.',
                variant: 'success'
            }));
            this._fireAction('flow_finished');
        }
    }

    handleViewDocument(event) {
        const docId = event.currentTarget.dataset.docId;
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: { pageName: 'filePreview' },
            state: { selectedRecordId: docId }
        });
    }

    handleViewHierarchy() {
        this._fireAction(ACTION.VIEW_HIERARCHY);
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                actionName: 'view'
            }
        });
    }

    handleViewRelated() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                actionName: 'view'
            }
        });
        this._fireAction('navigate_related');
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    _fireAction(actionType) {
        this.dispatchEvent(new CustomEvent('action', {
            detail: { actionType, stepId: this.step?.stepId }
        }));
    }
}
