import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saldo/core/database/app_database.dart';
import 'package:saldo/core/errors/failures.dart';
import 'package:saldo/features/accounts/data/account_repository.dart';
import 'package:saldo/features/categories/data/category_repository.dart';
import 'package:saldo/features/categories/domain/category.dart';
import 'package:saldo/features/transactions/data/transaction_repository.dart';

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

  test('expense cannot use income-only category', () async {
    final acc = await accounts.createAccount(
      name: 'Cash',
      currencyCode: 'NGN',
      openingBalanceMinor: 100000,
    );
    final incomeCats = await categories.getByType(CategoryType.income);
    expect(incomeCats, isNotEmpty);
    await expectLater(
      txs.createExpense(
        accountId: acc.id,
        categoryId: incomeCats.first.id,
        amountMinor: 1000,
        transactionDate: DateTime(2026, 10, 9),
      ),
      throwsA(isA<ValidationFailure>()),
    );
    await expectLater(
      txs.createIncome(
        accountId: acc.id,
        categoryId: (await categories.getByType(CategoryType.expense)).first.id,
        amountMinor: 1000,
        transactionDate: DateTime(2026, 10, 9),
      ),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('rename preserves historical relationship', () async {
    final acc = await accounts.createAccount(
      name: 'Cash',
      currencyCode: 'NGN',
      openingBalanceMinor: 100000,
    );
    final food = (await categories.getByType(
      CategoryType.expense,
    )).firstWhere((c) => c.name == 'Groceries');
    final tx = await txs.createExpense(
      accountId: acc.id,
      categoryId: food.id,
      amountMinor: 450000,
      transactionDate: DateTime(2026, 10, 9),
    );
    final renamed = await categories.rename(
      id: food.id,
      name: 'Groceries & Market',
    );
    expect(renamed.name, 'Groceries & Market');
    final reloaded = await txs.getById(tx.id);
    expect(reloaded!.categoryId, food.id);
    expect((await categories.getById(food.id))!.name, 'Groceries & Market');
  });

  test(
    'archived categories blocked for new, allowed when editing history',
    () async {
      final acc = await accounts.createAccount(
        name: 'Cash',
        currencyCode: 'NGN',
        openingBalanceMinor: 100000,
      );
      final food = (await categories.getByType(
        CategoryType.expense,
      )).firstWhere((c) => c.name == 'Groceries');
      // Historical record first.
      final tx = await txs.createExpense(
        accountId: acc.id,
        categoryId: food.id,
        amountMinor: 1000,
        transactionDate: DateTime(2026, 10, 9),
      );
      await categories.setArchived(id: food.id, archived: true);
      // New records blocked.
      await expectLater(
        txs.createExpense(
          accountId: acc.id,
          categoryId: food.id,
          amountMinor: 1000,
          transactionDate: DateTime(2026, 10, 10),
        ),
        throwsA(isA<ValidationFailure>()),
      );
      // Editing historical record to keep/adjust with archived category allowed.
      final edited = await txs.updateExpense(id: tx.id, amountMinor: 2000);
      expect(edited.amountMinor, 2000);
      expect(edited.categoryId, food.id);
    },
  );

  test('delete blocked when referenced; unique names enforced', () async {
    final custom = await categories.create(
      name: 'CustomX',
      type: CategoryType.expense,
    );
    // Duplicate (name+type) rejected.
    await expectLater(
      categories.create(name: 'CustomX', type: CategoryType.expense),
      throwsA(isA<ValidationFailure>()),
    );
    // Same name, different type allowed.
    final sameNameIncome = await categories.create(
      name: 'CustomX',
      type: CategoryType.income,
    );
    expect(sameNameIncome.name, 'CustomX');

    final acc = await accounts.createAccount(
      name: 'Cash',
      currencyCode: 'NGN',
      openingBalanceMinor: 100000,
    );
    await txs.createExpense(
      accountId: acc.id,
      categoryId: custom.id,
      amountMinor: 1000,
      transactionDate: DateTime(2026, 10, 9),
    );
    await expectLater(
      categories.delete(custom.id),
      throwsA(isA<ValidationFailure>()),
    );

    // Unreferenced deletable.
    final spare = await categories.create(
      name: 'Spare',
      type: CategoryType.expense,
    );
    await categories.delete(spare.id);
    expect(await categories.getById(spare.id), isNull);
  });

  test('seed defaults idempotent', () async {
    final before = await categories.getAll();
    await categories.seedSystemDefaults();
    final after = await categories.getAll();
    expect(after.length, before.length);
    expect(after.where((c) => c.isSystem), isNotEmpty);
  });
}
