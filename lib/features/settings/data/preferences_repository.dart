import 'package:shared_preferences/shared_preferences.dart';
import 'package:saldo/core/errors/failures.dart';

import '../domain/preferences_repository.dart';

/// Device-persisted preferences. Financial records are never stored here —
/// only the default currency code. Safe to back up as plain JSON.
class SharedPrefsPreferencesRepository implements PreferencesRepository {
  SharedPrefsPreferencesRepository(this._prefs);

  final SharedPreferences _prefs;

  static const keyDefaultCurrency = 'defaultCurrencyCode';
  static const keyOnboardingCompleted = 'onboardingCompleted';
  static const fallbackCurrency = 'NGN';

  @override
  Future<String> defaultCurrencyCode() async {
    final raw = _prefs.getString(keyDefaultCurrency);
    if (raw == null) return fallbackCurrency;
    try {
      return PreferencesRepository.normalizeCurrency(raw);
    } on Object {
      return fallbackCurrency;
    }
  }

  @override
  Future<void> setDefaultCurrencyCode(String code) async {
    final normalized = PreferencesRepository.normalizeCurrency(code);
    final ok = await _prefs.setString(keyDefaultCurrency, normalized);
    if (!ok) throw const DatabaseFailure('Could not save preferences');
  }

  @override
  Future<bool> onboardingCompleted() async =>
      _prefs.getBool(keyOnboardingCompleted) ?? false;

  @override
  Future<void> completeOnboarding() async {
    final ok = await _prefs.setBool(keyOnboardingCompleted, true);
    if (!ok) throw const DatabaseFailure('Could not save preferences');
  }
}

/// In-memory implementation for widget tests (SharedPreferences needs
/// platform channels, unavailable under flutter_test).
class MemoryPreferencesRepository implements PreferencesRepository {
  MemoryPreferencesRepository({String initialCurrency = 'NGN'})
    : _currency = initialCurrency;

  String _currency;
  bool _onboardingCompleted = false;

  @override
  Future<String> defaultCurrencyCode() async => _currency;

  @override
  Future<void> setDefaultCurrencyCode(String code) async {
    _currency = PreferencesRepository.normalizeCurrency(code);
  }

  @override
  Future<bool> onboardingCompleted() async => _onboardingCompleted;

  @override
  Future<void> completeOnboarding() async {
    _onboardingCompleted = true;
  }
}
