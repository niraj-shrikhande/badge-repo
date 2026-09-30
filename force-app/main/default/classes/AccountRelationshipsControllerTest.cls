@isTest
private class AccountRelationshipsControllerTest {

    // ------------------------------------------------------------------
    // Test data helpers
    // ------------------------------------------------------------------

    private static Account createAccount(String name) {
        return createAccount(name, null);
    }

    private static Account createAccount(String name, Id parentId) {
        Account acc = new Account(
            Name              = name,
            Industry          = 'Technology',
            NumberOfEmployees = 100,
            ParentId          = parentId
        );
        insert acc;
        return acc;
    }

    private static Contact createContact(Id accountId, String lastName) {
        Contact c = new Contact(LastName = lastName, AccountId = accountId);
        insert c;
        return c;
    }

    // Links an existing contact to another account via an indirect ACR.
    private static void linkContactToAccount(Id contactId, Id accountId) {
        insert new AccountContactRelation(
            ContactId = contactId,
            AccountId = accountId
        );
    }

    private static void createClosedWonOpp(Id accountId, Decimal amount) {
        insert new Opportunity(
            Name      = 'Opp ' + accountId,
            AccountId = accountId,
            StageName = 'Closed Won',
            Amount    = amount,
            CloseDate = Date.today()
        );
    }

    // ------------------------------------------------------------------
    // Guard clauses / empty results
    // ------------------------------------------------------------------

    @isTest
    static void testNullAccountId_returnsEmpty() {
        Test.startTest();
        List<AccountRelationshipsController.AccountRelationshipWrapper> results =
            AccountRelationshipsController.getRelatedAccounts(null, 10, 'name');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Null accountId should return an empty list');
    }

    @isTest
    static void testNoSharedContacts_returnsEmpty() {
        Account source = createAccount('Source Account');

        Test.startTest();
        List<AccountRelationshipsController.AccountRelationshipWrapper> results =
            AccountRelationshipsController.getRelatedAccounts(source.Id, 10, 'name');
        Test.stopTest();

        System.assertEquals(0, results.size(),
            'Account with no contacts should return an empty list');
    }

    @isTest
    static void testContactsButNoOtherAccounts_returnsEmpty() {
        Account source = createAccount('Source Account');
        // Contact belongs only to the source account (direct ACR only)
        createContact(source.Id, 'Solo');

        Test.startTest();
        List<AccountRelationshipsController.AccountRelationshipWrapper> results =
            AccountRelationshipsController.getRelatedAccounts(source.Id, 10, 'name');
        Test.stopTest();

        System.assertEquals(0, results.size(),
            'When contacts do not belong to any other account, result should be empty');
    }

    // ------------------------------------------------------------------
    // Happy path
    // ------------------------------------------------------------------

    @isTest
    static void testRelatedAccounts_basic() {
        Account source  = createAccount('Source Account');
        Account related = createAccount('Related Account');
        Contact c       = createContact(source.Id, 'Shared');
        linkContactToAccount(c.Id, related.Id);
        createClosedWonOpp(related.Id, 5000);

        Test.startTest();
        List<AccountRelationshipsController.AccountRelationshipWrapper> results =
            AccountRelationshipsController.getRelatedAccounts(source.Id, 10, 'name');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Exactly one related account expected');
        AccountRelationshipsController.AccountRelationshipWrapper w = results[0];
        System.assertEquals(related.Id, w.accountId, 'Related account id should match');
        System.assertEquals('Related Account', w.accountName);
        System.assertEquals('Technology', w.industry);
        System.assertEquals(100, w.employeeCount);
        System.assertEquals(5000, w.lifetimeValue, 'LTV should sum closed-won opportunities');
        System.assertEquals(1, w.contactCount, 'One shared contact expected');
    }

    @isTest
    static void testLifetimeValue_defaultsToZeroWithoutOpps() {
        Account source  = createAccount('Source Account');
        Account related = createAccount('Related Account');
        Contact c       = createContact(source.Id, 'Shared');
        linkContactToAccount(c.Id, related.Id);

        Test.startTest();
        List<AccountRelationshipsController.AccountRelationshipWrapper> results =
            AccountRelationshipsController.getRelatedAccounts(source.Id, 10, 'name');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(0, results[0].lifetimeValue,
            'Related account with no closed-won opps should have LTV of 0');
    }

    @isTest
    static void testContactCount_multipleSharedContacts() {
        Account source  = createAccount('Source Account');
        Account related = createAccount('Related Account');

        Contact c1 = createContact(source.Id, 'One');
        Contact c2 = createContact(source.Id, 'Two');
        linkContactToAccount(c1.Id, related.Id);
        linkContactToAccount(c2.Id, related.Id);

        Test.startTest();
        List<AccountRelationshipsController.AccountRelationshipWrapper> results =
            AccountRelationshipsController.getRelatedAccounts(source.Id, 10, 'name');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(2, results[0].contactCount,
            'Both shared contacts should be counted for the related account');
    }

