import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saldo/core/database/providers.dart';
import 'package:saldo/core/dates/periods.dart';
import 'package:saldo/core/dates/report_period.dart';
import 'package:saldo/features/accounts/presentation/accounts_providers.dart';
import 'package:saldo/features/categories/presentation/categories_providers.dart';
import 'package:saldo/features/transactions/domain/transaction.dart';
import 'package:saldo/features/transactions/presentation/transactions_providers.dart';

/// Reports period selection — independent from the dashboard so the two
/// screens never fight over one shared selection.
class ReportPeriodNotifier extends Notifier<SelectedPeriod> {
  @override
  SelectedPeriod build() => const SelectedPeriod();

  void setPreset(PeriodPreset preset) => state = SelectedPeriod(preset: preset);

  void setCustom(DateTime start, DateTime endExclusive) =>
      state = SelectedPeriod(
        preset: PeriodPreset.custom,
        customStart: start,
        customEndExclusive: endExclusive,
      );
}

final reportPeriodProvider =
    NotifierProvider<ReportPeriodNotifier, SelectedPeriod>(
      ReportPeriodNotifier.new,
    );

/// Drill-down: preset the shared history filter to one category's expenses
/// in [range]. The caller then navigates to `/transactions`.
/// Takes the notifier (not a ref) so the logic is unit-testable with a
/// plain ProviderContainer.
void applyCategoryDrillDown(
  TxFilterNotifier notifier, {
  required String categoryId,
  required PeriodRange range,
}) {
  notifier.clear();
  notifier.setCategory(categoryId);
  notifier.setType(TransactionType.expense);
  notifier.setRange(range.start, range.endExclusive);
}

/// Drill-down to everything recorded in [range].
void applyPeriodDrillDown(
  TxFilterNotifier notifier, {
  required PeriodRange range,
}) {
  notifier.clear();
  notifier.setRange(range.start, range.endExclusive);
}

/// Income/expense/net for the report period, per currency.
final reportTotalsProvider = FutureProvider<PeriodTotals>((ref) async {
  final selection = ref.watch(reportPeriodProvider);
  ref.watch(transactionsVersionProvider);
  final range = queryRangeFor(selection, DateTime.now());
  return ref
      .watch(transactionRepositoryProvider)
      .getPeriodTotals(start: range.start, endExclusive: range.endExclusive);
});

/// One expense slice: category + currency + summed minor units.
class CategorySlice {
  const CategorySlice({
    required this.categoryId,
    required this.categoryName,
    required this.currencyCode,
    required this.totalMinor,
    required this.count,
  });

  final String categoryId;
  final String categoryName;
  final String currencyCode;
  final int totalMinor;
  final int count;
}

/// Expense breakdown for the period, grouped by (category, currency),
/// largest first. Same inclusion rule as the totals query.
final expenseByCategoryProvider = FutureProvider<List<CategorySlice>>((
  ref,
) async {
  final selection = ref.watch(reportPeriodProvider);
  ref.watch(transactionsVersionProvider);
  final range = queryRangeFor(selection, DateTime.now());
  final repo = ref.watch(transactionRepositoryProvider);
  final rows = await repo.query(
    filter: TransactionFilter(
      type: TransactionType.expense,
      start: range.start,
      endExclusive: range.endExclusive,
    ),
  );
  final catMap = await ref.watch(categoryMapProvider.future);
  final sums = <String, int>{};
  final counts = <String, int>{};
  for (final t in rows) {
    final key = '${t.categoryId ?? '?'}|${t.currencyCode}';
    sums.update(key, (v) => v + t.amountMinor, ifAbsent: () => t.amountMinor);
    counts.update(key, (v) => v + 1, ifAbsent: () => 1);
  }
  final out = <CategorySlice>[];
  for (final entry in sums.entries) {
    final sep = entry.key.split('|');
    out.add(
      CategorySlice(
        categoryId: sep[0],
        categoryName: catMap[sep[0]]?.name ?? 'Uncategorized',
        currencyCode: sep[1],
        totalMinor: entry.value,
        count: counts[entry.key] ?? 0,
      ),
    );
  }
  out.sort((a, b) => b.totalMinor.compareTo(a.totalMinor));
  return out;
});

/// One trend bucket with both legs of cash flow.
class TrendPoint {
  const TrendPoint({
    required this.bucketStart,
    required this.label,
    required this.incomeMinor,
    required this.expenseMinor,
  });

  final DateTime bucketStart;
  final String label;
  final int incomeMinor;
  final int expenseMinor;
}

/// Cash-flow trend for the period in its primary currency (the currency
/// with the most expense — MVP never converts between currencies).
/// All-time uses the trailing 12 full months so the chart stays readable.
/// Returns the denominating currency with the points (null currency = empty).
final spendingTrendProvider =
    FutureProvider<({String? currencyCode, List<TrendPoint> points})>((
      ref,
    ) async {
      final selection = ref.watch(reportPeriodProvider);
      ref.watch(transactionsVersionProvider);
      final now = DateTime.now();
      final trailing12 = PeriodRange(
        start: DateTime(now.year, now.month - 11, 1),
        endExclusive: DateTime(now.year, now.month + 1, 1),
      );
      final range = selection.resolve(now) ?? trailing12;
      final repo = ref.watch(transactionRepositoryProvider);
      final rows = await repo.query(
        filter: TransactionFilter(
          start: range.start,
          endExclusive: range.endExclusive,
        ),
      );
      if (rows.isEmpty) {
        return (currencyCode: null, points: <TrendPoint>[]);
      }
      // Primary currency = highest expense total.
      final expenseByCurrency = <String, int>{};
      for (final t in rows) {
        if (t.type != TransactionType.expense) continue;
        expenseByCurrency.update(
          t.currencyCode,
          (v) => v + t.amountMinor,
          ifAbsent: () => t.amountMinor,
        );
      }
      if (expenseByCurrency.isEmpty) {
        return (currencyCode: null, points: <TrendPoint>[]);
      }
      final code = expenseByCurrency.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final points = <TrendPoint>[];
      for (final bucket in trendBuckets(range, now)) {
        final end = bucketEnd(bucket, range);
        var income = 0;
        var expense = 0;
        for (final t in rows) {
          if (t.currencyCode != code) continue;
          if (t.transactionDate.isBefore(bucket) ||
              !t.transactionDate.isBefore(end)) {
            continue;
          }
          if (t.type == TransactionType.income) {
            income += t.amountMinor;
          } else if (t.type == TransactionType.expense) {
            expense += t.amountMinor;
          }
        }
        final label = range.endExclusive.difference(range.start).inDays > 92
            ? months[bucket.month - 1]
            : '${bucket.day}';
        points.add(
          TrendPoint(
            bucketStart: bucket,
            label: label,
            incomeMinor: income,
            expenseMinor: expense,
          ),
        );
      }
      return (currencyCode: code, points: points);
    });
