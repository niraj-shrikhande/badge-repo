/**
 * Invocable Apex service called from Screen Flows to generate AI-driven summaries
 * of past meeting minutes for a given Account.
 *
 * Addresses three challenges the pure-Flow approach cannot solve:
 *  1. Dynamic language — response language adapts to the running user's locale.
 *  2. Logging & traceability — every invocation is captured in the debug log with
 *     a correlation ID so support can trace failures end-to-end.
 *  3. Robust error handling — AI and SOQL failures are caught, logged, and returned
 *     as a user-friendly message rather than an unhandled flow error.
 */
public with sharing class MeetingSummaryService {

    // Max characters of meeting notes fed to the model to stay within prompt limits.
    @TestVisible
    private static final Integer MAX_CONTEXT_CHARS = 6000;

    // -----------------------------------------------------------------
    // Invocable input / output wrappers
    // -----------------------------------------------------------------

    public class SummaryRequest {
        @InvocableVariable(label='Account Id' required=true)
        public Id accountId;

        @InvocableVariable(label='Advisor Question' required=true)
        public String advisorQuestion;

        /** ISO language tag (e.g. en, fr, de, es). Falls back to user locale. */
        @InvocableVariable(label='Response Language (optional)')
        public String responseLanguage;

        /** How many recent meeting records to retrieve (default 5, max 20). */
        @InvocableVariable(label='Max Meeting Records (optional)')
        public Integer maxRecords;
    }

    public class SummaryResponse {
        @InvocableVariable(label='AI Summary')
        public String summary;

        @InvocableVariable(label='Is Error')
        public Boolean isError;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    // -----------------------------------------------------------------
    // Invocable entry point
    // -----------------------------------------------------------------

    @InvocableMethod(
        label='Generate Meeting Summary'
        description='RAG-based AI summary of meeting minutes for an Account. Supports dynamic language and structured error handling.'
        category='AI'
    )
    public static List<SummaryResponse> generateSummary(List<SummaryRequest> requests) {
        List<SummaryResponse> responses = new List<SummaryResponse>();
        for (SummaryRequest req : requests) {
            responses.add(processRequest(req));
        }
        return responses;
    }

    // -----------------------------------------------------------------
    // Core logic
    // -----------------------------------------------------------------

    private static SummaryResponse processRequest(SummaryRequest req) {
        String correlationId = generateCorrelationId();
        SummaryResponse res = new SummaryResponse();
        res.isError = false;

        try {
            // 1. Validate inputs
            if (req.accountId == null || String.isBlank(req.advisorQuestion)) {
                throw new IllegalArgumentException('accountId and advisorQuestion are required.');
            }

            // 2. Resolve language
            String lang = resolveLanguage(req.responseLanguage);
            System.debug(LoggingLevel.INFO,
                '[MeetingSummaryService][' + correlationId + '] lang=' + lang
                + ' accountId=' + req.accountId);

            // 3. Retrieve meeting minutes (RAG retrieval step)
            Integer recordLimit = (req.maxRecords != null && req.maxRecords > 0)
                ? Math.min(req.maxRecords, 20)
                : 5;
            String context = fetchMeetingContext(req.accountId, recordLimit);

            if (String.isBlank(context)) {
                res.summary = buildNoDataMessage(lang);
                return res;
            }

            // 4. Build prompt
            String prompt = buildPrompt(req.advisorQuestion, context, lang);
            System.debug(LoggingLevel.FINE,
                '[MeetingSummaryService][' + correlationId + '] prompt length=' + prompt.length());

            // 5. Call AI model via existing LLMService
            String aiResponse = LLMService.generateText(prompt);
            System.debug(LoggingLevel.INFO,
                '[MeetingSummaryService][' + correlationId + '] AI response received, length=' + aiResponse.length());

            // 6. Basic hallucination guard — reject responses that echo the prompt verbatim
            if (aiResponse.length() < 20 || aiResponse.startsWith(prompt.left(30))) {
                throw new AiResponseException('AI returned an unusable response.');
            }

            res.summary = aiResponse;

        } catch (IllegalArgumentException e) {
            logError(correlationId, 'Validation', e);
            res.isError = true;
            res.errorMessage = e.getMessage();

        } catch (AiResponseException e) {
            logError(correlationId, 'AIResponse', e);
            res.isError = true;
            res.errorMessage = 'The AI could not generate a valid summary. Please try again.';

        } catch (Exception e) {
            logError(correlationId, 'Unexpected', e);
            res.isError = true;
            res.errorMessage = 'An unexpected error occurred. Reference: ' + correlationId;
        }

        return res;
    }

    // -----------------------------------------------------------------
    // RAG retrieval
    // -----------------------------------------------------------------

    @TestVisible
    private static String fetchMeetingContext(Id accountId, Integer maxRecords) {
        List<Meeting_Minutes__c> minutes = [
            SELECT Name, Meeting_Date__c, Topics_Discussed__c, Notes__c
            FROM Meeting_Minutes__c
            WHERE Account__c = :accountId
            ORDER BY Meeting_Date__c DESC
            LIMIT :maxRecords
        ];

        if (minutes.isEmpty()) {
            return null;
        }

        Integer totalChars = 0;
        List<String> sections = new List<String>();

        for (Meeting_Minutes__c m : minutes) {
            String section =
                'Date: ' + (m.Meeting_Date__c != null ? String.valueOf(m.Meeting_Date__c) : 'Unknown') + '\n' +
                'Topics: ' + (m.Topics_Discussed__c != null ? m.Topics_Discussed__c : '') + '\n' +
                'Notes: ' + (m.Notes__c != null ? m.Notes__c : '');

            // Truncate individual record contribution to keep total prompt manageable
            if (totalChars + section.length() > MAX_CONTEXT_CHARS) {
                Integer remaining = MAX_CONTEXT_CHARS - totalChars;
                if (remaining > 100) {
                    sections.add(section.left(remaining) + '... [truncated]');
                }
                break;
            }

            sections.add(section);
            totalChars += section.length();
        }

        return String.join(sections, '\n---\n');
    }

    // -----------------------------------------------------------------
    // Prompt construction
    // -----------------------------------------------------------------

    @TestVisible
    private static String buildPrompt(String question, String context, String lang) {
        return 'You are a helpful financial advisor assistant. '
            + 'Answer the following question using ONLY the meeting notes provided below. '
            + 'Do not fabricate information not present in the notes. '
            + 'Be concise and factual. '
            + 'Respond exclusively in the language: ' + lang + '.\n\n'
            + 'MEETING NOTES:\n' + context + '\n\n'
            + 'ADVISOR QUESTION:\n' + question + '\n\n'
            + 'ANSWER:';
    }

    // -----------------------------------------------------------------
    // Language resolution
    // -----------------------------------------------------------------

    @TestVisible
    private static String resolveLanguage(String requested) {
        if (String.isNotBlank(requested)) {
            return requested.trim().toLowerCase();
        }
        // Derive from running user's locale (e.g. en_US → en, fr_FR → fr)
        String locale = UserInfo.getLocale();
        return locale.contains('_') ? locale.substringBefore('_').toLowerCase() : locale.toLowerCase();
    }

    // -----------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------

    private static String buildNoDataMessage(String lang) {
        // Simple multi-language fallback for the no-data case
        Map<String, String> messages = new Map<String, String>{
            'fr' => 'Aucun compte rendu de réunion trouvé pour ce client.',
            'de' => 'Keine Besprechungsnotizen für diesen Kunden gefunden.',
            'es' => 'No se encontraron actas de reunión para este cliente.'
        };
        return messages.containsKey(lang)
            ? messages.get(lang)
            : 'No meeting minutes found for this account.';
    }

    private static String generateCorrelationId() {
        return EncodingUtil.convertToHex(Crypto.generateDigest('MD5',
            Blob.valueOf(String.valueOf(System.now())))).left(12);
    }

    private static void logError(String correlationId, String errorType, Exception e) {
        System.debug(LoggingLevel.ERROR,
            '[MeetingSummaryService][' + correlationId + '][' + errorType + '] '
            + e.getMessage() + '\n' + e.getStackTraceString());
    }

    public class AiResponseException extends Exception {}
}
