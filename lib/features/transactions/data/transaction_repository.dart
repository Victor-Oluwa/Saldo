import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:saldo/core/database/app_database.dart';
import 'package:saldo/core/errors/failures.dart';
import 'package:saldo/features/categories/domain/category.dart';
import '../domain/transaction.dart';
import '../domain/transaction_repository.dart';

final _uuid = Uuid();

SaldoTransaction _toDomain(TransactionRow r) {
  return SaldoTransaction(
    id: r.id,
    type: transactionTypeFromString(r.type),
    accountId: r.accountId,
    categoryId: r.categoryId,
    amountMinor: r.amountMinor,
    currencyCode: r.currencyCode,
    transactionDate: r.transactionDate,
    description: r.description,
    notes: r.notes,
    transferGroupId: r.transferGroupId,
    transferSide: r.transferSide == null
        ? null
        : transferSideFromString(r.transferSide!),
    counterpartAccountId: r.counterpartAccountId,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  );
}

class DriftTransactionRepository implements TransactionRepository {
  DriftTransactionRepository(this._db);
  final AppDatabase _db;

  Future<AccountRow> _accountOrThrow(String id) async {
    final row = await (_db.select(
      _db.accounts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) throw NotFoundFailure('Account $id not found');
    return row;
  }

  Future<CategoryRow> _categoryOrThrow(String id) async {
    final row = await (_db.select(
      _db.categories,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) throw NotFoundFailure('Category $id not found');
    return row;
  }

  void _checkCategoryCompatible(CategoryRow cat, TransactionType expected) {
    final catType = categoryTypeFromString(cat.type);
    if (expected == TransactionType.income && catType != CategoryType.income) {
      throw const ValidationFailure(
        'Expense/income mismatch: income requires an income category',
      );
    }
    if (expected == TransactionType.expense &&
        catType != CategoryType.expense) {
      throw const ValidationFailure(
        'Expense/income mismatch: expense requires an expense category',
      );
    }
  }

  @override
  Future<SaldoTransaction> createIncome({
    required String accountId,
    required String categoryId,
    required int amountMinor,
    required DateTime transactionDate,
    String? description,
    String? notes,
  }) async {
    SaldoTransaction.validateAmount(amountMinor);
    final acc = await _accountOrThrow(accountId);
    if (acc.isArchived) {
      throw const ValidationFailure(
        'Account is archived — unarchive it to add transactions',
      );
    }
    final cat = await _categoryOrThrow(categoryId);
    _checkCategoryCompatible(cat, TransactionType.income);
    if (cat.isArchived) {
      throw const ValidationFailure(
        'Category is archived — choose an active category for new records',
      );
    }
    final now = DateTime.now();
    final id = _uuid.v4();
    await _db
        .into(_db.transactions)
        .insert(
          TransactionsCompanion.insert(
            id: id,
            type: 'income',
            accountId: accountId,
            categoryId: Value(categoryId),
            amountMinor: amountMinor,
            currencyCode: acc.currencyCode,
            transactionDate: transactionDate,
            description: Value(
              description?.trim().isEmpty == true ? null : description?.trim(),
            ),
            notes: Value(notes?.trim().isEmpty == true ? null : notes),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (await getById(id))!;
  }

  @override
  Future<SaldoTransaction> createExpense({
    required String accountId,
    required String categoryId,
    required int amountMinor,
    required DateTime transactionDate,
    String? description,
    String? notes,
  }) async {
    SaldoTransaction.validateAmount(amountMinor);
    final acc = await _accountOrThrow(accountId);
    if (acc.isArchived) {
      throw const ValidationFailure(
        'Account is archived — unarchive it to add transactions',
      );
    }
    final cat = await _categoryOrThrow(categoryId);
    _checkCategoryCompatible(cat, TransactionType.expense);
    if (cat.isArchived) {
      throw const ValidationFailure(
        'Category is archived — choose an active category for new records',
      );
    }
    final now = DateTime.now();
    final id = _uuid.v4();
    await _db
        .into(_db.transactions)
        .insert(
          TransactionsCompanion.insert(
            id: id,
            type: 'expense',
            accountId: accountId,
            categoryId: Value(categoryId),
            amountMinor: amountMinor,
            currencyCode: acc.currencyCode,
            transactionDate: transactionDate,
            description: Value(
              description?.trim().isEmpty == true ? null : description?.trim(),
            ),
            notes: Value(notes?.trim().isEmpty == true ? null : notes),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (await getById(id))!;
  }

  @override
  Future<SaldoTransaction> createTransfer({
    required String sourceAccountId,
    required String destAccountId,
    required int amountMinor,
    required DateTime transactionDate,
    String? description,
    String? notes,
  }) async {
    SaldoTransaction.validateAmount(amountMinor);
    if (sourceAccountId == destAccountId) {
      throw const ValidationFailure('Transfer needs two different accounts');
    }
    final src = await _accountOrThrow(sourceAccountId);
    final dst = await _accountOrThrow(destAccountId);
    if (src.isArchived || dst.isArchived) {
      throw const ValidationFailure(
        'Archived accounts cannot start new transfers',
      );
    }
    if (src.currencyCode != dst.currencyCode) {
      throw const ValidationFailure('Transfers are same-currency only in MVP');
    }
    final groupId = _uuid.v4();
    final now = DateTime.now();
    final desc = description?.trim().isEmpty == true
        ? null
        : description?.trim();
    final noteVal = notes?.trim().isEmpty == true ? null : notes;
    await _db.transaction(() async {
      await _db
          .into(_db.transactions)
          .insert(
            TransactionsCompanion.insert(
              id: _uuid.v4(),
              type: 'transfer',
              accountId: sourceAccountId,
              amountMinor: amountMinor,
              currencyCode: src.currencyCode,
              transactionDate: transactionDate,
              description: Value(desc),
              notes: Value(noteVal),
              transferGroupId: Value(groupId),
              transferSide: const Value('out'),
              counterpartAccountId: Value(destAccountId),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _db
          .into(_db.transactions)
          .insert(
            TransactionsCompanion.insert(
              id: _uuid.v4(),
              type: 'transfer',
              accountId: destAccountId,
              amountMinor: amountMinor,
              currencyCode: dst.currencyCode,
              transactionDate: transactionDate,
              description: Value(desc),
              notes: Value(noteVal),
              transferGroupId: Value(groupId),
              transferSide: const Value('in'),
              counterpartAccountId: Value(sourceAccountId),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
    final legs = await getTransferLegs(groupId);
    return legs.firstWhere((e) => e.transferSide == TransferSide.out);
  }

  @override
  Future<SaldoTransaction> updateIncome({
    required String id,
    String? accountId,
    String? categoryId,
    int? amountMinor,
    DateTime? transactionDate,
    String? description,
    String? notes,
  }) async {
    return _updateSimple(
      id: id,
      expected: TransactionType.income,
      accountId: accountId,
      categoryId: categoryId,
      amountMinor: amountMinor,
      transactionDate: transactionDate,
      description: description,
      notes: notes,
    );
  }

  @override
  Future<SaldoTransaction> updateExpense({
    required String id,
    String? accountId,
    String? categoryId,
    int? amountMinor,
    DateTime? transactionDate,
    String? description,
    String? notes,
  }) async {
    return _updateSimple(
      id: id,
      expected: TransactionType.expense,
      accountId: accountId,
      categoryId: categoryId,
      amountMinor: amountMinor,
      transactionDate: transactionDate,
      description: description,
      notes: notes,
    );
  }

  Future<SaldoTransaction> _updateSimple({
    required String id,
    required TransactionType expected,
    String? accountId,
    String? categoryId,
    int? amountMinor,
    DateTime? transactionDate,
    String? description,
    String? notes,
  }) async {
    final existing = await getById(id);
    if (existing == null) throw NotFoundFailure('Transaction $id not found');
    if (existing.type != expected) {
      throw const ValidationFailure('Wrong transaction type for this update');
    }
    if (amountMinor != null) SaldoTransaction.validateAmount(amountMinor);

    var currency = existing.currencyCode;
    if (accountId != null && accountId != existing.accountId) {
      final acc = await _accountOrThrow(accountId);
      if (acc.isArchived) {
        throw const ValidationFailure('Target account is archived');
      }
      currency = acc.currencyCode;
    }
    if (categoryId != null) {
      final cat = await _categoryOrThrow(categoryId);
      _checkCategoryCompatible(cat, expected);
      // Archived categories allowed when editing historical records.
    }
    await (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        accountId: accountId == null ? const Value.absent() : Value(accountId),
        categoryId: categoryId == null
            ? const Value.absent()
            : Value(categoryId),
        amountMinor: amountMinor == null
            ? const Value.absent()
            : Value(amountMinor),
        currencyCode: accountId == null
            ? const Value.absent()
            : Value(currency),
        transactionDate: transactionDate == null
            ? const Value.absent()
            : Value(transactionDate),
        description: description == null
            ? const Value.absent()
            : Value(description.trim().isEmpty ? null : description.trim()),
        notes: notes == null
            ? const Value.absent()
            : Value(notes.trim().isEmpty ? null : notes),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return (await getById(id))!;
  }

  @override
  Future<void> updateTransfer({
    required String transferGroupId,
    int? amountMinor,
    DateTime? transactionDate,
    String? description,
    String? notes,
  }) async {
    if (amountMinor != null) SaldoTransaction.validateAmount(amountMinor);
    final legs = await getTransferLegs(transferGroupId);
    if (legs.length != 2) {
      throw const ValidationFailure(
        'Transfer group is corrupted (expected 2 legs)',
      );
    }
    await _db.transaction(() async {
      for (final leg in legs) {
        await (_db.update(
          _db.transactions,
        )..where((t) => t.id.equals(leg.id))).write(
          TransactionsCompanion(
            amountMinor: amountMinor == null
                ? const Value.absent()
                : Value(amountMinor),
            transactionDate: transactionDate == null
                ? const Value.absent()
                : Value(transactionDate),
            description: description == null
                ? const Value.absent()
                : Value(description.trim().isEmpty ? null : description.trim()),
            notes: notes == null
                ? const Value.absent()
                : Value(notes.trim().isEmpty ? null : notes),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
  }

  @override
  Future<void> deleteTransaction(String id) async {
    final existing = await getById(id);
    if (existing == null) throw NotFoundFailure('Transaction $id not found');
    if (existing.type == TransactionType.transfer) {
      await deleteTransfer(existing.transferGroupId!);
      return;
    }
    await (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> deleteTransfer(String transferGroupId) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.transactions,
      )..where((t) => t.transferGroupId.equals(transferGroupId))).go();
    });
  }

  @override
  Future<SaldoTransaction?> getById(String id) async {
    final row = await (_db.select(
      _db.transactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<SaldoTransaction>> getTransferLegs(
    String transferGroupId,
  ) async {
    final rows = await (_db.select(
      _db.transactions,
    )..where((t) => t.transferGroupId.equals(transferGroupId))).get();
    if (rows.isEmpty) {
      throw NotFoundFailure('Transfer $transferGroupId not found');
    }
    return rows.map(_toDomain).toList();
  }

  SimpleSelectStatement<$TransactionsTable, TransactionRow> _filteredQuery(
    TransactionFilter filter,
  ) {
    final q = _db.select(_db.transactions);
    if (filter.type != null) {
      q.where((t) => t.type.equals(transactionTypeToString(filter.type!)));
    }
    if (filter.accountId != null) {
      q.where((t) => t.accountId.equals(filter.accountId!));
    }
    if (filter.categoryId != null) {
      q.where((t) => t.categoryId.equals(filter.categoryId!));
    }
    if (filter.start != null) {
      q.where((t) => t.transactionDate.isBiggerOrEqualValue(filter.start!));
    }
    if (filter.endExclusive != null) {
      q.where(
        (t) => t.transactionDate.isSmallerThanValue(filter.endExclusive!),
      );
    }
    if (filter.search != null && filter.search!.trim().isNotEmpty) {
      final like = '%${filter.search!.trim()}%';
      q.where((t) => t.description.like(like) | t.notes.like(like));
    }
    q.orderBy([
      (t) =>
          OrderingTerm(expression: t.transactionDate, mode: OrderingMode.desc),
      (t) => OrderingTerm(expression: t.id, mode: OrderingMode.asc),
    ]);
    return q;
  }

  @override
  Future<List<SaldoTransaction>> query({
    TransactionFilter filter = const TransactionFilter(),
    int? limit,
    int? offset,
  }) async {
    final q = _filteredQuery(filter);
    if (limit != null) q.limit(limit, offset: offset);
    return (await q.get()).map(_toDomain).toList();
  }

  @override
  Stream<List<SaldoTransaction>> watch({
    TransactionFilter filter = const TransactionFilter(),
  }) {
    return _filteredQuery(
      filter,
    ).watch().map((rows) => rows.map(_toDomain).toList());
  }

  Future<Map<String, int>> _sumsByCurrency(
    String type,
    DateTime start,
    DateTime end,
  ) async {
    final rows = await _db
        .customSelect(
          'SELECT currency_code AS c, COALESCE(SUM(amount_minor),0) AS s FROM "transactions" '
          'WHERE type = ? AND transaction_date >= ? AND transaction_date < ? GROUP BY currency_code',
          variables: [
            Variable.withString(type),
            Variable.withDateTime(start),
            Variable.withDateTime(end),
          ],
          readsFrom: {_db.transactions},
        )
        .get();
    final out = <String, int>{};
    for (final r in rows) {
      out[(r.data['c'] as String)] = (r.data['s'] as num).toInt();
    }
    return out;
  }

  @override
  Future<PeriodTotals> getPeriodTotals({
    required DateTime start,
    required DateTime endExclusive,
  }) async {
    final income = await _sumsByCurrency('income', start, endExclusive);
    final expense = await _sumsByCurrency('expense', start, endExclusive);
    final currencies = {...income.keys, ...expense.keys};
    final net = <String, int>{};
    for (final c in currencies) {
      net[c] = (income[c] ?? 0) - (expense[c] ?? 0);
    }
    return PeriodTotals(
      incomeByCurrency: income,
      expenseByCurrency: expense,
      netByCurrency: net,
    );
  }
}
