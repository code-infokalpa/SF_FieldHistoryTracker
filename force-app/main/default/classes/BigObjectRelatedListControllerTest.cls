@isTest
public class BigObjectRelatedListControllerTest {

    @TestSetup
    private static void makeData(){
        // Create and insert a new user
        Profile standardProfile = [Select Id From Profile Where Name = 'Standard User'];
        User u = new User(FirstName = 'Anthony',
                        LastName = 'Stark',
                        ProfileId = standardProfile.Id,
                        Alias = 'astar',
                        Username = 'stark@industries.eu',
                        Email = 'stark@industries.eu',
                        TimeZoneSidKey = 'America/Los_Angeles',
                        languagelocalekey   = 'en_US',
                        localesidkey        = 'en_US',
                        emailencodingkey    = 'UTF-8'
                        );
        insert u;

        // Create and insert 1 account
        Account acc = new Account(
            Name = 'The Rolling Stones',
            Website = 'stones.com',
            Description = 'One of the greatest Rock and Roll bands of all time'
        );
        insert acc;

        // Create and insert new 3 contacts
        Contact ct1 = new Contact(FirstName = 'Mick',
                                LastName = 'Jagger',
                                Email = 'tswift@fakeemail.com',
                                MobilePhone = '33193495283',
                                AccountId = acc.Id);
        Contact ct2 = new Contact(FirstName = 'Ronnie',
                                LastName = 'Wood',
                                Email = 'rwood@fakeemail.com',
                                MobilePhone = '33132325219',
                                AccountId = acc.Id);
        Contact ct3 = new Contact(FirstName = 'Keith',
                                LastName = 'Richards',
                                Email = 'krichards@fakeemail.com',
                                MobilePhone = '3319342342',
                                AccountId = acc.Id);
        insert new List<Contact>{ct1, ct2, ct3};
    }

    @isTest
    private static void testGetRecords() {
        List<SObject> result;
        User u = [Select Id, ProfileId from User Where LastName='Stark'];
        System.runAs(u) {
            Test.startTest();
                Account acc = [Select Id from Account where Name='The Rolling Stones'];
                result = BigObjectRelatedListController.getRecords('Contact', 'Name,Email', (String) acc.Id, 2);
            Test.stopTest();
        }
        System.assertEquals(2, result.size(), '2 contacts must be returned');
    }

    @isTest
    private static void testGetColumns() {
        List<BigObjectRelatedListController.ColumnWrapper> result;
        User u = [Select Id, ProfileId from User Where LastName='Stark'];
        System.runAs(u) {
            Test.startTest();
                result = BigObjectRelatedListController.getColumns('Contact', 'Name,Email,Phone,AccountId');
            Test.stopTest();
        }
        System.assertEquals(4, result.size(), '4 columns must be returned');
        System.assertEquals('Full Name', result.get(0).label, 'The first column must be the name');
        System.assertEquals('email', result.get(1).type, 'The second column type must be email');
        System.assertEquals('Phone', result.get(2).fieldName, 'The third column fieldName must be Phone');
    }

    @isTest
    private static void testGetSObjectPluralLabel() {
        String result;
        User u = [Select Id, ProfileId from User Where LastName='Stark'];
        System.runAs(u) {
            Test.startTest();
                result = BigObjectRelatedListController.getSObjectPluralLabel('Contact');
            Test.stopTest();
        }
        System.assertEquals('Contacts', result, 'The plural name of the Contact SObject is incorrect');      
    }

    @isTest
    private static void testIsSObjectAccessible() {
        Boolean result;
        User u = [Select Id, ProfileId from User Where LastName='Stark'];
        System.runAs(u) {
            Test.startTest();
                result = BigObjectRelatedListController.isSObjectAccessible('Contact');
            Test.stopTest();
        }
        System.assertEquals(true, result, 'The Contact SObject should be accessible');          
    }

    @isTest
    private static void testGetAccessibleFields() {
        String result;
        User u = [Select Id, ProfileId from User Where LastName='Stark'];
        System.runAs(u) {
            Test.startTest();
                result = BigObjectRelatedListController.getAccessibleFields('Contact', 'Name,Email,Phone,AccountId');
            Test.stopTest();
        }
        System.assertEquals('Name,Email,Phone,AccountId', result, 'The accessible fields in the Contact SObject are incorrect');  
    }

    @isTest
    private static void testGetAllWithRelationshipFields() {
        String result;
        User u = [Select Id, ProfileId from User Where LastName='Stark'];
        System.runAs(u) {
            Test.startTest();
                result = BigObjectRelatedListController.getAllWithRelationshipFields('Contact', 'AccountId');
            Test.stopTest();
        }
        System.assertEquals('AccountId,Account.Name', result, 'The fields with their relationship from the Contact SObject are incorrect');     
    }
}