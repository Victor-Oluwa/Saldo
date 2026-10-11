import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saldo/app/theme/responsive.dart';
import 'package:saldo/core/dates/format.dart';
import 'package:saldo/core/finance/saldo_math.dart';
import 'package:saldo/core/money/money.dart';
import 'package:saldo/core/widgets/saldo_line.dart';
import 'package:saldo/core/widgets/saldo_states.dart';
import 'package:saldo/core/widgets/saldo_tile.dart';
import 'package:saldo/core/widgets/money_text.dart';
import 'package:saldo/core/widgets/period_selector.dart';
import 'package:saldo/core/widgets/section_header.dart';
import 'package:saldo/core/widgets/skeleton.dart';
import 'package:saldo/core/widgets/stagger.dart';
import 'package:saldo/features/accounts/presentation/accounts_providers.dart';
import 'package:saldo/features/budgets/presentation/budget_usage_row.dart';
import 'package:saldo/features/budgets/presentation/budgets_providers.dart';
import 'package:saldo/features/categories/presentation/categories_providers.dart';
import 'package:saldo/features/transactions/domain/transaction.dart';
import 'package:saldo/features/transactions/presentation/transactions_list_page.dart';
import 'package:saldo/features/transactions/presentation/transactions_providers.dart';

import 'dashboard_providers.dart';

/// Home dashboard: quiet balance + period cash flow + highlights.
/// Every amount comes from a repository query over committed records.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(totalBalancesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Saldo')),
      body: totals.when(
        loading: () => const _HomeSkeleton(),
        error: (e, _) => SaldoErrorState(
          message: 'The saldo could not be read.',
          onRetry: () => ref.invalidate(totalBalancesProvider),
        ),
        data: (map) {
          if (map.isEmpty) {
            return _FirstRun(theme: Theme.of(context));
          }
          return const _Dashboard();
        },
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final gutter = context.saldoGutter;
    return ListView(
      padding: EdgeInsets.all(gutter),
      children: const [
        SaldoSkeleton.card(height: 300),
        SizedBox(height: 16),
        SaldoSkeleton.card(),
        SizedBox(height: 16),
        SaldoSkeletonList(count: 3),
      ],
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard();

  @override
  Widget build(BuildContext context) {
    final gutter = context.saldoGutter;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(gutter, gutter + 8, gutter, 0),
          sliver: const SliverToBoxAdapter(
            child: StaggerIn(index: 0, child: _HeroCard()),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(gutter, 28, gutter, 110),
          sliver: SliverList.list(
            children: const [
              StaggerIn(index: 1, child: _PeriodCashFlow()),
              SizedBox(height: 32),
              StaggerIn(index: 2, child: _BudgetHighlights()),
              SizedBox(height: 32),
              StaggerIn(index: 3, child: _AccountsSection()),
              SizedBox(height: 32),
              StaggerIn(index: 4, child: _RecentSection()),
            ],
          ),
        ),
      ],
    );
  }
}

