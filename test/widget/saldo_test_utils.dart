import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saldo/app/theme/app_theme.dart';
import 'package:saldo/core/database/app_database.dart';
import 'package:saldo/core/database/providers.dart';
import 'package:saldo/features/accounts/data/account_repository.dart';
import 'package:saldo/features/categories/data/category_repository.dart';
import 'package:saldo/features/categories/domain/category.dart';

/// Shared harness: in-memory saldo + cleanup that keeps flutter_test's
/// fake-async zone happy.
///
/// Drift's stream queries schedule zero-duration close timers when
/// subscriptions cancel. If the widget tree is still mounted at test end,
/// those timers are pending during teardown verification and fail the test
/// ("A Timer is still pending..."). [dispose] unmounts first, flushes the
/// timers with extra pumps, then closes the db — all inside the test body.
class SaldoHarness {
  SaldoHarness(this.db);

  final AppDatabase db;
  bool _closed = false;

  /// Unmounts, flushes drift stream-cancel timers, then closes the db.
  ///
  /// Drift defers stream shutdown with zero-duration timers and `close()`
  /// awaits them. Inside flutter_test's fake-async zone those timers only
  /// fire when the clock advances, so a bare `await db.close()` hangs
  /// forever. Interleaving pumps until close completes fixes it.
  Future<void> dispose(WidgetTester tester) async {
    if (_closed) return;
    try {
      await tester.pumpWidget(Container());
      // Flush subscription-cancel timers scheduled during unmount.
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

/// Bounded settle: Drift watch streams resolve via microtasks, but loading
/// spinners animate forever, so [pumpAndSettle] never returns. Pump a few
/// timed frames instead — enough for streams/futures to emit.
Future<void> settle(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps until [finder] matches or [maxFrames] elapse. For multi-step async
/// flows (e.g. demo seeding with ~25 sequential writes) a fixed frame count
/// either wastes time or — worse — asserts before the final rebuild.
/// Fails the test on timeout via [expect].
Future<void> settleUntil(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 100,
}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsWidgets);
}

/// Pumps [child] with an isolated in-memory saldo. Caller must
/// `await harness.dispose(tester)` as the last step of the test.
///
/// Pass [seed] to write test data BEFORE the first frame: future-based
/// providers (totals, usage, reports) evaluate once and only recompute when
/// watched state changes — exactly like the app, where forms bump
/// `transactionsVersionProvider` after every write. Seeding up-front keeps
/// tests deterministic instead of racing the initial fetch.
///
/// [extra] carries additional provider overrides (e.g. an in-memory
/// preferences repo — `List<dynamic>` because the override type is not
/// exported by flutter_riverpod).
Future<SaldoHarness> pumpSaldo(
  WidgetTester tester,
  Widget child, {
  Future<void> Function(AppDatabase db)? seed,
  List<dynamic> extra = const [],
}) async {
  final harness = SaldoHarness(
    AppDatabase.forTesting(NativeDatabase.memory()),
  );
  if (seed != null) await seed(harness.db);
  addTearDown(() => harness.dispose(tester));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(harness.db), ...extra],
      child: MaterialApp(theme: SaldoTheme.dark(), home: child),
    ),
  );
  await settle(tester);
  return harness;
}

/// Replaces the current tree with [child] on the same harness db.
Future<void> repumpSaldo(
  WidgetTester tester,
  SaldoHarness harness,
  Widget child,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(harness.db)],
      child: MaterialApp(theme: SaldoTheme.dark(), home: child),
    ),
  );
  await settle(tester);
}

/// Seeds one NGN account + default categories. Returns ids for tests that
/// record transactions/budgets through repositories.
Future<({String accountId, String incomeCatId, String expenseCatId})>
seedSaldoBasics(AppDatabase db) async {
  final accounts = DriftAccountRepository(db);
  final cats = DriftCategoryRepository(db);
  await cats.seedSystemDefaults();
  final acc = await accounts.createAccount(
    name: 'Bank',
    currencyCode: 'NGN',
    openingBalanceMinor: 0,
  );
  final incomeCat = (await cats.getByType(CategoryType.income)).first;
  final expenseCat = (await cats.getByType(
    CategoryType.expense,
  )).firstWhere((c) => c.name == 'Groceries');
  return (
    accountId: acc.id,
    incomeCatId: incomeCat.id,
    expenseCatId: expenseCat.id,
  );
}
