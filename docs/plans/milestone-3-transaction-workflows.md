# Milestone 3 — Core Transaction Workflows (Saldo)

**Status:** Implemented + verified
**Date:** 2026-10-10
**Source:** `AGENTS.md` §15 Milestone 3 (FR-02, FR-04..FR-07)

## What was built

Riverpod (AsyncNotifier/`NotifierProvider`) presentation over the Milestone 2
repositories — no `flutter_bloc` added, keeping one consistent state/DI story.

### Shared
- `lib/core/widgets/`: `saldo_states.dart` (empty/error), `confirm_dialog.dart`
  (destructive confirm with balance/report effect note), `money_text.dart`
  (`MoneyText` emerald +/coral −/neutral transfer with text label, never color
  alone; `BalanceText` tabular).
- `lib/core/dates/format.dart`: Today/Yesterday/full labels.
- `test/widget/saldo_test_utils.dart`: in-memory `SaldoHarness`, bounded
  `settle()` (timed pumps — `pumpAndSettle` never returns while loading
  spinners animate), close-safe `dispose()`.

### Accounts (FR-02)
- `accounts_list_page.dart`: list with per-account derived balances, empty
  state, FAB.
- `account_form_page.dart`: create (name/currency/opening — zero + `-`
  allowed via `parseOpeningBalance`/desc) / edit metadata only (currency +
  opening locked with explanation). Inline validation, no double-submit,
  success only after commit.
- `account_detail_page.dart`: big balance, currency/archived chips, opening,
  history, edit/archive-unarchive/delete (delete blocked when referenced —
  archive suggested).

### Transactions (FR-04/05/07)
- `transactions_list_page.dart`: reverse-chronological stable-sorted history,
  `SearchBar` (description/notes), filter panel (type segmented, account,
  category, All-time/This-month/Last-month), clear-filters empty state,
  explicit Income/Expense/Transfer bottom sheet.
- `income_expense_form_page.dart`: amount (numeric keypad, minor-units parse),
  account (active-only for new), category by type (active for new, incl.
  archived when editing history), date picker, desc/notes. Input preserved on
  `Failure`; no pop until commit.
- `transaction_detail_page.dart`: amount/type/date/account (link)/
  category-or-both-transfer-legs/desc/notes; edit routes with
  `?type=income|expense`; delete with confirmation.

### Transfers (FR-06)
- `transfer_form_page.dart`: from/to/note pickers, same-currency +
  different-accounts enforced with messages; edit limited to
  amount/date/desc/notes on BOTH legs atomically (accounts immutable).
- `categories_page.dart`: list per type + create/rename/archive/delete with
  reference guards (needed for compatible assignment).

### Home + routing
- `home_page.dart`: first-run welcome → totals by currency, top accounts,
  recent 5, add/see-all.
- `router.dart`: `/accounts…`, `/transactions…` (income/expense/transfer
  new, `:id`, `:id/edit?type=`, `transfer/:groupId/edit`), `/categories`
  under shell branches.

## Verified (actually run)
- `flutter analyze --no-fatal-infos --no-fatal-warnings` — No issues found
- `flutter test` — **53/53 passed** (46 prior + 7 widget):
  empty-state display, form validation rejects empty name/malformed amount
  with zero rows written (no phantom success), search narrows + type filter
  combines, transfer requires both accounts, delete asks confirmation first.
- Repository-level invariants from Milestone 2 still green (transfer
  equal/opposite, totals untouched, atomicity, archive semantics).

## Notable issues fixed
- **Widget-test hang**: bare `db.close()` with open Drift watch streams
  awaits stream-shutdown timers that never fire in fake-async → infinite
  hang (plus an orphaned runner burning CPU). Fixed with pump-interleaved
  close in `SaldoHarness.dispose` + bounded `settle()`.
- **Seed collision**: helper categories renamed (`SeedSalary`/`SeedFood`)
  to avoid UNIQUE clash with auto-seeded defaults.
- Riverpod 3.4 API: `AsyncValue.value` (not `valueOrNull`), `NotifierProvider`
  counters, `initialValue` on dropdowns, `@ReferenceName` kept from M2.

## Next (Milestone 4)
Reactive dashboard (period selector, income/expense/net, budget highlights,
charts) + monthly budget UI on these repositories.
