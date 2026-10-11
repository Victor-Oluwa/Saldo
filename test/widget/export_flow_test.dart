import 'package:flutter_test/flutter_test.dart';
import 'package:saldo/core/database/app_database.dart';
import 'package:saldo/features/settings/presentation/export_page.dart';
import 'package:saldo/features/transactions/data/transaction_repository.dart';

import 'saldo_test_utils.dart';

/// Seeds one income + one expense in the current month.
Future<void> seedTwoTx(AppDatabase db) async {
  final ids = await seedSaldoBasics(db);
  final txs = DriftTransactionRepository(db);
  final now = DateTime.now();
  await txs.createIncome(
    accountId: ids.accountId,
    categoryId: ids.incomeCatId,
    amountMinor: 8500000,
    transactionDate: DateTime(now.year, now.month, 5),
  );
  await txs.createExpense(
    accountId: ids.accountId,
    categoryId: ids.expenseCatId,
    amountMinor: 450000,
    transactionDate: DateTime(now.year, now.month, 9),
  );
}

void main() {
  testWidgets(
    'export shows live match count + convention note',
    (WidgetTester tester) async {
      final harness = await pumpSaldo(
        tester,
        const ExportPage(),
        seed: seedTwoTx,
      );
      await settle(tester);

      expect(find.text('2 transactions match.'), findsOneWidget);
      expect(find.textContaining('transfer group/side'), findsOneWidget);
      expect(find.text('Export CSV'), findsOneWidget);

      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'type filter narrows the export count',
    (WidgetTester tester) async {
      final harness = await pumpSaldo(
        tester,
        const ExportPage(),
        seed: seedTwoTx,
      );
      await settle(tester);

      await tester.tap(find.text('Expense'));
      await settle(tester);

      expect(find.text('1 transaction matches.'), findsOneWidget);

      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
