trigger OpportunityStockTrigger on Opportunity (after update) {

    if (Trigger.isAfter && Trigger.isUpdate) {
        OpportunityStockHandler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}