import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saldo/core/money/money.dart';
import 'package:saldo/core/widgets/saldo_states.dart';
import 'package:saldo/core/widgets/saldo_tile.dart';
import 'package:saldo/core/widgets/skeleton.dart';
import 'package:saldo/features/accounts/presentation/accounts_providers.dart';

/// Accounts list — balance per account derived from records.
class AccountsListPage extends ConsumerWidget {
  const AccountsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      body: accounts.when(
        loading: () => const SaldoSkeletonList(count: 3, itemHeight: 72),
        error: (e, _) => SaldoErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(accountsListProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return SaldoEmptyState(
              title: 'No accounts yet',
              message:
                  'Create your first account with an opening balance to start tracking.',
              actionLabel: 'Create account',
              onAction: () => context.push('/accounts/new'),
            );
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 180),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final a = list[i];
                return _AccountTile(accountId: a.id);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/accounts/new'),
        icon: const Icon(Icons.add),
        label: const Text('Account'),
      ),
    );
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsListProvider).value ?? [];
    final acc = accounts.where((a) => a.id == accountId).firstOrNull;
    if (acc == null) return const SizedBox.shrink();
    final balance = ref.watch(accountBalanceProvider(accountId));
    return SaldoTile(
      leading: AccountGlyph(name: acc.name, heroTag: 'account-$accountId'),
      title: Text(
        acc.name,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        acc.currencyCode,
        style: Theme.of(context).textTheme.labelSmall,
      ),
      trailing: balance.when(
        loading: () => const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        error: (_, _) => const Icon(Icons.error_outline),
        data: (b) => Text(
          formatMinorUnits(b, acc.currencyCode),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
      onTap: () => context.push('/accounts/$accountId'),
    );
  }
}
