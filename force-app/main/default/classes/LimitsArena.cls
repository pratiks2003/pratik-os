/**
 * Governor Limits Arena (fictional "Orbit Supply" orders).
 *
 * Seeds real records inside a savepoint, applies tier discounts twice, once
 * bulkified and once with the classic per-record anti-pattern, and measures
 * each run with the Limits class. Everything is rolled back afterwards.
 *
 * The naive run stops a few queries short of the limit: at query 101 the
 * platform throws System.LimitException, which cannot be caught and would end
 * the request before we could show the result.
 */
public without sharing class LimitsArena {
  public static final Integer MAX_RECORDS = 200;
  @TestVisible
  private static final Integer QUERY_HEADROOM = 5;

  public static Result run(Integer requestedRecords) {
    Integer count = Math.max(
      1,
      Math.min(requestedRecords ?? MAX_RECORDS, MAX_RECORDS)
    );
    Savepoint beforeDemo = Database.setSavepoint();
    try {
      List<Demo_Order__c> orders = seedOrders(count);
      Result result = new Result();
      result.recordCount = count;
      result.queryLimit = Limits.getLimitQueries();
      result.dmlLimit = Limits.getLimitDmlStatements();
      result.bulkified = measure('bulkified', new BulkifiedDiscounts(), orders);
      result.naive = measure('naive', new NaiveDiscounts(), orders);
      return result;
    } finally {
      Database.rollback(beforeDemo);
    }
  }

  /** One query and one DML statement, however many orders there are. */
  public class BulkifiedDiscounts implements DiscountJob {
    public Integer apply(List<Demo_Order__c> orders) {
      Set<Id> customerIds = new Set<Id>();
      for (Demo_Order__c order : orders) {
        customerIds.add(order.Customer__c);
      }
      Map<Id, Demo_Customer__c> customers = new Map<Id, Demo_Customer__c>(
        [SELECT Id, Tier__c FROM Demo_Customer__c WHERE Id IN :customerIds]
      );
      for (Demo_Order__c order : orders) {
        order.Discount__c = discountFor(
          customers.get(order.Customer__c).Tier__c
        );
      }
      update orders;
      return orders.size();
    }
  }

  /** ANTI-PATTERN, shown on purpose: a query and a DML statement per order. */
  public class NaiveDiscounts implements DiscountJob {
    public Integer apply(List<Demo_Order__c> orders) {
      Integer processed = 0;
      for (Demo_Order__c order : orders) {
        // Demo safety net only. Real code like this simply crashes at query 101.
        if (Limits.getQueries() >= Limits.getLimitQueries() - QUERY_HEADROOM) {
          break;
        }
        Demo_Customer__c customer = [
          SELECT Id, Tier__c
          FROM Demo_Customer__c
          WHERE Id = :order.Customer__c
        ];
        order.Discount__c = discountFor(customer.Tier__c);
        update order;
        processed++;
      }
      return processed;
    }
  }

  public interface DiscountJob {
    Integer apply(List<Demo_Order__c> orders);
  }

  private static Approach measure(
    String name,
    DiscountJob job,
    List<Demo_Order__c> orders
  ) {
    Integer queriesBefore = Limits.getQueries();
    Integer dmlBefore = Limits.getDmlStatements();
    Integer cpuBefore = Limits.getCpuTime();

    Approach approach = new Approach();
    approach.name = name;
    approach.records = orders.size();
    approach.processed = job.apply(orders);
    approach.queries = Limits.getQueries() - queriesBefore;
    approach.dmlStatements = Limits.getDmlStatements() - dmlBefore;
    approach.cpuMs = Limits.getCpuTime() - cpuBefore;
    approach.halted = approach.processed < approach.records;
    approach.queriesNeeded = name == 'naive' ? orders.size() : approach.queries;
    approach.dmlNeeded = name == 'naive'
      ? orders.size()
      : approach.dmlStatements;
    return approach;
  }

  private static List<Demo_Order__c> seedOrders(Integer count) {
    List<String> tiers = new List<String>{ 'Gold', 'Silver', 'Bronze' };
    List<Demo_Customer__c> customers = new List<Demo_Customer__c>();
    for (Integer i = 0; i < Math.min(count, 30); i++) {
      customers.add(
        new Demo_Customer__c(
          Name = 'Orbit Supply customer ' + (i + 1),
          Tier__c = tiers[Math.mod(i, 3)]
        )
      );
    }
    insert customers;

    List<Demo_Order__c> orders = new List<Demo_Order__c>();
    for (Integer i = 0; i < count; i++) {
      orders.add(
        new Demo_Order__c(
          Name = 'OS-' + String.valueOf(i + 1).leftPad(4, '0'),
          Customer__c = customers[Math.mod(i, customers.size())].Id,
          Amount__c = 40 + Math.mod(i * 37, 160)
        )
      );
    }
    insert orders;
    return orders;
  }

  private static Decimal discountFor(String tier) {
    return tier == 'Gold' ? 15 : tier == 'Silver' ? 10 : 5;
  }

  public class Result {
    @AuraEnabled
    public Integer recordCount;
    @AuraEnabled
    public Integer queryLimit;
    @AuraEnabled
    public Integer dmlLimit;
    @AuraEnabled
    public Approach bulkified;
    @AuraEnabled
    public Approach naive;
  }

  public class Approach {
    @AuraEnabled
    public String name;
    @AuraEnabled
    public Integer records;
    @AuraEnabled
    public Integer processed;
    @AuraEnabled
    public Integer queries;
    @AuraEnabled
    public Integer dmlStatements;
    @AuraEnabled
    public Integer cpuMs;
    @AuraEnabled
    public Boolean halted;
    @AuraEnabled
    public Integer queriesNeeded;
    @AuraEnabled
    public Integer dmlNeeded;
  }
}
