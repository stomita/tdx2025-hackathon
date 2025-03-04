import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';
import getAccountActivities from '@salesforce/apex/AccountActivityController.getAccountActivities';

export default class AccountActivityTimeline extends NavigationMixin(LightningElement) {
    @api recordId; // Account Id passed from parent component
    @track activities = [];
    @track error;
    @track isLoading = true;
    
    wiredActivitiesResult; // Store the wired result for refreshing
    
    /**
     * Wire the Apex method to get account activities
     */
    @wire(getAccountActivities, { accountId: '$recordId' })
    wiredActivities(result) {
        this.wiredActivitiesResult = result;
        this.isLoading = true;
        
        if (result.data) {
            this.activities = this.processActivities(result.data);
            this.error = undefined;
        } else if (result.error) {
            this.activities = [];
            this.error = 'Error loading activities: ' + result.error.body.message;
        }
        
        this.isLoading = false;
    }
    
    /**
     * Process the activities data to add UI-specific properties
     */
    processActivities(data) {
        return data.map(activity => {
            return {
                ...activity,
                isTask: activity.type === 'task',
                isEvent: activity.type === 'event',
                isEmail: activity.type === 'email',
                isHighPriority: activity.priority === 'High',
                formattedDate: this.formatDate(activity.activityDate),
                showDescription: false, // Default to not showing description
                detailsId: `activity-details-${activity.id}`,
                timelineItemClass: 'slds-timeline__item_expandable' // Default class
            };
        });
    }
    
    /**
     * Format the date for display
     */
    formatDate(dateValue) {
        if (!dateValue) return '';
        
        const options = {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        };
        
        // Use fixed locale 'en-US' instead of browser's locale
        return new Date(dateValue).toLocaleDateString('en-US', options);
    }
    
    /**
     * Handle click on an activity
     */
    handleActivityClick(event) {
        const activityId = event.currentTarget.dataset.id;
        
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: activityId,
                actionName: 'view'
            }
        });
    }
    
    /**
     * Toggle description visibility
     */
    toggleDescription(event) {
        event.preventDefault();
        event.stopPropagation();
        
        const activityId = event.currentTarget.dataset.id;
        
        this.activities = this.activities.map(activity => {
            if (activity.id === activityId) {
                const isExpanded = !activity.showDescription;
                return {
                    ...activity,
                    showDescription: isExpanded,
                    timelineItemClass: isExpanded
                        ? 'slds-timeline__item_expandable slds-is-open'
                        : 'slds-timeline__item_expandable'
                };
            }
            return activity;
        });
    }
    
    /**
     * Refresh the activities data
     */
    @api
    refreshActivities() {
        return refreshApex(this.wiredActivitiesResult);
    }
    
    /**
     * Check if there are activities to display
     */
    get hasActivities() {
        return this.activities && this.activities.length > 0;
    }
}