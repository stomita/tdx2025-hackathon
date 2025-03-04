import { LightningElement, api, track, wire } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import getChartData from '@salesforce/apex/PieChartMetricController.getChartData';
import CHART_JS from '@salesforce/resourceUrl/ChartJS';

export default class PieChartMetric extends LightningElement {
    // Public properties that can be set by parent components
    @api title = 'Pie Chart Metric';
    @api objectName;
    @api groupByField;
    @api aggregateField;
    @api aggregateFunction = 'COUNT';
    @api filterConditions;
    @api maxSlices = 5;
    @api showLegend = false;
    @api height = '400px';
    @api width = '100%';
    @api colorPalette = 'default'; // default, pastel, bright, dark
    
    // Private properties
    @track isLoading = false;
    @track error;
    @track chartData;
    @track chartLabels = [];
    @track chartValues = [];
    @track chartColors = [];
    @track chartTotal = 0;
    
    // Chart instance
    chart;
    chartjsInitialized = false;
    
    // Color palettes
    defaultColors = [
        '#3366CC', '#DC3912', '#FF9900', '#109618', '#990099',
        '#3B3EAC', '#0099C6', '#DD4477', '#66AA00', '#B82E2E',
        '#316395', '#994499', '#22AA99', '#AAAA11', '#6633CC'
    ];
    
    pastelColors = [
        '#FFB3BA', '#FFDFBA', '#FFFFBA', '#BAFFC9', '#BAE1FF',
        '#FFC6FF', '#DCDCDC', '#C1E1C1', '#C4A484', '#B5EAD7',
        '#E2F0CB', '#FFDAC1', '#FF9AA2', '#B5B9FF', '#85E3FF'
    ];
    
    brightColors = [
        '#FF5733', '#33FF57', '#3357FF', '#FF33A8', '#33FFF5',
        '#FFD433', '#8C33FF', '#FF5733', '#33FF57', '#3357FF',
        '#FF33A8', '#33FFF5', '#FFD433', '#8C33FF', '#FF5733'
    ];
    
    darkColors = [
        '#1A237E', '#311B92', '#4A148C', '#880E4F', '#B71C1C',
        '#004D40', '#0D47A1', '#1B5E20', '#827717', '#E65100',
        '#212121', '#263238', '#3E2723', '#BF360C', '#01579B'
    ];
    
    // Lifecycle hooks
    connectedCallback() {
        // If all required properties are provided, fetch data automatically
        if (this.areRequiredPropertiesSet()) {
            this.loadChartJs();
        }
    }
    
    renderedCallback() {
        if (this.chartjsInitialized) {
            return;
        }
        this.loadChartJs();
    }
    
    // Public methods
    @api
    refresh() {
        if (this.areRequiredPropertiesSet()) {
            this.fetchChartData();
        } else {
            this.error = 'Required properties are not set. Please provide objectName, groupByField, and aggregateField.';
        }
    }
    
    // Private methods
    loadChartJs() {
        if (this.chartjsInitialized) {
            return;
        }
        
        this.isLoading = true;
        
        Promise.all([
            loadScript(this, CHART_JS + '/Chart.min.js')
        ])
        .then(() => {
            this.chartjsInitialized = true;
            // Now that ChartJS is loaded, fetch the data
            if (this.areRequiredPropertiesSet()) {
                this.fetchChartData();
            }
        })
        .catch(error => {
            this.error = 'Error loading ChartJS: ' + this.reduceErrors(error);
            this.isLoading = false;
        });
    }
    
    areRequiredPropertiesSet() {
        return this.objectName && this.groupByField && this.aggregateField;
    }
    
    fetchChartData() {
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
        
        getChartData({
            objectName: this.objectName,
            groupByField: this.groupByField,
            aggregateField: this.aggregateField,
            aggregateFunction: this.aggregateFunction,
            filterConditions: filterConditionsJson,
            maxSlices: this.maxSlices
        })
        .then(result => {
            this.processChartData(result);
            this.isLoading = false;
        })
        .catch(error => {
            this.error = 'Error retrieving chart data: ' + this.reduceErrors(error);
            this.chartData = undefined;
            this.chartLabels = [];
            this.chartValues = [];
            this.chartColors = [];
            this.chartTotal = 0;
            this.isLoading = false;
        });
    }
    
    processChartData(data) {
        if (!data || !data.labels || data.labels.length === 0) {
            this.chartData = undefined;
            this.chartLabels = [];
            this.chartValues = [];
            this.chartColors = [];
            this.chartTotal = 0;
            return;
        }
        
        this.chartData = data;
        this.chartLabels = data.labels;
        this.chartValues = data.values;
        this.chartTotal = data.total;
        
        // Generate colors based on the selected palette
        this.generateChartColors();
        
        // If chart is already initialized, update it
        if (this.chart) {
            this.updateChart();
        } else {
            // Otherwise, create a new chart
            this.createChart();
        }
    }
    
    generateChartColors() {
        let colorArray;
        
        switch (this.colorPalette) {
            case 'pastel':
                colorArray = this.pastelColors;
                break;
            case 'bright':
                colorArray = this.brightColors;
                break;
            case 'dark':
                colorArray = this.darkColors;
                break;
            default:
                colorArray = this.defaultColors;
        }
        
        // Generate colors for each slice
        this.chartColors = [];
        for (let i = 0; i < this.chartLabels.length; i++) {
            this.chartColors.push(colorArray[i % colorArray.length]);
        }
    }
    
    createChart() {
        const canvas = this.template.querySelector('canvas.pie-chart');
        if (!canvas) {
            return;
        }
        
        const ctx = canvas.getContext('2d');
        this.chart = new Chart(ctx, {
            type: 'pie',
            data: {
                labels: this.chartLabels,
                datasets: [{
                    data: this.chartValues,
                    backgroundColor: this.chartColors,
                    borderColor: 'white',
                    borderWidth: 1
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                legend: {
                    display: this.showLegend,
                    position: 'right',
                    labels: {
                        boxWidth: 12,
                        padding: 10
                    }
                },
                tooltips: {
                    callbacks: {
                        label: (tooltipItem, data) => {
                            const dataset = data.datasets[tooltipItem.datasetIndex];
                            const value = dataset.data[tooltipItem.index];
                            const label = data.labels[tooltipItem.index];
                            const percentage = ((value / this.chartTotal) * 100).toFixed(1);
                            return `${label}: ${this.formatValue(value)} (${percentage}%)`;
                        }
                    }
                }
            }
        });
    }
    
    updateChart() {
        if (!this.chart) {
            return;
        }
        
        this.chart.data.labels = this.chartLabels;
        this.chart.data.datasets[0].data = this.chartValues;
        this.chart.data.datasets[0].backgroundColor = this.chartColors;
        this.chart.options.legend.display = this.showLegend;
        
        this.chart.update();
    }
    
    formatValue(value) {
        if (value === null || value === undefined) {
            return '';
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
    get hasChartData() {
        return this.chartData && this.chartLabels.length > 0;
    }
    
    get showNoDataMessage() {
        return !this.isLoading && !this.error && !this.hasChartData && this.areRequiredPropertiesSet();
    }
    
    get containerStyle() {
        return `height: ${this.height}; width: ${this.width};`;
    }
    
    get formattedTotal() {
        return this.formatValue(this.chartTotal);
    }
}