@IsTest
private class HistoryTrackingCreateRecordTest {
    @TestSetup
    static void createTestData() {
		Account acc = new Account(
            Name = 'Example University',
            BuildingAndStreet__c = '123 Street',
            BuildingAndStreet2__c = 'Building 1',
            Postcode__c = 'AB12 4CD',
            CountryOrTerritory__c = 'United Kingdom'
        );
        insert acc;

        
        Application__c application = new Application__c(
			Name = 'APP-TEST00',
			Account__c = acc.Id
		);
        insert application;
		
        Participant__c participant = new Participant__c();
        participant.Application__c =application.Id;
        participant.Name='P-001';
        participant.FirstName__c ='firstname';
        participant.LastName__c ='lastname';
        insert participant;
	}
	
	@IsTest
	static void insertHistoryRecordTest() {
		Participant__c participant = [SELECT Id FROM Participant__c LIMIT 1];
		
		Test.startTest();
		
		participant.FirstName__c ='firstnamenew';
		update participant;
		
		Test.stopTest();
		
		List<ParticipantHistory__c> lstParticipantHistory =[SELECT Id, NewValue__c, OldValue__c FROM ParticipantHistory__c];
        System.assertEquals(1, lstParticipantHistory.size());
		System.assertEquals('firstnamenew', lstParticipantHistory[0].NewValue__c, 'New value not macth');
        System.assertEquals('firstname', lstParticipantHistory[0].OldValue__c, 'Old value not macth');
	}
	
	@IsTest
	static void insertHistoryRecordsTest() {
		Participant__c participant = [SELECT Id FROM Participant__c LIMIT 1];
		
		Test.startTest();
		
		participant.Email__c= 'Test@gmail.com';
        participant.ActualCostsSend__c =100;
        participant.ActualExceptionalCosts__c =100;
        participant.ActualExceptionallyExpensiveTravel__c=100;
        participant.CostOfLiving__c= 100;
        participant.DateOfBirth__c= Date.today();
        update participant;
		
		Test.stopTest();
		
		List<ParticipantHistory__c> lstParticipantHistory =[SELECT Id, NewValue__c, OldValue__c FROM ParticipantHistory__c];
        System.assertEquals(6, lstParticipantHistory.size());
	}
}