# Milestone 2 — Domain and Persistence (Saldo)

**Status:** Implemented + verified
**Date:** 2026-10-09
**Source:** `AGENTS.md` §15 Milestone 2 + §§6–7

## Decisions

- Transfers = two linked `transactions` rows sharing `transfer_group_id`
  (`transfer_side` in/out + `counterpart_account_id`).
  Pair always written/updated/deleted atomically in `db.transaction()`.
- Dates = local wall-clock `DateTime` (no TZ conversion); reports use
  half-open `start <= t < nextStart`. Avoids DST shifts moving date-only
  entries. Documented in `tables.dart`.
- Currency derived from account (`transaction.currencyCode = account.currencyCode`);
  same-currency transfers only; multi-currency totals grouped, never summed.
- Repositories throw typed `Failure` (no fpdart); `updateTransfer` edits
  amount/date/desc/notes only (accounts immutable post-create for MVP).
- Budget uniqueness enforced in repo (active dup blocked); no DB UNIQUE so
  archived history stays intact.
- `@ReferenceName('accountTransactions' / 'counterpartTransactions')`
  resolves Drift's dual-FK-to-Accounts clash.

## Files

```
lib/core/database/tables.dart            # Accounts, Categories, Transactions, Budgets
lib/core/database/app_database.dart      # v2, migration 1→2 via createAll
lib/core/database/providers.dart         # + 4 repository providers
lib/core/finance/saldo_math.dart        # balance/net/budget/savingsRate (pure)
lib/features/accounts/domain+data/
lib/features/categories/domain+data/     # + seedSystemDefaults (4 income, 9 expense)
lib/features/transactions/domain+data/   # + PeriodTotals, TransactionFilter
lib/features/budgets/domain+data/        # + BudgetUsage
test/core/saldo_math_test.dart          # 7 pure-math tests
test/core/database_migration_test.dart   # v2 fresh + idempotent
test/database/accounts_test.dart         # 5 (opening, archive, immutability, delete, multi-FX)
test/database/categories_test.dart       # 5 (type compat, rename, archive, delete, seed)
test/database/transactions_test.dart     # 8 (income/expense/transfer 20k, guards, edit/delete, search)
test/database/budgets_test.dart          # 5 (60k/42k→18k, overspend, exclusions, dup, FX)
test/database/reports_test.dart          # 1 (reconciliation across periods)
```

## Verified

- `dart run build_runner build` — clean (ReferenceName fix, no warnings)
- `flutter analyze --no-fatal-infos` — No issues found
- `flutter test` — 46/46 passed

## Invariants covered

- balance = opening + income + in − expenses − out
- transfer equal/opposite; income/expense/net untouched; total same-FX assets unchanged
- failed atomics leave no partial state; deleting one leg removes both
- category-type compatibility; archived blocked for new, allowed editing history
- budget remaining = limit − spent (negative = overspent); income/transfers + wrong-FX/month excluded
- report totals reconcile with history query; empty periods safe

## Next (Milestone 3)

Account CRUD/archive UI, income/expense create-edit-delete, atomic transfers UI,
history search/filters/details — all backed by these repositories.