/// Hero: total balance with a quiet count-up and the 30-day saldo line
/// beneath it — the app's signature "ruling line". Flat surface, generous
/// padding, single calm action.
class _HeroCard extends ConsumerWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final totals = ref.watch(totalBalancesProvider).value ?? {};
    final entries = totals.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final hero = entries.first;
    final rest = entries.skip(1).toList();
    final history = ref.watch(
      balanceHistoryProvider((currency: hero.key, days: 30)),
    );

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total balance', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            Semantics(
              label:
                  'Total recorded balance ${formatMinorUnits(hero.value, hero.key)}',
              child: ExcludeSemantics(
                child: SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: AnimatedBalanceText(
                      minorUnits: hero.value,
                      currencyCode: hero.key,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontSize: context.saldoHeroSize,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 64,
              width: double.infinity,
              child: history.maybeWhen(
                data: (values) => values.length < 2
                    ? null
                    : SaldoLine(
                        values: values,
                        height: 64,
                        semanticsLabel:
                            'Balance trend over the last 30 days for '
                            '${hero.key}',
                      ),
                orElse: () => null,
              ),
            ),
            for (final e in rest) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(e.key, style: theme.textTheme.labelMedium),
                  const Spacer(),
                  BalanceText(
                    minorUnits: e.value,
                    currencyCode: e.key,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => showNewTransactionSheet(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add transaction'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact inline error for a dashboard section — quiet message plus a
/// retry; never leaks raw exception text into the UI.
class _SectionError extends StatelessWidget {
  const _SectionError({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.labelSmall,
              ),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// Quiet inline empty state for a dashboard section.
class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(message, style: theme.textTheme.labelSmall),
      ),
    );
  }
}

/// Period selector + income/expense/net for the selection.
/// Changing the period re-queries the same totals call the reports use.
class _PeriodCashFlow extends ConsumerWidget {
  const _PeriodCashFlow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selection = ref.watch(dashboardPeriodProvider);
    final notifier = ref.read(dashboardPeriodProvider.notifier);
    final now = DateTime.now();
    final totals = ref.watch(periodTotalsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cash flow', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(selection.label(now), style: theme.textTheme.labelSmall),
        const SizedBox(height: 12),
        PeriodSelector(
          selection: selection,
          now: now,
          onPreset: notifier.setPreset,
        ),
        const SizedBox(height: 12),
        totals.when(
          loading: () => const SaldoSkeleton.card(),
          error: (e, _) => _SectionError(
            message: 'Cash flow could not be loaded.',
            onRetry: () => ref.invalidate(periodTotalsProvider),
          ),
          data: (t) {
            final currencies = {
              ...t.incomeByCurrency.keys,
              ...t.expenseByCurrency.keys,
            }.toList()..sort();
            if (currencies.isEmpty) {
              return const _SectionEmpty(message: 'Nothing in this period.');
            }
            return Column(
              children: [
                for (var i = 0; i < currencies.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _CashFlowCard(
                    code: currencies[i],
                    income: t.incomeByCurrency[currencies[i]] ?? 0,
                    expense: t.expenseByCurrency[currencies[i]] ?? 0,
                    net: t.netByCurrency[currencies[i]] ?? 0,
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CashFlowCard extends StatelessWidget {
  const _CashFlowCard({
    required this.code,
    required this.income,
    required this.expense,
    required this.net,
  });

  final String code;
  final int income;
  final int expense;
  final int net;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rate = savingsRate(incomeMinor: income, expenseMinor: expense);
    final netIsNegative = net < 0;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Net takes the full width on top — no 3-way squeeze.
            Row(
              children: [
                Text('Net', style: theme.textTheme.labelMedium),
                const SizedBox(width: 8),
                Text(code, style: theme.textTheme.labelSmall),
                const Spacer(),
                _RatePill(rate: rate),
              ],
            ),
            const SizedBox(height: 8),
            // Scale down instead of overflowing on huge balances / 1.3x text.
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: MoneyText(
                  minorUnits: net.abs(),
                  currencyCode: code,
                  type: netIsNegative
                      ? TransactionType.expense
                      : TransactionType.income,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),
            // Income / Expenses share the row 50/50 with a divider —
            // each gets ~2x the width of the old 3-column layout.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _InOutBlock(
                      icon: Icons.arrow_downward,
                      iconColor: theme.colorScheme.primary,
                      label: 'Income',
                      minorUnits: income,
                      currencyCode: code,
                      type: TransactionType.income,
                    ),
                  ),
                  const VerticalDivider(width: 24, thickness: 1),
                  Expanded(
                    child: _InOutBlock(
                      icon: Icons.arrow_upward,
                      iconColor: theme.colorScheme.error,
                      label: 'Expenses',
                      minorUnits: expense,
                      currencyCode: code,
                      type: TransactionType.expense,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small quiet pill for the cash-flow rate. Keeps the exact contract
/// strings the tests look for ("61.8", "no income recorded").
class _RatePill extends StatelessWidget {
  const _RatePill({required this.rate});

  final double? rate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = rate;
    final text = r == null
        ? 'no income recorded'
        : '${(r * 100).toStringAsFixed(1)}% kept';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.textTheme.labelSmall?.color,
        ),
      ),
    );
  }
}

class _InOutBlock extends StatelessWidget {
  const _InOutBlock({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.minorUnits,
    required this.currencyCode,
    required this.type,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final int minorUnits;
  final String currencyCode;
  final TransactionType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: theme.textTheme.labelSmall),
              const SizedBox(height: 4),
              MoneyText(
                minorUnits: minorUnits,
                currencyCode: currencyCode,
                type: type,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// This month's budgets (month of the selected period): worst-first,
/// top 3 + link. Usage matches the budget detail query exactly.
class _BudgetHighlights extends ConsumerWidget {
  const _BudgetHighlights();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(dashboardPeriodProvider);
    final month = selection.highlightMonth(DateTime.now());
    final highlights = ref.watch(budgetsWithUsageProvider(month));
    return Column(
      children: [
        SectionHeader(
          title: 'Budgets',
          actionLabel: 'See all',
          onAction: () => context.push('/budgets'),
        ),
        highlights.when(
          loading: () => const SaldoSkeletonList(count: 2, itemHeight: 76),
          error: (e, _) => _SectionError(
            message: 'Budgets could not be loaded.',
            onRetry: () => ref.invalidate(budgetsWithUsageProvider(month)),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const _SectionEmpty(message: 'No budgets this month.');
            }
            final sorted = [...list]
              ..sort(
                (a, b) => b.usage.percentUsed.compareTo(a.usage.percentUsed),
              );
            final rows = sorted.take(3).toList();
            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  for (final row in rows)
                    BudgetUsageRow(
                      data: row,
                      onTap: () => context.push('/budgets/${row.budget.id}'),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AccountsSection extends ConsumerWidget {
  const _AccountsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsListProvider);
    return Column(
      children: [
        SectionHeader(
          title: 'Accounts',
          actionLabel: 'See all',
          onAction: () => context.push('/accounts'),
        ),
        accounts.when(
          loading: () => const SaldoSkeletonList(count: 2, itemHeight: 64),
          error: (e, _) => _SectionError(
            message: 'Accounts could not be loaded.',
            onRetry: () => ref.invalidate(accountsListProvider),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const _SectionEmpty(message: 'No active accounts.');
            }
            final shown = list.take(5).toList();
            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  for (final a in shown)
                    SaldoTile(
                      leading: AccountGlyph(
                        name: a.name,
                        heroTag: 'account-${a.id}',
                      ),
                      title: Text(
                        a.name,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        a.currencyCode,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      trailing: _Balance(id: a.id, code: a.currencyCode),
                      onTap: () => context.push('/accounts/${a.id}'),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _RecentSection extends ConsumerWidget {
  const _RecentSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentTransactionsProvider(5));
    return Column(
      children: [
        SectionHeader(
          title: 'Recent transactions',
          actionLabel: 'See all',
          onAction: () => context.push('/transactions'),
        ),
        recent.when(
          loading: () => const SaldoSkeletonList(count: 3, itemHeight: 64),
          error: (e, _) => _SectionError(
            message: 'Recent activity could not be loaded.',
            onRetry: () => ref.invalidate(recentTransactionsProvider(5)),
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return const _SectionEmpty(message: 'No activity yet.');
            }
            final cats = ref.watch(categoryMapProvider).value ?? {};
            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  for (final t in rows)
                    Builder(
                      builder: (context) {
                        final style = tileStyleFor(t.type);
                        final title = t.description?.isNotEmpty == true
                            ? t.description!
                            : (cats[t.categoryId]?.name ?? _fallbackOf(t));
                        return SaldoTile(
                          leading: TileIcon(
                            icon: style.icon,
                            color: style.color,
                            heroTag: 'tx-${t.id}',
                          ),
                          title: Text(
                            title,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
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
        ),
      ],
    );
  }

  String _fallbackOf(SaldoTransaction t) {
    return switch (t.type) {
      TransactionType.income => 'Income',
      TransactionType.expense => 'Expense',
      TransactionType.transfer =>
        t.transferSide == TransferSide.out ? 'Transfer out' : 'Transfer in',
    };
  }
}

class _FirstRun extends StatelessWidget {
  const _FirstRun({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SaldoMotif(accent: Colors.transparent),
            const SizedBox(height: 24),
            Text('Welcome to Saldo', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Private, offline money tracking. Create your first account to begin.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.textTheme.labelSmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/accounts/new'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create account'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Balance extends ConsumerWidget {
  const _Balance({required this.id, required this.code});

  final String id;
  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = ref.watch(accountBalanceProvider(id));
    return b.when(
      loading: () => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, _) => const Icon(Icons.error_outline),
      data: (v) => BalanceText(minorUnits: v, currencyCode: code),
    );
  }
}
