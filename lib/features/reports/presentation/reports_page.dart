import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saldo/app/theme/colors.dart';
import 'package:saldo/app/theme/motion.dart';
import 'package:saldo/core/dates/report_period.dart';
import 'package:saldo/core/finance/saldo_math.dart';
import 'package:saldo/core/money/money.dart';
import 'package:saldo/core/widgets/saldo_states.dart';
import 'package:saldo/core/widgets/money_text.dart';
import 'package:saldo/core/widgets/period_selector.dart';
import 'package:saldo/core/widgets/skeleton.dart';
import 'package:saldo/features/transactions/domain/transaction.dart';
import 'package:saldo/features/transactions/presentation/transactions_providers.dart';

import 'reports_providers.dart';

/// Period reports: totals, category breakdown, cash-flow trend.
/// Every figure derives from the same transaction query path as history —
/// transfers never count as income or expenses. Tapping a category drills
/// down to its transactions.
class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selection = ref.watch(reportPeriodProvider);
    final notifier = ref.read(reportPeriodProvider.notifier);
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(selection.label(now), style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          PeriodSelector(
            selection: selection,
            now: now,
            onPreset: notifier.setPreset,
            onCustom: () => _pickCustom(context, ref, selection),
          ),
          if (selection.preset == PeriodPreset.custom) ...[
            const SizedBox(height: 12),
            _CustomRangeTiles(selection: selection),
          ],
          const SizedBox(height: 28),
          const _SummarySection(),
          const SizedBox(height: 28),
          const _BreakdownSection(),
          const SizedBox(height: 28),
          const _TrendSection(),
        ],
      ),
    );
  }

  Future<void> _pickCustom(
    BuildContext context,
    WidgetRef ref,
    SelectedPeriod current,
  ) async {
    final now = DateTime.now();
    final initialStart =
        current.customStart ?? DateTime(now.year, now.month, 1);
    final start = await showDatePicker(
      context: context,
      initialDate: initialStart,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Custom range start',
    );
    if (start == null || !context.mounted) return;
    final initialEnd =
        current.customEndExclusive?.subtract(const Duration(days: 1)) ?? now;
    final end = await showDatePicker(
      context: context,
      initialDate: initialEnd.isBefore(start) ? start : initialEnd,
      firstDate: start,
      lastDate: DateTime(2100),
      helpText: 'Custom range end',
    );
    if (end == null) return;
    final startDay = DateTime(start.year, start.month, start.day);
    final endExclusive = DateTime(
      end.year,
      end.month,
      end.day,
    ).add(const Duration(days: 1));
    ref.read(reportPeriodProvider.notifier).setCustom(startDay, endExclusive);
  }
}

class _CustomRangeTiles extends StatelessWidget {
  const _CustomRangeTiles({required this.selection});

  final SelectedPeriod selection;

  @override
  Widget build(BuildContext context) {
    String fmt(DateTime? d) => d == null
        ? '—'
        : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          'From ${fmt(selection.customStart)} to '
          '${fmt(selection.customEndExclusive?.subtract(const Duration(days: 1)))} (inclusive)',
        ),
      ),
    );
  }
}

class _SummarySection extends ConsumerWidget {
  const _SummarySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final totals = ref.watch(reportTotalsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Summary', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        totals.when(
          loading: () => const SaldoSkeleton.card(),
          error: (e, _) => SaldoErrorState(message: e.toString()),
          data: (t) {
            final currencies = {
              ...t.incomeByCurrency.keys,
              ...t.expenseByCurrency.keys,
            }.toList()..sort();
            if (currencies.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No income or expenses in this period.'),
                ),
              );
            }
            return Column(
              children: [
                for (final code in currencies)
                  _SummaryCard(
                    code: code,
                    income: t.incomeByCurrency[code] ?? 0,
                    expense: t.expenseByCurrency[code] ?? 0,
                    net: t.netByCurrency[code] ?? 0,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.code,
    required this.income,
    required this.expense,
    required this.net,
  });

  final String code;
  final int income;
  final int expense;
  final int net;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rate = savingsRate(incomeMinor: income, expenseMinor: expense);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _SummaryRow(
              label: 'Income',
              child: AnimatedMoneyText(
                minorUnits: income,
                currencyCode: code,
                type: TransactionType.income,
              ),
            ),
            _SummaryRow(
              label: 'Expenses',
              child: AnimatedMoneyText(
                minorUnits: expense,
                currencyCode: code,
                type: TransactionType.expense,
              ),
            ),
            const Divider(),
            _SummaryRow(
              label: 'Net cash flow',
              child: AnimatedMoneyText(
                minorUnits: net.abs(),
                currencyCode: code,
                type: net < 0
                    ? TransactionType.expense
                    : TransactionType.income,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                rate == null
                    ? 'Cash-flow rate — (no income recorded)'
                    : 'Cash-flow rate ${(rate * 100).toStringAsFixed(1)}% of income kept',
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(child: child),
        ],
      ),
    );
  }
}

