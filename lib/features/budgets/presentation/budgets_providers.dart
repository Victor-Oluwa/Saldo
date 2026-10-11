import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saldo/core/database/providers.dart';
import 'package:saldo/features/accounts/presentation/accounts_providers.dart';
import 'package:saldo/features/budgets/domain/budget.dart';
import 'package:saldo/features/categories/presentation/categories_providers.dart';

/// Month navigator state, normalized to month start 00:00 local.
class BudgetMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  void setMonth(DateTime monthStart) {
    state = DateTime(monthStart.year, monthStart.month, 1);
  }

  void shift(int delta) {
    var m = state.month + delta;
    var y = state.year;
    while (m < 1) {
      m += 12;
      y -= 1;
    }
    while (m > 12) {
      m -= 12;
      y += 1;
    }
    state = DateTime(y, m, 1);
  }

  void today() {
    final now = DateTime.now();
    state = DateTime(now.year, now.month, 1);
  }
}

final budgetMonthProvider = NotifierProvider<BudgetMonthNotifier, DateTime>(
  BudgetMonthNotifier.new,
);

/// Budgets for [monthStart] (normalized). Reactive to writes.
final budgetsForMonthProvider = StreamProvider.autoDispose
    .family<List<Budget>, DateTime>((ref, monthStart) {
      ref.watch(seedProvider);
      ref.watch(transactionsVersionProvider);
      final normalized = Budget.normalizeMonthStart(monthStart);
      return ref.watch(budgetRepositoryProvider).watchForMonth(normalized);
    });

final budgetUsageProvider = FutureProvider.autoDispose
    .family<BudgetUsage, String>((ref, budgetId) async {
      ref.watch(transactionsVersionProvider);
      return ref.watch(budgetRepositoryProvider).getUsage(budgetId);
    });

/// One row for list/highlight cards: budget + fresh usage + category name.
class BudgetCardData {
  const BudgetCardData({
    required this.budget,
    required this.usage,
    required this.categoryName,
  });

  final Budget budget;
  final BudgetUsage usage;
  final String categoryName;
}

/// Budgets + usages + names for a month. Usage is computed per budget with
/// the same query the detail page uses, so list and detail never disagree.
final budgetsWithUsageProvider = FutureProvider.autoDispose
    .family<List<BudgetCardData>, DateTime>((ref, monthStart) async {
      final normalized = Budget.normalizeMonthStart(monthStart);
      final repo = ref.watch(budgetRepositoryProvider);
      ref.watch(transactionsVersionProvider);
      final budgets = await repo.getForMonth(normalized);
      final catMap = await ref.watch(categoryMapProvider.future);
      final out = <BudgetCardData>[];
      for (final b in budgets) {
        if (b.isArchived) continue;
        out.add(
          BudgetCardData(
            budget: b,
            usage: await repo.getUsage(b.id),
            categoryName: catMap[b.categoryId]?.name ?? 'Category',
          ),
        );
      }
      return out;
    });
