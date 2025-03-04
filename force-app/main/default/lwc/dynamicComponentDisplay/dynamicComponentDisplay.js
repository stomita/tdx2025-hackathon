import { LightningElement, track, api } from 'lwc';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

export default class DynamicComponentDisplay extends LightningElement {
    channelName = '/event/UIInstruction__e';
    subscription = null;
    
    // API properties
    @api maxDisplayCount = 1; // Default to 1 component displayed at a time
    
    // Array to store components to display
    @track displayComponents = [];
    
    // Getter for empty display components check
    get isDisplayEmpty() {
        return this.displayComponents.length === 0;
    }
    
    // Called when component is connected
    connectedCallback() {
        // Register error listener for platform events
        this.registerErrorListener();
        // Subscribe to platform event channel
        this.subscribeToChannel();
    }

    // Called when component is disconnected
    disconnectedCallback() {
        // Unsubscribe from channel
        this.unsubscribeFromChannel();
    }

    // Subscribe to platform event channel
    subscribeToChannel() {
        // Do nothing if already subscribed
        if (this.subscription) {
            return;
        }
        // Subscribe to channel
        subscribe(this.channelName, -1, (message) => {
            this.handleEvent(message);
        }).then(response => {
            // Save subscription info
            this.subscription = response;
            console.log('Successfully subscribed to channel: ' + this.channelName);
        });
    }

    // Unsubscribe from platform event channel
    unsubscribeFromChannel() {
        // Do nothing if not subscribed
        if (!this.subscription) {
            return;
        }
        // Unsubscribe from channel
        unsubscribe(this.subscription, (response) => {
            console.log('Successfully unsubscribed from channel: ' + this.channelName);
            this.subscription = null;
        });
    }

    // Register error listener for platform events
    registerErrorListener() {
        onError(error => {
            console.error('Received error from server: ', JSON.stringify(error));
        });
    }

    // Handle platform event
    handleEvent(message) {
        console.log('Received event: ', JSON.stringify(message));
        
        // Get event data
        const eventData = message.data.payload;
        const command = eventData.Command__c;
        const parameters = eventData.Parameters__c;
        const recordId = eventData.RecordId__c;
        
        console.log('Command: ' + command);
        console.log('Parameters: ' + parameters);
        console.log('RecordId: ' + recordId);
        
        // Execute action based on command
        switch (command) {
            case 'showAccountInfo':
                this.showAccountDetail(recordId);
                break;
            case 'showSalesTrendTable':
                this.showSalesTrendTable(parameters, recordId);
                break;
            case 'clearDisplay':
                this.clearDisplay();
                break;
            case 'setMaxDisplayCount':
                this.setMaxDisplayCount(parameters);
                break;
            // Add handlers for other commands here
            default:
                console.log('Unknown command: ' + command);
        }
    }
    
    // Show account detail component
    showAccountDetail(recordId) {
        if (!recordId) {
            console.error('Record ID is required for showAccountDetail command');
            return;
        }
        
        // Add account detail component to display array
        this.addComponentToDisplay({
            isAccountDetail: true,
            isSalesTrendTable: false,
            key: `account-${recordId}-${Date.now()}`,
            recordId: recordId
        });
    }
    
    // Show sales trend table component
    showSalesTrendTable(parameters, recordId) {
        let title = 'Sales Trend';
        let startDate = null;
        let endDate = null;
        
        // Parse parameters if available
        if (parameters) {
            try {
                const params = JSON.parse(parameters);
                title = params.title || title;
                startDate = params.startDate || null;
                endDate = params.endDate || null;
            } catch (error) {
                console.error('Error parsing parameters for showSalesTrendTable:', error);
            }
        }
        
        // Add sales trend table component to display array
        this.addComponentToDisplay({
            isAccountDetail: false,
            isSalesTrendTable: true,
            key: `sales-trend-${Date.now()}`,
            title: title,
            startDate: startDate,
            endDate: endDate,
            recordId: recordId // Optional, may be null
        });
    }
    
    // Add component to display array
    addComponentToDisplay(component) {
        // Add new component to end of array
        this.displayComponents = [...this.displayComponents, component];
        
        // Limit array to maxDisplayCount
        if (this.displayComponents.length > this.maxDisplayCount) {
            this.displayComponents = this.displayComponents.slice(this.displayComponents.length - this.maxDisplayCount);
        }
    }
    
    // Clear all displayed components
    clearDisplay() {
        this.displayComponents = [];
    }
    
    // Set maximum number of components to display
    setMaxDisplayCount(parameters) {
        let count = 1; // Default to 1
        
        if (parameters) {
            try {
                const params = JSON.parse(parameters);
                count = params.count || 1;
            } catch (error) {
                console.error('Error parsing parameters for setMaxDisplayCount:', error);
                // If parsing fails, try to use the raw value
                count = parseInt(parameters) || 1;
            }
        }
        
        // Ensure count is at least 1
        this.maxDisplayCount = Math.max(1, count);
        
        // Trim display components if needed
        if (this.displayComponents.length > this.maxDisplayCount) {
            this.displayComponents = this.displayComponents.slice(this.displayComponents.length - this.maxDisplayCount);
        }
    }
}