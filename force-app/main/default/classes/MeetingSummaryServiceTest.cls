@isTest
private class MeetingSummaryServiceTest {

    // ------------------------------------------------------------------
    // Test data helpers
    // ------------------------------------------------------------------

    private static Account createAccount() {
        Account acc = new Account(Name = 'Bedrock Enterprises Test');
        insert acc;
        return acc;
    }

    private static void createMeetingMinutes(Id accountId, Integer count) {
        List<Meeting_Minutes__c> minutes = new List<Meeting_Minutes__c>();
        for (Integer i = 0; i < count; i++) {
            minutes.add(new Meeting_Minutes__c(
                Name         = 'Meeting ' + i,
                Account__c   = accountId,
                Meeting_Date__c = Date.today().addDays(-i),
                Topics_Discussed__c = 'Portfolio review, risk assessment',
                Notes__c     = 'Client discussed interest in emerging markets. Action: send report by end of week.'
            ));
        }
        insert minutes;
    }

    // ------------------------------------------------------------------
    // resolveLanguage
    // ------------------------------------------------------------------

    @isTest
    static void testResolveLanguage_explicit() {
        String lang = MeetingSummaryService.resolveLanguage('FR');
        System.assertEquals('fr', lang, 'Explicit language should be lowercased');
    }

    @isTest
    static void testResolveLanguage_fromLocale() {
        // UserInfo.getLocale() returns something like en_US in test context
        String lang = MeetingSummaryService.resolveLanguage(null);
        System.assert(lang.length() == 2, 'Language code derived from locale should be 2 chars');
    }

    @isTest
    static void testResolveLanguage_blank() {
        String lang = MeetingSummaryService.resolveLanguage('  ');
        System.assert(String.isNotBlank(lang), 'Blank input should fall back to locale');
    }

    // ------------------------------------------------------------------
    // buildPrompt
    // ------------------------------------------------------------------

    @isTest
    static void testBuildPrompt_containsKeyParts() {
        String prompt = MeetingSummaryService.buildPrompt('What products?', 'Notes here', 'en');
        System.assert(prompt.contains('What products?'), 'Prompt should include the question');
        System.assert(prompt.contains('Notes here'),     'Prompt should include the context');
        System.assert(prompt.contains('en'),             'Prompt should specify language');
        System.assert(prompt.contains('ANSWER:'),        'Prompt should end with ANSWER: marker');
    }

    @isTest
    static void testBuildPrompt_noHallucinationInstruction() {
        String prompt = MeetingSummaryService.buildPrompt('Q', 'C', 'de');
        System.assert(prompt.contains('Do not fabricate'), 'Hallucination guard instruction must be present');
    }

    // ------------------------------------------------------------------
    // fetchMeetingContext
    // ------------------------------------------------------------------

    @isTest
    static void testFetchMeetingContext_returnsData() {
        Account acc = createAccount();
        createMeetingMinutes(acc.Id, 3);

        Test.startTest();
        String ctx = MeetingSummaryService.fetchMeetingContext(acc.Id, 5);
        Test.stopTest();

        System.assert(String.isNotBlank(ctx), 'Context should not be blank when minutes exist');
        System.assert(ctx.contains('Portfolio review'), 'Context should include topics');
    }

    @isTest
    static void testFetchMeetingContext_noRecords() {
        Account acc = createAccount();

        Test.startTest();
        String ctx = MeetingSummaryService.fetchMeetingContext(acc.Id, 5);
        Test.stopTest();

        System.assertEquals(null, ctx, 'Context should be null when no minutes exist');
    }

    @isTest
    static void testFetchMeetingContext_respectsMaxRecords() {
        Account acc = createAccount();
        createMeetingMinutes(acc.Id, 10);

        Test.startTest();
        String ctx = MeetingSummaryService.fetchMeetingContext(acc.Id, 2);
        Test.stopTest();

        // Each record is separated by ---; 2 records = 1 separator
        Integer separatorCount = ctx.countMatches('---');
        System.assertEquals(1, separatorCount, 'Should retrieve exactly 2 records (1 separator)');
    }

    @isTest
    static void testFetchMeetingContext_truncatesLargeNotes() {
        Account acc = createAccount();
        // Create a single record whose notes exceed MAX_CONTEXT_CHARS
        String hugeNotes = 'X'.repeat(10000);
        insert new Meeting_Minutes__c(
            Name = 'Big Meeting',
            Account__c = acc.Id,
            Meeting_Date__c = Date.today(),
            Notes__c = hugeNotes
        );

        Test.startTest();
        String ctx = MeetingSummaryService.fetchMeetingContext(acc.Id, 1);
        Test.stopTest();

        System.assert(ctx.length() <= MeetingSummaryService.MAX_CONTEXT_CHARS + 50,
            'Context should be truncated to stay near the character limit');
    }

