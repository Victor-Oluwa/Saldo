import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saldo/app/app.dart';
import 'package:saldo/app/saldo_nav_bar.dart';
import 'package:saldo/app/router.dart';
import 'package:saldo/core/database/app_database.dart';
import 'package:saldo/core/database/providers.dart';
import 'package:saldo/features/accounts/data/account_repository.dart';
import 'package:saldo/features/accounts/presentation/account_form_page.dart';
import 'package:saldo/features/budgets/presentation/budget_form_page.dart';
import 'package:saldo/features/settings/data/preferences_repository.dart';
import 'package:saldo/features/settings/presentation/settings_providers.dart';

/// Full user journeys through the real app (router + screens + database).
///
/// These run headlessly via `flutter test integration_test` with an
/// isolated in-memory saldo per test — same flows, no device state.
/// Platform share/file pickers are never tapped (no channels headlessly);
/// export/backup UI states are covered by widget tests, logic by
/// database tests.
///
/// Harness notes (hard-won in Milestones 3–5):
/// - Bounded timed pumps instead of `pumpAndSettle` (spinners never settle).
/// - Dispose unmounts first, flushes drift stream timers, then closes.
/// - `goRouter` is global: reset to `/` before each flow.
class FlowHarness {
  FlowHarness(this.db);

  final AppDatabase db;
  bool _closed = false;

  Future<void> dispose(WidgetTester tester) async {
    if (_closed) return;
    try {
      await tester.pumpWidget(Container());
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      var closed = false;
      final pending = db.close().then((_) => closed = true);
      for (var i = 0; i < 50 && !closed; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await pending;
    } finally {
      _closed = true;
    }
  }
}

Future<void> settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<FlowHarness> pumpApp(WidgetTester tester) async {
  goRouter.go('/');
  final harness = FlowHarness(AppDatabase.forTesting(NativeDatabase.memory()));
  addTearDown(() => harness.dispose(tester));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(harness.db),
        preferencesRepositoryProvider.overrideWith(
          (ref) async => MemoryPreferencesRepository(),
        ),
      ],
      child: const SaldoApp(),
    ),
  );
  await settle(tester);
  return harness;
}

/// Drags down (revealing lower content) until [target] builds, using
/// screen-coordinate drags. Finder-based scroll targeting breaks whenever
/// overlays (dropdown menus, sheets) add extra scrollables to the tree,
/// and lazy lists evict off-screen widgets — so loop + check.
///
/// Finishes with [tester.ensureVisible]: the loop exits as soon as the
/// target *builds*, but sliver cache extents build widgets while they are
/// still off-screen (tap would then miss under the app bar). ensureVisible
/// scrolls the minimal amount for true visibility; the rest settle lets
/// any residual ballistic fling decay.
Future<void> scrollDownTo(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 30 && target.evaluate().isEmpty; i++) {
    await tester.dragFrom(const Offset(400, 500), const Offset(0, -300));
    await settle(tester, 4);
  }
  if (target.evaluate().isNotEmpty) {
    await tester.ensureVisible(target.first);
    await settle(tester, 12);
  }
}

/// Drags up (revealing top content) until [target] builds. See [scrollDownTo].
Future<void> scrollUpTo(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 30 && target.evaluate().isEmpty; i++) {
    await tester.dragFrom(const Offset(400, 300), const Offset(0, 400));
    await settle(tester, 4);
  }
  if (target.evaluate().isNotEmpty) {
    await tester.ensureVisible(target.first);
    await settle(tester, 12);
  }
}

