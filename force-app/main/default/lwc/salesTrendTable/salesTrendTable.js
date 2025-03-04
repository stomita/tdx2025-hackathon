import { LightningElement, api, track } from 'lwc';

export default class SalesTrendTable extends LightningElement {
    // Public properties
    @api title = 'Sales Trend';
    @api startDate;
    @api endDate;
    
    // Private properties
    @track filterConditions = [];
    
    // Lifecycle hooks
    connectedCallback() {
        this.updateFilterConditions();
    }
    
    // Getters
    get formattedStartDate() {
        return this.startDate ? this.formatDateString(this.startDate) : null;
    }
    
    get formattedEndDate() {
        return this.endDate ? this.formatDateString(this.endDate) : null;
    }
    
    get filterConditionsJson() {
        return JSON.stringify(this.filterConditions);
    }
    
    // Private methods
    updateFilterConditions() {
        const filters = [];
        
        // Add date range filter if both dates are provided
        if (this.startDate && this.endDate) {
            filters.push({
                fieldName: 'CloseDate',
                operator: '>=',
                value: this.formatDateString(this.startDate)
            });
            
            filters.push({
                fieldName: 'CloseDate',
                operator: '<=',
                value: this.formatDateString(this.endDate)
            });
        }
        
        this.filterConditions = filters;
    }
    
    // Format date string to YYYY-MM-DD format for SOQL
    formatDateString(dateStr) {
        if (!dateStr) return null;
        
        let date;
        if (typeof dateStr === 'string') {
            // Parse the date string
            date = new Date(dateStr);
        } else if (dateStr instanceof Date) {
            date = dateStr;
        } else {
            return null;
        }
        
        // Check if date is valid
        if (isNaN(date.getTime())) {
            return null;
        }
        
        // Format as YYYY-MM-DD
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        
        return `${year}-${month}-${day}`;
    }
    
    // Handle property changes
    @api
    set dateRange(value) {
        if (value) {
            try {
                const range = JSON.parse(value);
                this.startDate = range.startDate;
                this.endDate = range.endDate;
                this.updateFilterConditions();
            } catch (error) {
                console.error('Error parsing date range:', error);
            }
        }
    }
    
    get dateRange() {
        return JSON.stringify({
            startDate: this.startDate,
            endDate: this.endDate
        });
    }
}