import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getRelatedAccounts from '@salesforce/apex/AccountRelationshipsController.getRelatedAccounts';

const COLUMNS = [
    {
        label: 'Account Name',
        fieldName: 'accountUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'accountName' }, target: '_self' },
        sortable: true,
        cellAttributes: { iconName: { fieldName: 'rowIcon' } }
    },
    { label: 'Industry',          fieldName: 'industry',      type: 'text',     sortable: true },
    { label: 'Employees',         fieldName: 'employeeCount', type: 'number',   sortable: true },
    {
        label: 'Lifetime Value',
        fieldName: 'lifetimeValue',
        type: 'currency',
        typeAttributes: { currencyCode: 'USD', minimumFractionDigits: 0, maximumFractionDigits: 0 },
        sortable: true,
        cellAttributes: { alignment: 'left' }
    },
    {
        label: 'Shared Contacts',
        fieldName: 'contactCount',
        type: 'number',
        sortable: true,
        cellAttributes: { alignment: 'left' }
    },
    {
        label: 'Relationship',
        fieldName: 'relationshipLabel',
        type: 'text',
        cellAttributes: {
            class: { fieldName: 'relationshipClass' }
        }
    }
];

export default class AccountRelationships extends NavigationMixin(LightningElement) {
    @api recordId;

    // Admin-configurable via App Builder
    @api maxItems = 10;
    @api sortBy = 'contactCount';

    columns = COLUMNS;
    relationships = [];
    error;
    isLoading = true;

    // Internal sort state (client-side column header clicks)
    _sortedBy = '';
    _sortDirection = 'asc';

    @wire(getRelatedAccounts, {
        accountId: '$recordId',
        maxItems: '$maxItems',
        sortBy: '$sortBy'
    })
    wiredRelationships({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.relationships = this._enrichRows(data);
            this.error = undefined;
        } else if (error) {
            this.error = error?.body?.message || 'An unexpected error occurred.';
            this.relationships = [];
        }
    }

    // ── Getters ──────────────────────────────────────────────────────────────

    get hasRelationships() {
        return this.relationships.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && this.relationships.length === 0 && !this.error;
    }

    get cardTitle() {
        const count = this.relationships.length;
        return `Account Relationships${count > 0 ? ` (${count})` : ''}`;
    }

    get sortByLabel() {
        return this.sortBy === 'contactCount' ? 'Shared Contacts' : 'Account Name';
    }

    // ── Event handlers ───────────────────────────────────────────────────────

    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this._sortedBy = fieldName;
        this._sortDirection = sortDirection;

        const sorted = [...this.relationships].sort((a, b) => {
            let valA = a[fieldName] ?? '';
            let valB = b[fieldName] ?? '';
            if (typeof valA === 'string') valA = valA.toLowerCase();
            if (typeof valB === 'string') valB = valB.toLowerCase();
            const factor = sortDirection === 'asc' ? 1 : -1;
            if (valA < valB) return -1 * factor;
            if (valA > valB) return  1 * factor;
            return 0;
        });

        this.relationships = sorted;
    }

    handleRowAction(event) {
        const accountId = event.detail.row.accountId;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: accountId, actionName: 'view' }
        });
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    _enrichRows(data) {
        return data.map(row => ({
            ...row,
            accountUrl: `/lightning/r/Account/${row.accountId}/view`,
            relationshipLabel: row.isDirect ? 'Direct' : 'Indirect',
            relationshipClass: row.isDirect
                ? 'slds-badge slds-badge_lightest relationship-direct'
                : 'slds-badge relationship-indirect',
            rowIcon: row.isDirect ? 'standard:account' : 'utility:connected_apps'
        }));
    }
}
