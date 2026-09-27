import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getProcessForRecord from '@salesforce/apex/ProcessNavigatorController.getProcessForRecord';

export default class ProcessNavigator extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;
    @api componentTitle = 'Business Process';

    @track processData;
    @track activeStep;
    @track modalOpen = false;
    @track error;
    isLoading = true;

    @wire(getProcessForRecord, {
        recordId: '$recordId',
        objectApiName: '$objectApiName'
    })
    wiredProcess({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.processData = data;
            this.error = undefined;
        } else if (error) {
            this.error = error?.body?.message || 'Unable to load process configuration.';
            this.processData = undefined;
        }
    }

    // ── Getters ───────────────────────────────────────────────────────────────

    get hasProcess() {
        return !!this.processData;
    }

    get isEmpty() {
        return !this.isLoading && !this.processData && !this.error;
    }

    get isChevron() {
        return this.processData?.displayStyle === 'Chevron';
    }

    get isButton() {
        return this.processData?.displayStyle === 'Button';
    }

    get steps() {
        return this.processData?.steps || [];
    }

    get chevronSteps() {
        return this.steps.map((step, index) => ({
            ...step,
            chevronClass: this._chevronClass(index),
            isFirst: index === 0,
            isLast: index === this.steps.length - 1,
            iconName: step.iconName || 'utility:process'
        }));
    }

    get buttonSteps() {
        return this.steps.map(step => ({
            ...step,
            iconName: step.iconName || 'utility:process'
        }));
    }

    // ── Event handlers ────────────────────────────────────────────────────────

    handleStepClick(event) {
        const stepId = event.currentTarget.dataset.stepId;
        this.activeStep = this.steps.find(s => s.stepId === stepId);
        if (this.activeStep) {
            this.modalOpen = true;
        }
    }

    handleModalClose() {
        this.modalOpen = false;
        this.activeStep = undefined;
    }

    handleModalAction(event) {
        const { actionType, result } = event.detail;
        this.modalOpen = false;
        this.activeStep = undefined;

        if (actionType === 'View_Hierarchy') {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: this.recordId, actionName: 'view' }
            });
        }
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    _chevronClass(index) {
        const base = 'slds-path__item';
        // All steps render as "current" style — the modal drives action not stage state
        return base + ' slds-is-incomplete';
    }
}
