public with sharing class SetHeighlightThresholdAction {
    @InvocableMethod(
        label='Set Heighlight Threshold value of sales trend table'
        description='Set Heighlight Threshold value of sales trend table'
    )
    public static List<Boolean> setHeighlightThreshold(
        List<Integer> highlightThresholds
    ) {
        if (highlightThresholds.size() > 1) {
            System.debug('Currently only one highlightThresholds per action (bulkification is not supported)');
        }
        System.debug(highlightThresholds);
        String paramsJSON = JSON.serialize(new Map<String, Object>{ 'threshold' => highlightThresholds[0] });
        EventBus.publish(
            new UIInstruction__e(Command__c = 'setHeighlightThreshold', Parameters__c = paramsJSON)
        );
        return new List<Boolean>{ true };
    }
}