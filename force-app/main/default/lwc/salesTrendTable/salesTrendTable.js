import { LightningElement, api, track, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { createRecord } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import USER_ACTION_LOG_OBJECT from '@salesforce/schema/UserActionLog__c';
import ACTION_DETAILS_FIELD from '@salesforce/schema/UserActionLog__c.ActionDetails__c';
import USER_FIELD from '@salesforce/schema/UserActionLog__c.User__c';
import RELATED_RECORD_ID_FIELD from '@salesforce/schema/UserActionLog__c.RelatedRecordId__c';

export default class SalesTrendTable extends LightningElement {
    // Public properties
    @api title = 'Sales Trend';
    @api startDate;
    @api endDate;
    @api highlightThreshold;
    @api recordId;
    
    // Private properties
    @track filterConditions = [];
    userId = USER_ID;
    
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

    // Event handlers
    handleCellClick(event) {
        // Get the details from the cell click event
        const { rowValue, columnValue, cellValue, formattedValue } = event.detail;
        
        // Create action details as natural language text in English
        const actionDetails = `User clicked on a cell in SalesTrendTable. Opportunity Type: ${rowValue}, Year and Month: ${columnValue}, Amount: ${formattedValue}`;
        
        // Log the user action
        this.logUserAction(actionDetails);
    }
    
    // Helper methods
    logUserAction(actionDetails) {
        // Create a record
        const fields = {};
        fields[ACTION_DETAILS_FIELD.fieldApiName] = actionDetails;
        fields[USER_FIELD.fieldApiName] = this.userId;
        
        // If we have a record ID (e.g., from a record page), include it
        if (this.recordId) {
            fields[RELATED_RECORD_ID_FIELD.fieldApiName] = this.recordId;
        }
        
        const recordInput = {
            apiName: USER_ACTION_LOG_OBJECT.objectApiName,
            fields
        };
        
        createRecord(recordInput)
            .then(() => {
                console.log('User action logged successfully');
            })
            .catch(error => {
                console.error('Error logging user action', error);
            });
    }
}