import 'budget.dart';

abstract class BudgetRepository {
  Future<Budget> create({
    required String categoryId,
    required DateTime periodStart,
    required int limitMinor,
    required String currencyCode,
    int? warningThresholdPercent,
  });

  Future<Budget> update({
    required String id,
    int? limitMinor,
    int? warningThresholdPercent,
  });

  Future<void> delete(String id);
  Future<Budget?> getById(String id);
  Future<List<Budget>> getForMonth(
    DateTime monthStart, {
    bool includeArchived = false,
  });
  Stream<List<Budget>> watchForMonth(DateTime monthStart);

  /// Spent = eligible expenses in [budget.currencyCode] for category+month.
  /// Transfers + income excluded. Remaining = limit − spent (may be negative).
  Future<BudgetUsage> getUsage(String budgetId);
}
