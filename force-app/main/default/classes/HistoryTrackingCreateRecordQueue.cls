public with sharing class HistoryTrackingCreateRecordQueue implements Queueable {
    private List<SobjectHistoryTrackingWrapper> recordsWrapper;

    public HistoryTrackingCreateRecordQueue(List<SobjectHistoryTrackingWrapper> recordsWrapper) {
        this.recordsWrapper = recordsWrapper;
    }

    public void execute(QueueableContext context) {
        insertHistoryRecordV2(recordsWrapper);
    }

    public static List<SobjectHistoryTrackingWrapper> insertHistoryRecordV2(List<SobjectHistoryTrackingWrapper> recordsWrapper) {
        Map<String, String> fieldsLabelMap = getFieldLabelList(String.valueOf(recordsWrapper[0].newRecordState.getSObjectType()));
        ManageRecordHistoryTracking__mdt configRecord = getConfigMetadataRec(String.valueOf(recordsWrapper[0].newRecordState.getSObjectType()));
        List<String> trackedFieldsList = configRecord.TrackedFieldName__c.split(',');
        List<sObject> sObjHistoryList = new List<sObject>(); 
        Map<String, Field_History_Tracker__c> fhtMap = new Map<String, Field_History_Tracker__c>();
        List<ContentVersion> filesToInsert = new List<ContentVersion>();

        //Map<String,Field_History_Tracker__c> recordsToCVMap = new Map<String,Field_History_Tracker__c>();
        for(SobjectHistoryTrackingWrapper ohtWrapper: recordsWrapper){
            if(ohtWrapper.oldRecordState != null){
                Field_History_Tracker__c fht = new Field_History_Tracker__c();
                fht.Sobject_API_Name__c = String.valueOf(ohtWrapper.newRecordState.getSObjectType());
                fht.Sobject_Record_Id__c = ohtWrapper.newRecordState.Id;
                System.debug(ohtWrapper.newRecordState.getSObjectType().getDescribe().getRecordTypeInfosByDeveloperName());
                fht.RecordTypeId = fht.getSObjectType().getDescribe().getRecordTypeInfosByDeveloperName().get('tracker').getRecordTypeId();
                fhtMap.put(ohtWrapper.newRecordState.Id, fht);

                ContentVersion cvNewState = new Contentversion(); 
                cvNewState.Title = 'Record_New_State'; 
                cvNewState.PathOnClient = 'Record_New_State.json';
                cvNewState.Description = fht.Sobject_Record_Id__c;
                cvNewState.VersionData = Blob.valueOf(JSON.serialize(ohtWrapper.newRecordState));
                //insert cvNewState; // Save test json as file with header data linking to the app reference.
                filesToInsert.add(cvNewState);
                //recordsToCVMap.put(cvNewState.Title, fht);                

                ContentVersion cvOldState = new Contentversion(); 
                cvOldState.Title = 'Record_Old_State'; 
                cvOldState.Description = fht.Sobject_Record_Id__c;
                cvOldState.PathOnClient = 'Record_Old_State.json'; 
                cvOldState.VersionData = Blob.valueOf(JSON.serialize(ohtWrapper.oldRecordState));
                //insert cvOldState; // Save test json as file with header data linking to the app reference.
                filesToInsert.add(cvOldState);
                //recordsToCVMap.put(cvOldState.Title, fht);
            }
        }

        if(fhtMap.size() > 0) insert fhtMap.values();
        if(filesToInsert.size() > 0) insert filesToInsert;

        List<ContentVersion> cvList = [SELECT Id, ContentDocumentId,Description FROM ContentVersion WHERE Id IN :filesToInsert];
        List<ContentDocumentLink> cdlList = new List<ContentDocumentLink>();
        for(ContentVersion cv : cvList){
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.LinkedEntityId = fhtMap.get(cv.Description).Id;
            cdl.ContentDocumentId = cv.ContentDocumentId;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            cdlList.add(cdl);
        }        
        if(cdlList.size() > 0) insert cdlList;

        checkAndExecuteBatch();

        return recordsWrapper;
    }


    public static void checkAndExecuteBatch(){
        
        //List<AsyncApexJob> aaJobs = [SELECT Id, ApexClassId, ApexClass.Name  FROM AsyncApexJob WHERE ApexClass.Name = 'FieldHistoryCreationBatch' AND CompletedDate = null];
        List<Field_History_Tracker__c> fhtList = [SELECT Id, Batch_Status__c, Name FROM Field_History_Tracker__c WHERE RecordType.DeveloperName = 'Batch_Info' AND Batch_Status__c = 'In-Progress'];
        if(fhtList.size() == 0) {
            Field_History_Tracker__c fht = new Field_History_Tracker__c();
            fht.Batch_Status__c = 'In-Progress';
            fht.RecordTypeId = Schema.SObjectType.Field_History_Tracker__c.getRecordTypeInfosByDeveloperName().get('Batch_Info').getRecordTypeId();
            insert fht;
            startHistoryTrackingBatch();
        }
        
    }

    public static void startHistoryTrackingBatch(){
        FieldHistoryCreationBatch fhcBatch = new FieldHistoryCreationBatch();
        Integer batchSize =  Field_History_Tracker_Batch_Config__c.getInstance().Batch_Size__c == null ? 10 : Integer.valueOf(Field_History_Tracker_Batch_Config__c.getInstance().Batch_Size__c);
        Database.executeBatch(fhcBatch,batchSize);
    }
    
    public static ManageRecordHistoryTracking__mdt getConfigMetadataRec(String objectName){
        if(!Test.isRunningTest()){
            ManageRecordHistoryTracking__mdt metadataRec = [SELECT DeveloperName, Tracking_Object__r.QualifiedApiName, TrackedFieldName__c
                FROM ManageRecordHistoryTracking__mdt WHERE Tracking_Object__r.QualifiedApiName = :objectName];
                return metadataRec; 
        }
        else{
            ManageRecordHistoryTracking__mdt metadataRec = new ManageRecordHistoryTracking__mdt();
            EntityDefinition ed = [SELECT Id FROM EntityDefinition WHERE QualifiedApiName = 'Account' LIMIT 1];
            metadataRec.DeveloperName = 'myName';
            metadataRec.Tracking_Object__c = 'Account';
            metadataRec.TrackedFieldName__c = 'Name,Email';
            return metadataRec;
        }
        
        
    }
    
    public static Map<String, String> getFieldLabelList(String sObjectName){
        Map<String, String> fieldList = new Map<String, String>();
        if(sObjectName != null){
            Map<String,SObjectField> fList = Schema.getGlobalDescribe().get(sObjectName).getDescribe().fields.getMap();
            for(String str: fList.keySet()){
                fieldList.put(str.toLowerCase(), fList.get(str).getDescribe().getLabel());                
            }
        }else{
            return null;
        }
        return fieldList;
    }
}
