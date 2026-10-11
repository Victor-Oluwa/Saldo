import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saldo/core/database/app_database.dart';
import 'package:saldo/core/errors/failures.dart';
import 'package:saldo/features/accounts/data/account_repository.dart';
import 'package:saldo/features/categories/data/category_repository.dart';
import 'package:saldo/features/categories/domain/category.dart';
import 'package:saldo/features/transactions/data/transaction_repository.dart';

AppDatabase _memoryDb() => AppDatabase.forTesting(NativeDatabase.memory());

void main() {
  late AppDatabase db;
  late DriftAccountRepository accounts;
  late DriftCategoryRepository categories;
  late DriftTransactionRepository txs;

  setUp(() async {
    db = _memoryDb();
    accounts = DriftAccountRepository(db);
    categories = DriftCategoryRepository(db);
    txs = DriftTransactionRepository(db);
    await categories.seedSystemDefaults();
  });

  tearDown(() async {
    await db.close();
  });

  test('opening balance displays before activity (₦20,000)', () async {
    final acc = await accounts.createAccount(
      name: 'Bank',
      currencyCode: 'NGN',
      openingBalanceMinor: 2000000,
    );
    expect(await accounts.getBalance(acc.id), 2000000);
  });

  test('archiving preserves transactions + balances', () async {
    final acc = await accounts.createAccount(
      name: 'Cash',
      currencyCode: 'NGN',
      openingBalanceMinor: 2000000,
    );
    final cats = await categories.getByType(CategoryType.expense);
    final food = cats.firstWhere((c) => c.name == 'Groceries');
    await txs.createExpense(
      accountId: acc.id,
      categoryId: food.id,
      amountMinor: 450000, // ₦4,500
      transactionDate: DateTime(2026, 10, 9),
    );
    final before = await accounts.getBalance(acc.id);
    expect(before, 2000000 - 450000);

    await accounts.setArchived(id: acc.id, archived: true);
    expect(await accounts.getBalance(acc.id), before);
    final history = await txs.query();
    expect(history.length, 1);
    expect(await accounts.getAll(), isEmpty);
    expect((await accounts.getAll(includeArchived: true)).length, 1);
  });

  test('currency immutable via metadata update', () async {
    final acc = await accounts.createAccount(
      name: 'Bank',
      currencyCode: 'NGN',
      openingBalanceMinor: 0,
    );
    final updated = await accounts.updateMetadata(
      id: acc.id,
      name: 'Bank Renamed',
    );
    expect(updated.name, 'Bank Renamed');
    expect(updated.currencyCode, 'NGN');
  });

  test('delete blocked when referenced, allowed when clean', () async {
    final acc = await accounts.createAccount(
      name: 'Bank',
      currencyCode: 'NGN',
      openingBalanceMinor: 0,
    );
    final cats = await categories.getByType(CategoryType.expense);
    await txs.createExpense(
      accountId: acc.id,
      categoryId: cats.first.id,
      amountMinor: 1000,
      transactionDate: DateTime(2026, 10, 9),
    );
    await expectLater(
      accounts.deleteAccount(acc.id),
      throwsA(isA<ValidationFailure>()),
    );

    final clean = await accounts.createAccount(
      name: 'Spare',
      currencyCode: 'NGN',
      openingBalanceMinor: 0,
    );
    await accounts.deleteAccount(clean.id);
    expect(await accounts.getById(clean.id), isNull);
  });

  test('multi-currency totals never mixed', () async {
    final ngn = await accounts.createAccount(
      name: 'Naira',
      currencyCode: 'NGN',
      openingBalanceMinor: 2000000,
    );
    final usd = await accounts.createAccount(
      name: 'Dollar',
      currencyCode: 'USD',
      openingBalanceMinor: 10000, // $100.00
    );
    expect(await accounts.getBalance(ngn.id), 2000000);
    expect(await accounts.getBalance(usd.id), 10000);
    final totals = await accounts.getTotalBalancesByCurrency();
    expect(totals['NGN'], 2000000);
    expect(totals['USD'], 10000);
    expect(totals.keys, containsAll(['NGN', 'USD']));
  });
}
