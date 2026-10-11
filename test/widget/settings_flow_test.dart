import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saldo/features/settings/data/preferences_repository.dart';
import 'package:saldo/features/settings/presentation/settings_page.dart';
import 'package:saldo/features/settings/presentation/settings_providers.dart';

import 'saldo_test_utils.dart';

/// In-memory prefs override (SharedPreferences needs platform channels).
List<dynamic> prefsOverride([String currency = 'NGN']) => [
  preferencesRepositoryProvider.overrideWith(
    (ref) async => MemoryPreferencesRepository(initialCurrency: currency),
  ),
];

void main() {
  testWidgets('settings renders data actions', (WidgetTester tester) async {
    final harness = await pumpSaldo(
      tester,
      const SettingsPage(),
      extra: prefsOverride(),
    );
    await settle(tester);

    expect(find.text('Export transactions (CSV)'), findsOneWidget);
    expect(find.text('Back up saldo'), findsOneWidget);
    expect(find.text('Restore from backup'), findsOneWidget);
    expect(find.text('Clear all data'), findsOneWidget);
    expect(find.text('Ruled Saldo theme'), findsOneWidget);

    await harness.dispose(tester);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets(
    'currency locks once accounts exist',
    (WidgetTester tester) async {
      final harness = await pumpSaldo(
        tester,
        const SettingsPage(),
        seed: seedSaldoBasics,
        extra: prefsOverride(),
      );
      await settle(tester);

      expect(find.textContaining('Locked'), findsOneWidget);

      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'clear-all asks for confirmation first',
    (WidgetTester tester) async {
      final harness = await pumpSaldo(
        tester,
        const SettingsPage(),
        extra: prefsOverride(),
      );
      await settle(tester);

      await tester.scrollUntilVisible(find.text('Clear all data'), 300);
      await settle(tester);
      await tester.tap(find.text('Clear all data'));
      await settle(tester);

      // Destructive dialog explains the effect; nothing deleted yet.
      expect(find.text('Delete all saldo data?'), findsOneWidget);
      expect(find.text('Delete everything'), findsOneWidget);

      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'demo data loads onto an empty saldo only',
    (WidgetTester tester) async {
      final harness = await pumpSaldo(
        tester,
        const SettingsPage(),
        extra: prefsOverride(),
      );
      await settle(tester);

      expect(find.text('Load demo data'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Load demo data'), 300);
      await settle(tester);
      await tester.tap(find.text('Load demo data'));
      await settle(tester);
      // The lock note sits at the top of a lazy ListView whose items were
      // evicted while scrolled down — drag back up until it rebuilds.
      for (
        var i = 0;
        i < 20 && find.textContaining('Locked').evaluate().isEmpty;
        i++
      ) {
        await tester.drag(find.byType(ListView), const Offset(0, 400));
        await settle(tester);
      }

      // Seeded accounts lock the currency afterwards.
      expect(find.textContaining('Locked'), findsOneWidget);

      // Seeded accounts lock the currency afterwards.
      expect(find.textContaining('Locked'), findsOneWidget);

      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
