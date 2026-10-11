import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saldo/core/database/providers.dart';
import 'package:saldo/features/accounts/domain/account.dart';

/// Ensures system categories exist before any picker/list builds.
final seedProvider = FutureProvider<void>((ref) async {
  await ref.watch(categoryRepositoryProvider).seedSystemDefaults();
});

final accountsListProvider = StreamProvider<List<Account>>((ref) {
  ref.watch(seedProvider);
  return ref.watch(accountRepositoryProvider).watchAll(includeArchived: false);
});

final accountsListAllProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(accountRepositoryProvider).watchAll(includeArchived: true);
});

final accountByIdProvider = StreamProvider.autoDispose.family<Account?, String>(
  (ref, id) {
    final db = ref.watch(appDatabaseProvider);
    final q = db.select(db.accounts)..where((t) => t.id.equals(id));
    return q.watchSingleOrNull().map(
      (row) => row == null
          ? null
          : Account(
              id: row.id,
              name: row.name,
              currencyCode: row.currencyCode,
              openingBalanceMinor: row.openingBalanceMinor,
              description: row.description,
              iconKey: row.iconKey,
              colorKey: row.colorKey,
              createdAt: row.createdAt,
              updatedAt: row.updatedAt,
              isArchived: row.isArchived,
            ),
    );
  },
);

final accountBalanceProvider = FutureProvider.autoDispose.family<int, String>((
  ref,
  id,
) async {
  // Recompute when accounts/transactions change.
  ref.watch(accountsListAllProvider);
  ref.watch(transactionsVersionProvider);
  return ref.watch(accountRepositoryProvider).getBalance(id);
});

/// Bump to refresh balances after writes (watch() streams cover lists;
/// balances are futures so they need an explicit refresh signal).
final transactionsVersionProvider = NotifierProvider<VersionNotifier, int>(
  VersionNotifier.new,
);

class VersionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final totalBalancesProvider = FutureProvider<Map<String, int>>((ref) async {
  ref.watch(accountsListAllProvider);
  ref.watch(transactionsVersionProvider);
  return ref.watch(accountRepositoryProvider).getTotalBalancesByCurrency();
});

/// id → Account map for transaction rows.
final accountMapProvider = FutureProvider<Map<String, Account>>((ref) async {
  final all = await ref.watch(accountsListAllProvider.future);
  return {for (final a in all) a.id: a};
});
