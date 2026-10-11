import 'package:saldo/core/errors/failures.dart';

enum TransactionType { income, expense, transfer }

TransactionType transactionTypeFromString(String s) {
  return switch (s) {
    'income' => TransactionType.income,
    'expense' => TransactionType.expense,
    'transfer' => TransactionType.transfer,
    _ => throw ValidationFailure('Unknown transaction type: $s'),
  };
}

String transactionTypeToString(TransactionType t) => switch (t) {
  TransactionType.income => 'income',
  TransactionType.expense => 'expense',
  TransactionType.transfer => 'transfer',
};

/// Transfer leg direction within a two-row transfer group.
enum TransferSide { out, incoming }

TransferSide transferSideFromString(String s) {
  return switch (s) {
    'out' => TransferSide.out,
    'in' => TransferSide.incoming,
    _ => throw ValidationFailure('Unknown transfer side: $s'),
  };
}

String transferSideToString(TransferSide s) => switch (s) {
  TransferSide.out => 'out',
  TransferSide.incoming => 'in',
};

/// Unified transaction entity.
///
/// - income/expense: [categoryId] required, transfer fields null.
/// - transfer: two rows share [transferGroupId], [categoryId] null,
///   [transferSide] + [counterpartAccountId] required.
/// Amounts are always positive minor units. [transactionDate] is local
/// wall-clock (see tables.dart) for stable local reporting.
class SaldoTransaction {
  const SaldoTransaction({
    required this.id,
    required this.type,
    required this.accountId,
    this.categoryId,
    required this.amountMinor,
    required this.currencyCode,
    required this.transactionDate,
    this.description,
    this.notes,
    this.transferGroupId,
    this.transferSide,
    this.counterpartAccountId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final TransactionType type;
  final String accountId;
  final String? categoryId;
  final int amountMinor;
  final String currencyCode;
  final DateTime transactionDate;
  final String? description;
  final String? notes;
  final String? transferGroupId;
  final TransferSide? transferSide;
  final String? counterpartAccountId;
  final DateTime createdAt;
  final DateTime updatedAt;

  static void validateAmount(int minor) {
    if (minor <= 0) {
      throw const ValidationFailure('Amount must be greater than zero');
    }
  }
}

/// Optional filters for history queries — combinable.
class TransactionFilter {
  const TransactionFilter({
    this.search,
    this.start,
    this.endExclusive,
    this.accountId,
    this.categoryId,
    this.type,
  });

  final String? search;
  final DateTime? start;
  final DateTime? endExclusive;
  final String? accountId;
  final String? categoryId;
  final TransactionType? type;
}

/// Period sums by currency — transfers never included.
class PeriodTotals {
  const PeriodTotals({
    required this.incomeByCurrency,
    required this.expenseByCurrency,
    required this.netByCurrency,
  });

  final Map<String, int> incomeByCurrency;
  final Map<String, int> expenseByCurrency;
  final Map<String, int> netByCurrency;
}
