import 'package:flutter_test/flutter_test.dart';
import 'package:saldo/core/database/app_database.dart';
import 'package:saldo/features/budgets/data/budget_repository.dart';
import 'package:saldo/features/home/presentation/home_page.dart';
import 'package:saldo/features/transactions/data/transaction_repository.dart';

import 'saldo_test_utils.dart';

/// Seeds current-month income ₦85,000 + expense ₦32,500, plus an optional
/// previous-month expense. Takes the db so tests seed BEFORE the first
/// frame (see pumpSaldo).
Future<void> seedCashFlow(
  AppDatabase db, {
  bool includePreviousMonth = false,
}) async {
  final ids = await seedSaldoBasics(db);
  final txs = DriftTransactionRepository(db);
  final now = DateTime.now();
  await txs.createIncome(
    accountId: ids.accountId,
    categoryId: ids.incomeCatId,
    amountMinor: 8500000,
    transactionDate: DateTime(now.year, now.month, 5),
    description: 'Salary',
  );
  await txs.createExpense(
    accountId: ids.accountId,
    categoryId: ids.expenseCatId,
    amountMinor: 3250000,
    transactionDate: DateTime(now.year, now.month, 7),
    description: 'Groceries',
  );
  if (includePreviousMonth) {
    await txs.createExpense(
      accountId: ids.accountId,
      categoryId: ids.expenseCatId,
      amountMinor: 1000000,
      transactionDate: DateTime(now.year, now.month - 1, 15),
      description: 'Old bill',
    );
  }
}

void main() {
  testWidgets(
    'shows period income, expenses, net and rate',
    (WidgetTester tester) async {
      final harness = await pumpSaldo(
        tester,
        const HomePage(),
        seed: seedCashFlow,
      );
      await settle(tester);

      // Amounts repeat across cash-flow rows, balances and recent tiles —
      // assert presence, exact reconciliation lives in database tests.
      expect(find.textContaining('85,000'), findsWidgets);
      expect(find.textContaining('32,500'), findsWidgets);
      expect(find.textContaining('52,500'), findsWidgets);
      // (85000 − 32500) / 85000 = 61.8%.
      expect(find.textContaining('61.8'), findsOneWidget);

      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'switching period updates every figure',
    (WidgetTester tester) async {
      final harness = await pumpSaldo(
        tester,
        const HomePage(),
        seed: (db) => seedCashFlow(db, includePreviousMonth: true),
      );
      await settle(tester);

      const shorts = [
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
      final now = DateTime.now();
      final prev = DateTime(now.year, now.month - 1, 1);
      final prevLabel = '${shorts[prev.month - 1]} ${prev.year}';
      expect(find.text(prevLabel), findsNothing);

      await tester.tap(find.text('Last month'));
      await settle(tester);

      // Label follows the selection; previous-month expense drives the
      // cash-flow card (₦10,000 expense + −₦10,000 net).
      expect(find.text(prevLabel), findsOneWidget);
      expect(find.textContaining('10,000'), findsWidgets);
      expect(find.textContaining('no income recorded'), findsOneWidget);

      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'overspent budget highlight shows remaining debt',
    (WidgetTester tester) async {
      Future<void> seed(AppDatabase db) async {
        final ids = await seedSaldoBasics(db);
        final now = DateTime.now();
        await DriftBudgetRepository(db).create(
          categoryId: ids.expenseCatId,
          periodStart: DateTime(now.year, now.month, 1),
          limitMinor: 6000000,
          currencyCode: 'NGN',
        );
        await DriftTransactionRepository(db).createExpense(
          accountId: ids.accountId,
          categoryId: ids.expenseCatId,
          amountMinor: 6500000,
          transactionDate: DateTime(now.year, now.month, 9),
        );
      }

      final harness = await pumpSaldo(tester, const HomePage(), seed: seed);
      await settle(tester);

      // The hero pushes highlights below the fold in the lazy dashboard
      // list — scroll until built, then ensure truly visible (sliver cache
      // builds off-screen widgets a tap would miss).
      for (
        var i = 0;
        i < 10 && find.text('Groceries').evaluate().isEmpty;
        i++
      ) {
        await tester.dragFrom(const Offset(400, 500), const Offset(0, -300));
        await settle(tester, 4);
      }
      await tester.ensureVisible(find.text('Groceries').first);
      await settle(tester, 12);

      // Category name repeats in the highlight row and the recent tile.
      expect(find.text('Groceries'), findsWidgets);
      expect(find.textContaining('Overspent'), findsWidgets);
      // ₦65,000 spent contains '5,000' too — both spent and remaining match.
      expect(find.textContaining('5,000'), findsWidgets);

      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'zero income renders safely without division crash',
    (WidgetTester tester) async {
      Future<void> seed(AppDatabase db) async {
        final ids = await seedSaldoBasics(db);
        final now = DateTime.now();
        await DriftTransactionRepository(db).createExpense(
          accountId: ids.accountId,
          categoryId: ids.expenseCatId,
          amountMinor: 500000,
          transactionDate: DateTime(now.year, now.month, 9),
        );
      }

      final harness = await pumpSaldo(tester, const HomePage(), seed: seed);
      await settle(tester);

      expect(find.textContaining('no income recorded'), findsOneWidget);

      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
