import { LightningElement, track, api } from 'lwc';

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
    
    // Highlight threshold property
    @api highlightThreshold;
    
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
        console.log('User seems curious about opportunities where the Type is "' + detail.rowValue + " and CloseDate in " + detail.columnValue);
        // Additional actions can be executed here if needed
    }
}