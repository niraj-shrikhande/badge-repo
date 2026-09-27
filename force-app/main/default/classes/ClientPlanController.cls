public with sharing class ClientPlanController {

    // Growth markets: high-growth regions by revenue trajectory or strategic priority
    private static final Set<String> GROWTH_MARKETS = new Set<String>{
        'India', 'Saudi Arabia', 'United Arab Emirates', 'Japan', 'Singapore'
    };

    public class AccountLocation {
        @AuraEnabled public String name;
        @AuraEnabled public String city;
        @AuraEnabled public String country;
        @AuraEnabled public String street;
        @AuraEnabled public String postalCode;
        @AuraEnabled public Boolean isGrowthMarket;
        @AuraEnabled public Boolean isHQ;
    }

    public class ClientPlanData {
        @AuraEnabled public Account account;
        @AuraEnabled public Contact primaryContact;
        @AuraEnabled public List<Opportunity> opportunities;
        @AuraEnabled public List<Entitlement> entitlements;
        @AuraEnabled public Decimal totalPipelineValue;
        @AuraEnabled public Integer openOpportunityCount;
        @AuraEnabled public Integer activeEntitlementCount;
        @AuraEnabled public List<AccountLocation> globalPresence;
        @AuraEnabled public Integer growthMarketCount;
    }

    @AuraEnabled(cacheable=true)
    public static ClientPlanData getClientPlanData(Id accountId) {
        ClientPlanData data = new ClientPlanData();

        data.account = [
            SELECT Id, Name, Industry, Phone, Website, BillingStreet,
                   BillingCity, BillingState, BillingPostalCode, BillingCountry,
                   NumberOfEmployees, AnnualRevenue, Type, OwnerId, Owner.Name,
                   Description
            FROM Account
            WHERE Id = :accountId
            WITH USER_MODE
            LIMIT 1
        ];

        List<Contact> contacts = [
            SELECT Id, FirstName, LastName, Title, Email, Phone, MobilePhone
            FROM Contact
            WHERE AccountId = :accountId
            WITH USER_MODE
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        data.primaryContact = contacts.isEmpty() ? null : contacts[0];

        data.opportunities = [
            SELECT Id, Name, StageName, Amount, CloseDate, Probability, OwnerId, Owner.Name
            FROM Opportunity
            WHERE AccountId = :accountId
              AND IsClosed = false
            WITH USER_MODE
            ORDER BY CloseDate ASC
            LIMIT 50
        ];

        Decimal total = 0;
        for (Opportunity opp : data.opportunities) {
            if (opp.Amount != null) total += opp.Amount;
        }
        data.totalPipelineValue = total;
        data.openOpportunityCount = data.opportunities.size();

        data.entitlements = [
            SELECT Id, Name, Status, StartDate, EndDate, AssetId, Asset.Name, Type
            FROM Entitlement
            WHERE AccountId = :accountId
              AND Status = 'Active'
            WITH USER_MODE
            ORDER BY EndDate ASC
            LIMIT 50
        ];
        data.activeEntitlementCount = data.entitlements.size();

        // Build global presence: HQ + all child accounts with billing addresses
        data.globalPresence = new List<AccountLocation>();
        Integer growthCount = 0;

        AccountLocation hqLocation = new AccountLocation();
        hqLocation.name = data.account.Name;
        hqLocation.city = data.account.BillingCity;
        hqLocation.country = data.account.BillingCountry;
        hqLocation.street = data.account.BillingStreet;
        hqLocation.postalCode = data.account.BillingPostalCode;
        hqLocation.isHQ = true;
        hqLocation.isGrowthMarket = false;
        data.globalPresence.add(hqLocation);

        List<Account> childAccounts = [
            SELECT Id, Name, BillingStreet, BillingCity, BillingPostalCode, BillingCountry
            FROM Account
            WHERE ParentId = :accountId
              AND BillingCountry != null
            WITH USER_MODE
            ORDER BY Name ASC
        ];

        for (Account child : childAccounts) {
            AccountLocation loc = new AccountLocation();
            loc.name = child.Name;
            loc.city = child.BillingCity;
            loc.country = child.BillingCountry;
            loc.street = child.BillingStreet;
            loc.postalCode = child.BillingPostalCode;
            loc.isHQ = false;
            loc.isGrowthMarket = GROWTH_MARKETS.contains(child.BillingCountry);
            if (loc.isGrowthMarket) growthCount++;
            data.globalPresence.add(loc);
        }

        data.growthMarketCount = growthCount;

        return data;
    }
}
