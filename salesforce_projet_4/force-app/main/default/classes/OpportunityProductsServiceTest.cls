@IsTest
private class OpportunityProductsServiceTest {

    @TestSetup
    static void setupData() {
        // Compte
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Id du pricebook standard
        Id stdPbId = Test.getStandardPricebookId();

        // Produit avec stock
        Product2 p = new Product2(
            Name               = 'Test Product',
            ProductCode        = 'TP-001',
            QuantityInStock__c = 10,
            IsActive           = true
        );
        insert p;

        // PricebookEntry
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id   = p.Id,
            UnitPrice    = 100,
            IsActive     = true
        );
        insert pbe;

        // Opportunity
        Opportunity opp = new Opportunity(
            Name      = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(10),
            AccountId = acc.Id
        );
        insert opp;

        // OpportunityLineItem
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId    = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity         = 2,
            UnitPrice        = 100
        );
        insert oli;
    }

    @IsTest
    static void testGetOpportunityProducts() {
        Opportunity opp = [
            SELECT Id
            FROM Opportunity
            WHERE Name = 'Test Opp'
            LIMIT 1
        ];

        Test.startTest();
        List<OpportunityProductsService.OpportunityLineItemWrapper> results =
            OpportunityProductsService.getOpportunityProducts(opp.Id);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'On doit récupérer 1 ligne');
        OpportunityProductsService.OpportunityLineItemWrapper row = results[0];
        System.assertEquals('Test Product', row.productName);
        System.assertEquals(2, row.quantity);
        System.assertEquals(100, row.unitPrice);
        System.assertEquals(10, row.quantityInStock);
    }

    @IsTest
    static void testGetOpportunityProducts_NoRecords() {
        Account acc = new Account(Name = 'Empty Opp Account');
        insert acc;

        Opportunity emptyOpp = new Opportunity(
            Name      = 'Empty Opp',
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(5),
            AccountId = acc.Id
        );
        insert emptyOpp;

        Test.startTest();
        List<OpportunityProductsService.OpportunityLineItemWrapper> results =
            OpportunityProductsService.getOpportunityProducts(emptyOpp.Id);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Pas de produits pour cette opportunité');
    }

    @IsTest
    static void testDeleteOpportunityLine() {
        Opportunity opp = [
            SELECT Id
            FROM Opportunity
            WHERE Name = 'Test Opp'
            LIMIT 1
        ];

        OpportunityLineItem oli = [
            SELECT Id
            FROM OpportunityLineItem
            WHERE OpportunityId = :opp.Id
            LIMIT 1
        ];

        Test.startTest();
        OpportunityProductsService.deleteOpportunityLine(oli.Id);
        Test.stopTest();

        Integer countAfter = [
            SELECT COUNT()
            FROM OpportunityLineItem
            WHERE OpportunityId = :opp.Id
        ];
        System.assertEquals(0, countAfter, 'La ligne doit être supprimée');
    }
}