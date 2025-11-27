public with sharing class OpportunityStockHandler {

    // =========================================================
    // AFTER UPDATE : mise à jour du stock produit
    // =========================================================
    public static void afterUpdate(List<Opportunity> newList,
                                   Map<Id, Opportunity> oldMap) {

        // Opportunités qui viennent de passer à "Closed Won"
        Set<Id> oppIdsToProcess = new Set<Id>();

        for (Opportunity opp : newList) {
            Opportunity oldOpp = oldMap.get(opp.Id);
            if (oldOpp == null) continue;

            Boolean becameClosedWon =
                opp.StageName == 'Closed Won' &&
                oldOpp.StageName != 'Closed Won';

            if (becameClosedWon) {
                oppIdsToProcess.add(opp.Id);
            }
        }

        if (oppIdsToProcess.isEmpty()) {
            return;
        }

        // Lignes d’opportunité
        List<OpportunityLineItem> oliList = [
            SELECT Id,
                   OpportunityId,
                   Quantity,
                   PricebookEntry.Product2Id
            FROM OpportunityLineItem
            WHERE OpportunityId IN :oppIdsToProcess
        ];

        if (oliList.isEmpty()) {
            return;
        }

        // Total de quantité par produit
        Map<Id, Decimal> totalRequiredByProduct = new Map<Id, Decimal>();

        for (OpportunityLineItem oli : oliList) {
            Id productId = oli.PricebookEntry.Product2Id;
            if (productId == null) continue;

            Decimal qty = (oli.Quantity == null) ? 0 : oli.Quantity;

            Decimal current = totalRequiredByProduct.containsKey(productId)
                ? totalRequiredByProduct.get(productId)
                : 0;

            totalRequiredByProduct.put(productId, current + qty);
        }

        if (totalRequiredByProduct.isEmpty()) {
            return;
        }

        // Produits à mettre à jour
        List<Product2> productsToUpdate = [
            SELECT Id, QuantityInStock__c
            FROM Product2
            WHERE Id IN :totalRequiredByProduct.keySet()
        ];

        for (Product2 p : productsToUpdate) {
            Decimal stock = (p.QuantityInStock__c == null)
                ? 0
                : p.QuantityInStock__c;

            Decimal required = totalRequiredByProduct.get(p.Id);

            p.QuantityInStock__c = stock - required;
        }

        if (!productsToUpdate.isEmpty()) {
            update productsToUpdate;
        }
    }
}