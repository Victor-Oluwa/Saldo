import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saldo/core/database/app_database.dart';
import 'package:saldo/core/errors/failures.dart';
import 'package:saldo/features/accounts/data/account_repository.dart';
import 'package:saldo/features/categories/data/category_repository.dart';
import 'package:saldo/features/categories/domain/category.dart';
import 'package:saldo/features/transactions/data/transaction_repository.dart';
import 'package:saldo/features/transactions/domain/transaction.dart';

void main() {
  late AppDatabase db;
  late DriftAccountRepository accounts;
  late DriftCategoryRepository categories;
  late DriftTransactionRepository txs;

  late String bankId;
  late String cashId;
  late String salaryCat;
  late String foodCat;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    accounts = DriftAccountRepository(db);
    categories = DriftCategoryRepository(db);
    txs = DriftTransactionRepository(db);
    await categories.seedSystemDefaults();

    final bank = await accounts.createAccount(
      name: 'Bank',
      currencyCode: 'NGN',
      openingBalanceMinor: 2000000, // ₦20,000
    );
    final cash = await accounts.createAccount(
      name: 'Cash',
      currencyCode: 'NGN',
      openingBalanceMinor: 500000, // ₦5,000
    );
    bankId = bank.id;
    cashId = cash.id;
    salaryCat = (await categories.getByType(
      CategoryType.income,
    )).firstWhere((c) => c.name == 'Freelance').id;
    foodCat = (await categories.getByType(
      CategoryType.expense,
    )).firstWhere((c) => c.name == 'Groceries').id;
  });

  tearDown(() async {
    await db.close();
  });

  test('income increases balance + period income', () async {
    await txs.createIncome(
      accountId: bankId,
      categoryId: salaryCat,
      amountMinor: 2500000, // +₦25,000
      transactionDate: DateTime(2026, 10, 8),
      description: 'Freelance income',
    );
    expect(await accounts.getBalance(bankId), 2000000 + 2500000);
    final totals = await txs.getPeriodTotals(
      start: DateTime(2026, 10, 1),
      endExclusive: DateTime(2026, 11, 1),
    );
    expect(totals.incomeByCurrency['NGN'], 2500000);
    expect(totals.expenseByCurrency['NGN'] ?? 0, 0);
    expect(totals.netByCurrency['NGN'], 2500000);
  });

  test('expense decreases balance + increases expense totals', () async {
    await txs.createExpense(
      accountId: bankId,
      categoryId: foodCat,
      amountMinor: 450000,
      transactionDate: DateTime(2026, 10, 9),
    );
    expect(await accounts.getBalance(bankId), 2000000 - 450000);
  });

  test(
    'transfer ₦20,000 Bank→Cash: equal/opposite, totals unchanged',
    () async {
      final incomeTx = await txs.createIncome(
        accountId: bankId,
        categoryId: salaryCat,
        amountMinor: 8500000,
        transactionDate: DateTime(2026, 10, 1),
      );
      expect(incomeTx.type, TransactionType.income);

      final bankBefore = await accounts.getBalance(bankId);
      final cashBefore = await accounts.getBalance(cashId);
      final totalsBefore = await txs.getPeriodTotals(
        start: DateTime(2026, 10, 1),
        endExclusive: DateTime(2026, 11, 1),
      );

      final outLeg = await txs.createTransfer(
        sourceAccountId: bankId,
        destAccountId: cashId,
        amountMinor: 2000000,
        transactionDate: DateTime(2026, 10, 9),
      );
      expect(outLeg.transferSide, TransferSide.out);
      final legs = await txs.getTransferLegs(outLeg.transferGroupId!);
      expect(legs.length, 2);
      expect(
        legs.map((e) => e.transferSide),
        containsAll([TransferSide.out, TransferSide.incoming]),
      );
      // Same amount, same currency, linked counterparts.
      expect(legs[0].amountMinor, legs[1].amountMinor);
      expect(legs[0].currencyCode, legs[1].currencyCode);

      expect(await accounts.getBalance(bankId), bankBefore - 2000000);
      expect(await accounts.getBalance(cashId), cashBefore + 2000000);

      // Same-currency assets unchanged overall.
      final totalsAfter = await accounts.getTotalBalancesByCurrency();
      final totalsBeforeAll = bankBefore + cashBefore;
      expect(totalsAfter['NGN'], totalsBeforeAll);

      // Income/expense/net untouched by transfer.
      final totalsAfterPeriod = await txs.getPeriodTotals(
        start: DateTime(2026, 10, 1),
        endExclusive: DateTime(2026, 11, 1),
      );
      expect(totalsAfterPeriod.incomeByCurrency, totalsBefore.incomeByCurrency);
      expect(
        totalsAfterPeriod.expenseByCurrency,
        totalsBefore.expenseByCurrency,
      );
      expect(totalsAfterPeriod.netByCurrency, totalsBefore.netByCurrency);
    },
  );

  test('transfer rejects same account + leaves no partial state', () async {
    final countBefore = (await txs.query()).length;
    await expectLater(
      txs.createTransfer(
        sourceAccountId: bankId,
        destAccountId: bankId,
        amountMinor: 1000,
        transactionDate: DateTime(2026, 10, 9),
      ),
      throwsA(isA<ValidationFailure>()),
    );
    expect((await txs.query()).length, countBefore);
  });

  test('transfer rejects unlike currencies', () async {
    final usd = await accounts.createAccount(
      name: 'USD',
      currencyCode: 'USD',
      openingBalanceMinor: 10000,
    );
    await expectLater(
      txs.createTransfer(
        sourceAccountId: bankId,
        destAccountId: usd.id,
        amountMinor: 1000,
        transactionDate: DateTime(2026, 10, 9),
      ),
      throwsA(isA<ValidationFailure>()),
    );
    expect(await txs.query(), isEmpty);
  });

  test('edit + delete recompute balances from records', () async {
    final tx = await txs.createExpense(
      accountId: bankId,
      categoryId: foodCat,
      amountMinor: 450000,
      transactionDate: DateTime(2026, 10, 9),
    );
    expect(await accounts.getBalance(bankId), 2000000 - 450000);
    await txs.updateExpense(id: tx.id, amountMinor: 500000);
    expect(await accounts.getBalance(bankId), 2000000 - 500000);
    await txs.deleteTransaction(tx.id);
    expect(await accounts.getBalance(bankId), 2000000);
  });

  test('deleting one transfer leg removes both atomically', () async {
    final outLeg = await txs.createTransfer(
      sourceAccountId: bankId,
      destAccountId: cashId,
      amountMinor: 120000, // ₦1,200 transport-like
      transactionDate: DateTime(2026, 10, 8),
    );
    final bankAfter = await accounts.getBalance(bankId);
    expect(bankAfter, 2000000 - 120000);
    await txs.deleteTransaction(outLeg.id);
    expect(await accounts.getBalance(bankId), 2000000);
    expect(await accounts.getBalance(cashId), 500000);
    expect(await txs.query(), isEmpty);
  });

  test('search + filters combine, stable order, empty helpful', () async {
    await txs.createExpense(
      accountId: bankId,
      categoryId: foodCat,
      amountMinor: 450000,
      transactionDate: DateTime(2026, 10, 9),
      description: 'Groceries',
    );
    await txs.createIncome(
      accountId: bankId,
      categoryId: salaryCat,
      amountMinor: 2500000,
      transactionDate: DateTime(2026, 10, 8),
      description: 'Freelance income',
    );
    // Search.
    expect(
      (await txs.query(
        filter: const TransactionFilter(search: 'Groceries'),
      )).length,
      1,
    );
    // Type filter.
    expect(
      (await txs.query(
        filter: const TransactionFilter(type: TransactionType.income),
      )).length,
      1,
    );
    // Combined: expense in bank in October.
    final combined = await txs.query(
      filter: TransactionFilter(
        type: TransactionType.expense,
        accountId: bankId,
        start: DateTime(2026, 10, 1),
        endExclusive: DateTime(2026, 11, 1),
      ),
    );
    expect(combined.length, 1);
    // Reverse chronological: Oct 9 first.
    final all = await txs.query();
    expect(all.first.transactionDate, DateTime(2026, 10, 9));
    // Empty result.
    expect(
      await txs.query(filter: const TransactionFilter(search: 'zzz-no-match')),
      isEmpty,
    );
  });
}
