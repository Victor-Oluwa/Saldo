import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saldo/core/database/providers.dart';
import 'package:saldo/features/accounts/presentation/accounts_providers.dart';
import 'package:saldo/features/transactions/domain/transaction.dart';

/// Mutable history filter (search + type/account/category/date).
class TxFilterNotifier extends Notifier<TransactionFilter> {
  @override
  TransactionFilter build() => const TransactionFilter();

  void setSearch(String? v) => state = TransactionFilter(
    search: v?.trim().isEmpty == true ? null : v?.trim(),
    start: state.start,
    endExclusive: state.endExclusive,
    accountId: state.accountId,
    categoryId: state.categoryId,
    type: state.type,
  );

  void setType(TransactionType? t) => state = TransactionFilter(
    search: state.search,
    start: state.start,
    endExclusive: state.endExclusive,
    accountId: state.accountId,
    categoryId: state.categoryId,
    type: t,
  );

  void setAccount(String? id) => state = TransactionFilter(
    search: state.search,
    start: state.start,
    endExclusive: state.endExclusive,
    accountId: id,
    categoryId: state.categoryId,
    type: state.type,
  );

  void setCategory(String? id) => state = TransactionFilter(
    search: state.search,
    start: state.start,
    endExclusive: state.endExclusive,
    accountId: state.accountId,
    categoryId: id,
    type: state.type,
  );

  void setRange(DateTime? start, DateTime? endExclusive) =>
      state = TransactionFilter(
        search: state.search,
        start: start,
        endExclusive: endExclusive,
        accountId: state.accountId,
        categoryId: state.categoryId,
        type: state.type,
      );

  void clear() => state = const TransactionFilter();

  bool get isActive =>
      state.search != null ||
      state.type != null ||
      state.accountId != null ||
      state.categoryId != null ||
      state.start != null;
}

final txFilterProvider = NotifierProvider<TxFilterNotifier, TransactionFilter>(
  TxFilterNotifier.new,
);

final transactionsListProvider = StreamProvider<List<SaldoTransaction>>((ref) {
  ref.watch(seedProvider);
  final filter = ref.watch(txFilterProvider);
  ref.watch(transactionsVersionProvider);
  return ref.watch(transactionRepositoryProvider).watch(filter: filter);
});

/// Recent N across all accounts (home).
final recentTransactionsProvider = FutureProvider.autoDispose
    .family<List<SaldoTransaction>, int>((ref, limit) async {
      ref.watch(transactionsVersionProvider);
      return ref.watch(transactionRepositoryProvider).query(limit: limit);
    });

final transactionByIdProvider = FutureProvider.autoDispose
    .family<SaldoTransaction?, String>((ref, id) async {
      ref.watch(transactionsVersionProvider);
      return ref.watch(transactionRepositoryProvider).getById(id);
    });

final transferLegsProvider = FutureProvider.autoDispose
    .family<List<SaldoTransaction>, String>((ref, groupId) async {
      ref.watch(transactionsVersionProvider);
      return ref.watch(transactionRepositoryProvider).getTransferLegs(groupId);
    });

/// History for one account (detail page).
final accountTransactionsProvider = StreamProvider.autoDispose
    .family<List<SaldoTransaction>, String>((ref, accountId) {
      ref.watch(transactionsVersionProvider);
      return ref
          .watch(transactionRepositoryProvider)
          .watch(filter: TransactionFilter(accountId: accountId));
    });
