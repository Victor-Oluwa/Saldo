import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:saldo/core/database/app_database.dart';
import 'package:saldo/core/errors/failures.dart';
import 'package:saldo/core/finance/saldo_math.dart';
import 'package:saldo/features/accounts/domain/account.dart';
import 'package:saldo/features/categories/domain/category.dart';
import '../domain/budget.dart';
import '../domain/budget_repository.dart';

final _uuid = Uuid();

Budget _toDomain(BudgetRow r) {
  return Budget(
    id: r.id,
    categoryId: r.categoryId,
    periodStart: r.periodStart,
    limitMinor: r.limitMinor,
    currencyCode: r.currencyCode,
    warningThresholdPercent: r.warningThresholdPercent,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
    isArchived: r.isArchived,
  );
}

class DriftBudgetRepository implements BudgetRepository {
  DriftBudgetRepository(this._db);
  final AppDatabase _db;

  @override
  Future<Budget> create({
    required String categoryId,
    required DateTime periodStart,
    required int limitMinor,
    required String currencyCode,
    int? warningThresholdPercent,
  }) async {
    Budget.validateLimit(limitMinor);
    Budget.validateThreshold(warningThresholdPercent);
    final code = Account.normalizeCurrency(currencyCode);

    final catRow = await (_db.select(
      _db.categories,
    )..where((t) => t.id.equals(categoryId))).getSingleOrNull();
    if (catRow == null) throw NotFoundFailure('Category $categoryId not found');
    if (categoryTypeFromString(catRow.type) != CategoryType.expense) {
      throw const ValidationFailure('Budgets require an expense category');
    }

    final normalized = Budget.normalizeMonthStart(periodStart);
    final dup =
        await (_db.select(_db.budgets)
              ..where(
                (t) =>
                    t.categoryId.equals(categoryId) &
                    t.periodStart.equals(normalized) &
                    t.isArchived.equals(false),
              )
              ..limit(1))
            .get();
    if (dup.isNotEmpty) {
      throw const ValidationFailure(
        'Duplicate budget: one active budget per category per month',
      );
    }

    final now = DateTime.now();
    final id = _uuid.v4();
    await _db
        .into(_db.budgets)
        .insert(
          BudgetsCompanion.insert(
            id: id,
            categoryId: categoryId,
            periodStart: normalized,
            limitMinor: limitMinor,
            currencyCode: code,
            warningThresholdPercent: Value(warningThresholdPercent),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (await getById(id))!;
  }

  @override
  Future<Budget> update({
    required String id,
    int? limitMinor,
    int? warningThresholdPercent,
  }) async {
    final existing = await getById(id);
    if (existing == null) throw NotFoundFailure('Budget $id not found');
    if (limitMinor != null) Budget.validateLimit(limitMinor);
    Budget.validateThreshold(warningThresholdPercent);
    await (_db.update(_db.budgets)..where((t) => t.id.equals(id))).write(
      BudgetsCompanion(
        limitMinor: limitMinor == null
            ? const Value.absent()
            : Value(limitMinor),
        warningThresholdPercent:
            warningThresholdPercent == null && limitMinor == null
            ? const Value.absent()
            : warningThresholdPercent == null
            ? const Value.absent()
            : Value(warningThresholdPercent),
        updatedAt: Value(DateTime.now()),
      ),
    );
    // Allow clearing threshold? MVP: null means leave unchanged. Document.
    return (await getById(id))!;
  }

  @override
  Future<void> delete(String id) async {
    final deleted = await (_db.delete(
      _db.budgets,
    )..where((t) => t.id.equals(id))).go();
    if (deleted == 0) throw NotFoundFailure('Budget $id not found');
  }

  @override
  Future<Budget?> getById(String id) async {
    final row = await (_db.select(
      _db.budgets,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<Budget>> getForMonth(
    DateTime monthStart, {
    bool includeArchived = false,
  }) async {
    final normalized = Budget.normalizeMonthStart(monthStart);
    final q = _db.select(_db.budgets)
      ..where((t) => t.periodStart.equals(normalized));
    if (!includeArchived) q.where((t) => t.isArchived.equals(false));
    return (await q.get()).map(_toDomain).toList();
  }

  @override
  Stream<List<Budget>> watchForMonth(DateTime monthStart) {
    final normalized = Budget.normalizeMonthStart(monthStart);
    final q = _db.select(_db.budgets)
      ..where((t) => t.periodStart.equals(normalized));
    return q.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<BudgetUsage> getUsage(String budgetId) async {
    final b = await getById(budgetId);
    if (b == null) throw NotFoundFailure('Budget $budgetId not found');
    final start = b.periodStart;
    final end = start.month == 12
        ? DateTime(start.year + 1, 1, 1)
        : DateTime(start.year, start.month + 1, 1);

    final rows = await _db
        .customSelect(
          'SELECT COALESCE(SUM(amount_minor),0) AS s FROM "transactions" '
          'WHERE type = ? AND category_id = ? AND currency_code = ? '
          'AND transaction_date >= ? AND transaction_date < ?',
          variables: [
            Variable.withString('expense'),
            Variable.withString(b.categoryId),
            Variable.withString(b.currencyCode),
            Variable.withDateTime(start),
            Variable.withDateTime(end),
          ],
          readsFrom: {_db.transactions},
        )
        .getSingle();
    final spent = (rows.data['s'] as num).toInt();
    final remaining = budgetRemaining(
      limitMinor: b.limitMinor,
      spentMinor: spent,
    );
    final percent = budgetPercentUsed(
      limitMinor: b.limitMinor,
      spentMinor: spent,
    );
    final threshold = b.warningThresholdPercent;
    final warningReached = threshold == null
        ? percent >= 0.8
        : percent * 100 >= threshold;
    return BudgetUsage(
      spentMinor: spent,
      remainingMinor: remaining,
      percentUsed: percent,
      isOverspent: remaining < 0,
      isWarningReached: warningReached,
    );
  }
}
