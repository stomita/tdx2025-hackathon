public with sharing class GetLatestUserActionLogsAction {
    public class ActionLogRequest {
        @InvocableVariable(
            label='Limit'
            description='Number of recent logs to retrieve (default: 10)'
            required=false
        )
        public Integer limitCount;
    }
    
    public class ActionLogResponse {
        @InvocableVariable(
            label='Success'
            description='Whether the operation was successful'
        )
        public Boolean success;
        
        @InvocableVariable(
            label='Message'
            description='Status message or error details'
        )
        public String message;
        
        @InvocableVariable(
            label='User Action Logs'
            description='Formatted text of user action logs'
        )
        public String formattedLogs;
    }
    
    @InvocableMethod(
        label='Get Latest User Action Logs'
        description='Retrieves the most recent user action logs for the current user'
    )
    public static List<ActionLogResponse> getLatestUserActionLogs(
        List<ActionLogRequest> requests
    ) {
        ActionLogResponse response = new ActionLogResponse();
        response.success = true;
        
        try {
            if (requests.size() > 1) {
                System.debug('Currently only one request per action (bulkification is not supported)');
            }
            
            ActionLogRequest request = requests[0];
            Integer limitCount = (request.limitCount != null) ? request.limitCount : 10;
            
            // Get current user ID
            Id currentUserId = UserInfo.getUserId();
            
            // Calculate timestamp for 3 minutes ago
            Datetime threeMinutesAgo = Datetime.now().addMinutes(-3);
            
            // Build the query to get only current user's logs from the last 3 minutes
            String query = 'SELECT Id, ActionDetails__c, ActionTimestamp__c, User__c, User__r.Name ' +
                           'FROM UserActionLog__c ' +
                           'WHERE User__c = :currentUserId ' +
                           'AND ActionTimestamp__c >= :threeMinutesAgo ' +
                           'ORDER BY ActionTimestamp__c DESC LIMIT :limitCount';
            
            // Execute the query
            List<UserActionLog__c> logs = Database.query(query);
            
            // Format logs as text with date and details separated by colon, each log on a new line
            String logsText = '';
            for (UserActionLog__c log : logs) {
                if (logsText != '') {
                    logsText += '\n';
                }
                String timestamp = log.ActionTimestamp__c.format('yyyy/MM/dd HH:mm:ss');
                logsText += timestamp + ': ' + log.ActionDetails__c;
            }
            
            response.formattedLogs = logsText;
            response.message = 'Successfully retrieved ' + logs.size() + ' user action logs for current user';
        } catch (Exception e) {
            response.success = false;
            response.message = 'Error retrieving user action logs: ' + e.getMessage();
            System.debug('Error in GetLatestUserActionLogsAction: ' + e.getMessage());
            System.debug(e.getStackTraceString());
        }
        
        return new List<ActionLogResponse>{ response };
    }
}