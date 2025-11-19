@IsTest
private class OpportunityStockHandlerTest {

    /**
     * Utilitaire : crée un produit avec un stock donné
     * + une PricebookEntry dans le pricebook standard.
     */
    private static PricebookEntry createProductAndPbe(Decimal stock) {
        // Pricebook standard
        Id stdPbId = Test.getStandardPricebookId();

        Product2 p = new Product2(
            Name               = 'Test Product ' + stock,
            IsActive           = true,
            QuantityInStock__c = stock
        );
        insert p;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id   = p.Id,
            UnitPrice    = 100,
            IsActive     = true
        );
        insert pbe;

        return pbe;
    }

    /**
     * Utilitaire : crée une opportunité + une ligne produit
     */
    private static Opportunity createOppWithLine(PricebookEntry pbe, Decimal qty) {
        Account acc = new Account(Name = 'Test Account ' + qty);
        insert acc;

        Opportunity opp = new Opportunity(
            Name      = 'Test Opp ' + qty,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(10),
            AccountId = acc.Id
        );
        insert opp;

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId    = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity         = qty,
            UnitPrice        = 100
        );
        insert oli;

        return opp;
    }

    // ===================== SCÉNARIO 1 : SUCCÈS ===================== //
    @IsTest
    static void testStockUpdatedOnClosedWon_Success() {
        // Produit avec suffisamment de stock
        PricebookEntry pbe = createProductAndPbe(10); // stock 10
        Product2 prod = [SELECT Id, QuantityInStock__c FROM Product2 WHERE Id = :pbe.Product2Id];

        // Opp avec une ligne quantité = 2
        Opportunity opp = createOppWithLine(pbe, 2);

        Test.startTest();
        // Passage au stage "Closed Won" → doit décrémenter le stock
        opp.StageName = 'Closed Won';
        update opp;
        Test.stopTest();

        // Vérifier que le stock a été décrémenté
        prod = [SELECT QuantityInStock__c FROM Product2 WHERE Id = :prod.Id];
        System.assertEquals(
            8,
            prod.QuantityInStock__c,
            'Le stock doit être décrémenté de la quantité de la ligne (10 - 2 = 8).'
        );
    }

    // ===================== SCÉNARIO 2 : ERREUR ===================== //
    @IsTest
    static void testErrorWhenQuantityExceedsStock() {
        // Produit avec stock insuffisant
        PricebookEntry pbe = createProductAndPbe(5); // stock 5
        Product2 prod = [SELECT Id, QuantityInStock__c FROM Product2 WHERE Id = :pbe.Product2Id];

        // Opp avec une ligne quantité = 10 (> stock)
        Opportunity opp = createOppWithLine(pbe, 10);

        Test.startTest();
        Boolean gotException = false;
        try {
            opp.StageName = 'Closed Won';
            update opp; // doit lever une DmlException avec addError
        } catch (DmlException e) {
            gotException = true;
            System.assert(
                e.getDmlMessage(0).contains('Votre opportunité ne peut pas être mise à jour'),
                'Le message doit contenir le texte fonctionnel demandé.'
            );
        }
        Test.stopTest();

        System.assertEquals(true, gotException, 'On doit obtenir une DmlException.');

        // Vérifier que le stock n’a PAS été modifié
        prod = [SELECT QuantityInStock__c FROM Product2 WHERE Id = :prod.Id];
        System.assertEquals(
            5,
            prod.QuantityInStock__c,
            'En cas d’erreur de quantité, le stock produit ne doit pas être modifié.'
        );
    }
}