class _BreakdownSection extends ConsumerWidget {
  const _BreakdownSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final slices = ref.watch(expenseByCategoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Spending by category',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge,
              ),
            ),
            TextButton(
              onPressed: () => _viewAllInPeriod(context, ref),
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        slices.when(
          loading: () => const SaldoSkeletonList(count: 2, itemHeight: 76),
          error: (e, _) => SaldoErrorState(message: e.toString()),
          data: (list) {
            if (list.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No spending in this period.'),
                ),
              );
            }
            // One donut + rows per currency; MVP never converts between them.
            final byCurrency = <String, List<CategorySlice>>{};
            for (final s in list) {
              byCurrency.putIfAbsent(s.currencyCode, () => []).add(s);
            }
            // Share bars are relative to their own currency's total —
            // unlike currencies are never compared to each other.
            final totalsByCurrency = <String, int>{
              for (final e in byCurrency.entries)
                e.key: e.value.fold(0, (a, s) => a + s.totalMinor),
            };
            final codes = byCurrency.keys.toList()..sort();
            return Column(
              children: [
                for (final code in codes) ...[
                  _DonutCard(
                    currencyCode: code,
                    slices: byCurrency[code]!,
                    onSelect: (s) => _drillDown(context, ref, s),
                  ),
                  const SizedBox(height: 8),
                  for (final s in byCurrency[code]!)
                    _SliceRow(
                      slice: s,
                      fraction: totalsByCurrency[code]! <= 0
                          ? 0.0
                          : s.totalMinor / totalsByCurrency[code]!,
                      onTap: () => _drillDown(context, ref, s),
                    ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  void _drillDown(BuildContext context, WidgetRef ref, CategorySlice s) {
    final selection = ref.read(reportPeriodProvider);
    final range = queryRangeFor(selection, DateTime.now());
    applyCategoryDrillDown(
      ref.read(txFilterProvider.notifier),
      categoryId: s.categoryId,
      range: range,
    );
    context.go('/transactions');
  }

  void _viewAllInPeriod(BuildContext context, WidgetRef ref) {
    final selection = ref.read(reportPeriodProvider);
    final range = queryRangeFor(selection, DateTime.now());
    applyPeriodDrillDown(ref.read(txFilterProvider.notifier), range: range);
    context.go('/transactions');
  }
}

/// Donut of expense shares for one currency. Purely visual — names and
/// amounts live in the rows below (and in semantics), so text finders and
/// screen readers get exact figures while the chart stays clean.
/// Tapping a slice drills down to its transactions.
class _DonutCard extends StatefulWidget {
  const _DonutCard({
    required this.currencyCode,
    required this.slices,
    required this.onSelect,
  });

  final String currencyCode;
  final List<CategorySlice> slices;
  final ValueChanged<CategorySlice> onSelect;

  @override
  State<_DonutCard> createState() => _DonutCardState();
}

class _DonutCardState extends State<_DonutCard> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduced = SaldoMotion.resolve(context).isReduced;
    final total = widget.slices.fold(0, (a, s) => a + s.totalMinor);
    final topShare = total <= 0
        ? 0
        : (widget.slices.first.totalMinor / total * 100).round();
    final semantics =
        'Spending breakdown in ${widget.currencyCode}, '
        '${widget.slices.length} categories, '
        'total ${formatMinorUnits(total, widget.currencyCode)}. '
        '${[for (final s in widget.slices) '${s.categoryName} ${formatMinorUnits(s.totalMinor, s.currencyCode)}'].join(', ')}. Tap a slice to view its transactions.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Semantics(
              label: semantics,
              child: ExcludeSemantics(
                child: SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          startDegreeOffset: -90,
                          pieTouchData: PieTouchData(
                            touchCallback: (event, response) {
                              final index =
                                  response?.touchedSection?.touchedSectionIndex;
                              if (index == null ||
                                  index < 0 ||
                                  index >= widget.slices.length) {
                                if (_touched != -1) {
                                  setState(() => _touched = -1);
                                }
                                return;
                              }
                              if (_touched != index) {
                                setState(() => _touched = index);
                              }
                              if (event is FlTapUpEvent) {
                                widget.onSelect(widget.slices[index]);
                              }
                            },
                          ),
                          sections: [
                            for (var i = 0; i < widget.slices.length; i++)
                              PieChartSectionData(
                                value: widget.slices[i].totalMinor.toDouble(),
                                color: _sliceColor(i),
                                radius: i == _touched ? 30 : 24,
                                title: '',
                              ),
                          ],
                        ),
                        duration: reduced
                            ? Duration.zero
                            : const Duration(milliseconds: 350),
                        curve: SaldoCurves.standard,
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${widget.slices.length}',
                              style: theme.textTheme.headlineSmall,
                            ),
                            Text(
                              widget.slices.length == 1
                                  ? 'category'
                                  : 'categories',
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.currencyCode, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Largest share $topShare%',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap a slice to view',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Distinct slice colors from the calm palette — six muted hues so
/// category shares stay separable, lightening on repeat cycles so small
/// slices never collide with new hues.
Color _sliceColor(int index) {
  const bases = [
    SaldoColors.primary, // emerald
    SaldoColors.expense, // coral
    Color(0xFF7FA8C9), // muted ice blue
    Color(0xFFD9B06D), // soft amber
    Color(0xFFA78BBF), // muted violet
    SaldoColors.textSecondary, // sage
  ];
  final base = bases[index % bases.length];
  final cycle = index ~/ bases.length;
  if (cycle == 0) return base;
  final hsl = HSLColor.fromColor(base);
  return hsl
      .withLightness((hsl.lightness + 0.12 * cycle).clamp(0.0, 0.9))
      .toColor();
}

class _SliceRow extends StatelessWidget {
  const _SliceRow({
    required this.slice,
    required this.fraction,
    required this.onTap,
  });

  final CategorySlice slice;
  final double fraction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label =
        '${slice.categoryName}: ${formatMinorUnits(slice.totalMinor, slice.currencyCode)} '
        'across ${slice.count} ${slice.count == 1 ? 'transaction' : 'transactions'}. Tap to view.';
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Semantics(
          button: true,
          label: label,
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          slice.categoryName,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          formatMinorUnits(
                            slice.totalMinor,
                            slice.currencyCode,
                          ),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${slice.count} ${slice.count == 1 ? 'transaction' : 'transactions'} · tap to view',
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fraction.clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: SaldoColors.elevated,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        SaldoColors.expense,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendSection extends ConsumerWidget {
  const _TrendSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final trend = ref.watch(spendingTrendProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cash-flow trend', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        trend.when(
          loading: () => const SaldoSkeleton.card(height: 220),
          error: (e, _) => SaldoErrorState(message: e.toString()),
          data: (t) {
            if (t.points.isEmpty || t.currencyCode == null) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nothing to chart yet in this period.'),
                ),
              );
            }
            return _TrendChart(points: t.points, currencyCode: t.currencyCode!);
          },
        ),
      ],
    );
  }
}

