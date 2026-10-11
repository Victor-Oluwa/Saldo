# Saldo

Saldo is a private, offline-first personal finance tracker built with Flutter.
There is no account to create, no server to reach, and no bank to connect.
You record income, expenses, and transfers by hand, and every balance,
total, and chart on screen is derived from records stored on your device.

Core rule of the codebase: summaries are computed from persisted records,
never from independently maintained UI counters.

## Why Saldo

- **100% offline.** All core features work in airplane mode.
- **Private by default.** No registration, no analytics, no network calls
  for any core workflow.
- **Financially honest.** Money is stored as integer minor units (never
  binary floating point), transfers are atomic and never counted as income
  or expenses, and reports reconcile with the underlying transactions.
- **Recoverable.** Versioned backups with validated, atomic restore, plus
  CSV export of your transactions.

## Features

### Accounts

- Create accounts with a name, currency, opening balance, and optional
  description, icon, and color.
- Each account shows its current balance plus its own transaction history.
- Accounts with history are archived, never hard-deleted, so reports keep
  reconciling.
- Multiple currencies are supported. Totals are always shown per currency
  and are never summed across currencies.

### Income and expenses

- Record income and expenses with amount, account, category, date, and
  optional description and notes.
- Categories are typed: an expense cannot use an income-only category.
- Sensible default categories ship with the app; you can create, rename,
  recolor, and archive your own.
- Editing or deleting a transaction recomputes every affected balance,
  budget, and report from the database.

### Transfers

- Move money between two accounts of the same currency.
- A transfer is one logical operation with two linked effects that commit
  atomically: if either write fails, neither is kept.
- Transfers change the two account balances by equal and opposite amounts
  and leave income, expense, and net cash flow totals untouched.

### Dashboard

- Total recorded balance per currency, period income, expenses, net cash
  flow, account breakdown, budget highlights, recent transactions, and a
  spending chart.
- Period selector (week, month, year, custom range) drives every figure on
  screen.
- Empty states render clean zeros with guidance instead of misleading
  charts.

### Budgets

- Monthly budgets per expense category, each tied to a single currency.
- Spent is computed from eligible expenses in the budget month; transfers
  and income are excluded.
- Remaining is limit minus spent and can go negative, shown as a clear
  overspent state.
- One active budget per category per month.

### Reports

- Period income, expenses, and net cash flow, expense breakdown by
  category, and spending trend over time.
- Every total drills down to the transactions behind it.
- Consistent half-open date ranges (`start <= date < nextPeriodStart`)
  using the device local calendar.

### Export, backup, and restore

- **CSV export:** selected date range and filters, stable column headers
  (id, date, type, amount, currency, account, category, description,
  notes), with correct escaping of commas, quotes, and line breaks.
  Uses the platform share/save workflow.
- **Backup:** a versioned JSON file with accounts, opening balances,
  transactions, categories, budgets, relevant preferences, and schema
  metadata.
- **Restore:** validates format, version, required fields, IDs, foreign
  keys, and currency data before touching anything, then replaces the
  current data only after explicit confirmation. Failures leave existing
  data unchanged. Backups are not encrypted, so the app warns that the
  file contains sensitive financial data.

### Onboarding and settings

- First-launch onboarding with default currency selection. Works fully
  offline.
- Settings cover currency, appearance (dark interface), export, backup,
  restore, privacy info, and clear-all-data behind an explicit
  confirmation.

## Tech stack

| Layer        | Choice                                              |
| ------------ | --------------------------------------------------- |
| UI           | Flutter (Material 3), dark-only theme, Inter font   |
| State        | `flutter_riverpod`                                  |
| Navigation   | `go_router` (bottom nav: Home, Transactions, Budgets, Reports, Settings) |
| Persistence  | Drift + SQLite (`drift`, `sqlite3`)                 |
| Prefs        | `shared_preferences`                                |
| Charts       | `fl_chart`                                          |
| Export/share | `csv`, `share_plus`, `file_picker`, `path_provider` |
| IDs          | `uuid`                                              |
| Linting      | `flutter_lints`                                     |
| Codegen      | `drift_dev`, `build_runner` (generated files are committed) |

- Package name: `saldo`
- Application ID: `com.saldo.app`
- Current version: `1.0.0+1` (see `pubspec.yaml`)
- Flutter: stable 3.44, Dart `^3.12.2`

## Getting started

### Prerequisites

- Flutter stable (3.44 or newer) with Dart `^3.12.2`.
- For Android builds: Android Studio with SDK and platform tools.
- For iOS builds: a Mac with Xcode.
- No backend, API keys, or network access needed.

