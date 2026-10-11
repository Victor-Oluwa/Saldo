import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme/app_theme.dart';

/// Riverpod-aware app entry — single dark theme, GoRouter.
class SaldoApp extends ConsumerWidget {
  const SaldoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Saldo',
      theme: SaldoTheme.dark(),
      darkTheme: SaldoTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: goRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
