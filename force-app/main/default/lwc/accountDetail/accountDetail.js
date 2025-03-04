import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

// Account fields for map
const ACCOUNT_FIELDS = [
    'Account.Name',
    'Account.BillingStreet',
    'Account.BillingCity',
    'Account.BillingState',
    'Account.BillingPostalCode',
    'Account.BillingCountry'
];

export default class AccountDetail extends LightningElement {
    @api recordId;
    
    // Wire service to get account record for map
    @wire(getRecord, { recordId: '$recordId', fields: ACCOUNT_FIELDS })
    account;
    
    // Filter conditions for opportunity pie chart
    get opportunityTypeChartFilters() {
        return JSON.stringify([
            { fieldName: 'AccountId', operator: '=', value: this.recordId }
        ]);
    }
    
    // Filter conditions for revenue won metric
    get revenueWonFilters() {
        return JSON.stringify([
            { fieldName: 'AccountId', operator: '=', value: this.recordId },
            { fieldName: 'IsWon', operator: '=', value: 'true' }
        ]);
    }
    
    // Filter conditions for pipeline metric
    get pipelineFilters() {
        return JSON.stringify([
            { fieldName: 'AccountId', operator: '=', value: this.recordId },
            { fieldName: 'IsClosed', operator: '=', value: 'false' }
        ]);
    }
    
    // Get account name for display
    get accountName() {
        if (!this.account || !this.account.data) {
            return 'Account Details';
        }
        
        const fields = this.account.data.fields;
        return fields.Name ? fields.Name.value : 'Account Details';
    }
    
    // Map markers for lightning-map
    get mapMarkers() {
        if (!this.account || !this.account.data) {
            return [];
        }
        
        const fields = this.account.data.fields;
        
        // Check if billing address fields exist
        if (!fields.BillingStreet || !fields.BillingStreet.value) {
            return [];
        }
        
        return [
            {
                location: {
                    Street: fields.BillingStreet.value,
                    City: fields.BillingCity.value,
                    State: fields.BillingState.value,
                    PostalCode: fields.BillingPostalCode.value,
                    Country: fields.BillingCountry.value
                },
                title: fields.Name.value,
                description: `${fields.BillingStreet.value}, ${fields.BillingCity.value}, ${fields.BillingState.value}`
            }
        ];
    }
}