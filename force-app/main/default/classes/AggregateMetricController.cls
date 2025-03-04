/**
 * Controller class for Aggregate Metric component
 * Provides functionality to retrieve and aggregate data for metric display
 */
public with sharing class AggregateMetricController {
    
    /**
     * Get object schema information
     * @return Map of object API names to their labels
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getObjectOptions() {
        Map<String, String> objectOptions = new Map<String, String>();
        
        // Get all objects that are accessible to the current user
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        
        for (String objectName : globalDescribe.keySet()) {
            Schema.DescribeSObjectResult objDescribe = globalDescribe.get(objectName).getDescribe();
            
            // Only include objects that are queryable and accessible
            if (objDescribe.isQueryable() && objDescribe.isAccessible()) {
                objectOptions.put(objectName, objDescribe.getLabel());
            }
        }
        
        return objectOptions;
    }
    
    /**
     * Get field information for a specific object
     * @param objectName API name of the object
     * @return List of field wrapper objects
     */
    @AuraEnabled(cacheable=true)
    public static List<FieldWrapper> getFieldOptions(String objectName) {
        List<FieldWrapper> fieldOptions = new List<FieldWrapper>();
        
        try {
            // Get the object's describe result
            Schema.DescribeSObjectResult objDescribe = Schema.getGlobalDescribe().get(objectName).getDescribe();
            Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
            
            for (String fieldName : fieldMap.keySet()) {
                Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                
                // Only include fields that are accessible
                if (fieldDescribe.isAccessible()) {
                    String fieldType = String.valueOf(fieldDescribe.getType());
                    
                    // Create field wrapper
                    FieldWrapper field = new FieldWrapper(
                        fieldName,
                        fieldDescribe.getLabel(),
                        fieldType
                    );
                    
                    fieldOptions.add(field);
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving field options: ' + e.getMessage());
        }
        
        return fieldOptions;
    }
    
    /**
     * Get aggregate metric data based on specified parameters
     * @param objectName API name of the object to query
     * @param aggregateField Field to aggregate
     * @param aggregateFunction Function to use for aggregation (SUM, AVG, COUNT, etc.)
     * @param filterConditions JSON string of filter conditions
     * @return AggregateMetricWrapper containing the metric data
     */
    @AuraEnabled
    public static AggregateMetricWrapper getAggregateMetric(
        String objectName,
        String aggregateField,
        String aggregateFunction,
        String filterConditions
    ) {
        try {
            // Parse filter conditions
            List<FilterCondition> filters = new List<FilterCondition>();
            if (String.isNotBlank(filterConditions)) {
                filters = (List<FilterCondition>) JSON.deserialize(filterConditions, List<FilterCondition>.class);
            }
            
            // Build the SOQL query
            String soql = buildAggregateQuery(
                objectName,
                aggregateField,
                aggregateFunction,
                filters
            );
            
            // Execute the query
            List<AggregateResult> results = Database.query(soql);
            
            // Process the results
            return processAggregateResult(
                results,
                aggregateFunction,
                aggregateField
            );
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving aggregate metric: ' + e.getMessage());
        }
    }
    
    /**
     * Build the SOQL query for aggregate data
     */
    private static String buildAggregateQuery(
        String objectName,
        String aggregateField,
        String aggregateFunction,
        List<FilterCondition> filters
    ) {
        // Get object schema information
        Map<String, Schema.SObjectField> fieldMap;
        try {
            Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
            if (objectType != null) {
                fieldMap = objectType.getDescribe().fields.getMap();
            } else {
                fieldMap = new Map<String, Schema.SObjectField>();
            }
        } catch (Exception e) {
            System.debug('Error getting schema information: ' + e.getMessage());
            fieldMap = new Map<String, Schema.SObjectField>();
        }
        // Format aggregate function
        String aggregateExpr = aggregateFunction + '(' + aggregateField + ')';
        String aggregateAlias = 'metricValue';
        
        // Build the base query
        String soql = 'SELECT ' + aggregateExpr + ' ' + aggregateAlias + ' FROM ' + objectName + ' ';
        
        // Add filter conditions
        if (!filters.isEmpty()) {
            soql += 'WHERE ';
            List<String> filterClauses = new List<String>();
            
            for (FilterCondition filter : filters) {
                String fieldName = filter.fieldName;
                String operator = filter.operator;
                String value = filter.value;
                
                // Format the value based on the operator
                String formattedValue;
                if (operator == 'LIKE') {
                    formattedValue = '\'%' + String.escapeSingleQuotes(value) + '%\'';
                } else if (operator == 'IN' || operator == 'NOT IN') {
                    // Assume value is comma-separated list
                    List<String> values = value.split(',');
                    List<String> formattedValues = new List<String>();
                    for (String v : values) {
                        formattedValues.add('\'' + String.escapeSingleQuotes(v.trim()) + '\'');
                    }
                    formattedValue = '(' + String.join(formattedValues, ',') + ')';
                } else {
                    // Get field type from schema
                    Schema.DisplayType fieldType = null;
                    if (fieldMap.containsKey(fieldName)) {
                        Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                        fieldType = fieldDescribe.getType();
                    }
                    
                    // Format value based on field type
                    if (fieldType == Schema.DisplayType.BOOLEAN) {
                        formattedValue = value.toLowerCase(); // Don't quote Boolean values
                    } else if (fieldType == Schema.DisplayType.DATE ||
                              fieldType == Schema.DisplayType.DATETIME) {
                        formattedValue = value; // Don't quote Date/DateTime values
                    } else {
                        formattedValue = '\'' + String.escapeSingleQuotes(value) + '\'';
                    }
                }
                
                filterClauses.add(fieldName + ' ' + operator + ' ' + formattedValue);
            }
            
            soql += String.join(filterClauses, ' AND ');
        }
        
        return soql;
    }
    
    /**
     * Process aggregate result into a metric wrapper
     */
    private static AggregateMetricWrapper processAggregateResult(
        List<AggregateResult> results,
        String aggregateFunction,
        String aggregateField
    ) {
        AggregateMetricWrapper wrapper = new AggregateMetricWrapper();
        
        if (results.isEmpty()) {
            wrapper.value = 0;
            wrapper.formattedValue = '0';
            return wrapper;
        }
        
        // Get the aggregate value from the first result
        Object rawValue = results[0].get('metricValue');
        
        // Handle null value
        if (rawValue == null) {
            wrapper.value = 0;
            wrapper.formattedValue = '0';
            return wrapper;
        }
        
        // Convert to appropriate type based on aggregate function
        if (aggregateFunction == 'COUNT') {
            // COUNT always returns an Integer
            wrapper.value = (Integer)rawValue;
            wrapper.formattedValue = String.valueOf(wrapper.value);
        } else if (aggregateFunction == 'SUM' || aggregateFunction == 'AVG' || 
                  aggregateFunction == 'MIN' || aggregateFunction == 'MAX') {
            // These functions can return Decimal values
            if (rawValue instanceof Decimal) {
                Decimal decimalValue = (Decimal)rawValue;
                wrapper.value = decimalValue;
                
                // Format with appropriate decimal places
                if (decimalValue.scale() > 0) {
                    wrapper.formattedValue = decimalValue.setScale(2).format();
                } else {
                    wrapper.formattedValue = decimalValue.setScale(0).format();
                }
            } else {
                // Handle other numeric types
                wrapper.value = rawValue;
                wrapper.formattedValue = String.valueOf(rawValue);
            }
        } else {
            // Default handling for other functions
            wrapper.value = rawValue;
            wrapper.formattedValue = String.valueOf(rawValue);
        }
        
        return wrapper;
    }
    
    /**
     * Wrapper class for field information
     */
    public class FieldWrapper {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String dataType;
        
        public FieldWrapper(String apiName, String label, String dataType) {
            this.apiName = apiName;
            this.label = label;
            this.dataType = dataType;
        }
    }
    
    /**
     * Wrapper class for filter conditions
     */
    public class FilterCondition {
        @AuraEnabled public String fieldName;
        @AuraEnabled public String operator;
        @AuraEnabled public String value;
    }
    
    /**
     * Wrapper class for aggregate metric data
     */
    public class AggregateMetricWrapper {
        @AuraEnabled public Object value;
        @AuraEnabled public String formattedValue;
    }
}