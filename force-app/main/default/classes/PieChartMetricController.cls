/**
 * Controller class for Pie Chart Metric component
 * Provides functionality to retrieve and aggregate data for pie chart display
 */
public with sharing class PieChartMetricController {
    
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
     * Get grouped aggregate data for pie chart
     * @param objectName API name of the object to query
     * @param groupByField Field to group by
     * @param aggregateField Field to aggregate
     * @param aggregateFunction Function to use for aggregation (SUM, AVG, COUNT, etc.)
     * @param filterConditions JSON string of filter conditions
     * @param maxSlices Maximum number of slices to show in the pie chart (remaining will be grouped as "Other")
     * @return ChartDataWrapper containing the chart data
     */
    @AuraEnabled
    public static ChartDataWrapper getChartData(
        String objectName,
        String groupByField,
        String aggregateField,
        String aggregateFunction,
        String filterConditions,
        Integer maxSlices
    ) {
        try {
            // Parse filter conditions
            List<FilterCondition> filters = new List<FilterCondition>();
            if (String.isNotBlank(filterConditions)) {
                filters = (List<FilterCondition>) JSON.deserialize(filterConditions, List<FilterCondition>.class);
            }
            
            // Build the SOQL query
            String soql = buildGroupedQuery(
                objectName,
                groupByField,
                aggregateField,
                aggregateFunction,
                filters
            );
            
            // Execute the query
            List<AggregateResult> results = Database.query(soql);
            
            // Process the results into chart data
            return processChartData(
                results,
                groupByField,
                aggregateFunction,
                maxSlices
            );
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving chart data: ' + e.getMessage());
        }
    }
    
    /**
     * Build the SOQL query for grouped data
     */
    private static String buildGroupedQuery(
        String objectName,
        String groupByField,
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
        String aggregateAlias = 'aggregateValue';
        
        // Build the base query
        String soql = 'SELECT ' + groupByField + ' groupValue, ' + aggregateExpr + ' ' + aggregateAlias + ' FROM ' + objectName + ' ';
        
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
        
        // Add group by clause
        soql += ' GROUP BY ' + groupByField;
        
        // Add order by clause to sort by aggregate value in descending order
        soql += ' ORDER BY ' + aggregateExpr + ' DESC';
        
        return soql;
    }
    
    /**
     * Process aggregate results into chart data
     */
    private static ChartDataWrapper processChartData(
        List<AggregateResult> results,
        String groupByField,
        String aggregateFunction,
        Integer maxSlices
    ) {
        ChartDataWrapper wrapper = new ChartDataWrapper();
        
        if (results.isEmpty()) {
            wrapper.labels = new List<String>();
            wrapper.values = new List<Decimal>();
            wrapper.total = 0;
            return wrapper;
        }
        
        // Initialize lists for chart data
        List<String> labels = new List<String>();
        List<Decimal> values = new List<Decimal>();
        List<ChartDataItem> items = new List<ChartDataItem>();
        Decimal total = 0;
        
        // Process each result
        for (AggregateResult result : results) {
            Object groupValue = result.get('groupValue');
            Object aggregateValue = result.get('aggregateValue');
            
            // Skip null group values
            if (groupValue == null) {
                continue;
            }
            
            // Format group value
            String label = String.valueOf(groupValue);
            
            // Convert aggregate value to Decimal
            Decimal value;
            if (aggregateValue instanceof Decimal) {
                value = (Decimal)aggregateValue;
            } else if (aggregateValue instanceof Integer) {
                value = Decimal.valueOf((Integer)aggregateValue);
            } else {
                // Skip if value can't be converted to Decimal
                continue;
            }
            
            // Add to total
            total += value;
            
            // Add to items list
            items.add(new ChartDataItem(label, value));
        }
        
        // Sort items by value in descending order
        items.sort();
        
        // Limit to maxSlices if specified
        if (maxSlices != null && maxSlices > 0 && items.size() > maxSlices) {
            // Take top N-1 slices
            for (Integer i = 0; i < maxSlices - 1; i++) {
                ChartDataItem item = items[i];
                labels.add(item.label);
                values.add(item.value);
            }
            
            // Combine remaining slices as "Other"
            Decimal otherValue = 0;
            for (Integer i = maxSlices - 1; i < items.size(); i++) {
                otherValue += items[i].value;
            }
            
            labels.add('Other');
            values.add(otherValue);
        } else {
            // Use all slices
            for (ChartDataItem item : items) {
                labels.add(item.label);
                values.add(item.value);
            }
        }
        
        // Set wrapper properties
        wrapper.labels = labels;
        wrapper.values = values;
        wrapper.total = total;
        
        return wrapper;
    }
    
    /**
     * Helper class for sorting chart data items
     */
    private class ChartDataItem implements Comparable {
        public String label;
        public Decimal value;
        
        public ChartDataItem(String label, Decimal value) {
            this.label = label;
            this.value = value;
        }
        
        // Sort in descending order by value
        public Integer compareTo(Object obj) {
            ChartDataItem other = (ChartDataItem)obj;
            if (this.value > other.value) {
                return -1;
            } else if (this.value < other.value) {
                return 1;
            }
            return 0;
        }
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
     * Wrapper class for chart data
     */
    public class ChartDataWrapper {
        @AuraEnabled public List<String> labels;
        @AuraEnabled public List<Decimal> values;
        @AuraEnabled public Decimal total;
        @AuraEnabled public List<String> colors;
    }
}