import { LightningElement, api, track, wire } from 'lwc';
import getAggregateMetric from '@salesforce/apex/AggregateMetricController.getAggregateMetric';

export default class AggregateMetric extends LightningElement {
    // Public properties that can be set by parent components
    @api title = 'Metric';
    @api objectName;
    @api aggregateField;
    @api aggregateFunction = 'COUNT';
    @api filterConditions;
    @api icon = 'utility:metrics';
    @api iconSize = 'large';
    @api iconVariant = 'inverse';
    @api textColor = '#000000';
    @api backgroundColor = '#FFFFFF';
    @api borderColor;
    @api borderRadius = '8px';
    @api fontSize = '3rem';
    @api subtitleFontSize = '1rem';
    @api height = '200px';
    @api width = '100%';
    
    // Private properties
    @track isLoading = false;
    @track error;
    @track metricValue;
    @track formattedValue;
    
    // Lifecycle hooks
    connectedCallback() {
        // If all required properties are provided, fetch data automatically
        if (this.areRequiredPropertiesSet()) {
            this.fetchMetricData();
        }
    }
    
    // Public methods
    @api
    refresh() {
        if (this.areRequiredPropertiesSet()) {
            this.fetchMetricData();
        } else {
            this.error = 'Required properties are not set. Please provide objectName and aggregateField.';
        }
    }
    
    // Private methods
    areRequiredPropertiesSet() {
        return this.objectName && this.aggregateField;
    }
    
    fetchMetricData() {
        this.isLoading = true;
        this.error = undefined;
        
        // Prepare filter conditions if provided
        let filterConditionsJson = '[]';
        if (this.filterConditions) {
            if (typeof this.filterConditions === 'string') {
                // If filterConditions is already a JSON string, use it directly
                filterConditionsJson = this.filterConditions;
            } else {
                // If filterConditions is an object, convert it to JSON
                filterConditionsJson = JSON.stringify(this.filterConditions);
            }
        }
        
        getAggregateMetric({
            objectName: this.objectName,
            aggregateField: this.aggregateField,
            aggregateFunction: this.aggregateFunction,
            filterConditions: filterConditionsJson
        })
        .then(result => {
            this.metricValue = result.value;
            this.formattedValue = result.formattedValue;
            this.isLoading = false;
        })
        .catch(error => {
            this.error = 'Error retrieving metric data: ' + this.reduceErrors(error);
            this.metricValue = undefined;
            this.formattedValue = undefined;
            this.isLoading = false;
        });
    }
    
    reduceErrors(error) {
        if (!error) {
            return '';
        }
        
        // Custom error handling
        if (Array.isArray(error.body)) {
            return error.body.map(e => e.message).join(', ');
        } else if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        } else if (typeof error.message === 'string') {
            return error.message;
        } else if (typeof error === 'string') {
            return error;
        }
        
        return 'Unknown error';
    }
    
    // Getters
    get hasMetricData() {
        return this.metricValue !== undefined;
    }
    
    get showNoDataMessage() {
        return !this.isLoading && !this.error && !this.hasMetricData && this.areRequiredPropertiesSet();
    }
    
    get containerStyle() {
        let style = `height: ${this.height}; width: ${this.width}; background-color: ${this.backgroundColor}; border-radius: ${this.borderRadius};`;
        
        if (this.borderColor) {
            style += ` border: 1px solid ${this.borderColor};`;
        }
        
        return style;
    }
    
    get valueStyle() {
        return `color: ${this.textColor}; font-size: ${this.fontSize};`;
    }
    
    get subtitleStyle() {
        return `color: ${this.textColor}; font-size: ${this.subtitleFontSize};`;
    }
}