import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:saldo/core/database/app_database.dart';
import 'package:saldo/core/errors/failures.dart';
import '../domain/account.dart';
import '../domain/account_repository.dart';

final _uuid = Uuid();

Account _toDomain(AccountRow r) {
  return Account(
    id: r.id,
    name: r.name,
    currencyCode: r.currencyCode,
    openingBalanceMinor: r.openingBalanceMinor,
    description: r.description,
    iconKey: r.iconKey,
    colorKey: r.colorKey,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
    isArchived: r.isArchived,
  );
}

class DriftAccountRepository implements AccountRepository {
  DriftAccountRepository(this._db);
  final AppDatabase _db;

  @override
  Future<Account> createAccount({
    required String name,
    required String currencyCode,
    required int openingBalanceMinor,
    String? description,
    String? iconKey,
    String? colorKey,
  }) async {
    Account.validateName(name);
    final code = Account.normalizeCurrency(currencyCode);
    final now = DateTime.now();
    final id = _uuid.v4();
    try {
      await _db
          .into(_db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: id,
              name: name.trim(),
              currencyCode: code,
              openingBalanceMinor: openingBalanceMinor,
              description: Value(
                description?.trim().isEmpty == true
                    ? null
                    : description?.trim(),
              ),
              iconKey: Value(iconKey),
              colorKey: Value(colorKey),
              createdAt: now,
              updatedAt: now,
            ),
          );
    } catch (e) {
      throw DatabaseFailure('Failed to create account: $e');
    }
    final created = await getById(id);
    if (created == null) {
      throw const DatabaseFailure('Account not found after create');
    }
    return created;
  }

  @override
  Future<Account> updateMetadata({
    required String id,
    String? name,
    String? description,
    String? iconKey,
    String? colorKey,
  }) async {
    final existing = await getById(id);
    if (existing == null) throw NotFoundFailure('Account $id not found');
    if (name != null) Account.validateName(name);
    final now = DateTime.now();
    final updated =
        await (_db.update(_db.accounts)..where((t) => t.id.equals(id))).write(
          AccountsCompanion(
            name: name == null ? const Value.absent() : Value(name.trim()),
            description: description == null
                ? const Value.absent()
                : Value(description.trim().isEmpty ? null : description.trim()),
            iconKey: iconKey == null ? const Value.absent() : Value(iconKey),
            colorKey: colorKey == null ? const Value.absent() : Value(colorKey),
            updatedAt: Value(now),
          ),
        );
    if (updated == 0) throw NotFoundFailure('Account $id not found');
    return (await getById(id))!;
  }

  @override
  Future<Account> setArchived({
    required String id,
    required bool archived,
  }) async {
    final existing = await getById(id);
    if (existing == null) throw NotFoundFailure('Account $id not found');
    await (_db.update(_db.accounts)..where((t) => t.id.equals(id))).write(
      AccountsCompanion(
        isArchived: Value(archived),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return (await getById(id))!;
  }

  @override
  Future<void> deleteAccount(String id) async {
    // Hard-delete only when unreferenced — otherwise archive.
    final refs =
        await (_db.select(_db.transactions)
              ..where(
                (t) =>
                    t.accountId.equals(id) | t.counterpartAccountId.equals(id),
              )
              ..limit(1))
            .get();
    if (refs.isNotEmpty) {
      throw const ValidationFailure(
        'Account has transactions — archive it instead of deleting',
      );
    }
    final deleted = await (_db.delete(
      _db.accounts,
    )..where((t) => t.id.equals(id))).go();
    if (deleted == 0) throw NotFoundFailure('Account $id not found');
  }

  @override
  Future<Account?> getById(String id) async {
    final row = await (_db.select(
      _db.accounts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<Account>> getAll({bool includeArchived = false}) async {
    final q = _db.select(_db.accounts);
    if (!includeArchived) q.where((t) => t.isArchived.equals(false));
    q.orderBy([
      (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
    ]);
    return (await q.get()).map(_toDomain).toList();
  }

  @override
  Stream<List<Account>> watchAll({bool includeArchived = false}) {
    final q = _db.select(_db.accounts);
    if (!includeArchived) q.where((t) => t.isArchived.equals(false));
    q.orderBy([
      (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
    ]);
    return q.watch().map((rows) => rows.map(_toDomain).toList());
  }

  Future<int> _sumFor(String accountId, String type, String? side) async {
    final typeEsc = type.replaceAll("'", "''");
    final sideClause = side == null
        ? 'AND transfer_side IS NULL'
        : "AND transfer_side = '$side'";
    final row = await _db
        .customSelect(
          'SELECT COALESCE(SUM(amount_minor), 0) AS s FROM "transactions" '
          'WHERE account_id = ? AND type = ? $sideClause',
          variables: [
            Variable.withString(accountId),
            Variable.withString(typeEsc),
          ],
          readsFrom: {_db.transactions},
        )
        .getSingle();
    return (row.data['s'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<int> getBalance(String accountId) async {
    final acc = await getById(accountId);
    if (acc == null) throw NotFoundFailure('Account $accountId not found');
    final income = await _sumFor(accountId, 'income', null);
    final expense = await _sumFor(accountId, 'expense', null);
    final tIn = await _sumFor(accountId, 'transfer', 'in');
    final tOut = await _sumFor(accountId, 'transfer', 'out');
    return acc.openingBalanceMinor + income + tIn - expense - tOut;
  }

  @override
  Future<Map<String, int>> getTotalBalancesByCurrency({
    bool includeArchived = true,
  }) async {
    final accounts = await getAll(includeArchived: includeArchived);
    final totals = <String, int>{};
    for (final a in accounts) {
      final bal = await getBalance(a.id);
      totals.update(a.currencyCode, (v) => v + bal, ifAbsent: () => bal);
    }
    return totals;
  }
}