    // ------------------------------------------------------------------
    // isDirect flag
    // ------------------------------------------------------------------

    @isTest
    static void testIsDirect_childOfSource() {
        Account source = createAccount('Source Account');
        // related account's parent IS the source → direct
        Account related = createAccount('Child Account', source.Id);
        Contact c       = createContact(source.Id, 'Shared');
        linkContactToAccount(c.Id, related.Id);

        Test.startTest();
        List<AccountRelationshipsController.AccountRelationshipWrapper> results =
            AccountRelationshipsController.getRelatedAccounts(source.Id, 10, 'name');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].isDirect,
            'A child of the source account should be flagged direct');
    }

    @isTest
    static void testIsDirect_parentOfSource() {
        Account parent = createAccount('Parent Account');
        Account source = createAccount('Source Account', parent.Id);
        Contact c      = createContact(source.Id, 'Shared');
        linkContactToAccount(c.Id, parent.Id);

        Test.startTest();
        List<AccountRelationshipsController.AccountRelationshipWrapper> results =
            AccountRelationshipsController.getRelatedAccounts(source.Id, 10, 'name');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].isDirect,
            'The source account parent should be flagged direct');
    }

    @isTest
    static void testIsDirect_falseForUnrelatedHierarchy() {
        Account source  = createAccount('Source Account');
        Account related = createAccount('Related Account');
        Contact c       = createContact(source.Id, 'Shared');
        linkContactToAccount(c.Id, related.Id);

        Test.startTest();
        List<AccountRelationshipsController.AccountRelationshipWrapper> results =
            AccountRelationshipsController.getRelatedAccounts(source.Id, 10, 'name');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].isDirect,
            'Accounts with no parent/child link should not be direct');
    }

    // ------------------------------------------------------------------
    // Sorting
    // ------------------------------------------------------------------

    @isTest
    static void testSortByName() {
        Account source = createAccount('Source Account');
        Account zebra  = createAccount('Zebra Corp');
        Account alpha  = createAccount('Alpha Corp');
        Contact c      = createContact(source.Id, 'Shared');
        linkContactToAccount(c.Id, zebra.Id);
        linkContactToAccount(c.Id, alpha.Id);

        Test.startTest();
        List<AccountRelationshipsController.AccountRelationshipWrapper> results =
            AccountRelationshipsController.getRelatedAccounts(source.Id, 10, 'name');
        Test.stopTest();

        System.assertEquals(2, results.size());
        System.assertEquals('Alpha Corp', results[0].accountName,
            'Name sort should place Alpha before Zebra');
        System.assertEquals('Zebra Corp', results[1].accountName);
    }

    @isTest
    static void testSortByContactCount() {
        Account source = createAccount('Source Account');
        Account few    = createAccount('Few Contacts');
        Account many   = createAccount('Many Contacts');

        Contact c1 = createContact(source.Id, 'One');
        Contact c2 = createContact(source.Id, 'Two');

        // "few" gets 1 shared contact, "many" gets 2
        linkContactToAccount(c1.Id, few.Id);
        linkContactToAccount(c1.Id, many.Id);
        linkContactToAccount(c2.Id, many.Id);

        Test.startTest();
        List<AccountRelationshipsController.AccountRelationshipWrapper> results =
            AccountRelationshipsController.getRelatedAccounts(source.Id, 10, 'contactCount');
        Test.stopTest();

        System.assertEquals(2, results.size());
        System.assertEquals('Many Contacts', results[0].accountName,
            'contactCount sort should place the account with more shared contacts first');
        System.assertEquals(2, results[0].contactCount);
        System.assertEquals(1, results[1].contactCount);
    }

    // ------------------------------------------------------------------
    // maxItems
    // ------------------------------------------------------------------

    @isTest
    static void testMaxItems_limitsResults() {
        Account source = createAccount('Source Account');
        Contact c      = createContact(source.Id, 'Shared');

        for (Integer i = 0; i < 5; i++) {
            Account related = createAccount('Related ' + i);
            linkContactToAccount(c.Id, related.Id);
        }

        Test.startTest();
        List<AccountRelationshipsController.AccountRelationshipWrapper> results =
            AccountRelationshipsController.getRelatedAccounts(source.Id, 3, 'name');
        Test.stopTest();

        System.assertEquals(3, results.size(), 'maxItems should cap the result list to 3');
    }

    @isTest
    static void testMaxItems_nullReturnsAll() {
        Account source = createAccount('Source Account');
        Contact c      = createContact(source.Id, 'Shared');

        for (Integer i = 0; i < 4; i++) {
            Account related = createAccount('Related ' + i);
            linkContactToAccount(c.Id, related.Id);
        }

        Test.startTest();
        List<AccountRelationshipsController.AccountRelationshipWrapper> results =
            AccountRelationshipsController.getRelatedAccounts(source.Id, null, 'name');
        Test.stopTest();

        System.assertEquals(4, results.size(),
            'A null maxItems should return every related account');
    }
}
