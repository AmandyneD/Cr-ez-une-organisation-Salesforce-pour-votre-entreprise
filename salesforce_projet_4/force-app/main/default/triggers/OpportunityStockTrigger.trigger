trigger OpportunityStockTrigger on Opportunity (before update, after update) {

    if (Trigger.isBefore && Trigger.isUpdate) {
        OpportunityStockHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        OpportunityStockHandler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}