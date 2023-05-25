public with sharing class GlobalUtils {

    private static Map<String, Schema.SObjectType> globalDescribe;
    private static Map<String, Schema.DescribeFieldResult> fieldDescribes = new Map<String, Schema.DescribeFieldResult>();
    private static Map<String, Schema.DescribeSObjectResult> objectDescribes = new Map<String, Schema.DescribeSObjectResult>();
    private static Map<String, String> fieldTypes = new Map<String, String>();

    // Returns the global describe. If it's not already loaded in the map: globalDescribe, we retrieve it then place it
    // in this map to have a better performance.
    public static Map<String, Schema.SObjectType> getGlobalDescribe() {
        if(globalDescribe == null) {
            globalDescribe = Schema.getGlobalDescribe(); 
        }
        return globalDescribe;
    }

    // Returns the SObject describe. If it's not already loaded in the map: objectDescribes, we retrieve it then place it
    // in this map to have a better performance.
    public static Schema.DescribeSObjectResult getSObjectDescribe(String apiName) {
        Schema.DescribeSObjectResult SObjectDescribe;
        if(!objectDescribes.containsKey(apiName)) {
            SObjectDescribe =  getGlobalDescribe().get(apiName).getDescribe();
            objectDescribes.put(apiName, SObjectDescribe);
        }
        else {
            SObjectDescribe =  objectDescribes.get(apiName);
        }
        return SObjectDescribe;
    }

    // Returns the field describe. If it's not already loaded in the map: fieldDescribes, we retrieve it then place it
    // in this map to have a better performance.
    public static Schema.DescribeFieldResult getFieldDescribe(String SObjectApiName, String fieldApiName) {
        Schema.DescribeFieldResult fieldDescribe;
        String key = SObjectApiName + fieldApiName;
        if(!fieldDescribes.containsKey(key)) {
            fieldDescribe = getSObjectDescribe(SObjectApiName).fields.getMap().get(fieldApiName).getDescribe();
            fieldDescribes.put(key, fieldDescribe);
        }
        else {
            fieldDescribe =  fieldDescribes.get(key);
        }
        return fieldDescribe;
    }

    // Returns if the SObject is accessible or not according to the current user permissions.
    public static Boolean isSObjectAccessible(String apiName) {
        return getSObjectDescribe(apiName).isAccessible();
    }

    // Returns if the field is accessible or not according to the current user permissions.
    public static Boolean isFieldAccessible(String SObjectApiName, String fieldApiName) {
        return getFieldDescribe(SObjectApiName, fieldApiName).isAccessible();
    }

    // Returns the plural label of the SObject based on the current user language.
    public static String getSObjectPluralLabel(String apiName) {
        return getSObjectDescribe(apiName).getLabelPlural();
    }

    // Returns the label of the field based on the current user language.
    public static String getFieldLabel(String SObjectApiName, String apiName) {
        return getFieldDescribe(SObjectApiName, apiName).getLabel();
    }

    // Returns the label of the field type.
    public static String getFieldType(String SObjectApiName, String apiName) {
        String fieldType;
        String key = SObjectApiName + apiName;
        if(!fieldTypes.containsKey(key)) {
            Schema.DisplayType displayType = getFieldDescribe(SObjectApiName, apiName).getType();
            switch on displayType {
                when DATE, DATETIME {
                    fieldType = 'date';
                }
                when EMAIL {
                    fieldType = 'email';
                }
                when INTEGER, DOUBLE {
                    fieldType = 'number';
                }
                when PHONE {
                    fieldType = 'phone';
                }
                when STRING, TEXTAREA {
                    fieldType = 'text';
                }
                when URL {
                    fieldType = 'url';
                }
                when ID {
                    fieldType = 'id';
                }
                when REFERENCE {
                    fieldType = 'reference';
                }
            }
            fieldTypes.put(key, fieldType);
        }
        else {
            fieldType = fieldTypes.get(key);
        }
        return fieldType;
    }

    // Returns the reference field actual name through the relationship.
    public static String getFieldReferenceName(String SObjectApiName, String apiName) {
        return getFieldDescribe(SObjectApiName, apiName).getRelationshipName() + '.Name';
    }

    // Returns the field type attributes for two particular cases: url fields and reference fields.
    public static Map<String, Object> getFieldTypeAttributes(String fieldType, String urlLabel) {
        Map<String, Object> typeAttributes = new Map<String, Object>();
        Map<String, String> urlAttributes = new Map<String, String>();
        switch on fieldType {
            // If the field type is an url, we will display "Go to URL" as a label.
            when 'url' {
                typeAttributes.put('label', 'Go to URL');
            }
            // If the field type is a reference, we will display the actual record name instead of the id as a label.
            when 'reference' {
                if(urlLabel != null) {
                    urlAttributes.put('fieldName', urlLabel);
                }
                typeAttributes.put('label', urlAttributes);
            }
            // If the field type is a datetime, we will display also the hour and minutes in the proper format.
            when 'date' {
                typeAttributes.put('year', 'numeric');
                typeAttributes.put('month', 'numeric');
                typeAttributes.put('day', 'numeric');
                typeAttributes.put('hour', '2-digit');
                typeAttributes.put('minute', '2-digit');
                typeAttributes.put('time-zone-name', 'short');
                typeAttributes.put('hour12', 'true');
            }
        }
        return typeAttributes;
    }
}