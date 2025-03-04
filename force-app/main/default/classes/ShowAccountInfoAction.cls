public with sharing class ShowAccountInfoAction {
    @InvocableMethod(
        label='Show Account Info in UI'
        description='Show Account Info in Lightning Page UI'
    )
    public static List<Boolean> showAccountInfo(
        List<Id> recordIds
    ) {
        if (recordIds.size() > 1) {
            System.debug('Currently only one recordIds per action (bulkification is not supported)');
        }
        System.debug(recordIds);
        EventBus.publish(
            new UIInstruction__e(Command__c = 'showAccountInfo', RecordId__c = recordIds[0])
        );
        return new List<Boolean>{ true };
    }
}