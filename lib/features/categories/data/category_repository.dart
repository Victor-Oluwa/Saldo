import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:saldo/core/database/app_database.dart';
import 'package:saldo/core/errors/failures.dart';
import '../domain/category.dart';
import '../domain/category_repository.dart';

final _uuid = Uuid();

const _defaultIncome = ['Salary', 'Freelance', 'Business', 'Other Income'];
const _defaultExpense = [
  'Groceries',
  'Transport',
  'Rent',
  'Utilities',
  'Dining',
  'Health',
  'Entertainment',
  'Shopping',
  'Other',
];

Category _toDomain(CategoryRow r) {
  return Category(
    id: r.id,
    name: r.name,
    type: categoryTypeFromString(r.type),
    iconKey: r.iconKey,
    colorKey: r.colorKey,
    isSystem: r.isSystem,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
    isArchived: r.isArchived,
  );
}

class DriftCategoryRepository implements CategoryRepository {
  DriftCategoryRepository(this._db);
  final AppDatabase _db;

  @override
  Future<void> seedSystemDefaults() async {
    final existing = await _db.select(_db.categories).get();
    if (existing.isNotEmpty) {
      // Ensure any missing defaults (idempotent on name+type).
      final keys = existing.map((e) => '${e.type}:${e.name}').toSet();
      final now = DateTime.now();
      for (final entry in [
        ..._defaultIncome.map((n) => ('income', n)),
        ..._defaultExpense.map((n) => ('expense', n)),
      ]) {
        if (keys.contains('${entry.$1}:${entry.$2}')) continue;
        await _db
            .into(_db.categories)
            .insert(
              CategoriesCompanion.insert(
                id: _uuid.v4(),
                name: entry.$2,
                type: entry.$1,
                isSystem: const Value(true),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
      return;
    }
    final now = DateTime.now();
    for (final n in _defaultIncome) {
      await _db
          .into(_db.categories)
          .insert(
            CategoriesCompanion.insert(
              id: _uuid.v4(),
              name: n,
              type: 'income',
              isSystem: const Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    for (final n in _defaultExpense) {
      await _db
          .into(_db.categories)
          .insert(
            CategoriesCompanion.insert(
              id: _uuid.v4(),
              name: n,
              type: 'expense',
              isSystem: const Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  }

  @override
  Future<Category> create({
    required String name,
    required CategoryType type,
    String? iconKey,
    String? colorKey,
  }) async {
    Category.validateName(name);
    final now = DateTime.now();
    final id = _uuid.v4();
    try {
      await _db
          .into(_db.categories)
          .insert(
            CategoriesCompanion.insert(
              id: id,
              name: name.trim(),
              type: categoryTypeToString(type),
              iconKey: Value(iconKey),
              colorKey: Value(colorKey),
              createdAt: now,
              updatedAt: now,
            ),
          );
    } catch (e) {
      throw ValidationFailure(
        'Category already exists: ${name.trim()} (${categoryTypeToString(type)})',
      );
    }
    final created = await getById(id);
    if (created == null) {
      throw const DatabaseFailure('Category not found after create');
    }
    return created;
  }

  @override
  Future<Category> rename({required String id, required String name}) async {
    Category.validateName(name);
    final existing = await getById(id);
    if (existing == null) throw NotFoundFailure('Category $id not found');
    try {
      await (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
        CategoriesCompanion(
          name: Value(name.trim()),
          updatedAt: Value(DateTime.now()),
        ),
      );
    } catch (_) {
      throw ValidationFailure('Category already exists: ${name.trim()}');
    }
    return (await getById(id))!;
  }

  @override
  Future<Category> recolor({
    required String id,
    String? iconKey,
    String? colorKey,
  }) async {
    final existing = await getById(id);
    if (existing == null) throw NotFoundFailure('Category $id not found');
    await (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(
        iconKey: Value(iconKey),
        colorKey: Value(colorKey),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return (await getById(id))!;
  }

  @override
  Future<Category> setArchived({
    required String id,
    required bool archived,
  }) async {
    final existing = await getById(id);
    if (existing == null) throw NotFoundFailure('Category $id not found');
    await (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(
        isArchived: Value(archived),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return (await getById(id))!;
  }

  @override
  Future<void> delete(String id) async {
    final txRefs =
        await (_db.select(_db.transactions)
              ..where((t) => t.categoryId.equals(id))
              ..limit(1))
            .get();
    if (txRefs.isNotEmpty) {
      throw const ValidationFailure(
        'Category has transactions — archive it instead of deleting',
      );
    }
    final bRefs =
        await (_db.select(_db.budgets)
              ..where((t) => t.categoryId.equals(id))
              ..limit(1))
            .get();
    if (bRefs.isNotEmpty) {
      throw const ValidationFailure(
        'Category has budgets — archive it instead of deleting',
      );
    }
    final deleted = await (_db.delete(
      _db.categories,
    )..where((t) => t.id.equals(id))).go();
    if (deleted == 0) throw NotFoundFailure('Category $id not found');
  }

  @override
  Future<Category?> getById(String id) async {
    final row = await (_db.select(
      _db.categories,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<Category>> getAll({bool includeArchived = false}) async {
    final q = _db.select(_db.categories);
    if (!includeArchived) q.where((t) => t.isArchived.equals(false));
    q.orderBy([(t) => OrderingTerm(expression: t.name)]);
    return (await q.get()).map(_toDomain).toList();
  }

  @override
  Future<List<Category>> getByType(
    CategoryType type, {
    bool includeArchived = false,
  }) async {
    final q = _db.select(_db.categories)
      ..where((t) => t.type.equals(categoryTypeToString(type)));
    if (!includeArchived) q.where((t) => t.isArchived.equals(false));
    q.orderBy([(t) => OrderingTerm(expression: t.name)]);
    return (await q.get()).map(_toDomain).toList();
  }

  @override
  Stream<List<Category>> watchAll({bool includeArchived = false}) {
    final q = _db.select(_db.categories);
    if (!includeArchived) q.where((t) => t.isArchived.equals(false));
    q.orderBy([(t) => OrderingTerm(expression: t.name)]);
    return q.watch().map((rows) => rows.map(_toDomain).toList());
  }
}
