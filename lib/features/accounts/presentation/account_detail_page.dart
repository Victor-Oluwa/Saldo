import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saldo/app/theme/colors.dart';
import 'package:saldo/core/dates/format.dart';
import 'package:saldo/core/errors/failures.dart';
import 'package:saldo/core/money/money.dart';
import 'package:saldo/core/widgets/confirm_dialog.dart';
import 'package:saldo/core/widgets/saldo_states.dart';
import 'package:saldo/core/widgets/saldo_tile.dart';
import 'package:saldo/core/widgets/money_text.dart';
import 'package:saldo/core/widgets/skeleton.dart';
import 'package:saldo/features/accounts/presentation/accounts_providers.dart';
import 'package:saldo/features/categories/presentation/categories_providers.dart';
import 'package:saldo/features/transactions/domain/transaction.dart';
import 'package:saldo/features/transactions/presentation/transactions_providers.dart';
import 'package:saldo/core/database/providers.dart';

/// Account detail: balance + info + its transaction history.
class AccountDetailPage extends ConsumerWidget {
  const AccountDetailPage({super.key, required this.accountId});

  final String accountId;

  Future<void> _archiveToggle(
    BuildContext context,
    WidgetRef ref,
    bool archived,
  ) async {
    try {
      await ref
          .read(accountRepositoryProvider)
          .setArchived(id: accountId, archived: !archived);
      ref.read(transactionsVersionProvider.notifier).bump();
    } on Failure catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showSaldoConfirm(
      context: context,
      title: 'Delete account?',
      message:
          'This only works when the account has no transactions. Deleting removes it permanently. Balances and reports recompute from remaining records.',
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(accountRepositoryProvider).deleteAccount(accountId);
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
    final accAsync = ref.watch(accountByIdProvider(accountId));
    return accAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              SaldoSkeleton.card(height: 180),
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
      data: (acc) {
        if (acc == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const SaldoEmptyState(
              title: 'Account not found',
              message: 'It may have been deleted.',
            ),
          );
        }
        final balance = ref.watch(accountBalanceProvider(accountId));
        final history = ref.watch(accountTransactionsProvider(accountId));
        return Scaffold(
          appBar: AppBar(
            title: Text(acc.name),
            actions: [
              IconButton(
                tooltip: 'Edit account',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.push('/accounts/$accountId/edit'),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'archive') {
                    _archiveToggle(context, ref, acc.isArchived);
                  } else if (v == 'delete') {
                    _delete(context, ref);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'archive',
                    child: Text(acc.isArchived ? 'Unarchive' : 'Archive'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
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
                          AccountGlyph(
                            name: acc.name,
                            heroTag: 'account-$accountId',
                            size: 52,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current balance',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                                balance.when(
                                  loading: () =>
                                      const SaldoSkeleton.block(height: 36),
                                  error: (e, _) => Text('—'),
                                  data: (b) => AnimatedBalanceText(
                                    minorUnits: b,
                                    currencyCode: acc.currencyCode,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.displaySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(label: Text(acc.currencyCode)),
                          if (acc.isArchived)
                            const Chip(label: Text('Archived')),
                        ],
                      ),
                      if (acc.description?.isNotEmpty == true) ...[
                        const SizedBox(height: 12),
                        Text(acc.description!),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Opening: ${formatMinorUnits(acc.openingBalanceMinor, acc.currencyCode)}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text('History', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              history.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => SaldoErrorState(message: e.toString()),
                data: (rows) {
                  if (rows.isEmpty) {
                    return const SaldoEmptyState(
                      title: 'No transactions',
                      message:
                          'Income, expenses and transfers for this account will appear here.',
                    );
                  }
                  return _HistoryList(rows: rows);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryList extends ConsumerWidget {
  const _HistoryList({required this.rows});

  final List<SaldoTransaction> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoryMapProvider).value ?? {};
    return Column(
      children: [
        for (final t in rows)
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
                      : _fallbackTitle(t, cats),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Text(
                  '${cats[t.categoryId]?.name ?? (t.type == TransactionType.transfer ? 'Transfer' : '—')} · ${formatSaldoDate(t.transactionDate)}',
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
    );
  }

  String _fallbackTitle(SaldoTransaction t, Map cats) {
    return switch (t.type) {
      TransactionType.income => 'Income',
      TransactionType.expense => 'Expense',
      TransactionType.transfer =>
        t.transferSide == TransferSide.out ? 'Transfer out' : 'Transfer in',
    };
  }
}
