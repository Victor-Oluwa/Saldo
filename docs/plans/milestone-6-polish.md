# Milestone 6 — Product Polish (Saldo)

**Status:** Implemented + verified
**Date:** 2026-10-10
**Source:** `AGENTS.md` §15 Milestone 6

## What was built

### Demo data
- `lib/core/demo/demo_data.dart` `seedDemoData`: Bank ₦20,000 + Cash
  ₦5,000, freelance income ₦25,000, groceries ₦4,500, transport ₦1,200,
  ₦20,000 Bank→Cash transfer, ₦60,000 groceries budget (80% warning).
  Current-month dated so dashboard, budgets and reports light up at once.
- Gated to empty saldos only (callers check `getAll` empty; Settings tile
  hides once accounts exist) — never merges into real data.
- Settings `_DemoTile`: one-tap load + success snackbar; currency locks
  afterwards like any real account creation.

### Journey tests (`integration_test/` + `test/journeys/`)
- Three full UI flows through the real router + screens + database:
  1. first launch → create account → record income → balance checks out;
  2. record expense → transfer → both balances move, cash flow excludes
     the transfer, account detail agrees;
  3. create budget → record expense → remaining updates.
- `flutter test` refuses anything under `integration_test/` without a
  device, so the flows live in `test/journeys/app_flows.dart`
  (`defineFlows()`) with thin entry points in both locations — identical
  flows run headlessly now and on-device in CI.
- Platform share/file pickers are never tapped headlessly (no channels);
  export/backup UI states + logic stay covered by widget/database tests.

### Accessibility / empty-state audit
- Fixed gap: Home accounts section rendered nothing when only archived
  accounts exist — now explains and offers unarchive/create paths.
- Verified across screens: every async surface has loading/error/empty
  (filter-aware empties on history); semantic labels on amounts (income/
  expense/transfer announced, never color-only), budget rows, breakdown
  slices, trend chart, month navigator, history tiles; 48px touch targets
  (tiles, icon buttons, nav, FABs, chips); theme type scale throughout.
- Dark-only enforced (`ThemeMode.dark`, no toggle) per the design appendix,
  which overrides the PRD's light/dark item — stated in Settings + docs.

## Verified (actually run)
- `dart format lib test integration_test` — clean
- `flutter analyze --no-fatal-infos --no-fatal-warnings` — No issues found
- `flutter test` — **102/102 passed** (95 prior + 7 new: demo consistency,
  demo widget flow, 2 refresh-mechanic probes, 3 journeys).
- NOT run: on-device `integration_test` (no device/emulator in this
  environment) and share/picker sheets (no channels headlessly) — stated
  explicitly, not claimed.

## Issues fixed (evidence-backed)
- **Generic finder mismatch**: `widgetWithText(DropdownButtonFormField, …)`
  never matches `DropdownButtonFormField<String>` — pin exact type args.
- **Lazy-list eviction both directions**: scrolled-away widgets unbuild;
  scroll to every assert/tap target (`scrollDownTo`/`scrollUpTo` via
  screen-coordinate drags).
- **`scrollUntilVisible` needs exactly one `Scrollable`**: dropdown-menu
  overlays break it — coordinate drags instead.
- **Ambiguous labels** (AppBar title == tab label, e.g. "Budgets"): scope
  taps via `NavigationBar` descendant or form-page descendant.
- **Offstage routes stay in the tree**: `.first`/`.last` and exact-text
  discipline on shared labels (sheet tiles vs section labels).
- Orphaned runner from an early killed run pegged CPU and stalled later
  runs — check `Get-Process dart` when runs mysteriously slow.

## Next (Milestone 7)
Handoff: README (setup/architecture/features/limitations/test commands),
data-model + financial-rules docs, feature/test summary, known limitations
(dark-only, same-currency transfers, monthly budgets, no-device integration
runs yet, share/picker need on-device confirmation).
