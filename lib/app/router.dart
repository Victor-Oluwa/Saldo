import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'saldo_nav_bar.dart';
import 'package:saldo/features/accounts/presentation/account_detail_page.dart';
import 'package:saldo/features/accounts/presentation/account_form_page.dart';
import 'package:saldo/features/accounts/presentation/accounts_list_page.dart';
import 'package:saldo/features/budgets/presentation/budget_detail_page.dart';
import 'package:saldo/features/budgets/presentation/budget_form_page.dart';
import 'package:saldo/features/budgets/presentation/budgets_page.dart';
import 'package:saldo/features/categories/presentation/categories_page.dart';
import 'package:saldo/features/home/presentation/home_page.dart';
import 'package:saldo/features/onboarding/presentation/onboarding_page.dart';
import 'package:saldo/features/reports/presentation/reports_page.dart';
import 'package:saldo/features/settings/presentation/backup_page.dart';
import 'package:saldo/features/settings/presentation/export_page.dart';
import 'package:saldo/features/settings/presentation/settings_page.dart';
import 'package:saldo/features/transactions/presentation/income_expense_form_page.dart';
import 'package:saldo/features/transactions/presentation/transaction_detail_page.dart';
import 'package:saldo/features/transactions/presentation/transactions_list_page.dart';
import 'package:saldo/features/transactions/presentation/transfer_form_page.dart';

/// Bottom-nav scaffold for the 5 primary destinations.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: SaldoNavBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _goBranch,
          destinations: const [
            SaldoNavDestination(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'Home',
            ),
            SaldoNavDestination(
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long,
              label: 'Transactions',
            ),
            SaldoNavDestination(
              icon: Icons.pie_chart_outline,
              activeIcon: Icons.pie_chart,
              label: 'Budgets',
            ),
            SaldoNavDestination(
              icon: Icons.bar_chart_outlined,
              activeIcon: Icons.bar_chart,
              label: 'Reports',
            ),
            SaldoNavDestination(
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings,
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

/// First-run gate, set once in main() before runApp (prefs read is async,
/// GoRouter redirect is sync). Defaults to completed so widget tests and
/// headless journeys keep landing on `/`.
abstract final class OnboardingGate {
  static bool showOnboarding = false;
}

/// GoRouter — Milestones 3–4 routes (accounts, transactions, budgets).
/// Reports detail/settings land in Milestones 4–5.
final goRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    if (OnboardingGate.showOnboarding && state.matchedLocation == '/') {
      return '/onboarding';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingPage(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/', builder: (context, state) => const HomePage()),
            GoRoute(
              path: '/accounts',
              builder: (context, state) => const AccountsListPage(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const AccountFormPage(),
                ),
                GoRoute(
                  path: ':id',
                  builder: (context, state) =>
                      AccountDetailPage(accountId: state.pathParameters['id']!),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (context, state) => AccountFormPage(
                        accountId: state.pathParameters['id']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/transactions',
              builder: (context, state) => const TransactionsListPage(),
              routes: [
                GoRoute(
                  path: 'income/new',
                  builder: (context, state) =>
                      const IncomeExpenseFormPage(isIncome: true),
                ),
                GoRoute(
                  path: 'expense/new',
                  builder: (context, state) =>
                      const IncomeExpenseFormPage(isIncome: false),
                ),
                GoRoute(
                  path: 'transfer/new',
                  builder: (context, state) => const TransferFormPage(),
                ),
                GoRoute(
                  path: 'transfer/:groupId/edit',
                  builder: (context, state) => TransferFormPage(
                    groupId: state.pathParameters['groupId'],
                  ),
                ),
                GoRoute(
                  path: ':id',
                  builder: (context, state) => TransactionDetailPage(
                    transactionId: state.pathParameters['id']!,
                  ),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (context, state) {
                        final id = state.pathParameters['id']!;
                        // Type decides the form — resolve via query param.
                        final isIncome =
                            state.uri.queryParameters['type'] == 'income';
                        return IncomeExpenseFormPage(
                          isIncome: isIncome,
                          transactionId: id,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: '/categories',
              builder: (context, state) => const CategoriesPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/budgets',
              builder: (context, state) => const BudgetsPage(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const BudgetFormPage(),
                ),
                GoRoute(
                  path: ':id',
                  builder: (context, state) =>
                      BudgetDetailPage(budgetId: state.pathParameters['id']!),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (context, state) =>
                          BudgetFormPage(budgetId: state.pathParameters['id']!),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/reports',
              builder: (context, state) => const ReportsPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsPage(),
              routes: [
                GoRoute(
                  path: 'export',
                  builder: (context, state) => const ExportPage(),
                ),
                GoRoute(
                  path: 'backup',
                  builder: (context, state) => const BackupPage(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
