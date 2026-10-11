import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saldo/core/database/app_database.dart';
import 'package:saldo/features/accounts/presentation/account_form_page.dart';
import 'package:saldo/features/accounts/presentation/accounts_list_page.dart';

import 'saldo_test_utils.dart';

void main() {
  testWidgets(
    'accounts list empty state + shows created account',
    (WidgetTester tester) async {
      final harness = await pumpSaldo(tester, const AccountsListPage());
      final db = harness.db;
      expect(find.text('No accounts yet'), findsOneWidget);

      await tester.runAsync(
        () => db
            .into(db.accounts)
            .insert(
              AccountsCompanion.insert(
                id: 'a1',
                name: 'Cash',
                currencyCode: 'NGN',
                openingBalanceMinor: 2000000,
                createdAt: DateTime(2026, 10, 1),
                updatedAt: DateTime(2026, 10, 1),
              ),
            ),
      );
      await settle(tester);
      expect(find.text('Cash'), findsOneWidget);
      expect(find.textContaining('20,000'), findsOneWidget);

      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'account form rejects empty name (no phantom success)',
    (WidgetTester tester) async {
      final harness = await pumpSaldo(tester, const AccountFormPage());
      final db = harness.db;
      await tester.tap(find.text('Create account'));
      await settle(tester);
      expect(find.text('Account name is required'), findsOneWidget);
      expect(await db.select(db.accounts).get(), isEmpty);

      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'account form rejects malformed opening balance',
    (WidgetTester tester) async {
      final harness = await pumpSaldo(tester, const AccountFormPage());
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Account name'),
        'Bank',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Opening balance (NGN)'),
        'abc',
      );
      await tester.tap(find.text('Create account'));
      await settle(tester);
      expect(find.text('Amount must be numeric'), findsOneWidget);

      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
