import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saldo/core/backup/backup.dart';
import 'package:saldo/core/database/providers.dart';
import 'package:saldo/core/demo/demo_data.dart';
import 'package:saldo/core/errors/failures.dart';
import 'package:saldo/core/money/currency.dart';
import 'package:saldo/core/widgets/confirm_dialog.dart';
import 'package:saldo/features/accounts/presentation/accounts_providers.dart';
import 'package:saldo/features/settings/presentation/settings_providers.dart';

import 'restore_sheet.dart';

/// Settings: currency (locked once accounts exist), dark-only appearance
/// note, data actions (export/backup/restore/clear), about + privacy.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _changeCurrency(
    BuildContext context,
    WidgetRef ref,
    String code,
  ) async {
    try {
      final repo = await ref.read(preferencesRepositoryProvider.future);
      await repo.setDefaultCurrencyCode(code);
      ref.invalidate(defaultCurrencyProvider);
      ref.invalidate(hasAccountsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Default currency set to $code')),
        );
      }
    } on Failure catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final ok = await showSaldoConfirm(
      context: context,
      title: 'Delete all saldo data?',
      message:
          'Every account, transaction, category and budget on this device is '
          'removed permanently. Balances and reports go back to zero. '
          'This cannot be undone — make a backup first unless you are sure.',
      confirmLabel: 'Delete everything',
    );
    if (!ok || !context.mounted) return;
    try {
      await clearAllData(ref.read(appDatabaseProvider));
      ref.read(transactionsVersionProvider.notifier).bump();
      ref.invalidate(hasAccountsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All saldo data deleted')),
        );
      }
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
    final theme = Theme.of(context);
    final currency = ref.watch(defaultCurrencyProvider);
    final locked = ref.watch(hasAccountsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Preferences', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  currency.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Currency failed: $e'),
                    data: (code) => locked.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Lock check failed: $e'),
                      data: (isLocked) => DropdownButtonFormField<String>(
                        initialValue: kCurrencies.containsKey(code)
                            ? code
                            : 'NGN',
                        decoration: const InputDecoration(
                          labelText: 'Default currency',
                          prefixIcon: Icon(Icons.attach_money_outlined),
                        ),
                        items: [
                          for (final c in kCurrencies.keys)
                            DropdownMenuItem(
                              value: c,
                              child: Text('$c (${kCurrencies[c]!.symbol})'),
                            ),
                        ],
                        onChanged: isLocked
                            ? null
                            : (v) {
                                if (v != null) _changeCurrency(context, ref, v);
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    locked.value ?? false
                        ? 'Locked: accounts already exist, so existing records keep their currency.'
                        : 'Applies to new accounts and budgets. Existing records never change currency.',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text('Appearance', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.dark_mode_outlined),
              title: Text('Ruled Saldo theme'),
              subtitle: Text('Dark, calm and private by design.'),
            ),
          ),
          const SizedBox(height: 28),
          Text('Data', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          const _DemoTile(),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.table_view_outlined),
                  title: const Text('Export transactions (CSV)'),
                  subtitle: const Text(
                    'Filtered rows with stable columns for spreadsheets.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/export'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Back up saldo'),
                  subtitle: const Text(
                    'Versioned file with everything. Unencrypted — keep it private.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/backup'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore_outlined),
                  title: const Text('Restore from backup'),
                  subtitle: const Text(
                    'Validates first; replaces only after you confirm.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showRestoreSheet(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.delete_forever_outlined,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    'Clear all data',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  subtitle: const Text('Irreversible unless a backup exists.'),
                  onTap: () => _clearAll(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text('About', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Saldo keeps every record on this device. No accounts, '
                'no servers, no tracking. Balances and reports are always '
                'computed from your stored transactions — never from separate '
                'counters.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sample saldo for exploration. Only visible while the saldo is empty —
/// never merges into real data.
class _DemoTile extends ConsumerStatefulWidget {
  const _DemoTile();

  @override
  ConsumerState<_DemoTile> createState() => _DemoTileState();
}

class _DemoTileState extends ConsumerState<_DemoTile> {
  bool _busy = false;

  Future<void> _load() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await seedDemoData(
        accounts: ref.read(accountRepositoryProvider),
        categories: ref.read(categoryRepositoryProvider),
        transactions: ref.read(transactionRepositoryProvider),
        budgets: ref.read(budgetRepositoryProvider),
      );
      ref.read(transactionsVersionProvider.notifier).bump();
      ref.invalidate(hasAccountsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demo data loaded — explore freely')),
        );
      }
    } on Failure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(hasAccountsProvider).value ?? true;
    if (locked) return const SizedBox.shrink();
    return Card(
      child: ListTile(
        leading: _busy
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.science_outlined),
        title: const Text('Load demo data'),
        subtitle: const Text(
          'Sample accounts, transactions and a budget. Empty saldo only.',
        ),
        onTap: _busy ? null : _load,
      ),
    );
  }
}
