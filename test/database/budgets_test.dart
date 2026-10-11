import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saldo/core/database/app_database.dart';
import 'package:saldo/core/errors/failures.dart';
import 'package:saldo/features/accounts/data/account_repository.dart';
import 'package:saldo/features/budgets/data/budget_repository.dart';
import 'package:saldo/features/budgets/domain/budget.dart';
import 'package:saldo/features/categories/data/category_repository.dart';
import 'package:saldo/features/categories/domain/category.dart';
import 'package:saldo/features/transactions/data/transaction_repository.dart';

void main() {
  late AppDatabase db;
  late DriftAccountRepository accounts;
  late DriftCategoryRepository categories;
  late DriftTransactionRepository txs;
  late DriftBudgetRepository budgets;

  late String cashId;
  late String foodCat;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    accounts = DriftAccountRepository(db);
    categories = DriftCategoryRepository(db);
    txs = DriftTransactionRepository(db);
    budgets = DriftBudgetRepository(db);
    await categories.seedSystemDefaults();

    cashId = (await accounts.createAccount(
      name: 'Cash',
      currencyCode: 'NGN',
      openingBalanceMinor: 24850000, // ₦248,500
    )).id;
    foodCat = (await categories.getByType(
      CategoryType.expense,
    )).firstWhere((c) => c.name == 'Groceries').id;
  });

  tearDown(() async {
    await db.close();
  });

  test('₦60k budget with ₦42k spending → ₦18k remaining', () async {
    final b = await budgets.create(
      categoryId: foodCat,
      periodStart: DateTime(2026, 10, 1),
      limitMinor: 6000000,
      currencyCode: 'NGN',
    );
    await txs.createExpense(
      accountId: cashId,
      categoryId: foodCat,
      amountMinor: 4200000,
      transactionDate: DateTime(2026, 10, 9),
    );
    final usage = await budgets.getUsage(b.id);
    expect(usage.spentMinor, 4200000);
    expect(usage.remainingMinor, 1800000);
    expect(usage.isOverspent, isFalse);
  });

  test('₦65k spending on ₦60k → −₦5k overspent', () async {
    final b = await budgets.create(
      categoryId: foodCat,
      periodStart: DateTime(2026, 10, 1),
      limitMinor: 6000000,
      currencyCode: 'NGN',
    );
    await txs.createExpense(
      accountId: cashId,
      categoryId: foodCat,
      amountMinor: 6500000,
      transactionDate: DateTime(2026, 10, 9),
    );
    final usage = await budgets.getUsage(b.id);
    expect(usage.spentMinor, 6500000);
    expect(usage.remainingMinor, -500000);
    expect(usage.isOverspent, isTrue);
  });

  test('income + transfers excluded from budget usage', () async {
    final b = await budgets.create(
      categoryId: foodCat,
      periodStart: DateTime(2026, 10, 1),
      limitMinor: 6000000,
      currencyCode: 'NGN',
    );
    final incomeCat = (await categories.getByType(
      CategoryType.income,
    )).first.id;
    await txs.createIncome(
      accountId: cashId,
      categoryId: incomeCat,
      amountMinor: 8500000,
      transactionDate: DateTime(2026, 10, 5),
    );
    final other = await accounts.createAccount(
      name: 'Bank',
      currencyCode: 'NGN',
      openingBalanceMinor: 0,
    );
    await txs.createTransfer(
      sourceAccountId: cashId,
      destAccountId: other.id,
      amountMinor: 2000000,
      transactionDate: DateTime(2026, 10, 6),
    );
    final usage = await budgets.getUsage(b.id);
    expect(usage.spentMinor, 0);
    expect(usage.remainingMinor, 6000000);
  });

  test('duplicate active budget rejected; edit/delete update usage', () async {
    final b = await budgets.create(
      categoryId: foodCat,
      periodStart: DateTime(2026, 10, 15), // normalized to Oct 1
      limitMinor: 6000000,
      currencyCode: 'NGN',
    );
    expect(b.periodStart, DateTime(2026, 10, 1));
    await expectLater(
      budgets.create(
        categoryId: foodCat,
        periodStart: DateTime(2026, 10, 1),
        limitMinor: 6000000,
        currencyCode: 'NGN',
      ),
      throwsA(isA<ValidationFailure>()),
    );

    final tx = await txs.createExpense(
      accountId: cashId,
      categoryId: foodCat,
      amountMinor: 4200000,
      transactionDate: DateTime(2026, 10, 9),
    );
    expect((await budgets.getUsage(b.id)).remainingMinor, 1800000);
    // Editing eligible expense updates usage.
    await txs.updateExpense(id: tx.id, amountMinor: 5000000);
    expect((await budgets.getUsage(b.id)).remainingMinor, 1000000);
    // Deleting restores.
    await txs.deleteTransaction(tx.id);
    expect((await budgets.getUsage(b.id)).spentMinor, 0);

    // Out-of-month expenses ignored.
    await txs.createExpense(
      accountId: cashId,
      categoryId: foodCat,
      amountMinor: 999999,
      transactionDate: DateTime(2026, 9, 30, 23, 59),
    );
    expect((await budgets.getUsage(b.id)).spentMinor, 0);

    // Wrong-currency expenses ignored (single-currency policy).
    final usdAcc = await accounts.createAccount(
      name: 'USD',
      currencyCode: 'USD',
      openingBalanceMinor: 100000,
    );
    await txs.createExpense(
      accountId: usdAcc.id,
      categoryId: foodCat,
      amountMinor: 10000,
      transactionDate: DateTime(2026, 10, 10),
    );
    expect((await budgets.getUsage(b.id)).spentMinor, 0);
  });

  test('budgets require expense category + month normalization', () async {
    final incomeCat = (await categories.getByType(
      CategoryType.income,
    )).first.id;
    await expectLater(
      budgets.create(
        categoryId: incomeCat,
        periodStart: DateTime(2026, 10, 1),
        limitMinor: 1000,
        currencyCode: 'NGN',
      ),
      throwsA(isA<ValidationFailure>()),
    );
    expect(
      Budget.normalizeMonthStart(DateTime(2026, 10, 20, 15, 30)),
      DateTime(2026, 10, 1),
    );
  });
}
