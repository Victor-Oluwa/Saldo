import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saldo/app/theme/colors.dart';
import 'package:saldo/core/database/providers.dart';
import 'package:saldo/core/dates/format.dart';
import 'package:saldo/core/errors/failures.dart';
import 'package:saldo/core/widgets/confirm_dialog.dart';
import 'package:saldo/core/widgets/saldo_states.dart';
import 'package:saldo/core/widgets/saldo_tile.dart';
import 'package:saldo/core/widgets/money_text.dart';
import 'package:saldo/features/accounts/presentation/accounts_providers.dart';
import 'package:saldo/features/categories/presentation/categories_providers.dart';
import 'package:saldo/features/transactions/domain/transaction.dart';
import 'package:saldo/features/transactions/presentation/transactions_providers.dart';

/// Detail for any record. Transfer legs show both sides + counterpart.
/// Edit/delete update both legs atomically with confirmation.
class TransactionDetailPage extends ConsumerWidget {
  const TransactionDetailPage({super.key, required this.transactionId});

  final String transactionId;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    SaldoTransaction tx,
  ) async {
    final isTransfer = tx.type == TransactionType.transfer;
    final ok = await showSaldoConfirm(
      context: context,
      title: isTransfer ? 'Delete transfer?' : 'Delete transaction?',
      message: isTransfer
          ? 'Both sides of this transfer will be removed and both account balances plus reports will update.'
          : 'This record will be removed and its account balance plus reports will update.',
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(transactionRepositoryProvider).deleteTransaction(tx.id);
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
    final txAsync = ref.watch(transactionByIdProvider(transactionId));
    return txAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: SaldoErrorState(message: e.toString()),
      ),
      data: (tx) {
        if (tx == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const SaldoEmptyState(
              title: 'Not found',
              message: 'This record may have been deleted.',
            ),
          );
        }
        final isTransfer = tx.type == TransactionType.transfer;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              isTransfer
                  ? 'Transfer'
                  : (tx.type == TransactionType.income ? 'Income' : 'Expense'),
            ),
            actions: [
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  if (isTransfer) {
                    context.push(
                      '/transactions/transfer/${tx.transferGroupId}/edit',
                    );
                  } else {
                    final type = tx.type == TransactionType.income
                        ? 'income'
                        : 'expense';
                    context.push('/transactions/${tx.id}/edit?type=$type');
                  }
                },
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(context, ref, tx),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _AmountHero(tx: tx),
              const SizedBox(height: 20),
              _Row(
                label: 'Date',
                value: formatSaldoDateFull(tx.transactionDate),
              ),
              _AccountRow(tx: tx),
              if (!isTransfer) _CategoryRow(tx: tx),
              if (isTransfer) _TransferLegs(groupId: tx.transferGroupId!),
              if (tx.description?.isNotEmpty == true)
                _Row(label: 'Description', value: tx.description!),
              if (tx.notes?.isNotEmpty == true)
                _Row(label: 'Notes', value: tx.notes!),
            ],
          ),
        );
      },
    );
  }
}

/// Tinted amount hero with the type icon flying in from the list tile.
class _AmountHero extends StatelessWidget {
  const _AmountHero({required this.tx});

  final SaldoTransaction tx;

  @override
  Widget build(BuildContext context) {
    final style = tileStyleFor(tx.type);
    final label = switch (tx.type) {
      TransactionType.income => 'Income',
      TransactionType.expense => 'Expense',
      TransactionType.transfer =>
        tx.transferSide == TransferSide.out
            ? 'Transfer · Out'
            : 'Transfer · In',
    };
    return Container(
      decoration: BoxDecoration(
        color: SaldoColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SaldoColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            TileIcon(
              icon: style.icon,
              color: style.color,
              heroTag: 'tx-${tx.id}',
              size: 56,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MoneyText(
                    minorUnits: tx.amountMinor,
                    currencyCode: tx.currencyCode,
                    type: tx.type,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(label, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One side of a transfer leg.
class _LegChip extends StatelessWidget {
  const _LegChip({
    required this.label,
    required this.account,
    required this.color,
  });

  final String label;
  final String account;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: SaldoColors.elevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(account, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

class _AccountRow extends ConsumerWidget {
  const _AccountRow({required this.tx});

  final SaldoTransaction tx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final map = ref.watch(accountMapProvider).value ?? {};
    final name = map[tx.accountId]?.name ?? 'Account';
    return Card(
      child: ListTile(
        title: const Text('Account'),
        subtitle: Text(
          '$name · ${tx.currencyCode}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/accounts/${tx.accountId}'),
      ),
    );
  }
}

class _CategoryRow extends ConsumerWidget {
  const _CategoryRow({required this.tx});

  final SaldoTransaction tx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final map = ref.watch(categoryMapProvider).value ?? {};
    final name = map[tx.categoryId]?.name ?? '—';
    return _Row(label: 'Category', value: name);
  }
}

class _TransferLegs extends ConsumerWidget {
  const _TransferLegs({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final legs = ref.watch(transferLegsProvider(groupId));
    final accs = ref.watch(accountMapProvider).value ?? {};
    return legs.when(
      loading: () => const Card(child: LinearProgressIndicator()),
      error: (e, _) => SaldoErrorState(message: e.toString()),
      data: (rows) {
        final out = rows
            .where((e) => e.transferSide == TransferSide.out)
            .firstOrNull;
        final inn = rows
            .where((e) => e.transferSide == TransferSide.incoming)
            .firstOrNull;
        String nameOf(String? id) => accs[id]?.name ?? 'Account';
        final outName = nameOf(out?.accountId);
        final inName = nameOf(inn?.accountId);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Both sides',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Semantics(
                  label: 'Transfer from $outName to $inName.',
                  child: ExcludeSemantics(
                    child: Row(
                      children: [
                        Expanded(
                          child: _LegChip(
                            label: 'From',
                            account: outName,
                            color: SaldoColors.textSecondary,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(
                            Icons.arrow_forward,
                            color: SaldoColors.textSecondary,
                          ),
                        ),
                        Expanded(
                          child: _LegChip(
                            label: 'To',
                            account: inName,
                            color: SaldoColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Net assets unchanged.',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
