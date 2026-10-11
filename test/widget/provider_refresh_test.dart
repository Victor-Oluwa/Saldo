import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saldo/core/database/providers.dart';
import 'package:saldo/features/accounts/presentation/accounts_providers.dart';
import 'package:saldo/features/settings/presentation/settings_providers.dart';

import 'saldo_test_utils.dart';

/// Replicates the demo-data flow: seed through repos, then refresh.
/// Pinpoints whether post-write refresh works via invalidate vs version bump.
void main() {
  testWidgets(
    'invalidate recomputes hasAccounts after seeding',
    (WidgetTester tester) async {
      final harness = await pumpSaldo(tester, const _LockProbe());
      await settle(tester);
      expect(find.text('locked=false'), findsOneWidget);

      await tester.tap(find.text('seed-invalidate'));
      await settle(tester, 24);

      expect(find.text('locked=true'), findsOneWidget);
      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'version bump recomputes totals after seeding',
    (WidgetTester tester) async {
      final harness = await pumpSaldo(tester, const _TotalsProbe());
      await settle(tester);
      expect(find.text('empty'), findsOneWidget);

      await tester.tap(find.text('seed-bump'));
      await settle(tester, 24);

      expect(find.text('empty'), findsNothing);
      await harness.dispose(tester);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}

class _LockProbe extends ConsumerWidget {
  const _LockProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = ref.watch(hasAccountsProvider);
    return Material(
      child: Column(
        children: [
          locked.when(
            loading: () => const Text('loading'),
            error: (e, _) => Text('error $e'),
            data: (v) => Text('locked=$v'),
          ),
          ElevatedButton(
            onPressed: () async {
              await seedSaldoBasics(ref.read(appDatabaseProvider));
              ref.invalidate(hasAccountsProvider);
            },
            child: const Text('seed-invalidate'),
          ),
        ],
      ),
    );
  }
}

class _TotalsProbe extends ConsumerWidget {
  const _TotalsProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(totalBalancesProvider);
    return Material(
      child: Column(
        children: [
          totals.when(
            loading: () => const Text('loading'),
            error: (e, _) => Text('error $e'),
            data: (m) => Text(m.isEmpty ? 'empty' : 'total!'),
          ),
          ElevatedButton(
            onPressed: () async {
              await seedSaldoBasics(ref.read(appDatabaseProvider));
              ref.read(transactionsVersionProvider.notifier).bump();
            },
            child: const Text('seed-bump'),
          ),
        ],
      ),
    );
  }
}
