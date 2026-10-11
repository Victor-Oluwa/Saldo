import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saldo/app/theme/colors.dart';
import 'package:saldo/core/database/providers.dart';
import 'package:saldo/core/dates/format.dart';
import 'package:saldo/core/errors/failures.dart';
import 'package:saldo/core/money/money.dart';
import 'package:saldo/core/widgets/confirm_dialog.dart';
import 'package:saldo/core/widgets/saldo_states.dart';
import 'package:saldo/core/widgets/saldo_tile.dart';
import 'package:saldo/core/widgets/money_text.dart';
import 'package:saldo/core/widgets/progress_ring.dart';
import 'package:saldo/core/widgets/skeleton.dart';
import 'package:saldo/features/accounts/presentation/accounts_providers.dart';
import 'package:saldo/features/budgets/domain/budget.dart';
import 'package:saldo/features/categories/presentation/categories_providers.dart';
import 'package:saldo/features/transactions/domain/transaction.dart';

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Budget + fresh usage in one reactive read, so the hero renders from a
/// single loading state instead of nested future builders.
final _budgetDetailProvider = FutureProvider.autoDispose
    .family<({Budget budget, BudgetUsage usage})?, String>((ref, budgetId) async {
      ref.watch(transactionsVersionProvider);
      final repo = ref.watch(budgetRepositoryProvider);
      final budget = await repo.getById(budgetId);
      if (budget == null) return null;
      return (budget: budget, usage: await repo.getUsage(budgetId));
    });

/// Eligible expenses: same category + month + currency. Transfers and
/// income never appear here — same rule as the usage query. Reactive to
/// writes via the transactions version bump.
final _eligibleExpensesProvider = FutureProvider.autoDispose
    .family<List<SaldoTransaction>, String>((ref, budgetId) async {
      ref.watch(transactionsVersionProvider);
      final repo = ref.watch(budgetRepositoryProvider);
      final budget = await repo.getById(budgetId);
      if (budget == null) return const <SaldoTransaction>[];
      final end = budget.periodStart.month == 12
          ? DateTime(budget.periodStart.year + 1, 1, 1)
          : DateTime(
              budget.periodStart.year,
              budget.periodStart.month + 1,
              1,
            );
      final rows = await ref.watch(transactionRepositoryProvider).query(
            filter: TransactionFilter(
              categoryId: budget.categoryId,
              start: budget.periodStart,
              endExclusive: end,
              type: TransactionType.expense,
            ),
          );
      return rows
          .where((t) => t.currencyCode == budget.currencyCode)
          .toList();
    });

/// Budget detail: ring hero + eligible transactions (drill-down).
/// Usage uses the same repository query as the list, so they agree.
class BudgetDetailPage extends ConsumerWidget {
  const BudgetDetailPage({super.key, required this.budgetId});

  final String budgetId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showSaldoConfirm(
      context: context,
      title: 'Delete budget?',
      message:
          'The budget is removed. Transactions stay untouched — only this spending envelope disappears.',
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(budgetRepositoryProvider).delete(budgetId);
      ref.read(transactionsVersionProvider.notifier).bump();
      if (context.mounted) context.pop(true);
    } on Failure catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(_budgetDetailProvider(budgetId));
    return detail.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              SaldoSkeleton.card(height: 200),
              SizedBox(height: 16),
              SaldoSkeletonList(count: 3),
            ],
          ),
        ),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: SaldoErrorState(message: e.toString()),
      ),
      data: (d) => d == null
          ? Scaffold(
              appBar: AppBar(),
              body: const SaldoEmptyState(
                title: 'Budget not found',
                message: 'It may have been deleted.',
              ),
            )
          : _Loaded(
              budget: d.budget,
              usage: d.usage,
              onDelete: () => _delete(context, ref),
            ),
    );
  }
}

class _Loaded extends ConsumerWidget {
  const _Loaded({
    required this.budget,
    required this.usage,
    required this.onDelete,
  });

  final Budget budget;
  final BudgetUsage usage;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cats = ref.watch(categoryMapProvider).value ?? {};
    final catName = cats[budget.categoryId]?.name ?? 'Category';
    final progress = budget.limitMinor <= 0
        ? 0.0
        : (usage.spentMinor / budget.limitMinor).clamp(0.0, 1.0);
    final overspent = usage.remainingMinor < 0;
    final stateColor = usage.isOverspent
        ? SaldoColors.expense
        : SaldoColors.primary;
    final pctLabel = '${(usage.percentUsed * 100).round()}%';

    return Scaffold(
      appBar: AppBar(
        title: Text(catName),
        actions: [
          IconButton(
            tooltip: 'Edit budget',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/budgets/${budget.id}/edit'),
          ),
          IconButton(
            tooltip: 'Delete budget',
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            decoration: BoxDecoration(
              color: SaldoColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SaldoColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SaldoRing(
                        fraction: progress,
                        size: 116,
                        stroke: 10,
                        color: stateColor,
                        semanticsLabel:
                            '$catName budget $pctLabel used. '
                            '${formatMinorUnits(usage.spentMinor, budget.currencyCode)} spent of '
                            '${formatMinorUnits(budget.limitMinor, budget.currencyCode)}.',
                        child: Center(
                          child: Text(
                            pctLabel,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: stateColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_months[budget.periodStart.month - 1]} ${budget.periodStart.year}',
                              style: theme.textTheme.labelSmall,
                            ),
                            const SizedBox(height: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: AnimatedBalanceText(
                                minorUnits: usage.spentMinor,
                                currencyCode: budget.currencyCode,
                                style: theme.textTheme.headlineSmall,
                              ),
                            ),
                            Text(
                              'spent of ${formatMinorUnits(budget.limitMinor, budget.currencyCode)}',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              overspent
                                  ? 'Overspent ${formatMinorUnits(-usage.remainingMinor, budget.currencyCode)}'
                                  : '${formatMinorUnits(usage.remainingMinor, budget.currencyCode)} remaining',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: overspent ? SaldoColors.expense : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (budget.warningThresholdPercent != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Warns at ${budget.warningThresholdPercent}%',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Spending in this budget',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _EligibleList(budgetId: budget.id),
        ],
      ),
    );
  }
}

class _EligibleList extends ConsumerWidget {
  const _EligibleList({required this.budgetId});

  final String budgetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(_eligibleExpensesProvider(budgetId));
    return rows.when(
      loading: () => const SaldoSkeletonList(count: 3),
      error: (e, _) => SaldoErrorState(message: e.toString()),
      data: (list) {
        if (list.isEmpty) {
          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: SaldoColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SaldoColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No spending counted yet this month.',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              for (final t in list)
                Builder(
                  builder: (context) {
                    final style = tileStyleFor(t.type);
                    return SaldoTile(
                      leading: TileIcon(
                        icon: style.icon,
                        color: style.color,
                        heroTag: 'tx-${t.id}',
                      ),
                      title: Text(
                        t.description?.isNotEmpty == true
                            ? t.description!
                            : 'Expense',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        formatSaldoDate(t.transactionDate),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      trailing: MoneyText(
                        minorUnits: t.amountMinor,
                        currencyCode: t.currencyCode,
                        type: t.type,
                      ),
                      onTap: () => context.push('/transactions/${t.id}'),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
