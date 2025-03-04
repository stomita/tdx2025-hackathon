/**
 * Controller class for retrieving account activity history
 */
public with sharing class AccountActivityController {
    
    /**
     * Get activity history for a specific account
     * @param accountId The ID of the account to retrieve activities for
     * @return List of activity wrapper objects
     */
    @AuraEnabled(cacheable=true)
    public static List<ActivityWrapper> getAccountActivities(Id accountId) {
        List<ActivityWrapper> activities = new List<ActivityWrapper>();
        
        // Get Tasks related to the account
        for (Task task : [
            SELECT Id, Subject, Description, ActivityDate, Status, Priority,
                   CreatedDate, LastModifiedDate, Owner.Name, WhatId
            FROM Task
            WHERE AccountId = :accountId
            ORDER BY ActivityDate DESC, CreatedDate DESC
        ]) {
            activities.add(new ActivityWrapper(
                task.Id,
                'task',
                task.Subject,
                task.Description,
                task.ActivityDate,
                task.Status,
                task.Priority,
                task.Owner.Name,
                task.CreatedDate
            ));
        }
        
        // Get Events related to the account
        for (Event event : [
            SELECT Id, Subject, Description, ActivityDate, StartDateTime, EndDateTime,
                   CreatedDate, LastModifiedDate, Owner.Name, WhatId
            FROM Event
            WHERE AccountId = :accountId
            ORDER BY ActivityDate DESC, CreatedDate DESC
        ]) {
            activities.add(new ActivityWrapper(
                event.Id,
                'event',
                event.Subject,
                event.Description,
                event.ActivityDate,
                'Completed',
                'Normal',
                event.Owner.Name,
                event.CreatedDate
            ));
        }
        
        // Get EmailMessage related to the account
        for (EmailMessage email : [
            SELECT Id, Subject, TextBody, MessageDate, Status, CreatedDate,
                   LastModifiedDate, FromName, ToAddress
            FROM EmailMessage
            WHERE RelatedToId = :accountId
            ORDER BY MessageDate DESC, CreatedDate DESC
        ]) {
            activities.add(new ActivityWrapper(
                email.Id,
                'email',
                email.Subject,
                email.TextBody,
                Date.valueOf(email.MessageDate),
                email.Status,
                'Normal',
                email.FromName,
                email.CreatedDate
            ));
        }
        
        // Sort all activities by date
        activities.sort();
        
        return activities;
    }
    
    /**
     * Wrapper class for different types of activities
     */
    public class ActivityWrapper implements Comparable {
        @AuraEnabled public String id;
        @AuraEnabled public String type;
        @AuraEnabled public String title;
        @AuraEnabled public String description;
        @AuraEnabled public Date activityDate;
        @AuraEnabled public String status;
        @AuraEnabled public String priority;
        @AuraEnabled public String owner;
        @AuraEnabled public Datetime createdDate;
        
        public ActivityWrapper(
            String id, 
            String type, 
            String title, 
            String description, 
            Date activityDate, 
            String status, 
            String priority, 
            String owner, 
            Datetime createdDate
        ) {
            this.id = id;
            this.type = type;
            this.title = title;
            this.description = description;
            this.activityDate = activityDate;
            this.status = status;
            this.priority = priority;
            this.owner = owner;
            this.createdDate = createdDate;
        }
        
        /**
         * Compare activities for sorting
         */
        public Integer compareTo(Object compareTo) {
            ActivityWrapper compareToActivity = (ActivityWrapper)compareTo;
            
            // First compare by activity date
            if (activityDate > compareToActivity.activityDate) {
                return -1;
            } else if (activityDate < compareToActivity.activityDate) {
                return 1;
            }
            
            // If activity dates are the same, compare by created date
            if (createdDate > compareToActivity.createdDate) {
                return -1;
            } else if (createdDate < compareToActivity.createdDate) {
                return 1;
            }
            
            return 0;
        }
    }
}