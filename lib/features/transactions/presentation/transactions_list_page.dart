import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saldo/app/theme/colors.dart';
import 'package:saldo/core/dates/format.dart';
import 'package:saldo/core/widgets/saldo_states.dart';
import 'package:saldo/core/widgets/saldo_tile.dart';
import 'package:saldo/core/widgets/money_text.dart';
import 'package:saldo/core/widgets/skeleton.dart';
import 'package:saldo/features/accounts/domain/account.dart';
import 'package:saldo/features/accounts/presentation/accounts_providers.dart';
import 'package:saldo/features/categories/domain/category.dart';
import 'package:saldo/features/categories/presentation/categories_providers.dart';
import 'package:saldo/features/transactions/domain/transaction.dart';
import 'package:saldo/features/transactions/presentation/transactions_providers.dart';

/// Full history with combinable search + type/account/category/date filters,
/// grouped into pinned day sections (Today / Yesterday / date).
class TransactionsListPage extends ConsumerStatefulWidget {
  const TransactionsListPage({super.key});

  @override
  ConsumerState<TransactionsListPage> createState() =>
      _TransactionsListPageState();
}

class _TransactionsListPageState extends ConsumerState<TransactionsListPage> {
  final _search = TextEditingController();
  bool _showFilters = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(txFilterProvider);
    final notifier = ref.read(txFilterProvider.notifier);
    final rows = ref.watch(transactionsListProvider);
    final accounts = ref.watch(accountsListAllProvider).value ?? [];
    final catsAll = ref.watch(categoriesAllInclArchivedProvider).value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            tooltip: filterActive(filter)
                ? 'Hide filters (active)'
                : 'Show filters',
            icon: Badge(
              isLabelVisible: filterActive(filter),
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: SearchBar(
              controller: _search,
              hintText: 'Search description or notes',
              leading: const Icon(Icons.search),
              trailing: [
                if (_search.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _search.clear();
                      notifier.setSearch(null);
                      setState(() {});
                    },
                  ),
              ],
              onChanged: (v) {
                notifier.setSearch(v);
                setState(() {});
              },
            ),
          ),
          if (_showFilters)
            _FilterPanel(
              accounts: accounts,
              categories: catsAll,
              onClear: () {
                _search.clear();
                notifier.clear();
              },
            ),
          Expanded(
            child: rows.when(
              loading: () => const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: SaldoSkeletonList(count: 6),
              ),
              error: (e, _) => SaldoErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(transactionsListProvider),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return SaldoEmptyState(
                    title: filterActive(filter)
                        ? 'No matches'
                        : 'No transactions yet',
                    message: filterActive(filter)
                        ? 'Try a different search or clear the filters.'
                        : 'Record income, expenses or transfers to see them here.',
                    actionLabel: filterActive(filter)
                        ? 'Clear filters'
                        : 'Add transaction',
                    onAction: () {
                      if (filterActive(filter)) {
                        _search.clear();
                        notifier.clear();
                      } else {
                        showNewTransactionSheet(context);
                      }
                    },
                  );
                }
                final groups = _groupedByDay(list);
                return CustomScrollView(
                  slivers: [
                    for (final g in groups)
                      SliverMainAxisGroup(
                        slivers: [
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _DayHeaderDelegate(g.label),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            sliver: SliverList.builder(
                              itemCount: g.rows.length,
                              itemBuilder: (context, i) =>
                                  _TxTile(tx: g.rows[i]),
                            ),
                          ),
                        ],
                      ),
                    const SliverPadding(padding: EdgeInsets.only(bottom: 180)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showNewTransactionSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  /// Rows arrive newest-first; split them into day sections with friendly
  /// labels. Search/filter results keep the same grouping.
  List<({String label, List<SaldoTransaction> rows})> _groupedByDay(
    List<SaldoTransaction> list,
  ) {
    final now = DateTime.now();
    final groups = <({String label, List<SaldoTransaction> rows})>[];
    for (final t in list) {
      final label = formatSaldoDate(t.transactionDate, now: now);
      if (groups.isEmpty || groups.last.label != label) {
        groups.add((label: label, rows: [t]));
      } else {
        groups.last.rows.add(t);
      }
    }
    return groups;
  }

  bool filterActive(TransactionFilter f) =>
      f.search != null ||
      f.type != null ||
      f.accountId != null ||
      f.categoryId != null ||
      f.start != null;
}

/// Pinned day section header — opaque background so rows slide under it.
class _DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  _DayHeaderDelegate(this.label);

  final String label;

  static const double height = 40;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Semantics(
      header: true,
      child: Container(
        color: SaldoColors.background,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_DayHeaderDelegate oldDelegate) =>
      oldDelegate.label != label;
}

class _FilterPanel extends ConsumerWidget {
  const _FilterPanel({
    required this.accounts,
    required this.categories,
    required this.onClear,
  });

  final List<Account> accounts;
  final List<Category> categories;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(txFilterProvider);
    final notifier = ref.read(txFilterProvider.notifier);
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: filter.type == null,
                  onSelected: (_) => notifier.setType(null),
                ),
                ChoiceChip(
                  label: const Text('Income'),
                  selected: filter.type == TransactionType.income,
                  onSelected: (_) => notifier.setType(TransactionType.income),
                ),
                ChoiceChip(
                  label: const Text('Expense'),
                  selected: filter.type == TransactionType.expense,
                  onSelected: (_) =>
                      notifier.setType(TransactionType.expense),
                ),
                ChoiceChip(
                  label: const Text('Transfer'),
                  selected: filter.type == TransactionType.transfer,
                  onSelected: (_) =>
                      notifier.setType(TransactionType.transfer),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: filter.accountId,
                    decoration: const InputDecoration(labelText: 'Account'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All accounts'),
                      ),
                      for (final a in accounts)
                        DropdownMenuItem(value: a.id, child: Text(a.name)),
                    ],
                    onChanged: notifier.setAccount,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: filter.categoryId,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All categories'),
                      ),
                      for (final c in categories)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: notifier.setCategory,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Period', style: theme.textTheme.labelMedium),
                const Spacer(),
                TextButton(onPressed: onClear, child: const Text('Clear')),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All time'),
                  selected: filter.start == null,
                  onSelected: (_) => notifier.setRange(null, null),
                ),
                ChoiceChip(
                  label: const Text('This month'),
                  selected: _isThisMonth(filter),
                  onSelected: (_) {
                    final now = DateTime.now();
                    notifier.setRange(
                      DateTime(now.year, now.month, 1),
                      now.month == 12
                          ? DateTime(now.year + 1, 1, 1)
                          : DateTime(now.year, now.month + 1, 1),
                    );
                  },
                ),
                ChoiceChip(
                  label: const Text('Last month'),
                  selected: _isLastMonth(filter),
                  onSelected: (_) {
                    final now = DateTime.now();
                    final thisStart = DateTime(now.year, now.month, 1);
                    final prevStart = now.month == 1
                        ? DateTime(now.year - 1, 12, 1)
                        : DateTime(now.year, now.month - 1, 1);
                    notifier.setRange(prevStart, thisStart);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isThisMonth(TransactionFilter f) {
    if (f.start == null || f.endExclusive == null) return false;
    final now = DateTime.now();
    return f.start == DateTime(now.year, now.month, 1);
  }

  bool _isLastMonth(TransactionFilter f) {
    if (f.start == null || f.endExclusive == null) return false;
    final now = DateTime.now();
    final thisStart = DateTime(now.year, now.month, 1);
    return f.endExclusive == thisStart && f.start!.isBefore(thisStart);
  }
}

class _TxTile extends ConsumerWidget {
  const _TxTile({required this.tx});

  final SaldoTransaction tx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoryMapProvider).value ?? {};
    final accs = ref.watch(accountMapProvider).value ?? {};
    final catName =
        cats[tx.categoryId]?.name ??
        (tx.type == TransactionType.transfer ? 'Transfer' : '—');
    final accName = accs[tx.accountId]?.name ?? 'Account';
    final label = switch (tx.type) {
      TransactionType.income => 'Income',
      TransactionType.expense => 'Expense',
      TransactionType.transfer => 'Transfer',
    };
    final style = tileStyleFor(tx.type);
    return SaldoTile(
      leading: TileIcon(
        icon: style.icon,
        color: style.color,
        heroTag: 'tx-${tx.id}',
      ),
      title: Text(
        tx.description?.isNotEmpty == true
            ? tx.description!
            : (tx.type == TransactionType.transfer
                  ? (tx.transferSide == TransferSide.out
                        ? 'Transfer out'
                        : 'Transfer in')
                  : catName),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        '$catName · $accName · ${formatSaldoDate(tx.transactionDate)}',
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall,
      ),
      trailing: MoneyText(
        minorUnits: tx.amountMinor,
        currencyCode: tx.currencyCode,
        type: tx.type,
      ),
      onTap: () => context.push('/transactions/${tx.id}'),
      semanticLabel: '$label ${tx.description ?? catName}',
    );
  }
}

/// Bottom sheet to pick Income / Expense / Transfer explicitly.
void showNewTransactionSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'What would you like to record?',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 12),
              SaldoTile(
                leading: const TileIcon(
                  icon: Icons.arrow_downward,
                  color: SaldoColors.primary,
                ),
                title: const Text('Income'),
                subtitle: const Text('Salary, freelance'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/transactions/income/new');
                },
              ),
              SaldoTile(
                leading: const TileIcon(
                  icon: Icons.arrow_upward,
                  color: SaldoColors.expense,
                ),
                title: const Text('Expense'),
                subtitle: const Text('Groceries, transport, bills'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/transactions/expense/new');
                },
              ),
              SaldoTile(
                leading: const TileIcon(
                  icon: Icons.swap_horiz,
                  color: SaldoColors.textSecondary,
                ),
                title: const Text('Transfer'),
                subtitle: const Text('Move between accounts'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/transactions/transfer/new');
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
