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
import 'package:saldo/features/transactions/domain/transaction.dart';
import 'package:saldo/features/accounts/presentation/accounts_providers.dart';

/// Create or edit a same-currency transfer.
/// Edit ([groupId] set) changes amount/date/notes on BOTH legs atomically —
/// accounts are immutable after creation for MVP.
class TransferFormPage extends ConsumerStatefulWidget {
  const TransferFormPage({super.key, this.groupId});

  final String? groupId;

  @override
  ConsumerState<TransferFormPage> createState() => _TransferFormPageState();
}

class _TransferFormPageState extends ConsumerState<TransferFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  final _notes = TextEditingController();
  String? _sourceId;
  String? _destId;
  DateTime _date = DateTime.now();
  bool _submitting = false;
  bool _loading = false;
  String? _loadError;
  bool _ready = false;

  bool get isEdit => widget.groupId != null;

  Account? _accountById(List<Account>? accounts, String? id) {
    if (accounts == null || id == null) return null;
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Preview currency follows the source account, else the destination,
  /// else NGN (preview only — submit validates the real pair).
  String _previewCurrency(List<Account>? accounts) =>
      _accountById(accounts, _sourceId)?.currencyCode ??
      _accountById(accounts, _destId)?.currencyCode ??
      'NGN';

  String _previewRoute(List<Account>? accounts) {
    final from = _accountById(accounts, _sourceId)?.name;
    final to = _accountById(accounts, _destId)?.name;
    if (from == null && to == null) return 'Choose accounts below';
    return '${from ?? '…'} → ${to ?? '…'}';
  }

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
      final legs = await ref
          .read(transactionRepositoryProvider)
          .getTransferLegs(widget.groupId!);
      final out = legs.firstWhere(
        (e) => e.transferSide.toString().contains('out'),
      );
      _amount.text = formatMinorUnits(
        out.amountMinor,
        out.currencyCode,
      ).replaceAll(RegExp(r'[^0-9.\-]'), '');
      _desc.text = out.description ?? '';
      _notes.text = out.notes ?? '';
      _date = out.transactionDate;
      _sourceId = out.accountId;
      _destId = out.counterpartAccountId;
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
    if (_sourceId == null || _destId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Choose both accounts')));
      return;
    }
    if (_sourceId == _destId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfer needs two different accounts')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final accounts = await ref.read(accountsListAllProvider.future);
      final src = accounts.firstWhere((a) => a.id == _sourceId);
      final minor = parseInputToMinorUnits(_amount.text, src.currencyCode);
      final repo = ref.read(transactionRepositoryProvider);
      if (!isEdit) {
        await repo.createTransfer(
          sourceAccountId: _sourceId!,
          destAccountId: _destId!,
          amountMinor: minor,
          transactionDate: _date,
          description: _desc.text.isEmpty ? null : _desc.text,
          notes: _notes.text.isEmpty ? null : _notes.text,
        );
      } else {
        await repo.updateTransfer(
          transferGroupId: widget.groupId!,
          amountMinor: minor,
          transactionDate: _date,
          description: _desc.text,
          notes: _notes.text,
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
    final accountsAsync = ref.watch(accountsListProvider);
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit transfer' : 'New transfer')),
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
                    type: TransactionType.transfer,
                    contextLine: _previewRoute(accountsAsync.value),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amount,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      hintText: 'e.g. 20000.00',
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
                    data: (list) => Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: list.any((a) => a.id == _sourceId)
                              ? _sourceId
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'From account',
                            prefixIcon: Icon(Icons.arrow_upward),
                          ),
                          items: [
                            for (final a in list)
                              DropdownMenuItem(
                                value: a.id,
                                child: Text('${a.name} · ${a.currencyCode}'),
                              ),
                          ],
                          onChanged: isEdit
                              ? null
                              : (v) => setState(() => _sourceId = v),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: list.any((a) => a.id == _destId)
                              ? _destId
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'To account',
                            prefixIcon: Icon(Icons.arrow_downward),
                          ),
                          items: [
                            for (final a in list)
                              DropdownMenuItem(
                                value: a.id,
                                child: Text('${a.name} · ${a.currencyCode}'),
                              ),
                          ],
                          onChanged: isEdit
                              ? null
                              : (v) => setState(() => _destId = v),
                        ),
                      ],
                    ),
                  ),
                  if (isEdit)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Accounts cannot change after creation — only amount, date and notes.',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  if (!isEdit)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Same-currency only in MVP. Transfers never affect income or expense totals.',
                        style: Theme.of(context).textTheme.labelSmall,
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
                    ),
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
        label: isEdit ? 'Save changes' : 'Record transfer',
        busy: _submitting,
        onPressed: _submit,
      ),
    );
  }
}
