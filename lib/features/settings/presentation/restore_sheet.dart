import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saldo/core/backup/backup.dart';
import 'package:saldo/core/database/providers.dart';
import 'package:saldo/core/errors/failures.dart';
import 'package:saldo/features/accounts/presentation/accounts_providers.dart';
import 'package:saldo/features/settings/presentation/settings_providers.dart';

/// Restore entry point: pick a `.json` backup, validate it WITHOUT writing
/// anything, then replace the saldo only after explicit confirmation.
/// Invalid files never touch current data.
Future<void> showRestoreSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const Padding(
      padding: EdgeInsets.only(bottom: 24),
      child: _RestoreSheet(),
    ),
  );
}

class _RestoreSheet extends ConsumerStatefulWidget {
  const _RestoreSheet();

  @override
  ConsumerState<_RestoreSheet> createState() => _RestoreSheetState();
}

class _RestoreSheetState extends ConsumerState<_RestoreSheet> {
  bool _busy = false;
  String? _fileName;
  Map<String, dynamic>? _backup;
  BackupSummary? _summary;
  String? _error;

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
      _backup = null;
      _summary = null;
    });
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (picked == null) {
        if (mounted) setState(() => _busy = false);
        return; // user cancelled — nothing happened.
      }
      final text = await picked.xFile.readAsString();
      final backup = decodeBackup(text); // validates; throws on problems
      final summary = validateBackup(backup);
      if (mounted) {
        setState(() {
          _fileName = picked.name;
          _backup = backup;
          _summary = summary;
        });
      }
    } on Failure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Object catch (e) {
      if (mounted) setState(() => _error = 'Could not read that file ($e)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final backup = _backup;
    if (backup == null || _busy) return;
    setState(() => _busy = true);
    try {
      final prefs = await ref.read(preferencesRepositoryProvider.future);
      await restoreBackup(ref.read(appDatabaseProvider), prefs, backup);
      ref.read(transactionsVersionProvider.notifier).bump();
      ref.invalidate(hasAccountsProvider);
      ref.invalidate(defaultCurrencyProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saldo restored from backup')),
        );
      }
    } on Failure catch (e) {
      // Validation runs before any write, so current data is intact.
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = _summary;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Restore from backup', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text(
              'The file is checked first. Your current saldo stays '
              'untouched until you confirm the replacement.',
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Choose backup file'),
            ),
            if (_busy) ...const [
              SizedBox(height: 12),
              LinearProgressIndicator(),
            ],
            if (_fileName != null) ...[
              const SizedBox(height: 8),
              Text('File: $_fileName', style: theme.textTheme.labelSmall),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 4),
              const Text('Current data was not changed.'),
            ],
            if (summary != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Valid backup (v${summary.version})',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${summary.accountCount} accounts · '
                        '${summary.transactionCount} transactions · '
                        '${summary.categoryCount} categories · '
                        '${summary.budgetCount} budgets',
                      ),
                      Text('Default currency: ${summary.defaultCurrency}'),
                      if (summary.exportedAt != null)
                        Text(
                          'Exported: ${summary.exportedAt!.toLocal()}',
                          style: theme.textTheme.labelSmall,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Restoring REPLACES everything currently recorded. '
                'Backups are unencrypted — anyone with the file can read it.',
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _busy ? null : _restore,
                child: const Text('Replace saldo with this backup'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
