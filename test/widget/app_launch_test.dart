import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saldo/app/app.dart';
import 'package:saldo/core/database/app_database.dart';
import 'package:saldo/core/database/providers.dart';

import 'saldo_test_utils.dart';

void main() {
  testWidgets(
    'launches with dark shell, first-run home + 5 tabs',
    (WidgetTester tester) async {
      final harness = SaldoHarness(
        AppDatabase.forTesting(NativeDatabase.memory()),
      );
      addTearDown(() => harness.dispose(tester));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(harness.db)],
          child: const SaldoApp(),
        ),
      );
      await settle(tester);

      // First-run home (empty saldo): AppBar + welcome card.
      expect(find.text('Saldo'), findsOneWidget);
      expect(find.text('Welcome to Saldo'), findsOneWidget);

      // 5 bottom-nav destinations.
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Transactions'), findsOneWidget);
      expect(find.text('Budgets'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // Transactions tab renders its (empty) history.
      await tester.tap(find.text('Transactions'));
      await settle(tester);
      expect(find.text('No transactions yet'), findsOneWidget);

      // Navigate back home via nav bar.
      await tester.tap(find.text('Home'));
      await settle(tester);
      expect(find.text('Welcome to Saldo'), findsOneWidget);

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, ThemeMode.dark);

      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
