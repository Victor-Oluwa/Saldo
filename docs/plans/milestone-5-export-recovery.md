# Milestone 5 — Export and Recovery (Saldo)

**Status:** Implemented + verified
**Date:** 2026-10-10
**Source:** `AGENTS.md` §15 Milestone 5 (FR-11, FR-12, FR-13 data actions)

## What was built

### Preferences (FR-01/FR-13 groundwork)
- `settings/domain+data/preferences_repository.dart`: `defaultCurrencyCode`
  only (appearance is dark-only per design appendix — no toggle stored).
  `SharedPrefs` impl + `Memory` impl for tests (no platform channels).
- `settings_providers.dart`: async repo provider, `defaultCurrencyProvider`
  (NGN fallback, never crashes UI), `hasAccountsProvider` currency lock.
- New accounts now default to the stored currency until the user picks one;
  Settings locks the selector once any account exists — existing records
  never re-denominate.

### CSV export (FR-11)
- `core/export/transaction_csv.dart`: stable 15-column schema
  (id/date/type/decimal+minor/currency/account/category/desc/notes/
  transfer group/side/counterpart), ISO local `yyyy-MM-ddTHH:mm` dates,
  exact decimal strings from integer minor units (no `double` anywhere),
  RFC-4180 quoting via `csv` 8.x (`Csv().encode/decode`). Transfers export
  as linked `out`+`in` pairs so the file reconciles with balances.
- `core/export/share_file.dart`: temp-file + platform share sheet (user
  picks destination — no storage permission), `FileAccessFailure` mapping.
- `settings/export_page.dart` (`/settings/export`): range presets + custom,
  account/category/type filters, live match count, convention footnote.
  Only matching rows are serialized.

### Backup & restore (FR-12)
- `core/backup/backup.dart`, format `v1`:
  - `exportBackup`: all four tables (Drift ISO-string JSON) + preferences +
    version marker. Pure read.
  - `validateBackup`/`decodeBackup`: total validation BEFORE any write —
    version support, sections, row shapes, id uniqueness, currency shape,
    FK existence, amount positivity, transfer-pair rules (exactly 2 legs,
    in+out, equal amount/currency, distinct cross-linked accounts),
    category compatibility, budget rules incl. month-start periods.
    Any failure throws typed `Failure`; saldo untouched.
  - `restoreBackup`: prefs first (prefs failure leaves saldo intact),
    then delete+insert in FK-safe order inside ONE `db.transaction` —
    atomic by construction. Replace-only, never merge, caller confirms.
  - `clearAllData`: FK-ordered wipe in one transaction, prefs kept.
  - Backups are NOT encrypted — warnings on backup page, restore sheet,
    and confirmation copy.

### Settings UI (FR-13 data actions)
- Rewrote `settings_page.dart`: currency selector (+lock note), dark-only
  appearance note, data cards (export/backup/restore/clear), privacy About.
- `backup_page.dart` (`/settings/backup`): included-counts preview +
  unencrypted warning + create-and-share.
- `restore_sheet.dart`: file pick (`.json`, `file_picker` v13 URI API) →
  validate → summary card (counts/currency/exported-at) + replace warning →
  explicit confirm → atomic restore → reactive refresh. Invalid files show
  errors with current data explicitly intact. Cancel = nothing happens.

## Verified (actually run)
- `flutter analyze --no-fatal-infos --no-fatal-warnings` — No issues found
- `flutter test` — **95/95 passed** (75 prior + 20 new):
  - `csv_test` (6): stable headers, exact decimals (1.10+2.20=3.30),
    comma/quote/newline round-trip, transfer-pair columns, filtered-only
    rows, filename.
  - `backup_test` (8): round-trip reproduces balances/totals/budget usage,
    malformed text, unsupported version, missing section, dangling FK,
    single-leg group, duplicate ids, negative amount — every failure path
    asserts pre/post snapshots identical (no partial state); prefs
    round-trip; filename.
  - `preferences_test` (1), settings widget (3): sections render, currency
    lock text, clear-all confirmation dialog.
  - export widget (2): live count, type filter narrows count.

## Issues fixed (evidence-backed)
- `csv` 8.x renamed converters → `Csv().encode/decode`; decode is
  string-typed by default (assertions adjusted, no dynamic typing).
- Drift `toJson` keys are camelCase (`transferSide`, `amountMinor`) —
  tamper-test keys corrected (a wrong key would silently pass validation).
- `Failure` is sealed — prefs write failure uses `DatabaseFailure`.
- `file_picker` 13.x is URI/`XFile`-based (`pickFile`, no `platform`,
  no `withData`) — restore reads via `xFile.readAsString()`.
- `share_plus` 13.x is `SharePlus.instance.share(ShareParams(...))`
  (static `Share` deprecated) — used exclusively.
- Widget habit: scroll-into-view before below-fold taps.

## Next (Milestone 6)
Product polish: empty/loading/error audit, accessibility pass, demo data,
full `flutter analyze/test` + formatter gate, README/architecture docs
(Milestone 7 handoff content).
