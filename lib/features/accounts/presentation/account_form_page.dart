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
import 'package:saldo/features/settings/presentation/settings_providers.dart';
import 'package:saldo/features/accounts/presentation/accounts_providers.dart';

/// Parses opening balance: like [parseInputToMinorUnits] but zero allowed,
/// and a leading "-" yields negative (for owed/opening overdraft).
int parseOpeningBalance(String input, String currencyCode) {
  final trimmed = input.trim().replaceAll(',', '');
  if (trimmed.isEmpty) {
    throw const FormatException('Opening balance is required');
  }
  final negative = trimmed.startsWith('-');
  final unsigned = negative
      ? trimmed.substring(1)
      : trimmed.replaceFirst(RegExp(r'^\+'), '');
  if (unsigned.isEmpty) throw const FormatException('Invalid opening balance');
  if (unsigned == '0' || unsigned == '0.00' || unsigned == '0.0') return 0;
  final minor = parseInputToMinorUnits(unsigned, currencyCode);
  return negative ? -minor : minor;
}

/// Create (no [accountId]) or edit metadata ([accountId] set).
class AccountFormPage extends ConsumerStatefulWidget {
  const AccountFormPage({super.key, this.accountId});

  final String? accountId;

  @override
  ConsumerState<AccountFormPage> createState() => _AccountFormPageState();
}

class _AccountFormPageState extends ConsumerState<AccountFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _opening = TextEditingController(text: '0');
  final _desc = TextEditingController();
  String _currency = 'NGN';
  bool _currencyTouched = false;
  bool _loadingExisting = false;
  bool _submitting = false;
  String? _loadError;
  bool _initialized = false;

  bool get isEdit => widget.accountId != null;

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    if (isEdit == false || _initialized) return;
    setState(() {
      _loadingExisting = true;
      _loadError = null;
    });
    try {
      final acc = await ref
          .read(accountRepositoryProvider)
          .getById(widget.accountId!);
      if (acc == null) throw const NotFoundFailure('Account not found');
      _name.text = acc.name;
      _desc.text = acc.description ?? '';
      _currency = acc.currencyCode;
    } catch (e) {
      _loadError = e is Failure ? e.message : e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _loadingExisting = false;
          _initialized = true;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting) return; // avoid double taps
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      if (isEdit) {
        await ref
            .read(accountRepositoryProvider)
            .updateMetadata(
              id: widget.accountId!,
              name: _name.text,
              description: _desc.text,
            );
      } else {
        final opening = parseOpeningBalance(_opening.text, _currency);
        await ref
            .read(accountRepositoryProvider)
            .createAccount(
              name: _name.text,
              currencyCode: _currency,
              openingBalanceMinor: opening,
              description: _desc.text.isEmpty ? null : _desc.text,
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
    if (isEdit && !_initialized && !_loadingExisting) {
      // Defer to post-frame to access ref safely.
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
    }
    // New accounts default to the stored currency until the user picks one.
    if (!isEdit && !_currencyTouched) {
      final preset = ref.watch(defaultCurrencyProvider).value;
      if (preset != null &&
          preset != _currency &&
          kCurrencies.containsKey(preset)) {
        _currency = preset;
      }
    }
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit account' : 'New account')),
      body: _loadingExisting
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: SaldoSkeletonList(count: 3, itemHeight: 72),
            )
          : _loadError != null
          ? SaldoErrorState(message: _loadError!)
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Account name',
                      hintText: 'e.g. Cash, Bank',
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Account name is required';
                      }
                      if (v.trim().length > 100) return 'Too long (max 100)';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  if (!isEdit) ...[
                    DropdownButtonFormField<String>(
                      initialValue: kCurrencies.containsKey(_currency)
                          ? _currency
                          : null,
                      decoration: const InputDecoration(labelText: 'Currency'),
                      items: kCurrencies.keys
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text('$c (${kCurrencies[c]!.symbol})'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() {
                        _currency = v ?? 'NGN';
                        _currencyTouched = true;
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _opening,
                      decoration: InputDecoration(
                        labelText: 'Opening balance ($_currency)',
                        hintText: '0.00 (use - prefix if owed)',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      validator: (v) {
                        try {
                          parseOpeningBalance(v ?? '', _currency);
                        } on FormatException catch (e) {
                          return e.message;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Currency & opening balance are locked',
                      ),
                      subtitle: Text(
                        'Currency cannot change once set; opening balance stays fixed for audit. Current: $_currency',
                      ),
                    ),
                  ],
                  TextFormField(
                    controller: _desc,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
      bottomNavigationBar: SaldoSubmitBar(
        label: isEdit ? 'Save changes' : 'Create account',
        busy: _submitting,
        onPressed: _submit,
      ),
    );
  }
}
