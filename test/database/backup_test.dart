import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saldo/core/backup/backup.dart';
import 'package:saldo/core/database/app_database.dart';
import 'package:saldo/core/errors/failures.dart';
import 'package:saldo/features/accounts/data/account_repository.dart';
import 'package:saldo/features/budgets/data/budget_repository.dart';
import 'package:saldo/features/categories/data/category_repository.dart';
import 'package:saldo/features/categories/domain/category.dart';
import 'package:saldo/features/settings/data/preferences_repository.dart';
import 'package:saldo/features/transactions/data/transaction_repository.dart';

/// Seeds: Bank ₦20,000 + Cash ₦5,000, salary income ₦25,000 to Bank,
/// groceries expense ₦4,500 from Bank, ₦20,000 Bank→Cash transfer,
/// ₦60,000 Groceries budget.
Future<Map<String, String>> seedRichSaldo(
  AppDatabase db,
  MemoryPreferencesRepository prefs,
) async {
  final accounts = DriftAccountRepository(db);
  final cats = DriftCategoryRepository(db);
  final txs = DriftTransactionRepository(db);
  final budgets = DriftBudgetRepository(db);
  await cats.seedSystemDefaults();
  await prefs.setDefaultCurrencyCode('NGN');

  final bank = await accounts.createAccount(
    name: 'Bank',
    currencyCode: 'NGN',
    openingBalanceMinor: 2000000,
  );
  final cash = await accounts.createAccount(
    name: 'Cash',
    currencyCode: 'NGN',
    openingBalanceMinor: 500000,
  );
  final salary = (await cats.getByType(
    CategoryType.income,
  )).firstWhere((c) => c.name == 'Freelance').id;
  final food = (await cats.getByType(
    CategoryType.expense,
  )).firstWhere((c) => c.name == 'Groceries').id;

  await txs.createIncome(
    accountId: bank.id,
    categoryId: salary,
    amountMinor: 2500000,
    transactionDate: DateTime(2026, 10, 8),
  );
  await txs.createExpense(
    accountId: bank.id,
    categoryId: food,
    amountMinor: 450000,
    transactionDate: DateTime(2026, 10, 9),
  );
  await txs.createTransfer(
    sourceAccountId: bank.id,
    destAccountId: cash.id,
    amountMinor: 2000000,
    transactionDate: DateTime(2026, 10, 9),
  );
  final budget = await budgets.create(
    categoryId: food,
    periodStart: DateTime(2026, 10, 1),
    limitMinor: 6000000,
    currencyCode: 'NGN',
  );
  return {'bank': bank.id, 'cash': cash.id, 'budget': budget.id};
}

Future<Map<String, int>> snapshot(AppDatabase db) async {
  return {
    'accounts': (await db.select(db.accounts).get()).length,
    'categories': (await db.select(db.categories).get()).length,
    'transactions': (await db.select(db.transactions).get()).length,
    'budgets': (await db.select(db.budgets).get()).length,
  };
}

