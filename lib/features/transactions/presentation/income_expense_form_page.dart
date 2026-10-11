import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saldo/core/database/providers.dart';
import 'package:saldo/core/dates/format.dart';
import 'package:saldo/core/errors/failures.dart';
import 'package:saldo/core/money/money.dart';
import 'package:saldo/core/widgets/amount_preview.dart';
import 'package:saldo/core/widgets/saldo_states.dart';
import 'package:saldo/core/widgets/skeleton.dart';
import 'package:saldo/core/widgets/submit_bar.dart';
import 'package:saldo/features/accounts/domain/account.dart';
import 'package:saldo/features/accounts/presentation/accounts_providers.dart';
import 'package:saldo/features/categories/domain/category.dart';
import 'package:saldo/features/categories/presentation/categories_providers.dart';
import 'package:saldo/features/transactions/domain/transaction.dart';

/// Shared income/expense create+edit form.
/// [isIncome] picks category type + repo call. [transactionId] null = create.
class IncomeExpenseFormPage extends ConsumerStatefulWidget {
  const IncomeExpenseFormPage({
    super.key,
    required this.isIncome,
    this.transactionId,
  });

  final bool isIncome;
  final String? transactionId;

  @override
  ConsumerState<IncomeExpenseFormPage> createState() =>
      _IncomeExpenseFormPageState();
}

