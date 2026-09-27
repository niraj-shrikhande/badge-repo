public with sharing class AccountRelationshipsController {

    public class AccountRelationshipWrapper {
        @AuraEnabled public Id      accountId;
        @AuraEnabled public String  accountName;
        @AuraEnabled public String  industry;
        @AuraEnabled public Integer employeeCount;
        @AuraEnabled public Decimal lifetimeValue;
        @AuraEnabled public Integer contactCount;
        @AuraEnabled public Boolean isDirect;
    }

    @AuraEnabled(cacheable=true)
    public static List<AccountRelationshipWrapper> getRelatedAccounts(
        Id      accountId,
        Integer maxItems,
        String  sortBy
    ) {
        if (accountId == null) {
            return new List<AccountRelationshipWrapper>();
        }

        try {
            // Step 1: collect every ContactId linked to the source account via ACR
            Set<Id> sharedContactIds = new Set<Id>();
            for (AccountContactRelation acr : [
                SELECT ContactId
                FROM   AccountContactRelation
                WHERE  AccountId = :accountId
                WITH   USER_MODE
            ]) {
                sharedContactIds.add(acr.ContactId);
            }

            if (sharedContactIds.isEmpty()) {
                return new List<AccountRelationshipWrapper>();
            }

            // Step 2: find all OTHER accounts those contacts belong to,
            //         counting how many shared contacts each has
            Map<Id, Integer> relatedAccountContactCount = new Map<Id, Integer>();
            for (AccountContactRelation acr : [
                SELECT AccountId
                FROM   AccountContactRelation
                WHERE  ContactId IN :sharedContactIds
                AND    AccountId != :accountId
                WITH   USER_MODE
            ]) {
                Integer cnt = relatedAccountContactCount.get(acr.AccountId);
                relatedAccountContactCount.put(acr.AccountId, cnt == null ? 1 : cnt + 1);
            }

            if (relatedAccountContactCount.isEmpty()) {
                return new List<AccountRelationshipWrapper>();
            }

            Set<Id> relatedAccountIds = relatedAccountContactCount.keySet();

            // Step 3: fetch Account details
            Map<Id, Account> accountsMap = new Map<Id, Account>([
                SELECT Id, Name, Industry, NumberOfEmployees, ParentId
                FROM   Account
                WHERE  Id IN :relatedAccountIds
                WITH   USER_MODE
            ]);

            // Step 4: closed-won lifetime value per account
            Map<Id, Decimal> ltvMap = new Map<Id, Decimal>();
            for (AggregateResult ar : [
                SELECT AccountId acctId, SUM(Amount) total
                FROM   Opportunity
                WHERE  AccountId IN :relatedAccountIds
                  AND  StageName = 'Closed Won'
                WITH   USER_MODE
                GROUP  BY AccountId
            ]) {
                ltvMap.put((Id) ar.get('acctId'), (Decimal) ar.get('total'));
            }

            // Step 5: source account's parent for the isDirect flag
            Id sourceParentId = null;
            List<Account> srcAcct = [
                SELECT ParentId FROM Account WHERE Id = :accountId
                WITH USER_MODE LIMIT 1
            ];
            if (!srcAcct.isEmpty()) {
                sourceParentId = srcAcct[0].ParentId;
            }

            // Step 6: assemble wrappers
            List<AccountRelationshipWrapper> results =
                new List<AccountRelationshipWrapper>();

            for (Id relId : relatedAccountContactCount.keySet()) {
                Account acct = accountsMap.get(relId);
                if (acct == null) continue;

                AccountRelationshipWrapper w = new AccountRelationshipWrapper();
                w.accountId     = acct.Id;
                w.accountName   = acct.Name;
                w.industry      = acct.Industry;
                w.employeeCount = (Integer) acct.NumberOfEmployees;
                w.lifetimeValue = ltvMap.containsKey(relId) ? ltvMap.get(relId) : 0;
                w.contactCount  = relatedAccountContactCount.get(relId);
                w.isDirect      = (sourceParentId != null && sourceParentId == relId) ||
                                  (acct.ParentId  != null && acct.ParentId  == accountId);
                results.add(w);
            }

            // Step 7: sort
            if (sortBy == 'contactCount') {
                results.sort(new ContactCountComparator());
            } else {
                results.sort(new NameComparator());
            }

            // Step 8: apply maxItems
            if (maxItems != null && maxItems > 0 && results.size() > maxItems) {
                List<AccountRelationshipWrapper> limited =
                    new List<AccountRelationshipWrapper>();
                for (Integer i = 0; i < maxItems; i++) {
                    limited.add(results[i]);
                }
                return limited;
            }

            return results;

        } catch (Exception ex) {
            throw new AuraHandledException(
                'AccountRelationshipsController error: ' + ex.getMessage()
            );
        }
    }

    private class NameComparator implements Comparator<AccountRelationshipWrapper> {
        public Integer compare(AccountRelationshipWrapper a, AccountRelationshipWrapper b) {
            String na = a.accountName == null ? '' : a.accountName.toLowerCase();
            String nb = b.accountName == null ? '' : b.accountName.toLowerCase();
            if (na < nb) return -1;
            if (na > nb) return  1;
            return 0;
        }
    }

    private class ContactCountComparator implements Comparator<AccountRelationshipWrapper> {
        public Integer compare(AccountRelationshipWrapper a, AccountRelationshipWrapper b) {
            Integer ca = a.contactCount == null ? 0 : a.contactCount;
            Integer cb = b.contactCount == null ? 0 : b.contactCount;
            if (ca > cb) return -1;
            if (ca < cb) return  1;
            String na = a.accountName == null ? '' : a.accountName.toLowerCase();
            String nb = b.accountName == null ? '' : b.accountName.toLowerCase();
            if (na < nb) return -1;
            if (na > nb) return  1;
            return 0;
        }
    }
}