### Run the app

```sh
git clone https://github.com/Victor-Oluwa/Saldo.git
cd Saldo
flutter pub get
flutter run
```

Drift generated files (`*.g.dart`) are committed, so a plain
`flutter pub get` is enough. Only rerun code generation after changing
table or entity definitions:

```sh
dart run build_runner build --delete-conflicting-outputs
```

### Release builds

```sh
flutter build apk --release        # Android APK
flutter build appbundle --release  # Android App Bundle (Play Store)
flutter build ipa --release        # iOS (macOS with Xcode only)
```

## Project structure

```text
lib/
  app/            # MaterialApp, GoRouter, theme (colors, motion, type)
  core/
    backup/       # backup serialization, validation, restore
    database/     # Drift database, tables, providers
    dates/        # period helpers, half-open range logic
    demo/         # sample data for fresh installs
    errors/       # typed failures
    export/       # CSV mapping, escaping, share/save
    finance/      # balance math, budget math, reporting rules
    money/        # minor-unit money type, parsing, formatting
    widgets/      # shared design-system widgets (tiles, states, sheets)
  features/
    accounts/     # data / domain / presentation
    budgets/
    categories/
    home/         # dashboard
    onboarding/
    reports/
    settings/     # preferences, export, backup, restore
    transactions/ # income, expense, transfer flows
  main.dart
test/
  core/           # money, dates, math, CSV, preferences
  database/       # accounts, transactions, transfers, budgets, backup round-trip
  journeys/       # end-to-end app flows
  widget/         # screen and flow tests per feature
integration_test/
  app_flows_test.dart
docs/plans/       # milestone plans and UI redesign notes
```

Layer rules: widgets never touch the database and never own financial
math. Use cases validate domain rules and call repositories. Repositories
own Drift queries and wrap multi-record writes in database transactions.
The UI shows success only after the commit succeeds.

## Financial rules (enforced and tested)

- `balance = openingBalance + income + transfersIn - expenses - transfersOut`,
  computed per account from committed rows.
- Transaction amounts and budget limits are positive integers in minor
  units. Input parsing is decimal-safe at the boundary; storage and math
  never use `double`.
- Same-currency transfers only. Both effects share a transfer group ID and
  are created, edited, and deleted atomically.
- Income totals include only income rows in the period; expense totals only
  expense rows. Transfers are excluded from both and from net cash flow
  (`income - expenses`).
- Monthly budgets count only eligible expenses in that category, month,
  and currency.
- Savings rate, where shown, is
  `(periodIncome - periodExpenses) / periodIncome`, with zero income
  handled as a no-data state rather than a division by zero.

## Testing

```sh
flutter analyze   # static analysis (must be clean)
flutter test      # full suite: currently 121 tests, all passing
```

Coverage includes money parsing and formatting, balance and budget math,
period boundaries, transfer invariants, CSV escaping, migration and
repository behavior, backup/restore round-trips (including failed restores
leaving data intact), widget flows for every feature, and
`integration_test/app_flows_test.dart` for first-launch to restore
journeys.

## Privacy and security

- All records live in the on-device SQLite database. Core features make
  zero network requests.
- No accounts, tokens, or third-party SDKs that exfiltrate data.
- CSV exports and JSON backups contain real financial data and are not
  encrypted. They are written through the platform share/save flow so you
  control where they go; delete them from shared locations when done.
- Clearing app data is irreversible without a backup, and the app says so
  before doing it.

## Current limitations

- Android-first: iOS, macOS, Windows, Linux, and web runners exist, but
  day-to-day testing targets Android.
- Transfers require both accounts to share one currency; there is no
  currency conversion.
- Budgets are monthly and category-based; no carry-over.
- No cloud sync, bank import, receipt scanning, recurring transactions,
  savings goals, debt tracking, or PDF reports. These are documented in
  `AGENTS.md` as post-MVP work, not oversights.

## Roadmap (post-MVP)

Debt and repayment tracking, savings goals, recurring transactions and
reminders, PDF reports, receipt attachments, edit audit history, optional
biometric app lock, richer analytics, and (only with validated need)
encrypted multi-device sync.

## Docs

- `AGENTS.md`: full product requirements (source of truth for scope and
  financial rules).
- `docs/plans/`: milestone plans from foundation through polish, plus UI
  redesign notes.

## Status

MVP in active development. The app runs, the suite is green, and the
financial invariants above are covered by tests. Issues and pull requests
are welcome: keep money math out of widgets, keep writes transactional,
and add a test with every business rule change.