class _IncomeExpenseFormPageState extends ConsumerState<IncomeExpenseFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  final _notes = TextEditingController();
  String? _accountId;
  String? _categoryId;
  DateTime _date = DateTime.now();
  bool _submitting = false;
  bool _loading = false;
  String? _loadError;
  bool _ready = false;

  TransactionType get _type =>
      widget.isIncome ? TransactionType.income : TransactionType.expense;
  CategoryType get _catType =>
      widget.isIncome ? CategoryType.income : CategoryType.expense;
  bool get isEdit => widget.transactionId != null;

  @override
  void initState() {
    super.initState();
    _amount.addListener(_onAmountTyped);
  }

  void _onAmountTyped() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amount.removeListener(_onAmountTyped);
    _amount.dispose();
    _desc.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _ensureLoaded() async {
    if (!isEdit || _ready || _loading) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final tx = await ref
          .read(transactionRepositoryProvider)
          .getById(widget.transactionId!);
      if (tx == null) throw const NotFoundFailure('Transaction not found');
      if (tx.type != _type) {
        throw const ValidationFailure('Wrong form for this transaction type');
      }
      _amount.text = _minorToInput(tx.amountMinor, tx.currencyCode);
      _desc.text = tx.description ?? '';
      _notes.text = tx.notes ?? '';
      _accountId = tx.accountId;
      _categoryId = tx.categoryId;
      _date = tx.transactionDate;
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

  String _minorToInput(int minor, String code) {
    // Display helper: reuse formatter then strip symbol/commas for editing.
    final formatted = formatMinorUnits(minor, code);
    return formatted.replaceAll(RegExp(r'[^0-9.\-]'), '');
  }

  /// Preview currency follows the chosen account, else the first account,
  /// else NGN (preview only — submit resolves the real account currency).
  String _previewCurrency(List<Account>? accounts) {
    if (accounts != null) {
      for (final a in accounts) {
        if (a.id == _accountId) return a.currencyCode;
      }
      if (accounts.isNotEmpty) return accounts.first.currencyCode;
    }
    return 'NGN';
  }

  String _previewAccount(List<Account>? accounts) {
    if (accounts != null) {
      for (final a in accounts) {
        if (a.id == _accountId) return '${a.name} · ${a.currencyCode}';
      }
    }
    return 'Choose an account below';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(
        () => _date = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _date.hour,
          _date.minute,
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_accountId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Choose an account')));
      return;
    }
    if (_categoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Choose a category')));
      return;
    }
    setState(() => _submitting = true);
    try {
      // Currency follows the account.
      final accounts = await ref.read(accountsListAllProvider.future);
      final acc = accounts.firstWhere((a) => a.id == _accountId);
      final minor = parseInputToMinorUnits(_amount.text, acc.currencyCode);
      final repo = ref.read(transactionRepositoryProvider);
      if (!isEdit) {
        if (widget.isIncome) {
          await repo.createIncome(
            accountId: _accountId!,
            categoryId: _categoryId!,
            amountMinor: minor,
            transactionDate: _date,
            description: _desc.text.isEmpty ? null : _desc.text,
            notes: _notes.text.isEmpty ? null : _notes.text,
          );
        } else {
          await repo.createExpense(
            accountId: _accountId!,
            categoryId: _categoryId!,
            amountMinor: minor,
            transactionDate: _date,
            description: _desc.text.isEmpty ? null : _desc.text,
            notes: _notes.text.isEmpty ? null : _notes.text,
          );
        }
      } else {
        if (widget.isIncome) {
          await repo.updateIncome(
            id: widget.transactionId!,
            accountId: _accountId,
            categoryId: _categoryId,
            amountMinor: minor,
            transactionDate: _date,
            description: _desc.text,
            notes: _notes.text,
          );
        } else {
          await repo.updateExpense(
            id: widget.transactionId!,
            accountId: _accountId,
            categoryId: _categoryId,
            amountMinor: minor,
            transactionDate: _date,
            description: _desc.text,
            notes: _notes.text,
          );
        }
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
      // Input preserved — no pop, inline snackbar only.
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
    final title = isEdit
        ? (widget.isIncome ? 'Edit income' : 'Edit expense')
        : (widget.isIncome ? 'New income' : 'New expense');
    final accountsAsync = ref.watch(accountsListProvider);
    // Active categories for new; incl. archived when editing history.
    final catsActive = ref.watch(categoriesByTypeProvider(_catType));
    final catsAll = ref.watch(categoriesByTypeAllProvider(_catType));
    final cats = isEdit ? catsAll : catsActive;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
                  AmountPreview(
                    rawInput: _amount.text,
                    currencyCode: _previewCurrency(accountsAsync.value),
                    type: _type,
                    contextLine: _previewAccount(accountsAsync.value),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amount,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      hintText: 'e.g. 4500.00',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Amount is required';
                      }
                      try {
                        parseInputToMinorUnits(
                          v,
                          _previewCurrency(accountsAsync.value),
                        );
                      } on FormatException catch (e) {
                        return e.message;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  accountsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text(
                      'Accounts could not be loaded.',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    data: (list) {
                      // For new: active only (already filtered). For edit: need current even if archived.
                      return DropdownButtonFormField<String>(
                        initialValue: list.any((a) => a.id == _accountId)
                            ? _accountId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Account',
                          prefixIcon: Icon(Icons.account_balance_outlined),
                        ),
                        items: [
                          for (final a in list)
                            DropdownMenuItem(
                              value: a.id,
                              child: Text('${a.name} · ${a.currencyCode}'),
                            ),
                        ],
                        onChanged: (v) => setState(() => _accountId = v),
                        validator: (_) =>
                            _accountId == null ? 'Choose an account' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: cats.any((c) => c.id == _categoryId)
                        ? _categoryId
                        : null,
                    decoration: InputDecoration(
                      labelText:
                          'Category (${widget.isIncome ? 'income' : 'expense'})',
                      prefixIcon: const Icon(Icons.label_outline),
                    ),
                    items: [
                      for (final c in cats)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            c.name + (c.isArchived ? ' (archived)' : ''),
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                    validator: (_) =>
                        _categoryId == null ? 'Choose a category' : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push('/categories'),
                      child: const Text('Manage categories'),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Date'),
                    subtitle: Text(formatSaldoDateFull(_date)),
                    onTap: _pickDate,
                  ),
                  TextFormField(
                    controller: _desc,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'e.g. Groceries at market',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notes,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
      bottomNavigationBar: SaldoSubmitBar(
        label: isEdit
            ? 'Save changes'
            : (widget.isIncome ? 'Record income' : 'Record expense'),
        busy: _submitting,
        onPressed: _submit,
      ),
    );
  }
}
