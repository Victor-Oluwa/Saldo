import 'package:flutter/material.dart';
import 'package:saldo/app/theme/colors.dart';
import 'package:saldo/core/money/money.dart';
import 'package:saldo/features/budgets/presentation/budgets_providers.dart';

/// One budget usage row: quiet bar, category, spent/limit, remaining.
/// Text always carries the state — color never works alone.
class BudgetUsageRow extends StatelessWidget {
  const BudgetUsageRow({super.key, required this.data, this.onTap});

  final BudgetCardData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usage = data.usage;
    final limit = data.budget.limitMinor;
    final progress = limit <= 0
        ? 0.0
        : (usage.spentMinor / limit).clamp(0.0, 1.0);
    final remaining = usage.remainingMinor;
    final remainingLabel = remaining < 0
        ? 'Overspent ${formatMinorUnits(-remaining, data.budget.currencyCode)}'
        : '${formatMinorUnits(remaining, data.budget.currencyCode)} left';
    final stateColor = usage.isOverspent
        ? SaldoColors.expense
        : SaldoColors.primary;
    final semanticsLabel =
        '${data.categoryName}: spent '
        '${formatMinorUnits(usage.spentMinor, data.budget.currencyCode)} '
        'of ${formatMinorUnits(limit, data.budget.currencyCode)}. '
        '$remainingLabel.';
    return Container(
      decoration: const BoxDecoration(
        color: SaldoColors.surface,
        border: Border(
          bottom: BorderSide(color: SaldoColors.border, width: 1),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Semantics(
            label: semanticsLabel,
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          data.categoryName,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          '${formatMinorUnits(usage.spentMinor, data.budget.currencyCode)} '
                          'of ${formatMinorUnits(limit, data.budget.currencyCode)}',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    remainingLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: remaining < 0
                          ? SaldoColors.expense
                          : SaldoColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: SaldoColors.elevated,
                      valueColor: AlwaysStoppedAnimation<Color>(stateColor),
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
