import { LightningElement, track } from 'lwc';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

export default class UiInstructionReceiver extends LightningElement {
    channelName = '/event/UIInstruction__e';
    subscription = null;
    
    // Track properties to display in UI
    @track lastEventReceived = {
        command: '',
        parameters: '',
        recordId: '',
        timestamp: ''
    };
    
    @track eventHistory = [];
    
    // Getter for empty history check
    get isHistoryEmpty() {
        return this.eventHistory.length === 0;
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
        
        // Update UI with received event data
        this.lastEventReceived = {
            command: command || '',
            parameters: parameters || '',
            recordId: recordId || '',
            timestamp: new Date().toLocaleString()
        };
        
        // Add to history (keep last 5 events)
        this.eventHistory.unshift({...this.lastEventReceived});
        if (this.eventHistory.length > 5) {
            this.eventHistory = this.eventHistory.slice(0, 5);
        }
        
        // Execute action based on command
        switch (command) {
            case 'showAccountInfo':
                this.handleShowAccountInfo(recordId);
                break;
            case 'setHeighlightThreshold':
                this.handleSetHeighlightThreshold(parameters);
                break;
            // Add handlers for other commands here
            default:
                console.log('Unknown command: ' + command);
        }
    }
    
    // Handle showAccountInfo command
    handleShowAccountInfo(recordId) {
        console.log('Showing account info for record: ' + recordId);
        
        // Dispatch custom event for Dynamic Interactions
        const showAccountEvent = new CustomEvent('showaccountinfo', {
            detail: {
                recordId: recordId
            }
        });
        
        // Dispatch the event
        this.dispatchEvent(showAccountEvent);
        console.log('Dispatched showaccountinfo event with recordId: ' + recordId);
    }
    
    // Handle setHeighlightThreshold command
    handleSetHeighlightThreshold(parameters) {
        console.log('Setting highlight threshold with parameters: ' + parameters);
        
        // Parse parameters (assuming it's a JSON string)
        let highlightThreshold = 0;
        try {
            if (parameters) {
                const params = JSON.parse(parameters);
                highlightThreshold = params.threshold || 0;
            }
        } catch (error) {
            console.error('Error parsing parameters: ', error);
            // If parsing fails, try to use the raw value
            highlightThreshold = parseFloat(parameters) || 0;
        }
        
        console.log('Highlight threshold value: ' + highlightThreshold);
        
        // Dispatch custom event for Dynamic Interactions
        const highlightEvent = new CustomEvent('changehighlightthreshold', {
            detail: {
                highlightThreshold: highlightThreshold
            }
        });
        
        // Dispatch the event
        this.dispatchEvent(highlightEvent);
        console.log('Dispatched changehighlightthreshold event with threshold: ' + highlightThreshold);
    }
    
    // Clear event history
    clearHistory() {
        this.eventHistory = [];
    }
}