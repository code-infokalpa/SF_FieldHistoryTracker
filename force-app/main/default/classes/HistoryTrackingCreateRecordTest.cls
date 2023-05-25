@IsTest
public with sharing class HistoryTrackingCreateRecordTest {
    @TestSetup
    static void createTestData() {
        Account acc = new Account(
            Name = 'Example University'
        );
        insert acc;
    }

    @IsTest
	static void insertHistoryRecordTest() {
        List<SobjectHistoryTrackingWrapper> recordsWrapperLst = new List<SobjectHistoryTrackingWrapper>();
        SobjectHistoryTrackingWrapper sohtw = new SobjectHistoryTrackingWrapper();
        Account acc = [SELECT Id, Name FROM Account LIMIT 1];
        sohtw.oldRecordState = acc;
        acc.Name = 'Changed to New University';
        sohtw.newRecordState = acc;
        recordsWrapperLst.add(sohtw);
        Test.startTest();
        List<SobjectHistoryTrackingWrapper> retVal = HistoryTrackingCreateRecord.insertHistoryRecord(recordsWrapperLst);
        System.assertNotEquals(retVal, null);
        Test.stopTest();
    }
}