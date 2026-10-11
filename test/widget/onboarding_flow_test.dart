import 'package:flutter_test/flutter_test.dart';
import 'package:saldo/app/router.dart';
import 'package:saldo/features/onboarding/presentation/onboarding_page.dart';
import 'package:saldo/features/settings/data/preferences_repository.dart';
import 'package:saldo/features/settings/presentation/settings_providers.dart';

import 'saldo_test_utils.dart';

void main() {
  Future<MemoryPreferencesRepository> pumpOnboarding(
    WidgetTester tester,
    MemoryPreferencesRepository prefs,
  ) async {
    addTearDown(() => OnboardingGate.showOnboarding = false);
    await pumpSaldo(
      tester,
      const OnboardingPage(),
      extra: [preferencesRepositoryProvider.overrideWith((ref) async => prefs)],
    );
    return prefs;
  }

  testWidgets(
    'welcome → currency → account pages flow in order',
    (WidgetTester tester) async {
      final prefs = MemoryPreferencesRepository();
      await pumpOnboarding(tester, prefs);
      await settle(tester);

      expect(find.text('Welcome to Saldo'), findsOneWidget);
      expect(find.bySemanticsLabel('Step 1 of 3: Welcome'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await settle(tester);
      expect(find.text('Choose your currency'), findsOneWidget);

      await tester.tap(find.text('USD (\$)'));
      await tester.tap(find.text('Next'));
      await settle(tester);
      expect(await prefs.defaultCurrencyCode(), 'USD');
      expect(find.text('Create your first account'), findsOneWidget);

      await tester.tap(find.text('Explore first'));
      await settle(tester);
      expect(await prefs.onboardingCompleted(), isTrue);
      expect(OnboardingGate.showOnboarding, isFalse);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'skip completes onboarding without choosing',
    (WidgetTester tester) async {
      final prefs = MemoryPreferencesRepository();
      await pumpOnboarding(tester, prefs);
      await settle(tester);

      await tester.tap(find.text('Skip'));
      await settle(tester);
      expect(await prefs.onboardingCompleted(), isTrue);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
