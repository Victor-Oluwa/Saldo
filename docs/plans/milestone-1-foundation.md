# Milestone 1 — Foundation Plan (Saldo)

**Status:** Approved for execution
**Date:** 2026-10-09
**Source:** `AGENTS.md` §15 Milestone 1 + design appendix
**Decisions:** Riverpod for DI, infra-only DB v1, full shell placeholders, bundle Inter now.

## 0. Current state

Pristine `flutter create saldo` template:
- `lib/main.dart` counter app
- `pubspec.yaml` only `cupertino_icons`
- `test/widget_test.dart` counter test
- `docs/` empty

## 1. Goals (Milestone 1)

- [ ] App theme (midnight navy + emerald, dark-only, Inter)
- [ ] Routing (GoRouter + 5-tab shell + onboarding placeholders)
- [ ] DI (Riverpod `ProviderScope`, DB/router/theme providers)
- [ ] Database setup (Drift `AppDatabase` v1, migration strategy, no tables yet)
- [ ] Error types (`sealed Failure`)
- [ ] Core money/date utilities (minor-units int, half-open ranges, no double)
- [ ] Migration infra + tests
- [ ] App launches offline

## 2. Dependencies

Resolve latest stable compatible at build time via `flutter pub add`:

- `flutter_riverpod`
- `go_router`
- `drift`, `sqlite3`, `path_provider`, `path`
- `dev: drift_dev`, `build_runner`, `riverpod_lint`
- Keep `flutter_lints`, `flutter_test`

## 3. File map

```
lib/app/app.dart
lib/app/router.dart
lib/app/theme/colors.dart        # SaldoColors exact tokens
lib/app/theme/app_theme.dart     # dark Material3 ThemeData
lib/core/database/app_database.dart
lib/core/errors/failures.dart
lib/core/money/money.dart
lib/core/money/currency.dart
lib/core/dates/periods.dart
lib/features/{home,transactions,budgets,reports,settings,onboarding}/presentation/*_placeholder.dart
assets/fonts/Inter-*.ttf
test/core/money_test.dart
test/core/dates_test.dart
test/core/database_migration_test.dart
test/widget/app_launch_test.dart
```

## 4. Theme spec

`SaldoColors`:
- background `0xFF0B0F14`, surface `0xFF121821`, elevated `0xFF1B2430`
- primary `0xFF34D399`, textPrimary `0xFFF1F5F9`, textSecondary `0xFF94A3B8`
- expense `0xFFFB7185`, border `0xFF263241`

Single dark `ThemeData(useMaterial3: true)`, `fontFamily: Inter`,
type scale 32B / 24SB / 18SB / 15M / 14R-M / 12R,
radius 14–16 cards, 10–12 inputs, tabular numerals for amounts.

## 5. Inter bundling

- `assets/fonts/` TTFs 400/500/600/700
- Declare in `pubspec.yaml` `flutter: fonts:` section
- Offline-safe, no `google_fonts` network dep

## 6. Routing spec

- `GoRouter` + `StatefulShellRoute.indexedStack`
- Tabs: Home, Transactions, Budgets, Reports, Settings
- Extra: `/onboarding`, placeholder detail routes
- `MaterialApp.router`, deep-link ready

## 7. DI spec (Riverpod)

- `ProviderScope` in `main.dart`
- Providers: `appDatabaseProvider`, `routerProvider`
- No feature repos yet — stubs only

## 8. Domain rules

- Money: `int minorUnits` + `currencyCode`, decimal-safe parse at I/O boundary only, overflow/positive validation, never `double` as authoritative.
- Dates: `monthRange/weekRange`, half-open `start <= t < nextStart`, local-calendar boundaries, stable secondary sort by `id`.
- Errors: `sealed Failure { Database, Validation, NotFound, UnsupportedVersion, FileAccess }`, no sensitive data in messages.

## 9. DB spec (infra-only v1)

- `AppDatabase extends _$AppDatabase`, `schemaVersion = 1`
- Empty `onCreate` + `migrationStrategy`, FK ON, no tables (tables = Milestone 2)
- Tests: fresh open → v1, re-open idempotent, migration hook testable

## 10. Verification

```
flutter pub get
flutter analyze
flutter test
flutter run   # + airplane-mode launch check
```

App must launch with navy background, 5-tab shell, no counter code remaining.

## 11. Out of scope

No Account/Category/Transaction/Budget tables, no BLoC logic, no CSV/backup, no budget/report math. Milestone 2+.
