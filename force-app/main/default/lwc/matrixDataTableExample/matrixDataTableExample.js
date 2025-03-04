import { LightningElement, track, wire } from 'lwc';
import getObjectOptions from '@salesforce/apex/MatrixDataTableController.getObjectOptions';
import getFieldOptions from '@salesforce/apex/MatrixDataTableController.getFieldOptions';

export default class MatrixDataTableExample extends LightningElement {
    // Properties for object and field selection
    @track objectOptions = [];
    @track fieldOptions = [];
    @track aggregateFieldOptions = [];
    
    // Selected values
    @track selectedObject;
    @track selectedRowField;
    @track selectedColumnField;
    @track selectedAggregateField;
    @track selectedAggregateFunction = 'COUNT';
    @track selectedRowDateGrouping;
    @track selectedColumnDateGrouping;
    @track highlightThreshold = null;
    
    // Filter conditions
    @track filterConditions = [];
    @track nextFilterId = 0;
    
    // UI state
    @track isLoading = false;
    @track error;
    
    // Constants
    dateGroupingOptions = [
        { label: 'Day', value: 'DAY' },
        { label: 'Month', value: 'MONTH' },
        { label: 'Year', value: 'YEAR' }
    ];
    
    aggregateFunctionOptions = [
        { label: 'Count', value: 'COUNT' },
        { label: 'Sum', value: 'SUM' },
        { label: 'Average', value: 'AVG' },
        { label: 'Minimum', value: 'MIN' },
        { label: 'Maximum', value: 'MAX' }
    ];
    
    operatorOptions = [
        { label: 'Equals', value: '=' },
        { label: 'Not Equals', value: '!=' },
        { label: 'Less Than', value: '<' },
        { label: 'Greater Than', value: '>' },
        { label: 'Less or Equal', value: '<=' },
        { label: 'Greater or Equal', value: '>=' },
        { label: 'Contains', value: 'LIKE' },
        { label: 'In', value: 'IN' },
        { label: 'Not In', value: 'NOT IN' }
    ];
    
    // Wire methods
    @wire(getObjectOptions)
    wiredObjectOptions({ error, data }) {
        if (data) {
            const options = [];
            for (const [value, label] of Object.entries(data)) {
                options.push({ label, value });
            }
            this.objectOptions = options.sort((a, b) => a.label.localeCompare(b.label));
            this.error = undefined;
        } else if (error) {
            this.error = 'Error loading objects: ' + this.reduceErrors(error);
            this.objectOptions = [];
        }
    }
    
    // Event handlers
    handleObjectChange(event) {
        this.selectedObject = event.detail.value;
        this.selectedRowField = undefined;
        this.selectedColumnField = undefined;
        this.selectedAggregateField = undefined;
        this.selectedRowDateGrouping = undefined;
        this.selectedColumnDateGrouping = undefined;
        this.filterConditions = [];
        
        // Load fields for the selected object
        this.loadFieldOptions();
    }
    
    handleRowFieldChange(event) {
        this.selectedRowField = event.detail.value;
        this.selectedRowDateGrouping = undefined;
        
        // Check if the selected field is a date field
        this.checkDateField('row');
    }
    
    handleColumnFieldChange(event) {
        this.selectedColumnField = event.detail.value;
        this.selectedColumnDateGrouping = undefined;
        
        // Check if the selected field is a date field
        this.checkDateField('column');
    }
    
    handleAggregateFieldChange(event) {
        this.selectedAggregateField = event.detail.value;
    }
    
    handleAggregateFunctionChange(event) {
        this.selectedAggregateFunction = event.detail.value;
    }
    
    handleRowDateGroupingChange(event) {
        this.selectedRowDateGrouping = event.detail.value;
    }
    
    handleColumnDateGroupingChange(event) {
        this.selectedColumnDateGrouping = event.detail.value;
    }
    
    handleHighlightThresholdChange(event) {
        this.highlightThreshold = event.detail.value;
    }
    
    handleAddFilter() {
        const newFilter = {
            id: 'filter-' + this.nextFilterId++,
            fieldName: '',
            operator: '=',
            value: ''
        };
        
        this.filterConditions = [...this.filterConditions, newFilter];
    }
    
    handleRemoveFilter(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        this.filterConditions = this.filterConditions.filter((_, i) => i !== index);
    }
    
