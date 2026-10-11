import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saldo/core/database/providers.dart';
import 'package:saldo/features/accounts/presentation/accounts_providers.dart';
import 'package:saldo/features/categories/domain/category.dart';

final categoriesAllProvider = StreamProvider<List<Category>>((ref) {
  ref.watch(seedProvider);
  return ref.watch(categoryRepositoryProvider).watchAll(includeArchived: false);
});

final categoriesAllInclArchivedProvider = StreamProvider<List<Category>>((ref) {
  ref.watch(seedProvider);
  return ref.watch(categoryRepositoryProvider).watchAll(includeArchived: true);
});

/// Active categories of [type] — derived from [categoriesAllProvider].
final categoriesByTypeProvider = Provider.autoDispose
    .family<List<Category>, CategoryType>((ref, type) {
      final all = ref.watch(categoriesAllProvider).value ?? const <Category>[];
      return all.where((c) => c.type == type).toList();
    });

/// All categories (incl. archived) of [type] — for editing historical records.
final categoriesByTypeAllProvider = Provider.autoDispose
    .family<List<Category>, CategoryType>((ref, type) {
      final all =
          ref.watch(categoriesAllInclArchivedProvider).value ??
          const <Category>[];
      return all.where((c) => c.type == type).toList();
    });

/// id → Category map for rows (includes archived for history).
final categoryMapProvider = FutureProvider<Map<String, Category>>((ref) async {
  final all = await ref.watch(categoriesAllInclArchivedProvider.future);
  return {for (final c in all) c.id: c};
});
