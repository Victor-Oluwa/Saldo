import 'category.dart';

abstract class CategoryRepository {
  /// Seeds sensible defaults on first launch — idempotent.
  Future<void> seedSystemDefaults();

  Future<Category> create({
    required String name,
    required CategoryType type,
    String? iconKey,
    String? colorKey,
  });

  Future<Category> rename({required String id, required String name});
  Future<Category> recolor({
    required String id,
    String? iconKey,
    String? colorKey,
  });
  Future<Category> setArchived({required String id, required bool archived});

  /// Throws if transactions or budgets reference it — archive instead.
  Future<void> delete(String id);

  Future<Category?> getById(String id);
  Future<List<Category>> getAll({bool includeArchived = false});
  Future<List<Category>> getByType(
    CategoryType type, {
    bool includeArchived = false,
  });
  Stream<List<Category>> watchAll({bool includeArchived = false});
}
