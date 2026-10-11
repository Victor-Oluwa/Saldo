import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saldo/core/widgets/saldo_states.dart';
import 'package:saldo/core/widgets/skeleton.dart';
import 'package:saldo/features/budgets/presentation/budget_usage_row.dart';
import 'package:saldo/features/budgets/presentation/budgets_providers.dart';

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

/// Monthly category budgets: usage rows + month navigator.
/// Spent/remaining come from the same query the detail page uses.
class BudgetsPage extends ConsumerWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final month = ref.watch(budgetMonthProvider);
    final navigator = ref.read(budgetMonthProvider.notifier);
    final cards = ref.watch(budgetsWithUsageProvider(month));
    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => navigator.shift(-1),
                ),
                Expanded(
                  child: Semantics(
                    button: true,
                    label:
                        'Budget month ${_months[month.month - 1]} ${month.year}. Activate to return to current month.',
                    child: InkWell(
                      onTap: navigator.today,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Text(
                          '${_months[month.month - 1]} ${month.year}',
                          style: theme.textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => navigator.shift(1),
                ),
              ],
            ),
          ),
          Expanded(
            child: cards.when(
              loading: () => const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: SaldoSkeletonList(count: 4, itemHeight: 100),
              ),
              error: (e, _) => SaldoErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(budgetsWithUsageProvider(month)),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return SaldoEmptyState(
                    title: 'No budgets this month',
                    message:
                        'Create a monthly budget for an expense category to track what is left to spend.',
                    actionLabel: 'Create budget',
                    onAction: () => context.push('/budgets/new'),
                  );
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 180),
                    itemCount: list.length,
                    itemBuilder: (context, i) => BudgetUsageRow(
                      data: list[i],
                      onTap: () =>
                          context.push('/budgets/${list[i].budget.id}'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/budgets/new'),
        icon: const Icon(Icons.add),
        label: const Text('Budget'),
      ),
    );
  }
}
