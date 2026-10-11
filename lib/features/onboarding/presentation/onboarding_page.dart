import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saldo/app/router.dart';
import 'package:saldo/app/theme/colors.dart';
import 'package:saldo/app/theme/motion.dart';
import 'package:saldo/core/money/currency.dart';
import 'package:saldo/core/widgets/saldo_states.dart';
import 'package:saldo/features/settings/presentation/settings_providers.dart';

/// First-run flow: welcome → currency → first account. Shown once per
/// install (see [OnboardingGate]); returning users never see it.
/// Completing or skipping marks prefs so `/` stays the start thereafter.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _pages = PageController();
  int _index = 0;
  String _currency = 'NGN';
  bool _busy = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    final reduced = SaldoMotion.resolve(context).isReduced;
    setState(() => _index = page);
    if (reduced) {
      _pages.jumpToPage(page);
    } else {
      _pages.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: SaldoCurves.standard,
      );
    }
  }

  Future<void> _saveCurrency() async {
    try {
      final repo = await ref.read(preferencesRepositoryProvider.future);
      await repo.setDefaultCurrencyCode(_currency);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save currency')),
        );
      }
    }
  }

  Future<void> _finish(String location) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repo = await ref.read(preferencesRepositoryProvider.future);
      await repo.completeOnboarding();
    } catch (_) {
      // Flag write failed — still let the user through; Home's first-run
      // screen covers account creation.
    }
    OnboardingGate.showOnboarding = false;
    if (!mounted) return;
    // No router in widget tests (page pumps standalone) — flag + prefs
    // are the contract; navigation only where a router exists.
    if (GoRouter.maybeOf(context) != null) context.go(location);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _busy ? null : () => _finish('/'),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  _WelcomePage(onNext: () => _goTo(1)),
                  _CurrencyPage(
                    selected: _currency,
                    onSelect: (c) => setState(() => _currency = c),
                    onNext: () async {
                      await _saveCurrency();
                      if (mounted) _goTo(2);
                    },
                  ),
                  _AccountPage(
                    busy: _busy,
                    onCreate: () => _finish('/accounts/new'),
                    onExplore: () => _finish('/'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index
                            ? SaldoColors.primary
                            : SaldoColors.elevated,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
            // Screen-reader progress; dots are decorative.
            Semantics(
              label: 'Step ${_index + 1} of 3: ${_titles[_index]}',
              child: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

const _titles = ['Welcome', 'Currency', 'First account'];

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SaldoMotif(accent: Colors.transparent),
          const SizedBox(height: 24),
          Text('Welcome to Saldo', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
            'Private, offline money tracking. No accounts, no cloud — '
            'your saldo lives on this device alone.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onNext, child: const Text('Next')),
        ],
      ),
    );
  }
}

class _CurrencyPage extends StatelessWidget {
  const _CurrencyPage({
    required this.selected,
    required this.onSelect,
    required this.onNext,
  });

  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Choose your currency', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
            'New accounts use this. You can change it until your first '
            'account exists — existing records are never re-denominated.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final entry in kCurrencies.entries)
                ChoiceChip(
                  label: Text('${entry.key} (${entry.value.symbol})'),
                  selected: selected == entry.key,
                  onSelected: (_) => onSelect(entry.key),
                ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onNext, child: const Text('Next')),
        ],
      ),
    );
  }
}

class _AccountPage extends StatelessWidget {
  const _AccountPage({
    required this.busy,
    required this.onCreate,
    required this.onExplore,
  });

  final bool busy;
  final VoidCallback onCreate;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Create your first account',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Cash, bank, savings — each keeps its own balance, computed '
            'from your records.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: busy ? null : onCreate,
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create account'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: busy ? null : onExplore,
            child: const Text('Explore first'),
          ),
        ],
      ),
    );
  }
}
