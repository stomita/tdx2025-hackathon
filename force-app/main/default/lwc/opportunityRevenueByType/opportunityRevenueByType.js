import { LightningElement, track } from 'lwc';

export default class OpportunityRevenueByType extends LightningElement {
    // Title
    title = 'Opportunity Revenue by Type (Monthly)';
    
    // Matrix table configuration
    objectName = 'Opportunity';
    rowField = 'Type';
    columnField = 'CloseDate';
    aggregateField = 'Amount';
    aggregateFunction = 'SUM';
    columnDateGrouping = 'MONTH';
    
    // Filter condition for IsWon = true
    @track filterConditions = [
        {
            fieldName: 'IsWon',
            operator: '=',
            value: 'true'
        }
    ];
    
    // Convert filter conditions to JSON string
    get filterConditionsJson() {
        return JSON.stringify(this.filterConditions);
    }
    
    // Event handler for cell click
    handleCellClick(event) {
        const detail = event.detail;
        console.log('Cell clicked:', JSON.stringify(detail));
        // Additional actions can be executed here if needed
    }
}