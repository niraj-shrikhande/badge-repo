import { LightningElement, api, wire } from 'lwc';
import getClientPlanData from '@salesforce/apex/ClientPlanController.getClientPlanData';

export default class ClientPlan extends LightningElement {
    @api recordId;

    clientData;
    error;
    isLoading = true;

    @wire(getClientPlanData, { accountId: '$recordId' })
    wiredClientPlan({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.clientData = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.clientData = undefined;
        }
    }

    get hasOpportunities() {
        return this.clientData?.opportunities?.length > 0;
    }

    get hasEntitlements() {
        return this.clientData?.entitlements?.length > 0;
    }

    get hasGlobalPresence() {
        return this.clientData?.globalPresence?.length > 0;
    }

    get mapMarkers() {
        if (!this.clientData?.globalPresence) return [];
        return this.clientData.globalPresence.map(loc => {
            const marker = {
                location: {
                    Street: loc.street || '',
                    City: loc.city || '',
                    PostalCode: loc.postalCode || '',
                    Country: loc.country || ''
                },
                title: loc.name,
                description: loc.isHQ
                    ? '🏢 Corporate Headquarters'
                    : loc.isGrowthMarket
                        ? '📈 Growth Market'
                        : '📍 Regional Office'
            };
            if (loc.isHQ) {
                marker.mapIcon = {
                    path: 'M 0,0 C -2,-20 -10,-22 -10,-30 A 10,10 0 1,1 10,-30 C 10,-22 2,-20 0,0 z',
                    fillColor: '#032D60',
                    fillOpacity: 1,
                    strokeColor: '#ffffff',
                    strokeWeight: 2,
                    scale: 1.2
                };
            } else if (loc.isGrowthMarket) {
                marker.mapIcon = {
                    path: 'M 0,0 C -2,-20 -10,-22 -10,-30 A 10,10 0 1,1 10,-30 C 10,-22 2,-20 0,0 z',
                    fillColor: '#2e7d32',
                    fillOpacity: 1,
                    strokeColor: '#ffffff',
                    strokeWeight: 2,
                    scale: 1
                };
            } else {
                marker.mapIcon = {
                    path: 'M 0,0 C -2,-20 -10,-22 -10,-30 A 10,10 0 1,1 10,-30 C 10,-22 2,-20 0,0 z',
                    fillColor: '#706E6B',
                    fillOpacity: 1,
                    strokeColor: '#ffffff',
                    strokeWeight: 1.5,
                    scale: 0.9
                };
            }
            return marker;
        });
    }

    get growthMarketLocations() {
        return this.clientData?.globalPresence?.filter(l => l.isGrowthMarket) || [];
    }

    get billingAddress() {
        const a = this.clientData?.account;
        if (!a) return null;
        return [a.BillingStreet, a.BillingCity, a.BillingState, a.BillingPostalCode, a.BillingCountry]
            .filter(Boolean)
            .join(', ');
    }

    get formattedAnnualRevenue() {
        const rev = this.clientData?.account?.AnnualRevenue;
        if (!rev) return null;
        return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 }).format(rev);
    }

    get formattedPipelineTotal() {
        const total = this.clientData?.totalPipelineValue;
        if (!total) return '$0';
        return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 }).format(total);
    }

    get accountPhoneHref() {
        return `tel:${this.clientData?.account?.Phone}`;
    }

    get contactEmailHref() {
        return `mailto:${this.clientData?.primaryContact?.Email}`;
    }

    get contactPhoneHref() {
        return `tel:${this.clientData?.primaryContact?.Phone}`;
    }

    get contactMobileHref() {
        return `tel:${this.clientData?.primaryContact?.MobilePhone}`;
    }
}
