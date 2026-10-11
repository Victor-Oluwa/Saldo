import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saldo/core/database/providers.dart';
import 'package:saldo/core/dates/periods.dart';
import 'package:saldo/core/dates/report_period.dart';
import 'package:saldo/features/accounts/presentation/accounts_providers.dart';
import 'package:saldo/features/transactions/domain/transaction.dart';

/// Dashboard period selection (Home). Reports keeps its own copy so the
/// two screens never fight over one shared selection.
class DashboardPeriodNotifier extends Notifier<SelectedPeriod> {
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

final dashboardPeriodProvider =
    NotifierProvider<DashboardPeriodNotifier, SelectedPeriod>(
      DashboardPeriodNotifier.new,
    );

/// Income/expense/net for the selected period, per currency.
/// All-time uses a wide fixed window (2000→2100) so every real record is
/// included through the same half-open query path.
final periodTotalsProvider = FutureProvider<PeriodTotals>((ref) async {
  final selection = ref.watch(dashboardPeriodProvider);
  ref.watch(transactionsVersionProvider);
  final range =
      selection.resolve(DateTime.now()) ??
      PeriodRange(
        start: DateTime(2000, 1, 1),
        endExclusive: DateTime(2100, 1, 1),
      );
  return ref
      .watch(transactionRepositoryProvider)
      .getPeriodTotals(start: range.start, endExclusive: range.endExclusive);
});

/// Daily closing-balance series for the hero saldo line: the last
/// [days] days (oldest → newest) for [currency], rebuilt from committed
/// records — current total minus later-day deltas, walked backwards, then
/// accumulated forwards. Same-currency rows only; never summed across
/// currencies.
final balanceHistoryProvider = FutureProvider.autoDispose
    .family<List<double>, ({String currency, int days})>((ref, key) async {
      ref.watch(transactionsVersionProvider);
      final totals = await ref.watch(totalBalancesProvider.future);
      final nowTotal = totals[key.currency] ?? 0;
      final now = DateTime.now();
      final startDay = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: key.days - 1));
      final rows = await ref
          .watch(transactionRepositoryProvider)
          .query(filter: TransactionFilter(start: startDay));
      final deltas = List<int>.filled(key.days, 0);
      for (final t in rows) {
        if (t.currencyCode != key.currency) continue;
        if (t.transactionDate.isBefore(startDay)) continue;
        final day = DateTime(
          t.transactionDate.year,
          t.transactionDate.month,
          t.transactionDate.day,
        );
        final index = day.difference(startDay).inDays;
        if (index < 0 || index >= key.days) continue;
        deltas[index] += switch (t.type) {
          TransactionType.income => t.amountMinor,
          TransactionType.expense => -t.amountMinor,
          TransactionType.transfer =>
            t.transferSide == TransferSide.incoming
                ? t.amountMinor
                : -t.amountMinor,
        };
      }
      var running = (nowTotal - deltas.fold(0, (a, b) => a + b)).toDouble();
      return [for (final d in deltas) running += d];
    });
