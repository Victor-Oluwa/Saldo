import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/router.dart';
import 'features/settings/data/preferences_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fresh installs open the onboarding flow; anything else (returning
  // users, prefs failures) keeps the classic `/` start. Tests pump
  // SaldoApp directly and never touch this gate.
  try {
    final prefs = await SharedPreferences.getInstance();
    OnboardingGate.showOnboarding =
        !(prefs.getBool(
              SharedPrefsPreferencesRepository.keyOnboardingCompleted,
            ) ??
            false);
  } catch (_) {
    OnboardingGate.showOnboarding = false;
  }
  runApp(const ProviderScope(child: SaldoApp()));
}
