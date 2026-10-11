import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saldo/core/database/app_database.dart';
import 'package:saldo/core/widgets/saldo_tile.dart';
import 'package:saldo/features/transactions/presentation/transaction_detail_page.dart';
import 'package:saldo/features/transactions/presentation/transactions_list_page.dart';
import 'package:saldo/features/transactions/presentation/transfer_form_page.dart';

import 'saldo_test_utils.dart';

/// Seeds one account + income/expense categories + two transactions.
Future<({String accountId, String incomeId, String expenseId})> seedTwo(
  AppDatabase db,
) async {
  final now = DateTime(2026, 10, 9);
  await db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'bank',
          name: 'Bank',
          currencyCode: 'NGN',
          openingBalanceMinor: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );
  await db
      .into(db.categories)
      .insert(
        CategoriesCompanion.insert(
          id: 'seed-salary',
          name: 'SeedSalary',
          type: 'income',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await db
      .into(db.categories)
      .insert(
        CategoriesCompanion.insert(
          id: 'seed-food',
          name: 'SeedFood',
          type: 'expense',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          id: 'inc1',
          type: 'income',
          accountId: 'bank',
          categoryId: const Value('seed-salary'),
          amountMinor: 2500000,
          currencyCode: 'NGN',
          transactionDate: DateTime(2026, 10, 8),
          description: const Value('Freelance income'),
          createdAt: now,
          updatedAt: now,
        ),
      );
  await db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          id: 'exp1',
          type: 'expense',
          accountId: 'bank',
          categoryId: const Value('seed-food'),
          amountMinor: 450000,
          currencyCode: 'NGN',
          transactionDate: DateTime(2026, 10, 9),
          description: const Value('Groceries'),
          createdAt: now,
          updatedAt: now,
        ),
      );
  return (accountId: 'bank', incomeId: 'inc1', expenseId: 'exp1');
}

void main() {
  testWidgets(
    'search narrows history; clear restores',
    (WidgetTester tester) async {
      final harness = await pumpSaldo(tester, const TransactionsListPage());
      await seedTwo(harness.db);
      await settle(tester);

      expect(find.text('Freelance income'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byType(SearchBar),
          matching: find.byType(EditableText),
        ),
        'Groceries',
      );
      await settle(tester);
      // Tile title still matches; the search field input itself also contains
      // the text, so scope to the tile.
      expect(find.widgetWithText(SaldoTile, 'Groceries'), findsOneWidget);
      expect(find.text('Freelance income'), findsNothing);

      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'type filter combines (expense only)',
    (WidgetTester tester) async {
      final harness = await pumpSaldo(tester, const TransactionsListPage());
      await seedTwo(harness.db);
      await settle(tester);

      // Open filter panel, pick Expense segment.
      await tester.tap(find.byIcon(Icons.filter_list));
      await settle(tester);
      await tester.tap(find.text('Expense').last);
      await settle(tester);

      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Freelance income'), findsNothing);

      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'transfer form requires both accounts',
    (WidgetTester tester) async {
      final harness = await pumpSaldo(tester, const TransferFormPage());
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '20000',
      );
      // Preview hero pushes submit below the fold in the lazy form list —
      // scroll until built, then ensure truly visible before tapping.
      for (
        var i = 0;
        i < 10 && find.text('Record transfer').evaluate().isEmpty;
        i++
      ) {
        await tester.dragFrom(const Offset(400, 500), const Offset(0, -300));
        await settle(tester, 4);
      }
      await tester.ensureVisible(find.text('Record transfer').first);
      await settle(tester, 12);
      await tester.tap(find.text('Record transfer'));
      await settle(tester);
      expect(find.text('Choose both accounts'), findsOneWidget);

      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'detail delete asks for confirmation first',
    (WidgetTester tester) async {
      final harness = await pumpSaldo(tester, const TransactionsListPage());
      final ids = await seedTwo(harness.db);
      await settle(tester);

      await repumpSaldo(
        tester,
        harness,
        TransactionDetailPage(transactionId: ids.expenseId),
      );
      await tester.tap(find.byIcon(Icons.delete_outline));
      await settle(tester);
      expect(find.text('Delete transaction?'), findsOneWidget);
      expect(
        find.textContaining('account balance', findRichText: true),
        findsOneWidget,
      );

      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
