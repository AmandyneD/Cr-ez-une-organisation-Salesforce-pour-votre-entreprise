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
    // TEST : Succès + mise à jour du stock produit
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