import 'package:saldo/core/errors/failures.dart';

/// Minimal preferences. Only the default currency affects financial
/// interpretation (new accounts, budget currency default); appearance is
/// dark-only per the design appendix, so no theme toggle is stored.
abstract class PreferencesRepository {
  Future<String> defaultCurrencyCode();
  Future<void> setDefaultCurrencyCode(String code);

  /// First-run flow completion. False on fresh installs; never blocks
  /// returning users. Not part of backups — restoring data never
  /// re-triggers onboarding by itself.
  Future<bool> onboardingCompleted();
  Future<void> completeOnboarding();

  static String normalizeCurrency(String code) {
    final upper = code.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(upper)) {
      throw const ValidationFailure(
        'Currency code must be 3 letters (ISO 4217)',
      );
    }
    return upper;
  }
}
