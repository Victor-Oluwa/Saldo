import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saldo/core/backup/backup.dart';
import 'package:saldo/core/database/app_database.dart';
import 'package:saldo/core/database/providers.dart';
import 'package:saldo/core/errors/failures.dart';
import 'package:saldo/core/export/share_file.dart';
import 'package:saldo/features/settings/presentation/settings_providers.dart';

/// Backup preview (row counts) + creation. The file is unencrypted JSON —
/// the warning below is part of the acceptance criteria, not decoration.
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _busy = false;

  Future<Map<String, int>> _counts(AppDatabase db) async {
    return {
      'Accounts': (await db.select(db.accounts).get()).length,
      'Transactions': (await db.select(db.transactions).get()).length,
      'Categories': (await db.select(db.categories).get()).length,
      'Budgets': (await db.select(db.budgets).get()).length,
    };
  }

  Future<void> _createBackup() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final db = ref.read(appDatabaseProvider);
      final prefs = await ref.read(preferencesRepositoryProvider.future);
      final backup = await exportBackup(db, prefs);
      final name = backupFileName();
      await shareTextFile(
        fileName: name,
        content: encodeBackup(backup),
        mimeType: 'application/json',
        subject: 'Saldo backup',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup created — store it somewhere private'),
          ),
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
    final theme = Theme.of(context);
    final db = ref.watch(appDatabaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Back up saldo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What gets backed up',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<Map<String, int>>(
                    future: _counts(db),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const LinearProgressIndicator();
                      }
                      final counts = snap.data!;
                      return Column(
                        children: [
                          for (final e in counts.entries)
                            Row(
                              children: [
                                Expanded(child: Text(e.key)),
                                Text('${e.value}'),
                              ],
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Plus your default currency and a version marker. '
                    'Opening balances travel with their accounts.',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Backups are NOT encrypted. Amounts, descriptions and notes '
                'are readable by anyone with the file — share and store it '
                'like cash.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _busy ? null : _createBackup,
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.backup_outlined),
            label: const Text('Create backup file'),
          ),
        ],
      ),
    );
  }
}
