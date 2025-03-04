public with sharing class PromptViaUserInterfaceAction {
    @InvocableMethod(
        label='Prompt via User Interface'
        description='Prompt something in User Interface (LWC)'
    )
    public static List<Boolean> promptViaUserInterface(
        List<Id> recordIds
    ) {
        System.debug(recordIds);
        return new Boolean[] { true };
    }
}