/// Drags the form list down until [target] builds (submit buttons sit
/// below the fold). Screen-coordinate drags; see [scrollDownTo].
Future<void> scrollFormTo(
  WidgetTester tester,
  Finder target, {
  String anchorLabel = 'Amount',
}) async {
  // Anchor check proves we are on the right form; the drag itself uses
  // screen coordinates (see scrollDownTo).
  assert(find.widgetWithText(TextFormField, anchorLabel).evaluate().isNotEmpty);
  for (var i = 0; i < 30 && target.evaluate().isEmpty; i++) {
    await tester.dragFrom(const Offset(400, 500), const Offset(0, -300));
    await settle(tester, 4);
  }
  if (target.evaluate().isNotEmpty) {
    await tester.ensureVisible(target.first);
    await settle(tester, 12);
  }
}

/// Taps a dropdown field, then its menu entry, settling between.
/// NOTE: the field type must name the exact generic instantiation —
/// a raw `DropdownButtonFormField` (aka `<dynamic>`) never matches
/// `DropdownButtonFormField<String>` in this Flutter version.
Future<void> pickDropdown(
  WidgetTester tester,
  String fieldLabel,
  String optionLabel,
) async {
  await tester.tap(
    find.widgetWithText(DropdownButtonFormField<String>, fieldLabel),
  );
  await settle(tester, 4);
  await tester.tap(find.text(optionLabel).last);
  await settle(tester, 4);
}

