import { LightningElement, api, track, wire } from 'lwc';
import getMatrixData from '@salesforce/apex/MatrixDataTableController.getMatrixData';

export default class MatrixDataTable extends LightningElement {
    // Public properties that can be set by parent components
    @api title = 'Matrix Data Table';
    @api objectName;
    @api rowField;
    @api columnField;
    @api aggregateField;
    @api aggregateFunction = 'COUNT';
    @api rowDateGrouping;
    @api columnDateGrouping;
    
    // Private variable for filter conditions
    _filterConditions;
    
    // Getter and setter for filter conditions
    @api
    get filterConditions() {
        return this._filterConditions;
    }
    
    set filterConditions(value) {
        this._filterConditions = value;
        // Refresh matrix data when filter conditions change
        if (this.areRequiredPropertiesSet()) {
            this.fetchMatrixData();
        }
    }
    
    @api highlightThreshold; // Threshold value to highlight cells with values greater than or equal to this
    
    // Private properties
    @track isLoading = false;
    @track error;
    @track matrixData;
    @track matrixHeaders = [];
    @track matrixRows = [];
    @track selectedCell;

    // Lifecycle hooks
    connectedCallback() {
        // If all required properties are provided, fetch data automatically
        if (this.areRequiredPropertiesSet()) {
            this.fetchMatrixData();
        }
    }
    
    // Public methods
    @api
    refresh() {
        if (this.areRequiredPropertiesSet()) {
            this.fetchMatrixData();
        } else {
            this.error = 'Required properties are not set. Please provide objectName, rowField, columnField, and aggregateField.';
        }
    }
    
    // Private methods
    areRequiredPropertiesSet() {
        return this.objectName && this.rowField && this.columnField && this.aggregateField;
    }
    
    fetchMatrixData() {
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
        
        getMatrixData({
            objectName: this.objectName,
            rowField: this.rowField,
            columnField: this.columnField,
            aggregateField: this.aggregateField,
            aggregateFunction: this.aggregateFunction,
            rowDateGrouping: this.rowDateGrouping,
            columnDateGrouping: this.columnDateGrouping,
            filterConditions: filterConditionsJson
        })
        .then(result => {
            this.processMatrixData(result);
            this.isLoading = false;
        })
        .catch(error => {
            this.error = 'Error retrieving matrix data: ' + this.reduceErrors(error);
            this.matrixData = undefined;
            this.matrixHeaders = [];
            this.matrixRows = [];
            this.isLoading = false;
        });
    }
    
    processMatrixData(data) {
        if (!data || !data.matrixData || data.matrixData.length === 0) {
            this.matrixData = undefined;
            this.matrixHeaders = [];
            this.matrixRows = [];
            this.selectedCell = null;
            return;
        }
        
        this.matrixData = data.matrixData;
        
        // Process headers (first row of matrix data)
        const headerRow = this.matrixData[0];
        this.matrixHeaders = headerRow.map(header => header !== '' ? header : '');
        
        // Process data rows
        this.matrixRows = [];
        for (let i = 1; i < this.matrixData.length; i++) {
            const rowData = this.matrixData[i];
            const rowId = 'row-' + i;
            const cells = [];
            
            // Process each cell in the row
            for (let j = 0; j < rowData.length; j++) {
                const cellValue = rowData[j];
                const cellId = 'cell-' + i + '-' + j;
                const isHeader = j === 0;
                const label = isHeader ? 'Row Header' : this.matrixHeaders[j];
                const rowValue = rowData[0]; // First column is the row value
                const columnValue = isHeader ? '' : this.matrixHeaders[j]; // Column header
                
                // Determine cell class
                let cellClass = isHeader ? 'slds-cell-wrap' : 'slds-cell-wrap data-cell';
                
                // Check if cell value meets highlight threshold condition
                if (!isHeader &&
                    this.highlightThreshold &&
                    typeof cellValue === 'number' &&
                    cellValue >= Number(this.highlightThreshold)) {
                    cellClass += ' highlighted-cell';
                }
                
                cells.push({
                    id: cellId,
                    value: cellValue,
                    formattedValue: this.formatCellValue(cellValue, isHeader),
                    isHeader: isHeader,
                    label: label,
                    rowValue: rowValue,
                    columnValue: columnValue,
                    cellClass: cellClass
                });
            }
            
            this.matrixRows.push({
                id: rowId,
                cells: cells
            });
        }
    }
    
    handleCellClick(event) {
        // Get cell information
        const rowIndex = event.currentTarget.dataset.rowIndex;
        const cellIndex = event.currentTarget.dataset.cellIndex;
        const rowValue = event.currentTarget.dataset.rowValue;
        const columnValue = event.currentTarget.dataset.columnValue;
        const cellValue = this.matrixRows[rowIndex].cells[cellIndex].value;
        
        // Update selected cell
        if (this.selectedCell) {
            // Remove selected class from previously selected cell
            const prevRow = this.matrixRows[this.selectedCell.rowIndex];
            if (prevRow && prevRow.cells[this.selectedCell.cellIndex]) {
                prevRow.cells[this.selectedCell.cellIndex].cellClass = 'slds-cell-wrap data-cell';
            }
        }
        
        // Set new selected cell
        this.selectedCell = { rowIndex, cellIndex };
        this.matrixRows[rowIndex].cells[cellIndex].cellClass = 'slds-cell-wrap data-cell selected-cell';
        
        // Dispatch cell click event
        const cellClickEvent = new CustomEvent('cellclick', {
            detail: {
                rowValue,
                columnValue,
                cellValue,
                rowIndex,
                columnIndex: cellIndex,
                formattedValue: this.matrixRows[rowIndex].cells[cellIndex].formattedValue
            }
        });
        this.dispatchEvent(cellClickEvent);
    }
    
    formatCellValue(value, isHeader) {
        if (value === null || value === undefined) {
            return '';
        }
        
        if (isHeader) {
            return String(value);
        }
        
        // Format numeric values
        if (typeof value === 'number') {
            // If it's a whole number, don't show decimal places
            if (value % 1 === 0) {
                return value.toLocaleString();
            }
            // Otherwise, format with 2 decimal places
            return value.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
        }
        
        return String(value);
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
    get hasMatrixData() {
        return this.matrixData && this.matrixData.length > 0;
    }
    
    get showNoDataMessage() {
        return !this.isLoading && !this.error && !this.hasMatrixData && this.areRequiredPropertiesSet();
    }
    
    get getHeaderClass() {
        return 'slds-text-title_caps';
    }
}