void main() {
  late AppDatabase db;
  late MemoryPreferencesRepository prefs;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    prefs = MemoryPreferencesRepository();
  });

  tearDown(() async {
    await db.close();
  });

  test('round-trip reproduces balances, reports and budget usage', () async {
    final ids = await seedRichSaldo(db, prefs);
    final accounts = DriftAccountRepository(db);
    final txs = DriftTransactionRepository(db);
    final budgets = DriftBudgetRepository(db);

    final bankBefore = await accounts.getBalance(ids['bank']!);
    final cashBefore = await accounts.getBalance(ids['cash']!);
    final totalsBefore = await txs.getPeriodTotals(
      start: DateTime(2026, 10, 1),
      endExclusive: DateTime(2026, 11, 1),
    );
    final usageBefore = await budgets.getUsage(ids['budget']!);

    final backup = await exportBackup(db, prefs);
    final summary = validateBackup(backup);
    expect(summary.accountCount, 2);
    expect(summary.transactionCount, 4); // income + expense + 2 legs
    expect(summary.budgetCount, 1);
    expect(summary.defaultCurrency, 'NGN');

    await clearAllData(db);
    expect(await accounts.getBalance(ids['bank']!).catchError((_) => -1), -1);

    await restoreBackup(db, prefs, backup);

    expect(await accounts.getBalance(ids['bank']!), bankBefore);
    expect(await accounts.getBalance(ids['cash']!), cashBefore);
    final totalsAfter = await txs.getPeriodTotals(
      start: DateTime(2026, 10, 1),
      endExclusive: DateTime(2026, 11, 1),
    );
    expect(totalsAfter.incomeByCurrency, totalsBefore.incomeByCurrency);
    expect(totalsAfter.expenseByCurrency, totalsBefore.expenseByCurrency);
    expect(totalsAfter.netByCurrency, totalsBefore.netByCurrency);
    final usageAfter = await budgets.getUsage(ids['budget']!);
    expect(usageAfter.spentMinor, usageBefore.spentMinor);
    expect(usageAfter.remainingMinor, usageBefore.remainingMinor);
    expect(await prefs.defaultCurrencyCode(), 'NGN');
  });

  test('malformed text is rejected, saldo untouched', () async {
    await seedRichSaldo(db, prefs);
    final before = await snapshot(db);
    expect(() => decodeBackup('not json{{'), throwsA(isA<ValidationFailure>()));
    expect(() => decodeBackup('[1,2]'), throwsA(isA<ValidationFailure>()));
    expect(await snapshot(db), before);
  });

  test('unsupported version is rejected, saldo untouched', () async {
    await seedRichSaldo(db, prefs);
    final before = await snapshot(db);
    final backup = await exportBackup(db, prefs);
    backup['backupVersion'] = 99;
    expect(
      () => restoreBackup(db, prefs, backup),
      throwsA(isA<UnsupportedVersionFailure>()),
    );
    expect(await snapshot(db), before);

    final missing = await exportBackup(db, prefs)
      ..remove('transactions');
    expect(
      () => restoreBackup(db, prefs, missing),
      throwsA(isA<ValidationFailure>()),
    );
    expect(await snapshot(db), before);
  });

  test('dangling foreign key is rejected, nothing written', () async {
    await seedRichSaldo(db, prefs);
    final before = await snapshot(db);
    final backup = await exportBackup(db, prefs);
    (backup['accounts'] as List).removeAt(0); // orphan its transactions
    expect(
      () => restoreBackup(db, prefs, backup),
      throwsA(isA<ValidationFailure>()),
    );
    expect(await snapshot(db), before);
  });

  test('broken transfer group is rejected atomically', () async {
    await seedRichSaldo(db, prefs);
    final before = await snapshot(db);
    final backup = await exportBackup(db, prefs);
    final txns = backup['transactions'] as List;
    // Drop one leg of the transfer pair.
    txns.removeWhere(
      (t) => (t as Map)['type'] == 'transfer' && (t)['transferSide'] == 'in',
    );
    expect(
      () => restoreBackup(db, prefs, backup),
      throwsA(isA<ValidationFailure>()),
    );
    expect(await snapshot(db), before);
  });

  test('duplicate ids and bad amounts are rejected atomically', () async {
    await seedRichSaldo(db, prefs);
    final before = await snapshot(db);

    final dup = await exportBackup(db, prefs);
    (dup['accounts'] as List).add((dup['accounts'] as List).first);
    expect(
      () => restoreBackup(db, prefs, dup),
      throwsA(isA<ValidationFailure>()),
    );
    expect(await snapshot(db), before);

    final neg = await exportBackup(db, prefs);
    ((neg['transactions'] as List).first as Map)['amountMinor'] = -5;
    expect(
      () => restoreBackup(db, prefs, neg),
      throwsA(isA<ValidationFailure>()),
    );
    expect(await snapshot(db), before);
  });

  test('preferences round-trip through backup', () async {
    await seedRichSaldo(db, prefs);
    await prefs.setDefaultCurrencyCode('USD');
    final backup = await exportBackup(db, prefs);
    await prefs.setDefaultCurrencyCode('EUR');
    await restoreBackup(db, prefs, backup);
    expect(await prefs.defaultCurrencyCode(), 'USD');
  });

  test('backup filenames are timestamped', () {
    expect(
      backupFileName(DateTime(2026, 10, 10, 4, 30, 5)),
      'saldo-backup-20261010-043005.json',
    );
  });
}
