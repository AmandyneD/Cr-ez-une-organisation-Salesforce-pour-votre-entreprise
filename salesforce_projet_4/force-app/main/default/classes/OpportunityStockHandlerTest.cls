@IsTest
private class OpportunityStockHandlerTest {

    // ============================================================
    // UTIL : création d’un PricebookEntry valide
    // ============================================================
    private static PricebookEntry createPBE(Id productId, Decimal unitPrice) {
        return new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id   = productId,
            UnitPrice    = unitPrice,
            IsActive     = true
        );
    }

    // ============================================================
    // TEST 1 : Erreur lorsque la quantité dépasse le stock
    // ============================================================
    @IsTest
    static void testErrorWhenQuantityExceedsStock() {

        // --- Product ---
        Product2 p = new Product2(
            Name = 'Test Product',
            QuantityInStock__c = 5,
            IsActive = true
        );
        insert p;

        // --- PBE ---
        PricebookEntry pbe = createPBE(p.Id, 100);
        insert pbe;

        // --- Opportunity ---
        Opportunity opp = new Opportunity(
            Name      = 'Opp Error',
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(5)
        );
        insert opp;

        // --- Line : quantity > stock ---
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId    = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity         = 10,    // dépasse stock = 5
            UnitPrice        = 100
        );
        insert oli;

        // --- TEST : passage à Closed Won doit générer une erreur ---
        opp.StageName = 'Closed Won';

        Test.startTest();
        try {
            update opp;
            System.assert(false, 'Une erreur aurait dû être levée.');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains(Label.LBL_StockErrorTrigger),
                'Le message doit utiliser le Custom Label.'
            );
        }
        Test.stopTest();
    }

    // ============================================================
    // TEST 2 : Succès + mise à jour du stock produit
    // ============================================================
    @IsTest
    static void testStockUpdatedOnClosedWon_Success() {

        // --- Product ---
        Product2 p = new Product2(
            Name = 'Test Product 2',
            QuantityInStock__c = 20,
            IsActive = true
        );
        insert p;

        // --- PBE ---
        PricebookEntry pbe = createPBE(p.Id, 50);
        insert pbe;

        // --- Opportunity ---
        Opportunity opp = new Opportunity(
            Name      = 'Opp Success',
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(10)
        );
        insert opp;

        // --- Line : quantité en stock suffisante ---
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId    = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity         = 7,
            UnitPrice        = 50
        );
        insert oli;

        // --- Passage à Closed Won ---
        opp.StageName = 'Closed Won';

        Test.startTest();
        update opp; // ne doit PAS lever d'erreur
        Test.stopTest();

        // --- Vérification du stock ---
        Product2 pReloaded = [
            SELECT QuantityInStock__c
            FROM Product2
            WHERE Id = :p.Id
        ];

        System.assertEquals(
            13, // 20 - 7
            pReloaded.QuantityInStock__c,
            'Le stock doit être mis à jour après Closed Won.'
        );
    }
}