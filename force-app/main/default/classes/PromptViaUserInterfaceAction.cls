public with sharing class PromptViaUserInterfaceAction {
    @InvocableMethod(
        label='Prompt via User Interface'
        description='Prompt something in User Interface (LWC)'
    )
    public static List<Boolean> promptViaUserInterface(
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