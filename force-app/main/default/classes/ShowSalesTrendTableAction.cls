public with sharing class ShowSalesTrendTableAction {
    public class DisplayRequest {
        @InvocableVariable(
            label='Start Date'
            description='Start Date of the trending period'
            required=true
        )
        public Date startDate;
        @InvocableVariable(
            label='End Date'
            description='End Date of the trending period'
            required=true
        )
        public Date endDate;
    }

    @InvocableMethod(
        label='Show sales trend table to user'
        description='Show sales trend table to user via Lightning UI'
    )
    public static List<Boolean> showSalesTrendTable(
        List<DisplayRequest> requests 
    ) {
        if (requests.size() > 1) {
            System.debug('Currently only one request per action (bulkification is not supported)');
        }
        String paramsJSON = JSON.serialize(requests[0]);
        EventBus.publish(
            new UIInstruction__e(Command__c = 'showSalesTrend', Parameters__c = paramsJSON)
        );
        return new List<Boolean>{ true };
    }
}