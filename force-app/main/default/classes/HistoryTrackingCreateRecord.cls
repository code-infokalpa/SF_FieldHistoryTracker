public class HistoryTrackingCreateRecord {
    @InvocableMethod(label='Insert History Record' description='Creates History record of any sObject ' category= 'History')
    public static List<SobjectHistoryTrackingWrapper> insertHistoryRecord(List<SobjectHistoryTrackingWrapper> recordsWrapper) {
        System.enqueueJob(new HistoryTrackingCreateRecordQueue(recordsWrapper));
        return recordsWrapper;
    }
}