    // ------------------------------------------------------------------
    // generateSummary — validation errors
    // ------------------------------------------------------------------

    @isTest
    static void testGenerateSummary_missingAccountId() {
        MeetingSummaryService.SummaryRequest req = new MeetingSummaryService.SummaryRequest();
        req.advisorQuestion = 'Summarize engagement';

        Test.startTest();
        List<MeetingSummaryService.SummaryResponse> results =
            MeetingSummaryService.generateSummary(new List<MeetingSummaryService.SummaryRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true,  results[0].isError);
        System.assert(String.isNotBlank(results[0].errorMessage));
    }

    @isTest
    static void testGenerateSummary_blankQuestion() {
        Account acc = createAccount();
        MeetingSummaryService.SummaryRequest req = new MeetingSummaryService.SummaryRequest();
        req.accountId = acc.Id;
        req.advisorQuestion = '';

        Test.startTest();
        List<MeetingSummaryService.SummaryResponse> results =
            MeetingSummaryService.generateSummary(new List<MeetingSummaryService.SummaryRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].isError);
    }

    // ------------------------------------------------------------------
    // generateSummary — no meeting minutes
    // ------------------------------------------------------------------

    @isTest
    static void testGenerateSummary_noMinutes_returnsNoDataMessage() {
        Account acc = createAccount();
        MeetingSummaryService.SummaryRequest req = new MeetingSummaryService.SummaryRequest();
        req.accountId = acc.Id;
        req.advisorQuestion = 'What was discussed?';
        req.responseLanguage = 'en';

        Test.startTest();
        List<MeetingSummaryService.SummaryResponse> results =
            MeetingSummaryService.generateSummary(new List<MeetingSummaryService.SummaryRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].isError);
        System.assert(results[0].summary.containsIgnoreCase('No meeting minutes'),
            'Should return no-data message when account has no minutes');
    }

    @isTest
    static void testGenerateSummary_noMinutes_frenchLocale() {
        Account acc = createAccount();
        MeetingSummaryService.SummaryRequest req = new MeetingSummaryService.SummaryRequest();
        req.accountId = acc.Id;
        req.advisorQuestion = 'Résumé?';
        req.responseLanguage = 'fr';

        Test.startTest();
        List<MeetingSummaryService.SummaryResponse> results =
            MeetingSummaryService.generateSummary(new List<MeetingSummaryService.SummaryRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].isError);
        System.assert(results[0].summary.containsIgnoreCase('réunion'),
            'French language should return French no-data message');
    }

    // ------------------------------------------------------------------
    // generateSummary — maxRecords cap
    // ------------------------------------------------------------------

    @isTest
    static void testGenerateSummary_maxRecordsCappedAt20() {
        Account acc = createAccount();
        MeetingSummaryService.SummaryRequest req = new MeetingSummaryService.SummaryRequest();
        req.accountId = acc.Id;
        req.advisorQuestion = 'Summary?';
        req.maxRecords = 999;

        // No records → returns no-data message without errors
        Test.startTest();
        List<MeetingSummaryService.SummaryResponse> results =
            MeetingSummaryService.generateSummary(new List<MeetingSummaryService.SummaryRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].isError,
            'Request with maxRecords=999 should not error — it gets capped to 20');
    }

    // ------------------------------------------------------------------
    // Bulk invocation
    // ------------------------------------------------------------------

    @isTest
    static void testGenerateSummary_bulkRequests() {
        Account acc = createAccount();
        List<MeetingSummaryService.SummaryRequest> reqs = new List<MeetingSummaryService.SummaryRequest>();
        for (Integer i = 0; i < 5; i++) {
            MeetingSummaryService.SummaryRequest req = new MeetingSummaryService.SummaryRequest();
            req.accountId = acc.Id;
            req.advisorQuestion = 'Question ' + i;
            reqs.add(req);
        }

        Test.startTest();
        List<MeetingSummaryService.SummaryResponse> results =
            MeetingSummaryService.generateSummary(reqs);
        Test.stopTest();

        System.assertEquals(5, results.size(), 'Bulk invocation should return one response per request');
    }
}
