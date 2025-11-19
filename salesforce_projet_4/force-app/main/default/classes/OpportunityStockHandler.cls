public with sharing class OpportunityStockHandler {

    // =========================================================
    // BEFORE UPDATE : validation stock + message d’erreur
    // =========================================================
    public static void beforeUpdate(List<Opportunity> newList,
                                    Map<Id, Opportunity> oldMap) {

        // Opportunités qui viennent de passer à "Closed Won"
        Set<Id> oppIdsToCheck = new Set<Id>();

        for (Opportunity opp : newList) {
            Opportunity oldOpp = oldMap.get(opp.Id);
            if (oldOpp == null) continue;

            Boolean becameClosedWon =
                opp.StageName == 'Closed Won' &&
                oldOpp.StageName != 'Closed Won';

            if (becameClosedWon) {
                oppIdsToCheck.add(opp.Id);
            }
        }

        if (oppIdsToCheck.isEmpty()) {
            return;
        }

        // Lignes d’opportunité + stock produit
        List<OpportunityLineItem> oliList = [
            SELECT Id,
                   OpportunityId,
                   Quantity,
                   PricebookEntry.Product2Id,
                   PricebookEntry.Product2.QuantityInStock__c
            FROM OpportunityLineItem
            WHERE OpportunityId IN :oppIdsToCheck
        ];

        if (oliList.isEmpty()) {
            return;
        }

        // Total de quantité demandée par produit + stock disponible
        Map<Id, Decimal> totalRequiredByProduct = new Map<Id, Decimal>();
        Map<Id, Decimal> stockByProduct         = new Map<Id, Decimal>();

        for (OpportunityLineItem oli : oliList) {
            Id productId = oli.PricebookEntry.Product2Id;
            if (productId == null) continue;

            Decimal qty = (oli.Quantity == null) ? 0 : oli.Quantity;
            if (!totalRequiredByProduct.containsKey(productId)) {
                totalRequiredByProduct.put(productId, 0);
                Decimal stock = oli.PricebookEntry.Product2.QuantityInStock__c;
                stockByProduct.put(
                    productId,
                    (stock == null) ? 0 : stock
                );
            }
            totalRequiredByProduct.put(
                productId,
                totalRequiredByProduct.get(productId) + qty
            );
        }

        // Vérifier si au moins un produit n’a pas assez de stock
        Boolean hasStockError = false;

        for (Id productId : totalRequiredByProduct.keySet()) {
            Decimal required  = totalRequiredByProduct.get(productId);
            Decimal available = stockByProduct.get(productId);

            if (required > available) {
                hasStockError = true;
                break;
            }
        }

        if (hasStockError) {
            String msg =
                'Votre opportunité ne peut pas être mise à jour ' +
                'car vous avez un souci de quantité sur vos lignes.';

            for (Opportunity opp : newList) {
                if (oppIdsToCheck.contains(opp.Id)) {
                    opp.addError(msg);
                }
            }
        }
    }

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