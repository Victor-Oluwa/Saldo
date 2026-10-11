import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saldo/core/database/app_database.dart';
import 'package:saldo/core/demo/demo_data.dart';
import 'package:saldo/features/accounts/data/account_repository.dart';
import 'package:saldo/features/budgets/data/budget_repository.dart';
import 'package:saldo/features/categories/data/category_repository.dart';
import 'package:saldo/features/transactions/data/transaction_repository.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('demo saldo is balanced and internally consistent', () async {
    final accounts = DriftAccountRepository(db);
    // Gate: demo data is only ever seeded onto an empty saldo.
    expect(await accounts.getAll(includeArchived: true), isEmpty);

    await seedDemoData(
      accounts: accounts,
      categories: DriftCategoryRepository(db),
      transactions: DriftTransactionRepository(db),
      budgets: DriftBudgetRepository(db),
      now: DateTime(2026, 10, 9),
    );

    final all = await accounts.getAll();
    expect(all.map((a) => a.name), containsAll(['Bank', 'Cash']));

    final bank = all.firstWhere((a) => a.name == 'Bank');
    final cash = all.firstWhere((a) => a.name == 'Cash');
    // Bank: 20,000 + 25,000 − 4,500 − 20,000 = 20,500.
    expect(await accounts.getBalance(bank.id), 2050000);
    // Cash: 5,000 − 1,200 + 20,000 = 23,800.
    expect(await accounts.getBalance(cash.id), 2380000);

    final txs = await DriftTransactionRepository(
      db,
    ).query().then((rows) => rows.length);
    expect(txs, 5); // income + 2 expenses + 2 transfer legs

    final budgets = await DriftBudgetRepository(
      db,
    ).getForMonth(DateTime(2026, 10, 1));
    expect(budgets.length, 1);
    expect(budgets.first.limitMinor, 6000000);
  });
}
