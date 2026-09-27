public class CaseAutoAssignment {

    @InvocableMethod
    public static void caseAssgnmntRules(List<Id> caseIds){

        /*AssignmentRule AR = [SELECT Id FROM AssignmentRule WHERE SobjectType = 'Case' AND Active = true LIMIT 1];
		Database.DMLOptions dmlOpts = new Database.DMLOptions();
		dmlOpts.assignmentRuleHeader.assignmentRuleId = AR.id;
		
        System.debug('caseAssgnmntRules' + AR.ID);
        Case caseCreated=[select id,OwnerID from Case where id in :caseIds];
        caseCreated.setOptions(dmlOpts);
        update caseCreated;*/
        
        Case caseCreated=[select id,Type,OwnerID,Region__c from Case where id in :caseIds];
        
        string name = caseCreated.Type +' ' + caseCreated.Region__c;
        Group caseQueue = [SELECT Id FROM Group WHERE Type = 'Queue' AND Name =: name];
        
        caseCreated.OwnerId = caseQueue.Id;
        update caseCreated;

        System.debug('caseAssgnmntRules' + caseCreated.OwnerID);

   }
   
   
}