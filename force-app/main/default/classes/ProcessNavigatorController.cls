public with sharing class ProcessNavigatorController {

    public class ProcessResult {
        @AuraEnabled public String      processId;
        @AuraEnabled public String      processName;
        @AuraEnabled public String      displayStyle;
        @AuraEnabled public List<StepResult> steps;
    }

    public class StepResult {
        @AuraEnabled public String  stepId;
        @AuraEnabled public String  label;
        @AuraEnabled public String  iconName;
        @AuraEnabled public String  actionType;
        @AuraEnabled public String  targetObjectApiName;
        @AuraEnabled public String  flowApiName;
        @AuraEnabled public String  helpText;
        @AuraEnabled public String  layoutFields;
        @AuraEnabled public Integer stepOrder;
    }

    public class DocumentResult {
        @AuraEnabled public String   documentId;
        @AuraEnabled public String   title;
        @AuraEnabled public String   fileType;
        @AuraEnabled public Integer  fileSizeKb;
        @AuraEnabled public Datetime lastModified;
    }

    // ── Main method ──────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static ProcessResult getProcessForRecord(Id recordId, String objectApiName) {
        if (recordId == null || String.isBlank(objectApiName)) {
            return null;
        }

        try {
            // Query all active definitions for this object, with conditions subquery
            List<Process_Definition__c> definitions = [
                SELECT Id, Name, Display_Style__c, Priority__c,
                    (SELECT Field_API_Name__c, Operator__c, Value__c
                     FROM Process_Conditions__r),
                    (SELECT Id, Name, Step_Order__c, Icon_Name__c, Action_Type__c,
                            Target_Object_API_Name__c, Flow_API_Name__c,
                            Help_Text__c, Layout_Fields__c
                     FROM Process_Steps__r
                     WHERE Is_Active__c = true
                     ORDER BY Step_Order__c ASC)
                FROM Process_Definition__c
                WHERE Object_API_Name__c = :objectApiName
                  AND Is_Active__c = true
                WITH USER_MODE
                ORDER BY Priority__c ASC NULLS LAST
            ];

            if (definitions.isEmpty()) {
                return null;
            }

            // Collect all distinct field names needed across all conditions
            Set<String> fieldNames = new Set<String>{ 'Id' };
            for (Process_Definition__c def : definitions) {
                for (Process_Condition__c cond : def.Process_Conditions__r) {
                    if (String.isNotBlank(cond.Field_API_Name__c)) {
                        fieldNames.add(cond.Field_API_Name__c.trim());
                    }
                }
            }

            // Dynamically fetch the record with only the needed fields
            SObject record = null;
            try {
                String soql = 'SELECT ' + String.join(new List<String>(fieldNames), ', ')
                    + ' FROM ' + String.escapeSingleQuotes(objectApiName)
                    + ' WHERE Id = :recordId WITH USER_MODE LIMIT 1';
                List<SObject> rows = Database.query(soql);
                if (!rows.isEmpty()) {
                    record = rows[0];
                }
            } catch (Exception queryEx) {
                // Bad field names in conditions — proceed with record = null
                // (definitions with conditions will not match; unconditioned ones will)
            }

            // Walk definitions in priority order and return first match
            for (Process_Definition__c def : definitions) {
                if (evaluateConditions(record, def.Process_Conditions__r)) {
                    ProcessResult result = new ProcessResult();
                    result.processId    = def.Id;
                    result.processName  = def.Name;
                    result.displayStyle = def.Display_Style__c;
                    result.steps        = new List<StepResult>();

                    for (Process_Step__c step : def.Process_Steps__r) {
                        StepResult sr         = new StepResult();
                        sr.stepId             = step.Id;
                        sr.label              = step.Name;
                        sr.iconName           = step.Icon_Name__c;
                        sr.actionType         = step.Action_Type__c;
                        sr.targetObjectApiName = step.Target_Object_API_Name__c;
                        sr.flowApiName        = step.Flow_API_Name__c;
                        sr.helpText           = step.Help_Text__c;
                        sr.layoutFields       = step.Layout_Fields__c;
                        sr.stepOrder          = (Integer) step.Step_Order__c;
                        result.steps.add(sr);
                    }

                    return result;
                }
            }

            return null;

        } catch (Exception ex) {
            throw new AuraHandledException(
                'ProcessNavigatorController.getProcessForRecord: ' + ex.getMessage()
            );
        }
    }

    // ── Documents method ─────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<DocumentResult> getRelatedDocuments(Id recordId) {
        if (recordId == null) {
            return new List<DocumentResult>();
        }
        try {
            List<DocumentResult> results = new List<DocumentResult>();
            for (ContentDocumentLink cdl : [
                SELECT ContentDocument.Id, ContentDocument.Title,
                       ContentDocument.FileType, ContentDocument.ContentSize,
                       ContentDocument.LastModifiedDate
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :recordId
                WITH USER_MODE
                ORDER BY ContentDocument.LastModifiedDate DESC
                LIMIT 50
            ]) {
                DocumentResult dr  = new DocumentResult();
                dr.documentId      = cdl.ContentDocument.Id;
                dr.title           = cdl.ContentDocument.Title;
                dr.fileType        = cdl.ContentDocument.FileType;
                dr.fileSizeKb      = cdl.ContentDocument.ContentSize != null
                                     ? (Integer)(cdl.ContentDocument.ContentSize / 1024)
                                     : 0;
                dr.lastModified    = cdl.ContentDocument.LastModifiedDate;
                results.add(dr);
            }
            return results;
        } catch (Exception ex) {
            throw new AuraHandledException(
                'ProcessNavigatorController.getRelatedDocuments: ' + ex.getMessage()
            );
        }
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private static Boolean evaluateConditions(
        SObject record,
        List<Process_Condition__c> conditions
    ) {
        if (conditions == null || conditions.isEmpty()) {
            return true; // no conditions = always matches
        }
        if (record == null) {
            return false;
        }
        for (Process_Condition__c cond : conditions) {
            if (!evaluateCondition(record, cond)) {
                return false; // AND logic — all must pass
            }
        }
        return true;
    }

    private static Boolean evaluateCondition(SObject record, Process_Condition__c cond) {
        Object rawValue;
        try {
            rawValue = record.get(cond.Field_API_Name__c.trim());
        } catch (Exception e) {
            return false; // field not on record
        }

        String recordValue  = rawValue != null ? String.valueOf(rawValue) : '';
        String targetValue  = cond.Value__c != null ? cond.Value__c : '';
        String op           = cond.Operator__c;

        if (op == 'Equals')     return recordValue.equalsIgnoreCase(targetValue);
        if (op == 'Not_Equals') return !recordValue.equalsIgnoreCase(targetValue);
        if (op == 'Contains')   return recordValue.containsIgnoreCase(targetValue);
        if (op == 'Not_Contains') return !recordValue.containsIgnoreCase(targetValue);

        // Numeric comparisons
        try {
            Decimal recNum = Decimal.valueOf(recordValue);
            Decimal tgtNum = Decimal.valueOf(targetValue);
            if (op == 'Greater_Than')          return recNum >  tgtNum;
            if (op == 'Less_Than')             return recNum <  tgtNum;
            if (op == 'Greater_Than_Or_Equal') return recNum >= tgtNum;
            if (op == 'Less_Than_Or_Equal')    return recNum <= tgtNum;
        } catch (TypeException te) {
            return false; // non-numeric value for numeric operator
        }

        return false;
    }
}
