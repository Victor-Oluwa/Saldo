import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saldo/core/database/app_database.dart';
import 'package:saldo/features/home/presentation/home_page.dart';
import 'package:saldo/features/reports/presentation/reports_page.dart';
import 'package:saldo/features/transactions/data/transaction_repository.dart';
import 'package:saldo/features/transactions/presentation/transfer_form_page.dart';

import 'saldo_test_utils.dart';

/// Phones-only responsive matrix (see docs/plans/ui-redesign.md):
/// compact 320×640, standard 390×844, large 430×932, each at 1.0× and
/// 1.3× text scale. Any RenderFlex overflow surfaces as a test exception.
Future<void> seedActivity(AppDatabase db) async {
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
}

Future<void> expectNoOverflow(
  WidgetTester tester,
  Widget page, {
  required double width,
  required double height,
  required double textScale,
  Future<void> Function(AppDatabase db)? seed,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  // Reset even on failure — leaked view metrics poison later tests.
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  final harness = await pumpSaldo(tester, page, seed: seed);
  await settle(tester);
  await settle(tester, 16);
  // Scroll through the whole page: below-fold content must also fit.
  for (var i = 0; i < 12; i++) {
    await tester.dragFrom(const Offset(400, 500), const Offset(0, -300));
    await settle(tester, 4);
  }
  // TEMP-DIAG: don't take — let the framework print the full chain.
  final err = tester.takeException();
  expect(err, isNull);
  await harness.dispose(tester);
}

void main() {
  // flutter_test falls back to 1em-advance glyphs for variable fonts, which
  // inflates every label ~2x and flags phantoms. Load the real families so
  // the matrix measures device-faithful metrics.
  setUpAll(() async {
    Future<void> loadFamily(String family, String path) async {
      final loader = FontLoader(family);
      try {
        loader.addFont(rootBundle.load(path));
      } catch (_) {
        final bytes = await File(path).readAsBytes();
        loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      }
      await loader.load();
    }

    await loadFamily('Inter', 'assets/fonts/Inter-Variable.ttf');
  });

  const sizes = [
    (width: 320.0, height: 640.0, label: 'compact'),
    (width: 390.0, height: 844.0, label: 'standard'),
    (width: 430.0, height: 932.0, label: 'large'),
  ];

  for (final s in sizes) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'home dashboard fits ${s.label} at ${scale}x text',
        (tester) => expectNoOverflow(
          tester,
          const HomePage(),
          width: s.width,
          height: s.height,
          textScale: scale,
          seed: seedActivity,
        ),
        timeout: const Timeout(Duration(seconds: 60)),
      );
    }
  }

  testWidgets(
    'reports with charts fit standard at 1.3x text',
    (tester) => expectNoOverflow(
      tester,
      const ReportsPage(),
      width: 390,
      height: 844,
      textScale: 1.3,
      seed: seedActivity,
    ),
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'transfer form with preview fits compact at 1.3x text',
    (tester) => expectNoOverflow(
      tester,
      const TransferFormPage(),
      width: 320,
      height: 640,
      textScale: 1.3,
      seed: seedSaldoBasics,
    ),
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
