global class FieldHistoryCreationBatch implements Database.Batchable<sObject>, Database.Stateful{

    public Map<String, List<String>> objConfigs;
    global FieldHistoryCreationBatch() {
        objConfigs = new Map<String, List<String>>();
        List<ManageRecordHistoryTracking__mdt> mrhList = [SELECT Id, DeveloperName,Tracking_Object__r.QualifiedApiName,TrackedFieldName__c FROM ManageRecordHistoryTracking__mdt];
        for(ManageRecordHistoryTracking__mdt mrh : mrhList){
            objConfigs.put(mrh.Tracking_Object__r.QualifiedApiName, mrh.TrackedFieldName__c.toLowerCase().split(','));
        }
    }

    global Database.QueryLocator start(Database.BatchableContext BC) {        
        String query = 'SELECT Id,Name,OwnerId,Sobject_API_Name__c,Sobject_Record_Id__c FROM Field_History_Tracker__c WHERE RecordType.DeveloperName = \'tracker\' ORDER BY CreatedDate ASC';
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<Field_History_Tracker__c> fhtList) {
        List<Id> fhtIds = new List<Id>();
        for(Field_History_Tracker__c fht : fhtList){
            fhtIds.add(fht.Id);
        }

        List<Field_History_Store__b> fhStoreList = new List<Field_History_Store__b>();
        List<ContentDocumentLink> cdlOfFHT = [SELECT id,LinkedEntityId, ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId IN :fhtIds];
        Map<Id,Id> leToCdMap = new Map<Id, Id>();
        for(ContentDocumentLink cdl : cdlOfFHT){
            leToCdMap.put(cdl.ContentDocumentId,cdl.LinkedEntityId);
        }
        Map<Id,Id> cvToCDMap = new Map<Id,Id>();
        Map<Id, Map<String, ContentVersion>> mapOfLeCV = new Map<Id, Map<String, ContentVersion>>();

        List<ContentVersion> cvList = [SELECT Id,Title, ContentDocumentId, VersionData FROM ContentVersion WHERE ContentDocumentId IN :leToCdMap.keySet()];
        for(ContentVersion cv : cvList){
            //cvToCDMap.put(cv.ContentDocumentId, cv.Id);
            if(leToCdMap.containsKey(cv.ContentDocumentId)){
                if(!mapOfLeCV.containsKey(leToCdMap.get(cv.ContentDocumentId))){                
                    mapOfLeCV.put(leToCdMap.get(cv.ContentDocumentId), new Map<String, ContentVersion>{cv.Title => cv});
                }
                else{
                    Map<String, ContentVersion> tmpCVMap = mapOfLeCV.get(leToCdMap.get(cv.ContentDocumentId));
                    tmpCVMap.put(cv.Title, cv);
                    mapOfLeCV.put(leToCdMap.get(cv.ContentDocumentId), tmpCVMap);
                }
            } 
        }
        List<Field_History_Tracker__c> fhtToBeDeleted = new List<Field_History_Tracker__c>();
        for(Field_History_Tracker__c fht : fhtList){
            try{
                Set<String> combinedFieldsSetKeys = new Set<String>();
                System.debug('===============new state============');
                String vDataStrNew = mapOfLeCV.get(fht.Id).get('Record_New_State').VersionData.toString();
                Map<String, Object> objMapNew = (Map<String, Object>) JSON.deserializeUntyped(vDataStrNew);
                Map<String, String> fldMapNew = new Map<String, String>();
                for(String str : objMapNew.keySet()){
                    if(str != 'attributes'){
                        combinedFieldsSetKeys.add(str);
                        fldMapNew.put(str, String.valueOf(objMapNew.get(str)));
                        System.debug(str); 
                        System.debug(objMapNew.get(str));  
                    } 
                }
                System.debug('===============old state============');
                String vDataStrOld = mapOfLeCV.get(fht.Id).get('Record_Old_State').VersionData.toString();
                Map<String, Object> objMapOld = (Map<String, Object>) JSON.deserializeUntyped(vDataStrOld);
                Map<String, String> fldMapOld = new Map<String, String>();
                for(String str : objMapOld.keySet()){
                    if(str != 'attributes'){
                        combinedFieldsSetKeys.add(str);
                        fldMapOld.put(str, String.valueOf(objMapOld.get(str)));
                        System.debug(str); 
                        System.debug(objMapOld.get(str));  
                    }
                
                }
                Integer indexer=1;
                for(String fld : combinedFieldsSetKeys){
                    
                    if(objConfigs.get(fht.Sobject_API_Name__c).contains(fld.toLowerCase()) && fldMapOld.get(fld) != fldMapNew.get(fld)){
                        System.debug(fldMapOld.get(fld) +'<==>'+ fldMapNew.get(fld));
                        Field_History_Store__b fhs = new Field_History_Store__b();
                        fhs.Object_API_Name__c = fht.Sobject_API_Name__c;
                        fhs.Record_Id__c = fht.Sobject_Record_Id__c;
                        fhs.Field_API_Name__c = fld;
                        fhs.Field_Label__c = GlobalUtils.getFieldDescribe(fht.Sobject_API_Name__c, fld).getLabel();
                        fhs.Created_Date__c = (DateTime)json.deserialize('"' + fldMapNew.get('LastModifiedDate') + '"', datetime.class);
                        fhs.User__c = fldMapNew.get('LastModifiedById');
                        fhs.Old_Value__c = fldMapOld.get(fld);
                        fhs.New_Value__c = fldMapNew.get(fld); 
                        fhs.Indexer__c = indexer;
                        fhStoreList.add(fhs);
                        
                    }
                    indexer++;
                }
                fhtToBeDeleted.add(fht);
            }
            catch(Exception ex){
                System.debug('An Error occured with creating field history with Record- ' + fht.Id + ', Error Details: ' + ex.getMessage() + ', stack-trace: ' + ex.getStackTraceString());
            }
        }
            
        if(fhStoreList.size() > 0) Database.insertImmediate(fhStoreList);
        if(fhtToBeDeleted.size() > 0) delete fhtToBeDeleted;
        delete [SELECT Id FROM ContentDocument WHERE Id IN :leToCdMap.keySet()];
        
    }

    global void finish(Database.BatchableContext BC) {
        // execute any post-processing operations
        List<Field_History_Tracker__c> fhtList = [SELECT Id FROM Field_History_Tracker__c WHERE RecordType.DeveloperName = 'tracker'];
        if(fhtList.size() > 0){
            if(!Test.isRunningTest()){
                HistoryTrackingCreateRecordQueue.startHistoryTrackingBatch();
            }
            
        }
        else{
            List<Field_History_Tracker__c> fhtForUpdate = new List<Field_History_Tracker__c>([SELECT Id, Batch_Status__c, Name FROM Field_History_Tracker__c WHERE RecordType.DeveloperName = 'Batch_Info' AND Batch_Status__c = 'In-Progress']);
            for(Field_History_Tracker__c fht : fhtForUpdate){
                fht.Batch_Status__c = 'Completed';
            }                
            if(fhtForUpdate.size() > 0) update fhtForUpdate;
        }
    }
}