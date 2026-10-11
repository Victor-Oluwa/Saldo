import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saldo/core/database/app_database.dart';
import 'package:saldo/features/accounts/data/account_repository.dart';
import 'package:saldo/features/categories/data/category_repository.dart';
import 'package:saldo/features/categories/domain/category.dart';
import 'package:saldo/features/transactions/data/transaction_repository.dart';
import 'package:saldo/features/transactions/domain/transaction.dart';

/// Report reconciliation: period income/expenses/net must equal the
/// underlying transaction query for the same range. Transfers excluded.
void main() {
  late AppDatabase db;
  late DriftAccountRepository accounts;
  late DriftCategoryRepository categories;
  late DriftTransactionRepository txs;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    accounts = DriftAccountRepository(db);
    categories = DriftCategoryRepository(db);
    txs = DriftTransactionRepository(db);
    await categories.seedSystemDefaults();
  });

  tearDown(() async {
    await db.close();
  });

  test('report totals reconcile with transaction history', () async {
    final bank = await accounts.createAccount(
      name: 'Bank',
      currencyCode: 'NGN',
      openingBalanceMinor: 0,
    );
    final salary = (await categories.getByType(CategoryType.income)).first.id;
    final food = (await categories.getByType(
      CategoryType.expense,
    )).firstWhere((c) => c.name == 'Groceries').id;
    final transport = (await categories.getByType(
      CategoryType.expense,
    )).firstWhere((c) => c.name == 'Transport').id;

    await txs.createIncome(
      accountId: bank.id,
      categoryId: salary,
      amountMinor: 8500000, // ₦85,000 October
      transactionDate: DateTime(2026, 10, 5),
    );
    await txs.createExpense(
      accountId: bank.id,
      categoryId: food,
      amountMinor: 450000,
      transactionDate: DateTime(2026, 10, 9),
    );
    await txs.createExpense(
      accountId: bank.id,
      categoryId: transport,
      amountMinor: 120000,
      transactionDate: DateTime(2026, 10, 8),
    );
    // September expense must not leak into October.
    await txs.createExpense(
      accountId: bank.id,
      categoryId: food,
      amountMinor: 999900,
      transactionDate: DateTime(2026, 9, 28),
    );

    final oct = await txs.getPeriodTotals(
      start: DateTime(2026, 10, 1),
      endExclusive: DateTime(2026, 11, 1),
    );
    expect(oct.incomeByCurrency['NGN'], 8500000);
    expect(oct.expenseByCurrency['NGN'], 450000 + 120000);
    expect(oct.netByCurrency['NGN'], 8500000 - 570000);

    // Cross-check: manual sum over the same query matches.
    final octRows = await txs.query(
      filter: TransactionFilter(
        start: DateTime(2026, 10, 1),
        endExclusive: DateTime(2026, 11, 1),
      ),
    );
    var incomeSum = 0;
    var expenseSum = 0;
    for (final r in octRows) {
      if (r.type == TransactionType.income) {
        incomeSum += r.amountMinor;
      } else if (r.type == TransactionType.expense) {
        expenseSum += r.amountMinor;
      }
    }
    // Need import for TransactionType — use string-free check via totals.
    expect(incomeSum, oct.incomeByCurrency['NGN']);
    expect(expenseSum, oct.expenseByCurrency['NGN']);

    // Changing period updates everything; empty period safe.
    final sep = await txs.getPeriodTotals(
      start: DateTime(2026, 9, 1),
      endExclusive: DateTime(2026, 10, 1),
    );
    expect(sep.incomeByCurrency['NGN'] ?? 0, 0);
    expect(sep.expenseByCurrency['NGN'], 999900);

    final empty = await txs.getPeriodTotals(
      start: DateTime(2025, 1, 1),
      endExclusive: DateTime(2025, 2, 1),
    );
    expect(empty.incomeByCurrency, isEmpty);
    expect(empty.expenseByCurrency, isEmpty);
    expect(empty.netByCurrency, isEmpty);
  });
}
