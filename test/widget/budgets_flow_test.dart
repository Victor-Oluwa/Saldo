import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saldo/core/database/app_database.dart';
import 'package:saldo/features/budgets/data/budget_repository.dart';
import 'package:saldo/features/budgets/presentation/budget_form_page.dart';
import 'package:saldo/features/budgets/presentation/budgets_page.dart';
import 'package:saldo/features/transactions/data/transaction_repository.dart';

import 'saldo_test_utils.dart';

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _label(DateTime m) => '${_months[m.month - 1]} ${m.year}';

/// Seeds a Groceries budget (limit ₦60,000) + one expense of [spentMinor].
/// Takes the db so tests seed BEFORE the first frame (see pumpSaldo).
Future<void> seedBudget(
  AppDatabase db,
  int spentMinor, {
  int limitMinor = 6000000,
}) async {
  final ids = await seedSaldoBasics(db);
  final now = DateTime.now();
  await DriftBudgetRepository(db).create(
    categoryId: ids.expenseCatId,
    periodStart: DateTime(now.year, now.month, 1),
    limitMinor: limitMinor,
    currencyCode: 'NGN',
  );
  await DriftTransactionRepository(db).createExpense(
    accountId: ids.accountId,
    categoryId: ids.expenseCatId,
    amountMinor: spentMinor,
    transactionDate: DateTime(now.year, now.month, 9),
  );
}

void main() {
  testWidgets(
    'empty month explains and offers creation',
    (WidgetTester tester) async {
      final harness = await pumpSaldo(
        tester,
        const BudgetsPage(),
        seed: seedSaldoBasics,
      );
      await settle(tester);

      expect(find.text('No budgets this month'), findsOneWidget);

      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'usage row shows spent and remaining',
    (WidgetTester tester) async {
      final harness = await pumpSaldo(
        tester,
        const BudgetsPage(),
        seed: (db) => seedBudget(db, 4200000),
      );
      await settle(tester);

      expect(find.text('Groceries'), findsOneWidget);
      expect(find.textContaining('42,000'), findsOneWidget);
      expect(find.textContaining('18,000'), findsOneWidget);
      expect(find.textContaining('Overspent'), findsNothing);

      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'overspend shows negative remaining state',
    (WidgetTester tester) async {
      final harness = await pumpSaldo(
        tester,
        const BudgetsPage(),
        seed: (db) => seedBudget(db, 6500000),
      );
      await settle(tester);

      expect(find.textContaining('Overspent'), findsWidgets);
      // Both ₦65,000 spent and ₦5,000 remaining contain '5,000'.
      expect(find.textContaining('5,000'), findsWidgets);

      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'budget form rejects empty limit (no phantom success)',
    (WidgetTester tester) async {
      final harness = await pumpSaldo(tester, const BudgetFormPage());
      await settle(tester);
      await tester.tap(find.text('Create budget'));
      await settle(tester);

      expect(find.text('Limit is required'), findsOneWidget);

      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'month navigator shifts the displayed month',
    (WidgetTester tester) async {
      final harness = await pumpSaldo(tester, const BudgetsPage());
      await settle(tester);

      final now = DateTime.now();
      final current = DateTime(now.year, now.month, 1);
      final next = current.month == 12
          ? DateTime(current.year + 1, 1, 1)
          : DateTime(current.year, current.month + 1, 1);
      expect(find.text(_label(current)), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await settle(tester);

      expect(find.text(_label(current)), findsNothing);
      expect(find.text(_label(next)), findsOneWidget);

      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
