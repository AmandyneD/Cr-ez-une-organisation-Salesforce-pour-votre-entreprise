public with sharing class OpportunityProductsService {

    @AuraEnabled
    public static List<OpportunityLineItemWrapper> getOpportunityProducts(Id opportunityId) {

        if (opportunityId == null) {
            return new List<OpportunityLineItemWrapper>();
        }

        List<OpportunityLineItemWrapper> results = new List<OpportunityLineItemWrapper>();

        List<OpportunityLineItem> oliList = [
            SELECT 
                Id,
                Quantity,
                UnitPrice,
                TotalPrice,
                Product2.Id,
                Product2.Name,
                Product2.QuantityInStock__c
            FROM OpportunityLineItem
            WHERE OpportunityId = :opportunityId
        ];

        for (OpportunityLineItem oli : oliList) {
            results.add(new OpportunityLineItemWrapper(
                oli.Id,
                (oli.Product2 != null ? oli.Product2.Id : null),
                (oli.Product2 != null ? oli.Product2.Name : null),
                oli.UnitPrice,
                oli.TotalPrice,
                oli.Quantity,
                (oli.Product2 != null ? oli.Product2.QuantityInStock__c : null)
            ));
        }

        return results;
    }

    @AuraEnabled
    public static void deleteOpportunityLine(Id lineItemId) {
        if (lineItemId == null) {
            return;
        }

        List<OpportunityLineItem> olis = [
            SELECT Id
            FROM OpportunityLineItem
            WHERE Id = :lineItemId
            LIMIT 1
        ];

        if (!olis.isEmpty()) {
            delete olis;
        }
    }

    public class OpportunityLineItemWrapper {
        @AuraEnabled public Id      lineItemId      { get; set; }
        @AuraEnabled public Id      productId       { get; set; }
        @AuraEnabled public String  productName     { get; set; }
        @AuraEnabled public Decimal unitPrice       { get; set; }
        @AuraEnabled public Decimal totalPrice      { get; set; }
        @AuraEnabled public Decimal quantity        { get; set; }
        @AuraEnabled public Decimal quantityInStock { get; set; }

        public OpportunityLineItemWrapper(
            Id lineItemId,
            Id productId,
            String productName,
            Decimal unitPrice,
            Decimal totalPrice,
            Decimal quantity,
            Decimal quantityInStock
        ) {
            this.lineItemId      = lineItemId;
            this.productId       = productId;
            this.productName     = productName;
            this.unitPrice       = unitPrice;
            this.totalPrice      = totalPrice;
            this.quantity        = quantity;
            this.quantityInStock = quantityInStock;
        }
    }
}