/// Grouped income/expense bars via fl_chart. Tapping a group shows exact
/// figures in a tooltip; amounts stay readable as text in the summary too.
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points, required this.currencyCode});

  final List<TrendPoint> points;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduced = SaldoMotion.resolve(context).isReduced;
    var max = 0;
    for (final p in points) {
      if (p.incomeMinor > max) max = p.incomeMinor;
      if (p.expenseMinor > max) max = p.expenseMinor;
    }
    if (max <= 0) max = 1;
    final label =
        'Cash-flow trend in $currencyCode, ${points.length} buckets. '
        'Tallest bar ${formatMinorUnits(max, currencyCode)}.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _LegendDot(color: SaldoColors.primary, label: 'Income'),
                const SizedBox(width: 16),
                _LegendDot(color: SaldoColors.expense, label: 'Expenses'),
                const Spacer(),
                Text(currencyCode, style: theme.textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 12),
            Semantics(
              label: label,
              child: ExcludeSemantics(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: (points.length * 30).clamp(280, 900).toDouble(),
                    height: 190,
                    child: BarChart(
                      BarChartData(
                        minY: 0,
                        maxY: max * 1.15,
                        alignment: BarChartAlignment.spaceAround,
                        groupsSpace: 10,
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (value, _) {
                                final i = value.toInt();
                                if (i < 0 || i >= points.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    points[i].label,
                                    style: theme.textTheme.labelSmall,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            tooltipPadding: const EdgeInsets.all(8),
                            getTooltipItem: (group, _, rod, rodIndex) {
                              final p = points[group.x];
                              final minor = rodIndex == 0
                                  ? p.incomeMinor
                                  : p.expenseMinor;
                              return BarTooltipItem(
                                '${rodIndex == 0 ? 'Income' : 'Expenses'}\n'
                                '${formatMinorUnits(minor, currencyCode)}',
                                theme.textTheme.labelMedium!,
                              );
                            },
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < points.length; i++)
                            BarChartGroupData(
                              x: i,
                              barsSpace: 3,
                              barRods: [
                                BarChartRodData(
                                  toY: points[i].incomeMinor.toDouble(),
                                  color: SaldoColors.primary,
                                  width: 8,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(3),
                                  ),
                                ),
                                BarChartRodData(
                                  toY: points[i].expenseMinor.toDouble(),
                                  color: SaldoColors.expense,
                                  width: 8,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(3),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      duration: reduced
                          ? Duration.zero
                          : const Duration(milliseconds: 350),
                      curve: SaldoCurves.standard,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
