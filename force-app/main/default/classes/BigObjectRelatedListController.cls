public with sharing class BigObjectRelatedListController {

    // Returns big object's records based on lookup field and parent record Id
    @AuraEnabled(cacheable=true)
    public static List<SObject> getRecords(String bigObjectApiName, String fieldsApiNames, String parentRecordId, Integer numberOfRecords) {
        String accessibleFields = getAccessibleFields(bigObjectApiName, fieldsApiNames);
        // If there are lookup fields, we add also the name fields from the relationships to be displayed instead of 
        // directly showing the ids
        String allWithRelationshipFields = getAllWithRelationshipFields(bigObjectApiName, accessibleFields);
        return Database.query(String.escapeSingleQuotes('SELECT ' + allWithRelationshipFields + 
                                                        ' FROM ' + bigObjectApiName + 
                                                        ' WHERE Record_Id__c' + ' = :parentRecordId ' + 
                                                        ' WITH SECURITY_ENFORCED ' +
                                                        ' LIMIT ' + numberOfRecords));
    }

    // Returns fields in form of columns to be used in the client-side datatable
    @AuraEnabled(cacheable=true)
    public static List<ColumnWrapper> getColumns(String bigObjectApiName, String fieldsApiNames) {
        List<ColumnWrapper> columns = new List<ColumnWrapper>();
        List<String> fields = getAccessibleFields(bigObjectApiName, fieldsApiNames).split(',');
        for(String field : fields) {
            Map<String, Object> typeAttributes = new Map<String, Object>();
            String fieldLabel = GlobalUtils.getFieldLabel(bigObjectApiName, field);
            String fieldType = GlobalUtils.getFieldType(bigObjectApiName, field);
            String fieldRelationshipName;
            // If the field is a reference, we include the name of the associated record from the relationship
            // to be displayed in client-side through typeAttributes
            if(fieldType == 'reference') {
                fieldRelationshipName = GlobalUtils.getFieldReferenceName(bigObjectApiName, field);
            }
            typeAttributes = GlobalUtils.getFieldTypeAttributes(fieldType, fieldRelationshipName);

            ColumnWrapper columnWrapper = new ColumnWrapper(fieldLabel,
                                                            field,
                                                            fieldType);
            if(!typeAttributes.isEmpty()) {
                columnWrapper.typeAttributes = typeAttributes;
            }
            columns.add(columnWrapper);
        }
        return columns;
    }

    // Returns the SObject plural label based on the current user language.
    @AuraEnabled(cacheable=true)
    public static String getSObjectPluralLabel(String apiName) {
        return GlobalUtils.getSObjectPluralLabel(apiName);
    }

    // Returns the SObject accessibility based on the current user permissions.
    @AuraEnabled(cacheable=true)
    public static Boolean isSObjectAccessible(String apiName){
        return GlobalUtils.isSObjectAccessible(apiName);
    }

    // Returns the SObject accessible fields based on the current user permissions.
    public static String getAccessibleFields(String bigObjectApiName, String fields) {
        List<String> accessibleFields = new List<String>();
        for(String field : fields.split(',')) {
            if(GlobalUtils.isFieldAccessible(bigObjectApiName, field)) {
                accessibleFields.add(field);
            }
        }
        return String.join(accessibleFields,',');
    }

    // Returns the fields passed as a parameter plus their associated relationship fields.
    // (Example: If we have this reference field as parameter 'Contact__c', we will return 'Contact__c,Contact__r.Name')
    public static String getAllWithRelationshipFields(String bigObjectApiName, String fields) {
        List<String> allWithRelationshipFields = new List<String>();
        List<String> fieldsSplit = fields.split(',');
        for(String field : fieldsSplit) {
            allWithRelationshipFields.add(field);
            String fieldType = GlobalUtils.getFieldType(bigObjectApiName, field);
            if(fieldType == 'reference') {
                String fieldRelationshipName = GlobalUtils.getFieldReferenceName(bigObjectApiName, field);
                allWithRelationshipFields.add(fieldRelationshipName);
            }
        }
        return String.join(allWithRelationshipFields, ',');
    }
    
    // Wrapper class for columns (fields)
    public class ColumnWrapper {
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String fieldName;
        @AuraEnabled
        public String type;
        @AuraEnabled
        public Map<String, Object> typeAttributes;

        public ColumnWrapper(String label, String fieldName, String type) {
            this.label = label;
            this.fieldName = fieldName;
            this.type = type;
        }
    }

}