import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saldo/core/database/providers.dart';
import 'package:saldo/core/errors/failures.dart';
import 'package:saldo/core/money/currency.dart';
import 'package:saldo/core/money/money.dart';
import 'package:saldo/core/widgets/saldo_states.dart';
import 'package:saldo/core/widgets/skeleton.dart';
import 'package:saldo/core/widgets/submit_bar.dart';
import 'package:saldo/features/accounts/presentation/accounts_providers.dart';
import 'package:saldo/features/categories/domain/category.dart';
import 'package:saldo/features/categories/presentation/categories_providers.dart';

/// Create ([budgetId] null) or edit a monthly category budget.
/// Edit changes limit + warning only — category/month/currency are fixed
/// so recorded spending keeps its meaning.
class BudgetFormPage extends ConsumerStatefulWidget {
  const BudgetFormPage({super.key, this.budgetId});

  final String? budgetId;

  @override
  ConsumerState<BudgetFormPage> createState() => _BudgetFormPageState();
}

class _BudgetFormPageState extends ConsumerState<BudgetFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _limit = TextEditingController();
  final _threshold = TextEditingController();
  String? _categoryId;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String _currency = 'NGN';
  bool _submitting = false;
  bool _loading = false;
  String? _loadError;
  bool _ready = false;

  bool get isEdit => widget.budgetId != null;

  @override
  void dispose() {
    _limit.dispose();
    _threshold.dispose();
    super.dispose();
  }

  Future<void> _ensureLoaded() async {
    if (!isEdit || _ready || _loading) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final b = await ref
          .read(budgetRepositoryProvider)
          .getById(widget.budgetId!);
      if (b == null) throw const NotFoundFailure('Budget not found');
      _limit.text = formatMinorUnits(
        b.limitMinor,
        b.currencyCode,
      ).replaceAll(RegExp(r'[^0-9.]'), '');
      _threshold.text = b.warningThresholdPercent?.toString() ?? '';
      _categoryId = b.categoryId;
      _month = b.periodStart;
      _currency = b.currencyCode;
    } catch (e) {
      _loadError = e is Failure ? e.message : e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _ready = true;
        });
      }
    }
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    var year = _month.year;
    var month = _month.month;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) =>
          _MonthPicker(initial: DateTime(year, month, 1), now: now),
    );
    if (picked != null) setState(() => _month = picked);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (!isEdit && _categoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Choose a category')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final minor = parseInputToMinorUnits(_limit.text, _currency);
      final threshold = _threshold.text.trim().isEmpty
          ? null
          : int.parse(_threshold.text.trim());
      final repo = ref.read(budgetRepositoryProvider);
      if (!isEdit) {
        await repo.create(
          categoryId: _categoryId!,
          periodStart: _month,
          limitMinor: minor,
          currencyCode: _currency,
          warningThresholdPercent: threshold,
        );
      } else {
        await repo.update(
          id: widget.budgetId!,
          limitMinor: minor,
          warningThresholdPercent: threshold,
        );
      }
      ref.read(transactionsVersionProvider.notifier).bump();
      if (mounted) context.pop(true);
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on Failure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isEdit && !_ready && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
    }
    final cats = ref.watch(categoriesByTypeProvider(CategoryType.expense));
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit budget' : 'New budget')),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: SaldoSkeletonList(count: 4, itemHeight: 72),
            )
          : _loadError != null
          ? SaldoErrorState(message: _loadError!)
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (!isEdit)
                    DropdownButtonFormField<String>(
                      initialValue: cats.any((c) => c.id == _categoryId)
                          ? _categoryId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Expense category',
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                      items: [
                        for (final c in cats)
                          DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) => setState(() => _categoryId = v),
                      validator: (_) =>
                          _categoryId == null ? 'Choose a category' : null,
                    )
                  else
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Category and month are fixed'),
                      subtitle: Text(
                        'Only the limit and warning can change, so past spending keeps its meaning.',
                      ),
                    ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Month'),
                    subtitle: Text(
                      '${months[_month.month - 1]} ${_month.year}',
                    ),
                    enabled: !isEdit,
                    onTap: isEdit ? null : _pickMonth,
                  ),
                  TextFormField(
                    controller: _limit,
                    decoration: const InputDecoration(
                      labelText: 'Monthly limit',
                      hintText: 'e.g. 60000.00',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Limit is required';
                      }
                      try {
                        parseInputToMinorUnits(v, _currency);
                      } on FormatException catch (e) {
                        return e.message;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  if (!isEdit)
                    DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: const InputDecoration(labelText: 'Currency'),
                      items: [
                        for (final c in kCurrencies.keys)
                          DropdownMenuItem(
                            value: c,
                            child: Text('$c (${kCurrencies[c]!.symbol})'),
                          ),
                      ],
                      onChanged: (v) => setState(() => _currency = v ?? 'NGN'),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _threshold,
                    decoration: const InputDecoration(
                      labelText: 'Warning at % (optional)',
                      hintText: 'e.g. 80',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final n = int.tryParse(v.trim());
                      if (n == null || n < 0 || n > 100) {
                        return 'Enter 0–100';
                      }
                      return null;
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Spent counts same-currency expenses in this category and month. Transfers never count.',
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: SaldoSubmitBar(
        label: isEdit ? 'Save changes' : 'Create budget',
        busy: _submitting,
        onPressed: _submit,
      ),
    );
  }
}

/// Year-grid month picker returning month start.
class _MonthPicker extends StatefulWidget {
  const _MonthPicker({required this.initial, required this.now});

  final DateTime initial;
  final DateTime now;

  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
  }

  @override
  Widget build(BuildContext context) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return AlertDialog(
      title: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _year -= 1),
          ),
          Expanded(child: Text('$_year', textAlign: TextAlign.center)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() => _year += 1),
          ),
        ],
      ),
      content: SizedBox(
        width: 280,
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          children: [
            for (var m = 1; m <= 12; m++)
              ChoiceChip(
                label: Text(months[m - 1]),
                selected:
                    widget.initial.year == _year && widget.initial.month == m,
                onSelected: (_) =>
                    Navigator.of(context).pop(DateTime(_year, m, 1)),
              ),
          ],
        ),
      ),
    );
  }
}
