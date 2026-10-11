import 'transaction.dart';

abstract class TransactionRepository {
  Future<SaldoTransaction> createIncome({
    required String accountId,
    required String categoryId,
    required int amountMinor,
    required DateTime transactionDate,
    String? description,
    String? notes,
  });

  Future<SaldoTransaction> createExpense({
    required String accountId,
    required String categoryId,
    required int amountMinor,
    required DateTime transactionDate,
    String? description,
    String? notes,
  });

  /// Atomic two-leg transfer — both legs share a group id.
  /// Returns the OUT leg; use [getTransferLegs] for both.
  Future<SaldoTransaction> createTransfer({
    required String sourceAccountId,
    required String destAccountId,
    required int amountMinor,
    required DateTime transactionDate,
    String? description,
    String? notes,
  });

  Future<SaldoTransaction> updateIncome({
    required String id,
    String? accountId,
    String? categoryId,
    int? amountMinor,
    DateTime? transactionDate,
    String? description,
    String? notes,
  });

  Future<SaldoTransaction> updateExpense({
    required String id,
    String? accountId,
    String? categoryId,
    int? amountMinor,
    DateTime? transactionDate,
    String? description,
    String? notes,
  });

  Future<void> updateTransfer({
    required String transferGroupId,
    int? amountMinor,
    DateTime? transactionDate,
    String? description,
    String? notes,
  });

  /// Deletes income/expense by id; transfer leg id deletes BOTH legs atomically.
  Future<void> deleteTransaction(String id);
  Future<void> deleteTransfer(String transferGroupId);

  Future<SaldoTransaction?> getById(String id);
  Future<List<SaldoTransaction>> getTransferLegs(String transferGroupId);
  Future<List<SaldoTransaction>> query({
    TransactionFilter filter = const TransactionFilter(),
    int? limit,
    int? offset,
  });
  Stream<List<SaldoTransaction>> watch({
    TransactionFilter filter = const TransactionFilter(),
  });

  /// Income − expenses per currency for [start, endExclusive). Transfers excluded.
  Future<PeriodTotals> getPeriodTotals({
    required DateTime start,
    required DateTime endExclusive,
  });
}
