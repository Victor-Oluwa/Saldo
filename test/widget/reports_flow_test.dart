import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saldo/core/database/app_database.dart';
import 'package:saldo/core/dates/periods.dart';
import 'package:saldo/core/dates/report_period.dart';
import 'package:saldo/features/categories/data/category_repository.dart';
import 'package:saldo/features/categories/domain/category.dart';
import 'package:saldo/features/reports/presentation/reports_page.dart';
import 'package:saldo/features/reports/presentation/reports_providers.dart';
import 'package:saldo/features/transactions/data/transaction_repository.dart';
import 'package:saldo/features/transactions/domain/transaction.dart';
import 'package:saldo/features/transactions/presentation/transactions_providers.dart';

import 'saldo_test_utils.dart';

/// Seeds current-month income ₦85,000 + Groceries ₦4,500 + Transport ₦1,200.
/// Takes the db so tests seed BEFORE the first frame (see pumpSaldo).
Future<void> seedReportMonth(AppDatabase db) async {
  final ids = await seedSaldoBasics(db);
  final transport = (await DriftCategoryRepository(
    db,
  ).getByType(CategoryType.expense)).firstWhere((c) => c.name == 'Transport');
  final txs = DriftTransactionRepository(db);
  final now = DateTime.now();
  await txs.createIncome(
    accountId: ids.accountId,
    categoryId: ids.incomeCatId,
    amountMinor: 8500000,
    transactionDate: DateTime(now.year, now.month, 5),
  );
  await txs.createExpense(
    accountId: ids.accountId,
    categoryId: ids.expenseCatId,
    amountMinor: 450000,
    transactionDate: DateTime(now.year, now.month, 9),
  );
  await txs.createExpense(
    accountId: ids.accountId,
    categoryId: transport.id,
    amountMinor: 120000,
    transactionDate: DateTime(now.year, now.month, 8),
  );
}

void main() {
  testWidgets(
    'summary, breakdown and trend reconcile',
    (WidgetTester tester) async {
      final harness = await pumpSaldo(
        tester,
        const ReportsPage(),
        seed: seedReportMonth,
      );
      await settle(tester);

      // Summary: 85,000 − (4,500 + 1,200) = 79,300.
      expect(find.textContaining('85,000'), findsOneWidget);
      expect(find.textContaining('5,700'), findsOneWidget);
      expect(find.textContaining('79,300'), findsOneWidget);
      // Breakdown rows with counts.
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Transport'), findsOneWidget);
      expect(find.textContaining('4,500'), findsOneWidget);
      expect(find.textContaining('1,200'), findsOneWidget);
      // Trend section is below the fold in a lazy ListView — scroll first.
      await tester.scrollUntilVisible(find.text('Cash-flow trend'), 300);
      await settle(tester);
      expect(find.text('Cash-flow trend'), findsOneWidget);
      expect(find.text('Income'), findsWidgets);
      expect(find.text('Expenses'), findsWidgets);

      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'empty period renders safe zero states',
    (WidgetTester tester) async {
      final harness = await pumpSaldo(
        tester,
        const ReportsPage(),
        seed: seedReportMonth,
      );
      await settle(tester);

      await tester.tap(find.text('Last month'));
      await settle(tester);

      expect(
        find.text('No income or expenses in this period.'),
        findsOneWidget,
      );
      expect(find.text('No spending in this period.'), findsOneWidget);
      expect(find.text('Nothing to chart yet in this period.'), findsOneWidget);

      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test('category drill-down presets expense filter for range', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final range = PeriodRange(
      start: DateTime(2026, 10, 1),
      endExclusive: DateTime(2026, 11, 1),
    );
    applyCategoryDrillDown(
      container.read(txFilterProvider.notifier),
      categoryId: 'cat-1',
      range: range,
    );
    final filter = container.read(txFilterProvider);
    expect(filter.categoryId, 'cat-1');
    expect(filter.type, TransactionType.expense);
    expect(filter.start, range.start);
    expect(filter.endExclusive, range.endExclusive);
    expect(filter.search, isNull);
    expect(filter.accountId, isNull);
  });

  test('period drill-down keeps range, clears everything else', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(txFilterProvider.notifier);
    notifier.setSearch('old');
    notifier.setType(TransactionType.income);
    final range = queryRangeFor(
      const SelectedPeriod(preset: PeriodPreset.thisWeek),
      DateTime(2026, 10, 9),
    );
    applyPeriodDrillDown(notifier, range: range);
    final filter = container.read(txFilterProvider);
    expect(filter.start, DateTime(2026, 10, 5));
    expect(filter.endExclusive, DateTime(2026, 10, 12));
    expect(filter.search, isNull);
    expect(filter.type, isNull);
    expect(filter.categoryId, isNull);
  });
}