    handleFilterFieldChange(event) {
        const index = parseInt(event.target.dataset.index, 10);
        const fieldName = event.detail.value;
        
        this.filterConditions = this.filterConditions.map((filter, i) => {
            if (i === index) {
                return { ...filter, fieldName };
            }
            return filter;
        });
    }
    
    handleFilterOperatorChange(event) {
        const index = parseInt(event.target.dataset.index, 10);
        const operator = event.detail.value;
        
        this.filterConditions = this.filterConditions.map((filter, i) => {
            if (i === index) {
                return { ...filter, operator };
            }
            return filter;
        });
    }
    
    handleFilterValueChange(event) {
        const index = parseInt(event.target.dataset.index, 10);
        const value = event.detail.value;
        
        this.filterConditions = this.filterConditions.map((filter, i) => {
            if (i === index) {
                return { ...filter, value };
            }
            return filter;
        });
    }
    
    handleGetData() {
        // Find the matrix data table component and refresh it
        const matrixTable = this.template.querySelector('c-matrix-data-table');
        if (matrixTable) {
            matrixTable.refresh();
        }
    }
    
    // Helper methods
    loadFieldOptions() {
        if (!this.selectedObject) {
            this.fieldOptions = [];
            this.aggregateFieldOptions = [];
            return;
        }
        
        this.isLoading = true;
        
        getFieldOptions({ objectName: this.selectedObject })
            .then(result => {
                const options = [];
                const aggregateOptions = [];
                
                result.forEach(field => {
                    const option = {
                        label: field.label,
                        value: field.apiName,
                        dataType: field.dataType
                    };
                    
                    options.push(option);
                    
                    // Only numeric fields can be used with SUM and AVG
                    if (field.dataType === 'DOUBLE' || 
                        field.dataType === 'CURRENCY' || 
                        field.dataType === 'INTEGER' || 
                        field.dataType === 'LONG' || 
                        field.dataType === 'PERCENT') {
                        aggregateOptions.push(option);
                    }
                });
                
                this.fieldOptions = options.sort((a, b) => a.label.localeCompare(b.label));
                this.aggregateFieldOptions = aggregateOptions.sort((a, b) => a.label.localeCompare(b.label));
                this.error = undefined;
            })
            .catch(error => {
                this.error = 'Error loading fields: ' + this.reduceErrors(error);
                this.fieldOptions = [];
                this.aggregateFieldOptions = [];
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    checkDateField(fieldType) {
        if (fieldType === 'row' && this.selectedRowField) {
            const field = this.fieldOptions.find(f => f.value === this.selectedRowField);
            if (field && field.dataType === 'DATE') {
                this.selectedRowDateGrouping = 'MONTH'; // Default to month
            }
        } else if (fieldType === 'column' && this.selectedColumnField) {
            const field = this.fieldOptions.find(f => f.value === this.selectedColumnField);
            if (field && field.dataType === 'DATE') {
                this.selectedColumnDateGrouping = 'MONTH'; // Default to month
            }
        }
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
    get isFieldSelectionDisabled() {
        return !this.selectedObject;
    }
    
    get showRowDateGrouping() {
        if (!this.selectedRowField) return false;
        
        const field = this.fieldOptions.find(f => f.value === this.selectedRowField);
        return field && field.dataType === 'DATE';
    }
    
    get showColumnDateGrouping() {
        if (!this.selectedColumnField) return false;
        
        const field = this.fieldOptions.find(f => f.value === this.selectedColumnField);
        return field && field.dataType === 'DATE';
    }
    
    get isGetDataDisabled() {
        return !this.selectedObject || 
               !this.selectedRowField || 
               !this.selectedColumnField || 
               !this.selectedAggregateField;
    }
    
    get hasFilters() {
        return this.filterConditions.length > 0;
    }
    
    get matrixTitle() {
        if (!this.selectedObject) return 'Matrix Data Table';
        
        let title = this.selectedObject;
        
        if (this.selectedAggregateFunction && this.selectedAggregateField) {
            const field = this.fieldOptions.find(f => f.value === this.selectedAggregateField);
            if (field) {
                title += ' - ' + this.selectedAggregateFunction + ' of ' + field.label;
            }
        }
        
        return title;
    }
    
    get filterConditionsJson() {
        // Convert filter conditions to the format expected by the Apex controller
        const validFilters = this.filterConditions.filter(
            filter => filter.fieldName && filter.operator && filter.value
        );
        
        if (validFilters.length === 0) {
            return '[]';
        }
        
        return JSON.stringify(validFilters);
    }
}