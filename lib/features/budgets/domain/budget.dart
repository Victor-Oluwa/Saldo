import 'package:saldo/core/errors/failures.dart';

/// Monthly budget for one expense category in one currency.
class Budget {
  const Budget({
    required this.id,
    required this.categoryId,
    required this.periodStart,
    required this.limitMinor,
    required this.currencyCode,
    this.warningThresholdPercent,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
  });

  final String id;
  final String categoryId;
  final DateTime periodStart; // normalized to month start 00:00 local
  final int limitMinor;
  final String currencyCode;
  final int? warningThresholdPercent; // 0..100
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;

  static DateTime normalizeMonthStart(DateTime d) =>
      DateTime(d.year, d.month, 1);

  static void validateLimit(int minor) {
    if (minor <= 0) {
      throw const ValidationFailure('Budget limit must be greater than zero');
    }
  }

  static void validateThreshold(int? percent) {
    if (percent == null) return;
    if (percent < 0 || percent > 100) {
      throw const ValidationFailure('Warning threshold must be 0–100');
    }
  }
}

class BudgetUsage {
  const BudgetUsage({
    required this.spentMinor,
    required this.remainingMinor,
    required this.percentUsed,
    required this.isOverspent,
    required this.isWarningReached,
  });

  final int spentMinor;
  final int remainingMinor; // may be negative
  final double percentUsed; // spent / limit, e.g. 0.7
  final bool isOverspent;
  final bool isWarningReached;
}
