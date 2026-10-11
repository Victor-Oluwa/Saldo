import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saldo/core/database/providers.dart';
import 'package:saldo/core/dates/report_period.dart';
import 'package:saldo/core/errors/failures.dart';
import 'package:saldo/core/export/share_file.dart';
import 'package:saldo/core/export/transaction_csv.dart';
import 'package:saldo/core/widgets/saldo_states.dart';
import 'package:saldo/core/widgets/period_selector.dart';
import 'package:saldo/features/accounts/presentation/accounts_providers.dart';
import 'package:saldo/features/categories/domain/category.dart';
import 'package:saldo/features/categories/presentation/categories_providers.dart';
import 'package:saldo/features/transactions/domain/transaction.dart';

/// CSV export: range preset + account/category/type filters, live match
/// count, share sheet. Only the matching rows are ever serialized —
/// the query builds the row list, the CSV writer just formats it.
class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  SelectedPeriod _period = const SelectedPeriod();
  String? _accountId;
  String? _categoryId;
  TransactionType? _type;
  Future<List<SaldoTransaction>>? _rowsFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  TransactionFilter get _filter {
    final range = queryRangeFor(_period, DateTime.now());
    return TransactionFilter(
      start: range.start,
      endExclusive: range.endExclusive,
      accountId: _accountId,
      categoryId: _categoryId,
      type: _type,
    );
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _rowsFuture = ref
          .read(transactionRepositoryProvider)
          .query(filter: _filter);
    });
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final start = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year, now.month, 1),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Export range start',
    );
    if (start == null || !mounted) return;
    final end = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: start,
      lastDate: DateTime(2100),
      helpText: 'Export range end',
    );
    if (end == null || !mounted) return;
    setState(() {
      _period = SelectedPeriod(
        preset: PeriodPreset.custom,
        customStart: DateTime(start.year, start.month, start.day),
        customEndExclusive: DateTime(
          end.year,
          end.month,
          end.day,
        ).add(const Duration(days: 1)),
      );
    });
    _refresh();
  }

  Future<void> _export() async {
    if (_busy) return;
    final rows = await _rowsFuture;
    if (rows == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final accounts = await ref.read(accountMapProvider.future);
      final categories = await ref.read(categoryMapProvider.future);
      final csv = transactionsToCsv(
        rows,
        accounts: accounts,
        categories: categories,
      );
      await shareTextFile(
        fileName: csvFileName(),
        content: csv,
        mimeType: 'text/csv',
        subject: 'Saldo transactions',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported ${rows.length} transactions')),
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
    final now = DateTime.now();
    final accounts = ref.watch(accountsListAllProvider).value ?? [];
    final categories = ref.watch(categoriesAllInclArchivedProvider).value ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Export transactions')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_period.label(now), style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          PeriodSelector(
            selection: _period,
            now: now,
            onPreset: (p) {
              setState(() => _period = SelectedPeriod(preset: p));
              _refresh();
            },
            onCustom: _pickCustom,
          ),
          const SizedBox(height: 12),
          SegmentedButton<TransactionType?>(
            segments: const [
              ButtonSegment(value: null, label: Text('All')),
              ButtonSegment(
                value: TransactionType.income,
                label: Text('Income'),
              ),
              ButtonSegment(
                value: TransactionType.expense,
                label: Text('Expense'),
              ),
              ButtonSegment(
                value: TransactionType.transfer,
                label: Text('Transfer'),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (s) {
              setState(() => _type = s.first);
              _refresh();
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _accountId,
                  decoration: const InputDecoration(labelText: 'Account'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All accounts'),
                    ),
                    for (final a in accounts)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) {
                    setState(() => _accountId = v);
                    _refresh();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All categories'),
                    ),
                    for (final Category c in categories)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) {
                    setState(() => _categoryId = v);
                    _refresh();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final future = _rowsFuture;
              if (future == null) {
                return const LinearProgressIndicator();
              }
              return FutureBuilder<List<SaldoTransaction>>(
                future: future,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    if (snap.hasError) {
                      return SaldoErrorState(
                        message: '${snap.error}',
                        onRetry: _refresh,
                      );
                    }
                    return const LinearProgressIndicator();
                  }
                  final n = snap.data!.length;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        n == 1
                            ? '1 transaction matches.'
                            : '$n transactions match.',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 8),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'CSV columns: id, date (yyyy-MM-ddTHH:mm local), type, '
                'exact decimal amount + integer minor units, currency, '
                'account, category, description, notes, transfer group/side '
                'where applicable. Transfers export as linked pairs.',
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _busy ? null : _export,
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_outlined),
            label: const Text('Export CSV'),
          ),
        ],
      ),
    );
  }
}
