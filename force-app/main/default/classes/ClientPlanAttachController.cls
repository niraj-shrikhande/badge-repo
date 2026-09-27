public with sharing class ClientPlanAttachController {

    @AuraEnabled
    public static String attachClientPlanPDF(Id accountId) {
        Account acc = [SELECT Name FROM Account WHERE Id = :accountId WITH USER_MODE LIMIT 1];

        PageReference pdfPage = Page.ClientPlanPDF;
        pdfPage.getParameters().put('id', accountId);

        Blob pdfContent = Test.isRunningTest()
            ? Blob.valueOf('PDF placeholder')
            : pdfPage.getContent();

        String fileName = acc.Name + ' - Client Plan.pdf';

        ContentVersion cv = new ContentVersion(
            Title        = fileName,
            PathOnClient = fileName,
            VersionData  = pdfContent,
            FirstPublishLocationId = accountId
        );
        insert cv;

        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;
    }
}