/// Shared journey definitions, runnable headlessly (`flutter test
/// test/journeys`) and on-device (`flutter test integration_test`).
/// Call [defineFlows] from a `main()` entry point in either location.
void defineFlows() {
  testWidgets(
    'journey: first launch → account → income → balance checks out',
    (WidgetTester tester) async {
      final harness = await pumpApp(tester);
      expect(find.text('Welcome to Saldo'), findsOneWidget);

      // Create account with ₦20,000 opening.
      await tester.tap(find.text('Create account'));
      await settle(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Account name'),
        'Cash',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Opening balance (NGN)'),
        '20000',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AccountFormPage),
          matching: find.text('Create account'),
        ),
      );
      await settle(tester);
      // Account tile is below the fold in the lazy dashboard list.
      await scrollDownTo(tester, find.text('Cash'));
      await settle(tester);
      expect(find.text('Cash'), findsWidgets);

      // Back home, record ₦25,000 freelance income.
      await tester.tap(find.text('Home'));
      await settle(tester);
      await scrollUpTo(tester, find.text('Add transaction'));
      await tester.tap(find.text('Add transaction'));
      await settle(tester);
      await tester.tap(find.text('Income'));
      await settle(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '25000',
      );
      await pickDropdown(tester, 'Account', 'Cash · NGN');
      await pickDropdown(tester, 'Category (income)', 'Freelance');
      // Plain tap: the sheet-context push puts this route outside the
      // branch subtree that byType scoping expects, and the label is
      // unique on screen. The button sits below the fold — scroll first.
      await scrollFormTo(tester, find.text('Record income'));
      await settle(tester);
      await tester.tap(find.text('Record income'));
      await settle(tester, 16);
      // Home shows the recorded income and the derived balance.
      await tester.tap(find.text('Home'));
      await settle(tester);
      await scrollDownTo(tester, find.textContaining('25,000'));
      await settle(tester);
      expect(find.textContaining('25,000'), findsWidgets);
      // Opening 20,000 + income 25,000 = 45,000 total (scroll back up;
      // lazy lists evict in both directions).
      await scrollUpTo(tester, find.textContaining('45,000'));
      await settle(tester);
      expect(find.textContaining('45,000'), findsWidgets);

      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );

  testWidgets(
    'journey: expense + transfer move both balances, cash flow holds',
    (WidgetTester tester) async {
      final harness = await pumpApp(tester);
      // Setup (not under test): two accounts.
      final repos = DriftAccountRepository(harness.db);
      await repos.createAccount(
        name: 'Bank',
        currencyCode: 'NGN',
        openingBalanceMinor: 2000000,
      );
      await repos.createAccount(
        name: 'Cash',
        currencyCode: 'NGN',
        openingBalanceMinor: 500000,
      );
      await settle(tester);

      // Expense ₦4,500 groceries from Bank via UI.
      await tester.tap(find.text('Transactions'));
      await settle(tester);
      await tester.tap(find.text('Add'));
      await settle(tester);
      await tester.tap(find.text('Expense'));
      await settle(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '4500',
      );
      await pickDropdown(tester, 'Account', 'Bank · NGN');
      await pickDropdown(tester, 'Category (expense)', 'Groceries');
      await scrollFormTo(tester, find.text('Record expense'));
      await settle(tester);
      await tester.tap(find.text('Record expense'));
      await settle(tester, 16);

      // Transfer ₦5,000 Bank → Cash via UI.
      await tester.tap(find.text('Add'));
      await settle(tester);
      await tester.tap(find.text('Transfer'));
      await settle(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '5000',
      );
      await pickDropdown(tester, 'From account', 'Bank · NGN');
      await pickDropdown(tester, 'To account', 'Cash · NGN');
      await scrollFormTo(tester, find.text('Record transfer'));
      await settle(tester);
      await tester.tap(find.text('Record transfer'));
      await settle(tester, 16);

      // Bank: 20,000 − 4,500 − 5,000 = 10,500. Cash: 5,000 + 5,000 = 10,000.
      await tester.tap(find.text('Home'));
      await settle(tester);
      await scrollDownTo(tester, find.textContaining('10,500'));
      await settle(tester);
      expect(find.textContaining('10,500'), findsWidgets);
      expect(find.textContaining('10,000'), findsWidgets);
      // Net cash flow counts the expense only: −₦4,500 (scroll back up).
      await scrollUpTo(tester, find.textContaining('4,500'));
      await settle(tester);
      expect(find.textContaining('4,500'), findsWidgets);

      // Reactive balance detail agrees (drill into the account tile).
      await scrollDownTo(tester, find.text('Bank'));
      await settle(tester);
      await tester.tap(find.text('Bank'));
      await settle(tester);
      expect(find.textContaining('10,500'), findsWidgets);

      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 180)),
  );

  testWidgets(
    'journey: budget tracks spending to remaining',
    (WidgetTester tester) async {
      final harness = await pumpApp(tester);
      final repos = DriftAccountRepository(harness.db);
      await repos.createAccount(
        name: 'Cash',
        currencyCode: 'NGN',
        openingBalanceMinor: 24850000,
      );
      await settle(tester);

      // Create ₦60,000 groceries budget via UI. (AppBar title and tab
      // label both read "Budgets" — scope to the navigation bar.)
      await tester.tap(
        find.descendant(
          of: find.byType(SaldoNavBar),
          matching: find.text('Budgets'),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('Budget'));
      await settle(tester);
      await pickDropdown(tester, 'Expense category', 'Groceries');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Monthly limit'),
        '60000',
      );
      await scrollFormTo(
        tester,
        find.text('Create budget'),
        anchorLabel: 'Monthly limit',
      );
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(BudgetFormPage),
          matching: find.text('Create budget'),
        ),
      );
      await settle(tester, 16);
      expect(find.textContaining('60,000'), findsWidgets);

      // Spend ₦42,000 via UI, back on Budgets → ₦18,000 left.
      await tester.tap(find.text('Transactions'));
      await settle(tester);
      await tester.tap(find.text('Add'));
      await settle(tester);
      await tester.tap(find.text('Expense'));
      await settle(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '42000',
      );
      await pickDropdown(tester, 'Account', 'Cash · NGN');
      await pickDropdown(tester, 'Category (expense)', 'Groceries');
      await scrollFormTo(tester, find.text('Record expense'));
      await settle(tester);
      await tester.tap(find.text('Record expense'));
      await settle(tester, 16);

      await tester.tap(find.text('Budgets'));
      await settle(tester);
      expect(find.textContaining('42,000'), findsWidgets);
      expect(find.textContaining('18,000'), findsWidgets);

      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 180)),
  );
}
