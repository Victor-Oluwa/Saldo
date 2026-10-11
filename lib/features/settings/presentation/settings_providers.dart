import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saldo/core/database/providers.dart';
import 'package:saldo/features/settings/data/preferences_repository.dart';
import 'package:saldo/features/settings/domain/preferences_repository.dart';

final preferencesRepositoryProvider = FutureProvider<PreferencesRepository>((
  ref,
) async {
  final prefs = await SharedPreferences.getInstance();
  return SharedPrefsPreferencesRepository(prefs);
});

/// Default currency for new accounts/budgets. Falls back to NGN when
/// preferences are unavailable (e.g. widget tests without platform
/// channels) — never crashes the UI.
final defaultCurrencyProvider = FutureProvider<String>((ref) async {
  try {
    final repo = await ref.watch(preferencesRepositoryProvider.future);
    return repo.defaultCurrencyCode();
  } catch (_) {
    return SharedPrefsPreferencesRepository.fallbackCurrency;
  }
});

/// True once any account exists (archived included). Currency is locked
/// from then on: existing records must never be silently re-denominated.
final hasAccountsProvider = FutureProvider<bool>((ref) async {
  final accounts = await ref
      .watch(accountRepositoryProvider)
      .getAll(includeArchived: true);
  return accounts.isNotEmpty;
});
