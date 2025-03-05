public with sharing class GetOpportunitiesByTypeAndDateRangeAction {
    /**
     * Request parameters class
     */
    public class RequestParameters {
        @InvocableVariable(
            label='Opportunity Type'
            description='Type of the Opportunity to filter'
            required=false
        )
        public String opportunityType;
        
        @InvocableVariable(
            label='Start Date'
            description='Start date of the CloseDate range'
            required=false
        )
        public Date startDate;
        
        @InvocableVariable(
            label='End Date'
            description='End date of the CloseDate range'
            required=false
        )
        public Date endDate;
    }
    
    /**
     * Result class
     */
    public class OpportunityResult {
        @InvocableVariable(
            label='Opportunities'
            description='List of Opportunities matching the criteria'
        )
        public List<Opportunity> opportunities;
    }
    
    /**
     * Get opportunities based on specified type and date range
     */
    @InvocableMethod(
        label='Get Opportunities By Type And Date Range'
        description='Returns a list of Opportunities with the specified Type and CloseDate within the given date range'
    )
    public static List<OpportunityResult> getOpportunities(List<RequestParameters> requests) {
        // Check if more than one request is provided
        if (requests.size() > 1) {
            throw new IllegalArgumentException('Currently only one request per action is supported (bulkification is not supported)');
        }
        
        // Initialize results list
        List<OpportunityResult> results = new List<OpportunityResult>();
        
        // Get the single request
        RequestParameters request = requests[0];
        
        // Validate parameters if both dates are provided
        if (request.startDate != null && request.endDate != null && request.startDate > request.endDate) {
            throw new IllegalArgumentException('Start date cannot be after end date');
        }
        
        // Initialize result object
        OpportunityResult result = new OpportunityResult();
        
        // Build dynamic SOQL query
        String query = 'SELECT Id, Name, AccountId, Amount, CloseDate, StageName, Type FROM Opportunity';
        
        // Create a list to hold WHERE conditions
        List<String> conditions = new List<String>();
        
        // Add Type condition if provided
        if (request.opportunityType != null) {
            conditions.add('Type = :opportunityType');
        }
        
        // Add start date condition if provided
        if (request.startDate != null) {
            conditions.add('CloseDate >= :startDate');
        }
        
        // Add end date condition if provided
        if (request.endDate != null) {
            conditions.add('CloseDate <= :endDate');
        }
        
        // Add WHERE clause if any conditions exist
        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }
        
        // Add ORDER BY clause
        query += ' ORDER BY CloseDate ASC';
        
        // Set bind variables
        Map<String, Object> bindVariables = new Map<String, Object>();
        if (request.opportunityType != null) {
            bindVariables.put('opportunityType', request.opportunityType);
        }
        if (request.startDate != null) {
            bindVariables.put('startDate', request.startDate);
        }
        if (request.endDate != null) {
            bindVariables.put('endDate', request.endDate);
        }
        
        // Execute query
        result.opportunities = Database.queryWithBinds(query, bindVariables, AccessLevel.USER_MODE);
        
        // Add to results
        results.add(result);
        
        return results;
    }
}