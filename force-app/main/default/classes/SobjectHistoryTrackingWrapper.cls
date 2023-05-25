public class SobjectHistoryTrackingWrapper {
    @AuraEnabled @InvocableVariable public sObject oldRecordState;
    @AuraEnabled @InvocableVariable  public sObject newRecordState;
    @AuraEnabled @InvocableVariable  public String relationshipField;
    @AuraEnabled @InvocableVariable  public String trackedFields;
}