import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saldo/app/theme/app_theme.dart';
import 'package:saldo/app/theme/colors.dart';
import 'package:saldo/app/theme/motion.dart';
import 'package:saldo/core/widgets/saldo_line.dart';
import 'package:saldo/core/widgets/saldo_states.dart';
import 'package:saldo/core/widgets/saldo_tile.dart';
import 'package:saldo/core/widgets/money_text.dart';
import 'package:saldo/core/widgets/progress_ring.dart';
import 'package:saldo/core/widgets/section_header.dart';
import 'package:saldo/core/widgets/skeleton.dart';
import 'package:saldo/core/widgets/stagger.dart';
import 'package:saldo/features/transactions/domain/transaction.dart';

Widget _wrap(Widget child, {bool reducedMotion = false}) => SaldoMotion(
  durations: reducedMotion ? MotionDurations.reduced : MotionDurations.full,
  child: MaterialApp(
    theme: SaldoTheme.dark(),
    home: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('empty + error states keep their contract strings', (t) async {
    await t.pumpWidget(
      _wrap(
        const Column(
          children: [
            SaldoEmptyState(title: 'Nothing here', message: 'Why empty'),
            SaldoErrorState(message: 'Boom'),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.text('Why empty'), findsOneWidget);
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Boom'), findsOneWidget);
  });

  testWidgets('animated money settles on the final formatted value', (t) async {
    await t.pumpWidget(
      _wrap(
        const AnimatedMoneyText(
          minorUnits: 2500000,
          currencyCode: 'NGN',
          type: TransactionType.income,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('25,000'), findsOneWidget);
  });

  testWidgets('animated money snaps instantly under reduced motion', (t) async {
    await t.pumpWidget(
      _wrap(
        const AnimatedBalanceText(minorUnits: 2000000, currencyCode: 'NGN'),
        reducedMotion: true,
      ),
    );
    await t.pump();
    expect(find.textContaining('20,000'), findsOneWidget);
  });

  testWidgets('saldo line handles empty, single, and flat series', (t) async {
    for (final series in [
      <double>[],
      [5.0],
      [3.0, 3.0, 3.0],
      [1.0, 4.0, 2.0, 8.0],
    ]) {
      await t.pumpWidget(_wrap(SaldoLine(values: series)));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('ring clamps out-of-range fractions', (t) async {
    await t.pumpWidget(
      _wrap(
        const Column(
          children: [SaldoRing(fraction: -0.5), SaldoRing(fraction: 2.5)],
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('section header shows title + action', (t) async {
    var tapped = false;
    await t.pumpWidget(
      _wrap(
        SectionHeader(
          title: 'Budgets',
          actionLabel: 'See all',
          onAction: () => tapped = true,
        ),
      ),
    );
    expect(find.text('Budgets'), findsOneWidget);
    await t.tap(find.text('See all'));
    expect(tapped, isTrue);
  });

  testWidgets('stagger + skeleton render children without hanging', (t) async {
    await t.pumpWidget(
      _wrap(
        const Column(
          children: [
            StaggerIn(index: 3, child: Text('staggered')),
            SaldoSkeleton.card(),
            SaldoSkeletonList(count: 2),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('staggered'), findsOneWidget);
  });

  testWidgets('saldo tile shows leading, title, meta, trailing + taps', (
    t,
  ) async {
    var tapped = false;
    await t.pumpWidget(
      _wrap(
        SaldoTile(
          leading: const TileIcon(
            icon: Icons.arrow_downward,
            color: SaldoColors.primary,
          ),
          title: const Text('Salary'),
          subtitle: const Text('Job · Bank · Today'),
          trailing: const Text('+ ₦25,000.00'),
          onTap: () => tapped = true,
          semanticLabel: 'Income Salary',
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Job · Bank · Today'), findsOneWidget);
    await t.tap(find.text('Salary'));
    expect(tapped, isTrue);
  });

  testWidgets('account glyph renders initial, tile styles per type', (t) async {
    await t.pumpWidget(
      _wrap(
        const Column(
          children: [
            AccountGlyph(name: 'Bank'),
            AccountGlyph(name: '  '),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
    expect(find.text('?'), findsOneWidget);
    expect(
      tileStyleFor(TransactionType.transfer).color,
      SaldoColors.textSecondary,
    );
  });
}
