public class LeadAutoAssignment {

    @InvocableMethod
   public static void leadAssgnmntRules(List<Id> leadIds){

        AssignmentRule AR = [SELECT Id FROM AssignmentRule WHERE SobjectType = 'Lead' AND Active = true LIMIT 1];
		Database.DMLOptions dmo = new Database.DMLOptions();
		dmo.assignmentRuleHeader.useDefaultRule= true;

		
        System.debug('lead rules' + AR.ID);
        Lead leadCreated=[select id  from Lead where id in :leadIds];
        leadCreated.setOptions(dmo);
        update leadCreated;
   }
}