# Milestone 4 — Dashboard and Budgets (Saldo)

**Status:** Implemented + verified
**Date:** 2026-10-10
**Source:** `AGENTS.md` §15 Milestone 4 (FR-08..FR-10)

## What was built

### Period infrastructure
- `lib/core/dates/report_period.dart`: `PeriodPreset`
  (week/month/last-month/year/all-time/custom) + `SelectedPeriod`
  (resolve to half-open `PeriodRange`, `highlightMonth`, labels) +
  `trendBuckets`/`bucketEnd` (daily ≤92d, monthly otherwise) +
  `queryRangeFor` (wide 2000→2100 window for all-time through the same query
  path — no special-casing in repositories).
- `lib/core/widgets/period_selector.dart`: shared preset chips (Home +
  Reports keep independent selections so they never fight).

### Home dashboard (FR-08)
- Rewrote `home_page.dart`: balance card → **Cash flow** section (preset
  chips, per-currency income/expense/net cards, cash-flow-rate line with
  em-dash zero-income handling) → **Budgets** highlights (worst-first top 3
  for the selected month) → accounts → recent.
- `dashboard_providers.dart`: `dashboardPeriodProvider` + `periodTotalsProvider`.
- Every figure re-queries `getPeriodTotals` on period change — the same call
  Reports uses, so the two screens reconcile by construction.

### Budgets UI (FR-09)
- `budgets_providers.dart`: month navigator state, `watchForMonth` stream,
  per-budget usage, `budgetsWithUsageProvider` (list and detail share the
  exact usage query — they cannot disagree).
- `budgets_page.dart`: month navigator (< Month Year >, tap returns to
  today), usage rows, empty state, FAB.
- `budget_usage_row.dart` (shared with Home): spent/limit, remaining or
  coral `Overspent`/`Near limit` chips, progress bar; text always carries
  state, color never alone.
- `budget_form_page.dart`: create (expense category, month grid picker,
  limit, currency, optional 0–100 warning) / edit (limit + warning only —
  category/month/currency fixed). Routes `/budgets/new`, `/budgets/:id`,
  `/budgets/:id/edit`.
- `budget_detail_page.dart`: usage hero + eligible-transactions drill-down
  (same category+month+currency rule as the usage query) + edit/delete.

### Reports UI (FR-10)
- `reports_providers.dart`: independent `reportPeriodProvider`,
  `reportTotalsProvider`, `expenseByCategoryProvider` (grouped by
  category+currency, largest first), `spendingTrendProvider` (returns
  denominating currency + points; primary currency = highest expense —
  never converts; all-time uses trailing 12 months).
- `reports_page.dart`: custom-range pickers, per-currency summary cards
  (income/expenses/net + cash-flow rate), category breakdown with relative
  bars, hand-rolled grouped income/expense trend chart (theme-matched,
  no new dependencies), empty states per section.
- Drill-down split into testable `applyCategoryDrillDown`/
  `applyPeriodDrillDown` (notifier-level, no `BuildContext`) + `context.go`
  at the call site.

## Verified (actually run)
- `flutter analyze --no-fatal-infos --no-fatal-warnings` — No issues found
- `flutter test` — **75/75 passed** (53 prior + 22 new):
  - `report_period_test` (8): preset resolution, half-open bounds,
    Monday-first weeks, all-time null, highlight month, daily/monthly
    buckets, wide-window mapping.
  - `dashboard_test` (4): income/expense/net/rate render, period switch
    updates every figure, overspend highlight, zero-income em dash.
  - `budgets_flow_test` (5): empty state, spent/remaining, overspend,
    empty-limit validation, month navigator.
  - `reports_flow_test` (2 widget + 2 container): summary/breakdown/trend
    reconcile, empty-period zero states, drill-down filter logic.

## Issues fixed (all evidence-backed)
- **Stale futures in tests**: seeding post-pump left `FutureProvider`s
  serving empty data (one test passed only by race luck). Tests now seed
  BEFORE the first frame via `pumpSaldo(..., seed:)` — mirroring the app,
  where forms bump `transactionsVersionProvider` after writes.
- **Lazy-list finder**: trend section below the fold is never built —
  `scrollUntilVisible` before asserting.
- **Duplicate-text finders**: amounts repeat across cards/tiles — scoped
  counts (`findsWidgets`, `widgetWithText`) instead of `findsOneWidget`.
- **Unit expectation**: trailing partial month is a real bucket (13, not 12).
- Riverpod 3: `WidgetRef` ≠ `Ref` — drill-down helpers take the notifier.

## Next (Milestone 5)
Filtered CSV export + versioned backup/restore (serialization, validation,
atomic replace) + round-trip/failure-path tests.
