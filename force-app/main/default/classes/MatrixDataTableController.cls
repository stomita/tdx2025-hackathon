/**
 * Controller class for Matrix Data Table component
 * Provides functionality to retrieve and aggregate data in a matrix format
 */
public with sharing class MatrixDataTableController {
    
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
     * Get matrix data based on specified parameters
     * @param objectName API name of the object to query
     * @param rowField Field to group by for rows
     * @param columnField Field to group by for columns
     * @param aggregateField Field to aggregate
     * @param aggregateFunction Function to use for aggregation (SUM, AVG, COUNT, etc.)
     * @param rowDateGrouping Grouping level for row field if it's a date (DAY, MONTH, YEAR)
     * @param columnDateGrouping Grouping level for column field if it's a date (DAY, MONTH, YEAR)
     * @param filterConditions JSON string of filter conditions
     * @return MatrixDataWrapper containing the matrix data
     */
    @AuraEnabled
    public static MatrixDataWrapper getMatrixData(
        String objectName,
        String rowField,
        String columnField,
        String aggregateField,
        String aggregateFunction,
        String rowDateGrouping,
        String columnDateGrouping,
        String filterConditions
    ) {
        try {
            // Parse filter conditions
            List<FilterCondition> filters = new List<FilterCondition>();
            if (String.isNotBlank(filterConditions)) {
                filters = (List<FilterCondition>) JSON.deserialize(filterConditions, List<FilterCondition>.class);
            }
            
            // Build the SOQL query
            String soql = buildMatrixQuery(
                objectName,
                rowField,
                columnField,
                aggregateField,
                aggregateFunction,
                rowDateGrouping,
                columnDateGrouping,
                filters
            );
            
            // Execute the query
            List<AggregateResult> results = Database.query(soql);
            
            // Process the results into a matrix format
            return processMatrixResults(
                results,
                rowField,
                columnField,
                aggregateFunction,
                rowDateGrouping,
                columnDateGrouping
            );
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving matrix data: ' + e.getMessage());
        }
    }
    
    /**
     * Build the SOQL query for matrix data
     */
    private static String buildMatrixQuery(
        String objectName,
        String rowField,
        String columnField,
        String aggregateField,
        String aggregateFunction,
        String rowDateGrouping,
        String columnDateGrouping,
        List<FilterCondition> filters
    ) {
        // Format row field for grouping
        String formattedRowField = formatFieldForGrouping(rowField, rowDateGrouping);
        String rowAlias = 'rowValue';
        
        // For month grouping, we need to handle multiple fields
        boolean isRowMonthGrouping = rowDateGrouping == 'MONTH';
        
        // Format column field for grouping
        String formattedColumnField = formatFieldForGrouping(columnField, columnDateGrouping);
        String columnAlias = 'columnValue';
        
        // For month grouping, we need to handle multiple fields
        boolean isColumnMonthGrouping = columnDateGrouping == 'MONTH';
        
        // Format aggregate function
        String aggregateExpr = aggregateFunction + '(' + aggregateField + ')';
        String aggregateAlias = 'aggregateValue';
        
        // Build the base query
        String soql;
        
        if (isRowMonthGrouping && isColumnMonthGrouping) {
            // Both row and column are month grouping
            soql = 'SELECT CALENDAR_MONTH(' + rowField + ') rowMonth, CALENDAR_YEAR(' + rowField + ') rowYear, '
                 + 'CALENDAR_MONTH(' + columnField + ') columnMonth, CALENDAR_YEAR(' + columnField + ') columnYear, '
                 + aggregateExpr + ' ' + aggregateAlias + ' '
                 + 'FROM ' + objectName + ' ';
        } else if (isRowMonthGrouping) {
            // Only row is month grouping
            soql = 'SELECT CALENDAR_MONTH(' + rowField + ') rowMonth, CALENDAR_YEAR(' + rowField + ') rowYear, '
                 + formattedColumnField + ' ' + columnAlias + ', '
                 + aggregateExpr + ' ' + aggregateAlias + ' '
                 + 'FROM ' + objectName + ' ';
        } else if (isColumnMonthGrouping) {
            // Only column is month grouping
            soql = 'SELECT ' + formattedRowField + ' ' + rowAlias + ', '
                 + 'CALENDAR_MONTH(' + columnField + ') columnMonth, CALENDAR_YEAR(' + columnField + ') columnYear, '
                 + aggregateExpr + ' ' + aggregateAlias + ' '
                 + 'FROM ' + objectName + ' ';
        } else {
            // No month grouping
            soql = 'SELECT ' + formattedRowField + ' ' + rowAlias + ', '
                 + formattedColumnField + ' ' + columnAlias + ', '
                 + aggregateExpr + ' ' + aggregateAlias + ' '
                 + 'FROM ' + objectName + ' ';
        }
        
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
                    // Check if the value is a Boolean
                    if (value.equalsIgnoreCase('true') || value.equalsIgnoreCase('false')) {
                        formattedValue = value.toLowerCase(); // Don't quote Boolean values
                    } else {
                        formattedValue = '\'' + String.escapeSingleQuotes(value) + '\'';
                    }
                }
                
                filterClauses.add(fieldName + ' ' + operator + ' ' + formattedValue);
            }
            
            soql += String.join(filterClauses, ' AND ');
        }
        
        // Add group by clause
        if (isRowMonthGrouping && isColumnMonthGrouping) {
            soql += ' GROUP BY CALENDAR_MONTH(' + rowField + '), CALENDAR_YEAR(' + rowField + '), '
                  + 'CALENDAR_MONTH(' + columnField + '), CALENDAR_YEAR(' + columnField + ')';
            
            // Add order by clause
            soql += ' ORDER BY CALENDAR_YEAR(' + rowField + '), CALENDAR_MONTH(' + rowField + '), '
                  + 'CALENDAR_YEAR(' + columnField + '), CALENDAR_MONTH(' + columnField + ')';
        } else if (isRowMonthGrouping) {
            soql += ' GROUP BY CALENDAR_MONTH(' + rowField + '), CALENDAR_YEAR(' + rowField + '), '
                  + formattedColumnField;
            
            // Add order by clause
            soql += ' ORDER BY CALENDAR_YEAR(' + rowField + '), CALENDAR_MONTH(' + rowField + '), '
                  + formattedColumnField;
        } else if (isColumnMonthGrouping) {
            soql += ' GROUP BY ' + formattedRowField + ', '
                  + 'CALENDAR_MONTH(' + columnField + '), CALENDAR_YEAR(' + columnField + ')';
            
            // Add order by clause
            soql += ' ORDER BY ' + formattedRowField + ', '
                  + 'CALENDAR_YEAR(' + columnField + '), CALENDAR_MONTH(' + columnField + ')';
        } else {
            soql += ' GROUP BY ' + formattedRowField + ', ' + formattedColumnField;
            
            // Add order by clause
            soql += ' ORDER BY ' + formattedRowField + ', ' + formattedColumnField;
        }
        
        return soql;
    }
    
    /**
     * Format a field for grouping, applying date formatting if needed
     */
    private static String formatFieldForGrouping(String fieldName, String dateGrouping) {
        if (String.isBlank(dateGrouping)) {
            return fieldName;
        }
        
        switch on dateGrouping {
            when 'DAY' {
                return 'DAY_ONLY(' + fieldName + ')';
            }
            when 'MONTH' {
                // For month grouping, we need both month and year
                return 'CALENDAR_MONTH(' + fieldName + '), CALENDAR_YEAR(' + fieldName + ')';
            }
            when 'YEAR' {
                return 'CALENDAR_YEAR(' + fieldName + ')';
            }
            when else {
                return fieldName;
            }
        }
    }
    
    /**
     * Process aggregate results into a matrix format
     */
    private static MatrixDataWrapper processMatrixResults(
        List<AggregateResult> results,
        String rowField,
        String columnField,
        String aggregateFunction,
        String rowDateGrouping,
        String columnDateGrouping
    ) {
        // Extract unique row and column values
        Set<String> rowValues = new Set<String>();
        Set<String> columnValues = new Set<String>();
        Map<String, Map<String, Object>> dataMap = new Map<String, Map<String, Object>>();
        
        // Process results to extract unique values and build data map
        for (AggregateResult result : results) {
            String rowValue;
            String columnValue;
            
            // Handle month grouping for row
            if (rowDateGrouping == 'MONTH') {
                Integer rowMonth = (Integer)result.get('rowMonth');
                Integer rowYear = (Integer)result.get('rowYear');
                
                // Get month name
                List<String> monthNames = new List<String>{
                    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                };
                String monthName = monthNames[rowMonth - 1]; // Adjust for 0-based index
                
                // Format as MMM YYYY (e.g., Mar 2024)
                rowValue = monthName + ' ' + rowYear;
            } else {
                rowValue = formatResultValue(result.get('rowValue'), rowDateGrouping);
            }
            
            // Handle month grouping for column
            if (columnDateGrouping == 'MONTH') {
                Integer columnMonth = (Integer)result.get('columnMonth');
                Integer columnYear = (Integer)result.get('columnYear');
                
                // Get month name
                List<String> monthNames = new List<String>{
                    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                };
                String monthName = monthNames[columnMonth - 1]; // Adjust for 0-based index
                
                // Format as MMM YYYY (e.g., Mar 2024)
                columnValue = monthName + ' ' + columnYear;
            } else {
                columnValue = formatResultValue(result.get('columnValue'), columnDateGrouping);
            }
            
            Object aggregateValue = result.get('aggregateValue');
            
            rowValues.add(rowValue);
            columnValues.add(columnValue);
            
            // Initialize row map if it doesn't exist
            if (!dataMap.containsKey(rowValue)) {
                dataMap.put(rowValue, new Map<String, Object>());
            }
            
            // Add the aggregate value to the data map
            dataMap.get(rowValue).put(columnValue, aggregateValue);
        }
        
        // Convert sets to sorted lists
        List<String> sortedRowValues = new List<String>(rowValues);
        List<String> sortedColumnValues = new List<String>(columnValues);
        
        // Special sorting for month grouping
        if (rowDateGrouping == 'MONTH') {
            // Create a map of month-year values to their comparators
            Map<String, MonthYearComparator> comparators = new Map<String, MonthYearComparator>();
            List<MonthYearComparator> sortableValues = new List<MonthYearComparator>();
            
            for (String value : rowValues) {
                MonthYearComparator comp = new MonthYearComparator(value);
                comparators.put(value, comp);
                sortableValues.add(comp);
            }
            
            // Sort the comparators
            sortableValues.sort();
            
            // Rebuild the sorted list
            sortedRowValues.clear();
            for (MonthYearComparator comp : sortableValues) {
                for (String key : comparators.keySet()) {
                    if (comparators.get(key) == comp) {
                        sortedRowValues.add(key);
                        break;
                    }
                }
            }
        } else {
            sortedRowValues.sort();
        }
        
        // Special sorting for month grouping in columns
        if (columnDateGrouping == 'MONTH') {
            // Create a map of month-year values to their comparators
            Map<String, MonthYearComparator> comparators = new Map<String, MonthYearComparator>();
            List<MonthYearComparator> sortableValues = new List<MonthYearComparator>();
            
            for (String value : columnValues) {
                MonthYearComparator comp = new MonthYearComparator(value);
                comparators.put(value, comp);
                sortableValues.add(comp);
            }
            
            // Sort the comparators
            sortableValues.sort();
            
            // Rebuild the sorted list
            sortedColumnValues.clear();
            for (MonthYearComparator comp : sortableValues) {
                for (String key : comparators.keySet()) {
                    if (comparators.get(key) == comp) {
                        sortedColumnValues.add(key);
                        break;
                    }
                }
            }
        } else {
            sortedColumnValues.sort();
        }
        
        // Build the matrix data
        List<List<Object>> matrixData = new List<List<Object>>();
        
        // Add header row
        List<Object> headerRow = new List<Object>();
        headerRow.add(''); // Empty cell for top-left corner
        headerRow.addAll(sortedColumnValues);
        matrixData.add(headerRow);
        
        // Add data rows
        for (String rowValue : sortedRowValues) {
            List<Object> dataRow = new List<Object>();
            dataRow.add(rowValue); // Row header
            
            Map<String, Object> rowData = dataMap.get(rowValue);
            
            // Add cells for each column
            for (String columnValue : sortedColumnValues) {
                Object cellValue = rowData.containsKey(columnValue) ? rowData.get(columnValue) : 0;
                dataRow.add(cellValue);
            }
            
            matrixData.add(dataRow);
        }
        
        // Create and return the wrapper
        MatrixDataWrapper wrapper = new MatrixDataWrapper();
        wrapper.matrixData = matrixData;
        wrapper.rowLabels = sortedRowValues;
        wrapper.columnLabels = sortedColumnValues;
        
        return wrapper;
    }
    
    /**
     * Format a result value based on date grouping
     */
    private static String formatResultValue(Object value, String dateGrouping) {
        if (value == null) {
            return 'null';
        }
        
        if (String.isBlank(dateGrouping)) {
            return String.valueOf(value);
        }
        
        // Format date values based on grouping
        switch on dateGrouping {
            when 'DAY' {
                // For day grouping, format as YYYY-MM-DD
                Date dateValue = (Date)value;
                return dateValue.year() + '-' + 
                       String.valueOf(dateValue.month()).leftPad(2, '0') + '-' + 
                       String.valueOf(dateValue.day()).leftPad(2, '0');
            }
            when 'MONTH' {
                // For month grouping, format as MMM YYYY (e.g., Mar 2024)
                // CALENDAR_MONTH returns a number representing the year and month
                // The format is YYYYMM
                Integer monthValue = (Integer)value;
                String monthStr = String.valueOf(monthValue);
                if (monthStr.length() >= 6) {
                    Integer yearPart = Integer.valueOf(monthStr.substring(0, 4));
                    Integer monthPart = Integer.valueOf(monthStr.substring(4));
                    
                    // Store original value in format YYYY-MM for sorting
                    String sortableValue = yearPart + '-' + String.valueOf(monthPart).leftPad(2, '0');
                    
                    // Get month name
                    List<String> monthNames = new List<String>{
                        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                    };
                    String monthName = monthNames[monthPart - 1]; // Adjust for 0-based index
                    
                    // Return formatted value: MMM YYYY (e.g., Mar 2024)
                    return monthName + ' ' + yearPart;
                }
                return monthValue.format();
            }
            when 'YEAR' {
                // For year grouping, just return the year
                Integer yearValue = (Integer)value;
                return String.valueOf(yearValue);
            }
            when else {
                return String.valueOf(value);
            }
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
     * Wrapper class for matrix data
     */
    public class MatrixDataWrapper {
        @AuraEnabled public List<List<Object>> matrixData;
        @AuraEnabled public List<String> rowLabels;
        @AuraEnabled public List<String> columnLabels;
    }
    
    /**
     * Custom comparator for sorting month-year values
     */
    private class MonthYearComparator implements Comparable {
        private String value;
        private Integer sortOrder;
        
        public MonthYearComparator(String value) {
            this.value = value;
            this.sortOrder = calculateSortOrder(value);
        }
        
        private Integer calculateSortOrder(String monthYearStr) {
            // Parse "MMM YYYY" format (e.g., "Jan 2024")
            List<String> parts = monthYearStr.split(' ');
            if (parts.size() != 2) {
                return 0; // Default sort order for non-month-year values
            }
            
            String monthStr = parts[0];
            Integer year = Integer.valueOf(parts[1]);
            
            // Convert month name to number
            List<String> monthNames = new List<String>{
                'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
            };
            Integer month = monthNames.indexOf(monthStr) + 1;
            
            // Calculate sort order: year * 100 + month
            // This ensures proper chronological ordering
            return (year * 100) + month;
        }
        
        public Integer compareTo(Object obj) {
            MonthYearComparator other = (MonthYearComparator)obj;
            if (this.sortOrder < other.sortOrder) {
                return -1;
            } else if (this.sortOrder > other.sortOrder) {
                return 1;
            }
            return 0;
        }
    }
}