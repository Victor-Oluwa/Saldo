# Saldo --- Product Requirements Document (PRD)

**Document status:** Draft for implementation\
**Version:** 1.0\
**Product type:** Offline Flutter mobile application\
**Primary audience:** Individuals and freelancers who want private,
manual personal-finance tracking\
**Initial release:** MVP\
**Primary currency example:** NGN (₦); currency must be configurable

------------------------------------------------------------------------

## 1. Product summary

Saldo is an offline-first personal finance application that lets users
record income, expenses, transfers, account balances, budgets, and basic
financial reports on their device. Core functionality must work without
an internet connection, account registration, or a remote backend.

The product's central rule is: **financial summaries must be derived
from persisted financial records, not independently maintained UI
totals.** Data integrity, clear financial semantics, privacy, and
recovery are higher priorities than feature count.

### 1.1 Problem statement

People often rely on memory, bank notifications, spreadsheets, or
several disconnected apps to understand their finances. This makes it
difficult to know current balances, monitor spending, and review
financial activity consistently. Many finance apps require accounts,
connectivity, or bank integrations that are unnecessary for users who
prefer manual, private tracking.

### 1.2 Product vision

Provide a reliable, attractive, easy-to-use local saldo that helps a
user answer: - How much money is recorded in each account? - How much
income and expense have I recorded over a selected period? - What
categories account for my spending? - How much budget remains? - What
transactions explain a balance or report? - Can I safely export and
restore my records?

### 1.3 Target users

**Primary** - Individuals managing day-to-day personal finances. -
Freelancers with variable income. - Students tracking allowances and
expenses. - Users who prefer manual entry and local storage.

**Not a target for MVP** - Businesses requiring statutory or full
double-entry accounting. - Users expecting automatic bank feeds, payment
processing, or money transfers through the app. - Multi-user household
accounting or cloud synchronization.

### 1.4 Product principles

1.  Offline-first: all core features work without a network.
2.  Local source of truth: committed local records power balances and
    reports.
3.  Financial correctness over convenience shortcuts.
4.  Explicit semantics: transfers are not income or expenses; loans are
    not automatically income or spending.
5.  Recoverability: users can export and restore data.
6.  Privacy by default: no account or telemetry requirement for MVP.
7.  Accessible, responsive, and consistent UI.
8.  Testable business rules isolated from widgets.

------------------------------------------------------------------------

## 2. Goals and non-goals

### 2.1 MVP goals

-   Create, edit, archive, and view financial accounts.
-   Record income and expenses.
-   Transfer funds between accounts without affecting income/expense
    totals.
-   Categorize transactions.
-   Search, filter, and inspect transaction history.
-   Show balances and period summaries calculated from persisted data.
-   Create and monitor category budgets.
-   Export transactions to CSV.
-   Create and restore a versioned local backup.
-   Work fully offline.
-   Include meaningful unit, widget, and integration tests.

### 2.2 Non-goals for MVP

-   Bank account linking, open banking, or transaction import from
    banks.
-   Online accounts, authentication servers, cloud synchronization, or
    multi-device conflict resolution.
-   Actual payment processing or movement of money.
-   Full double-entry accounting or tax filing.
-   Investment tracking, exchange-rate conversion, or multi-currency
    consolidated totals.
-   Automatic AI financial advice.
-   Debt management, recurring transactions, receipt OCR, savings goals,
    and PDF reports (planned future features).
-   Web or desktop support unless added explicitly to project scope.

------------------------------------------------------------------------

## 3. Scope and release priorities

### P0 --- Required for MVP

1.  App shell, navigation, theme, and onboarding.
2.  Local database and migrations.
3.  Accounts and opening balances.
4.  Income and expense transactions.
5.  Atomic transfers.
6.  Categories and category assignment.
7.  Transaction list, details, edit, delete, search, and filters.
8.  Dashboard and period selector.
9.  Category budgets.
10. CSV export.
11. Backup and restore.
12. Input validation, errors, empty/loading states, and accessibility.
13. Automated tests and project documentation.

### P1 --- After MVP

-   Debt and repayment tracking.
-   Savings goals.
-   Recurring transactions and reminders.
-   PDF reports.
-   Transaction attachments/receipt images.
-   Audit history for edits and corrections.
-   Optional biometric app lock.
-   More advanced analytics.

### P2 --- Later, only with validated need

-   Encrypted synchronization across devices.
-   Import from external formats or bank statement files.
-   Double-entry accounting mode.
-   Multi-currency accounts and conversion-aware reports.

------------------------------------------------------------------------

## 4. Navigation and information architecture

Use a bottom navigation bar with these primary destinations: 1. **Home**
--- overview and recent activity. 2. **Transactions** --- complete
transaction history and filters. 3. **Budgets** --- category budget list
and usage. 4. **Reports** --- period-based financial analytics. 5.
**Settings** --- currency, appearance, export, backup, restore, privacy,
and app information.

Accounts should be accessible from Home and through a dedicated account
list/detail flow. A prominent action on Home should open a transaction
creation flow with an explicit Income, Expense, or Transfer selection.

### 4.1 Required screens

-   First-launch onboarding and default currency selection.
-   Home dashboard.
-   Accounts list.
-   Create/edit account.
-   Account detail and account transaction history.
-   Create/edit income transaction.
-   Create/edit expense transaction.
-   Create/edit transfer.
-   Transaction list.
-   Transaction detail.
-   Category list and create/edit category.
-   Budgets list.
-   Create/edit budget.
-   Budget detail.
-   Reports.
-   Export options/results.
-   Backup creation.
-   Backup restore and validation confirmation.
-   Settings, appearance, privacy, and destructive-action confirmations.

Every screen must support appropriate loading, empty, validation-error,
operation-error, and success states. Do not show success until
persistence succeeds.

------------------------------------------------------------------------

## 5. Functional requirements

### FR-01: First launch and preferences

-   The user can select a default currency before recording
    transactions.
-   The app must work without registration or network access.
-   Preferences such as theme and first-launch completion persist
    locally.
-   The app must not silently change the currency of existing records.

**Acceptance criteria** - A fresh installation opens without a network
connection. - The user can complete setup and create the first account
offline. - The chosen currency is displayed consistently in applicable
UI.

### FR-02: Accounts

-   Users can create accounts with name, currency code, opening balance,
    optional description, and optional icon/color.
-   Users can view each account's current balance and transaction
    history.
-   Users can edit account metadata.
-   Accounts referenced by transactions must not be hard-deleted; they
    should be archived.
-   Archived accounts remain available in historical reports but are not
    offered by default for new transactions.
-   Opening balances must be represented consistently in balance
    calculations and backup/export logic.
-   MVP should not combine unlike currencies into one unqualified total.

**Acceptance criteria** - A new account with an opening balance of
₦20,000 displays ₦20,000 before further activity. - Archiving an account
does not remove its transactions or alter historical balances. - Account
currency cannot be changed after transactions exist unless a carefully
defined migration/conversion flow is implemented; default behavior is to
prevent the change.

### FR-03: Categories

-   Ship sensible default income and expense categories.
-   Users can create, rename, recolor, and archive custom categories.
-   Category type must be compatible with transaction type.
-   Archived categories remain visible in historical transactions.
-   Category deletion must not cascade-delete transactions.
-   Transfers do not require an income/expense category.

**Acceptance criteria** - An expense cannot be assigned an income-only
category. - Renaming a category preserves its relationship to historical
transactions. - Archived categories are selectable when editing
historical records but not suggested for new ones.

### FR-04: Income transactions

-   Required fields: positive amount, destination account, compatible
    income category, transaction date.
-   Optional fields: description, notes.
-   The user can create, view, edit, and delete income transactions.
-   A committed income increases the account balance and period income
    totals.
-   Validation and persistence failures are visible and do not create
    phantom success.

### FR-05: Expense transactions

-   Required fields: positive amount, source account, compatible expense
    category, transaction date.
-   Optional fields: description and notes.
-   The user can create, view, edit, and delete expenses.
-   A committed expense decreases the account balance and increases
    expense totals for its reporting period.
-   MVP may permit a negative account balance; if permitted, show it
    accurately rather than silently rejecting or clamping it. Any
    overdraft rule must be explicit and consistent.

### FR-06: Transfers

-   Required fields: source account, destination account, positive
    amount, date.
-   Source and destination must be different accounts.
-   MVP transfers are allowed only between accounts with the same
    currency.
-   A transfer must be stored as one logical operation with linked
    source and destination effects.
-   Both effects must commit atomically in one database transaction.
-   Transfers must not affect income, expense, or savings-rate totals.
-   Editing or deleting a transfer must update/reverse both effects
    atomically.

**Acceptance criteria** - Transfer of ₦20,000 from Bank to Cash reduces
Bank by ₦20,000, increases Cash by ₦20,000, and leaves total
same-currency assets, income, and expenses unchanged. - If either
transfer write fails, neither effect remains committed. - A transfer
cannot reference the same account twice.

### FR-07: Transaction history

-   Display transactions in reverse chronological order by transaction
    date, with a stable secondary sort for ties.
-   Show type, amount, category, account, date, and description where
    available.
-   Support search across description/notes and category name where
    practical.
-   Support filters for date range, account, category, and transaction
    type.
-   Provide transaction detail, edit, and delete actions.
-   Confirm destructive deletion and explain its effect on balances and
    reports.
-   Paginate or use efficient database queries if needed for large
    datasets.

**Acceptance criteria** - Search and filters can be combined and produce
consistent results. - Deleting a transaction updates all affected
balances and reports from the database. - Empty results show a helpful
message and a way to clear filters.

### FR-08: Dashboard

-   Show total balance for the selected/default currency, account
    balance breakdown, current-period income, current-period expenses,
    net cash flow, budget highlights, and recent transactions.
-   Provide a period selector (at minimum this month and previous month;
    ideally week, year, and custom range).
-   Every displayed amount must be derived from database-backed queries
    or domain calculations.
-   No independently mutable balance counter may serve as the
    authoritative value.
-   If multiple currencies exist, show totals separately by currency; do
    not sum them without conversion.

**Acceptance criteria** - Dashboard values match the same-period
transaction query and account balance calculations. - A successful
create/edit/delete operation is reflected without requiring an app
restart. - An empty saldo has clear zero/empty states without
misleading charts.

### FR-09: Budgets

-   Users can create a budget for an expense category and a defined
    period.
-   MVP supports monthly budgets.
-   Each budget includes a positive limit, category, start period, and
    optional warning thresholds.
-   Spent amount is computed from eligible expense transactions in the
    budget period; transfers are excluded.
-   Remaining amount equals limit minus spent amount and may be
    negative.
-   Editing/deleting an eligible expense updates budget usage.
-   MVP must prevent duplicate active budgets for the same category and
    month unless multiple-budget behavior is explicitly designed.
-   Budget carry-over is off by default and not required for MVP.

**Acceptance criteria** - A ₦60,000 food budget with ₦42,000 eligible
spending shows ₦18,000 remaining. - ₦65,000 spending shows −₦5,000
remaining or an equivalent clear overspent state. - Income and transfers
do not count toward expense budget usage.

### FR-10: Reports

-   Provide period-based income, expenses, and net cash flow.
-   Provide expense breakdown by category and a spending trend over
    time.
-   Provide a transaction-level view supporting drill-down to the
    records behind totals.
-   Use consistent date boundaries and transaction inclusion rules.
-   Do not present transfers as income or expenses.
-   Savings rate, if displayed, is
    `(period income - period expenses) / period income`; handle zero
    income without division by zero and label it as a cash-flow measure
    rather than net-worth growth.

**Acceptance criteria** - Report totals reconcile with transaction
history for the same date range. - Changing the period updates every
related figure and chart. - Empty periods render safely and explain that
no records exist.

### FR-11: CSV export

-   Users can export transactions for a selected date range and optional
    filters.
-   Include stable column headers and enough data to identify records:
    transaction ID, date, type, amount, currency, account, category,
    description, and notes where appropriate.
-   Use a defined date format and decimal/currency convention documented
    in the export.
-   Correctly escape commas, quotes, and line breaks in CSV values.
-   Use the platform share/save workflow where available.
-   Do not expose unrelated local records in a filtered export.

**Acceptance criteria** - Exported rows match the selected records and
filters. - A CSV containing commas, quotes, and multiline notes opens as
valid CSV. - Export errors are surfaced clearly.

### FR-12: Backup and restore

-   Create a versioned backup containing accounts, opening balances,
    transactions, categories, budgets, preferences relevant to
    interpretation, and schema/version metadata.
-   The backup must be stored in a user-accessible location through a
    platform-supported file workflow.
-   Restore must validate file format, version compatibility, required
    fields, IDs, foreign keys, currency data, and logical invariants
    before replacing or merging data.
-   MVP default restore behavior should be clearly stated. Recommended:
    show a warning and offer to replace the current saldo only after
    validation and explicit confirmation.
-   Restore should be atomic: failure must not leave a partially
    restored database.
-   Never silently overwrite existing data.
-   If encryption is not implemented, clearly warn that an exported
    backup may contain sensitive financial data.

**Acceptance criteria** - A valid backup can be restored and reproduces
account balances and reports. - An invalid or unsupported backup leaves
current data unchanged. - The user must explicitly confirm destructive
replacement. - The backup format includes a version so future migrations
can be implemented.

### FR-13: Settings and appearance

-   Support system/light/dark theme.
-   Support configurable default currency before data exists, plus
    appropriate formatting for supported currencies.
-   Provide backup, restore, export, and clear-all-data actions.
-   Destructive actions require explicit confirmation.
-   Clear-all-data must clearly explain that the operation is
    irreversible unless a backup exists.

### FR-14: Offline behavior

-   All P0 functionality works in airplane mode.
-   No sign-in, remote API, or network permission is required for core
    features.
-   The app must not display connectivity errors for local operations.
-   Any optional future online feature must degrade gracefully and must
    not block local use.

------------------------------------------------------------------------

## 6. Financial domain rules

These rules are mandatory and must be centralized in the domain layer
and covered by tests.

### 6.1 Money representation

-   Never use binary floating-point values for persisted financial
    amounts or core arithmetic.
-   Store integer minor units for supported currencies where applicable,
    with currency code recorded.
-   Define a currency metadata/formatting strategy that accounts for
    currencies with different minor-unit precision.
-   Validate positive transaction amounts and avoid integer overflow.
-   Use decimal-safe conversion only at input/output boundaries.
-   Never mix currencies in a total without a defined conversion rate
    and timestamp; currency conversion is out of MVP scope.

### 6.2 Balance rules

For each account:

`Current balance = opening balance + income + transfers in - expenses - transfers out`

This assumes each transaction is included exactly once and transfer
effects are correctly linked. If opening balances are represented as
explicit saldo entries, do not also add them separately.

### 6.3 Reporting rules

-   Income totals include only income transactions in the selected
    period.
-   Expense totals include only expense transactions in the selected
    period.
-   Net cash flow = income − expenses.
-   Transfers are excluded from income, expense, and net cash flow.
-   A loan issued to another person is an asset/receivable, not ordinary
    expense, in a future debt feature.
-   Loan proceeds received are a liability, not ordinary income, in a
    future debt feature.
-   Repayment of loan principal is not ordinary income or expense;
    interest/fees require separate classification in a future debt
    feature.
-   Refund behavior must be explicit. For MVP, support refunds either as
    a dedicated transaction type or as a linked reversal/negative
    expense with consistent report behavior. Do not mix approaches
    silently. Preferred design: a dedicated refund or linked reversal
    that reduces net expenses while retaining auditability.

### 6.4 Date rules

-   Store transaction date/time in a defined representation, such as UTC
    timestamp plus local-calendar date semantics, or a date-only value
    if time is not required.
-   Reports use the user's local calendar for day/week/month boundaries.
-   Use half-open ranges: `start <= transactionTime < nextPeriodStart`.
-   Define a stable ordering for transactions with identical dates.
-   Changing device timezone must not unpredictably move date-only
    transactions into another reporting day.

### 6.5 Editing and deletion

-   Recompute balances and reports from committed records or database
    queries; never patch only displayed totals.
-   Update linked transfer effects atomically.
-   Use foreign keys and constraints where supported.
-   Consider soft deletion or audit history later; MVP can use confirmed
    hard deletion if linked records remain consistent.

------------------------------------------------------------------------

## 7. Data model proposal

This is a logical starting point; adapt field names to the chosen Drift
schema and migration strategy.

### Account

-   `id`: stable UUID/string primary key.
-   `name`: required, trimmed.
-   `currencyCode`: required ISO 4217 code or supported currency
    identifier.
-   `openingBalanceMinor`: integer.
-   `description`: optional.
-   `iconKey`, `colorKey`: optional presentation metadata.
-   `createdAt`, `updatedAt`: timestamps.
-   `isArchived`: boolean.

### Category

-   `id`: stable primary key.
-   `name`: required.
-   `type`: income or expense.
-   `iconKey`, `colorKey`: optional.
-   `isSystem`: boolean.
-   `createdAt`, `updatedAt`.
-   `isArchived`: boolean.

### Transaction

-   `id`: stable primary key.
-   `accountId`: foreign key.
-   `categoryId`: nullable for transaction types that do not need one.
-   `type`: income, expense, or a well-defined transfer representation.
-   `amountMinor`: positive integer.
-   `currencyCode`: persisted or derived from immutable account
    currency, with consistency enforced.
-   `transactionDate`: defined date/time representation.
-   `description`, `notes`: optional.
-   `transferGroupId`: nullable stable identifier linking transfer
    effects.
-   `createdAt`, `updatedAt`.
-   Optional `deletedAt` if soft deletion is chosen.

### Transfer

Choose one consistent model: 1. A parent transfer entity plus two linked
account-effect entries; or 2. Two linked transaction rows with a shared
transfer group ID.

In either model, the pair must be created, edited, and deleted
atomically. Prevent a transfer from being represented as ordinary income
or expense in reports.

### Budget

-   `id`: stable primary key.
-   `categoryId`: expense category foreign key.
-   `periodType`: monthly for MVP.
-   `periodStart`: local-calendar period start date.
-   `limitMinor`: positive integer.
-   `currencyCode`: must match the relevant account/reporting currency
    policy.
-   `warningThresholdPercent`: optional.
-   `createdAt`, `updatedAt`.
-   `isArchived`: boolean if required.

**Budget currency policy:** Because MVP may allow accounts in multiple
currencies, category budgets must be tied to a single currency and only
include eligible expenses in that currency. Do not aggregate unlike
currencies.

### Preferences

-   `defaultCurrencyCode`.
-   `themeMode`.
-   `onboardingCompleted`.
-   Other non-sensitive user preferences.

### Schema constraints

-   Primary keys are unique.
-   Foreign keys are enforced.
-   Amounts and budget limits follow domain validation.
-   Transfer pairs have valid, distinct accounts, matching currencies,
    and matching amounts.
-   Category types match transaction types.
-   Queries are indexed based on real access patterns (for example,
    transaction date, account ID, category ID, and combinations used by
    history filters).

------------------------------------------------------------------------

## 8. Recommended architecture and technology

### 8.1 Stack

-   Flutter and Dart with null safety.
-   BLoC (`flutter_bloc`) for presentation state and event handling.
-   Drift + SQLite for structured local persistence.
-   GoRouter for navigation.
-   GetIt or Riverpod for dependency injection; choose one approach and
    use it consistently.
-   `fl_chart` for charts if it meets the selected design.
-   A maintained CSV/export and platform file-sharing approach.
-   A maintained PDF package only if PDF reports are added after MVP.
-   `flutter_test` and `integration_test` for automated testing.
-   `fpdart` is optional; typed domain failures can also be implemented
    without a functional programming dependency.

Use current stable, mutually compatible package versions when
implementation begins; do not invent version numbers in this PRD.

### 8.2 Layer responsibilities

**Presentation** - Screens, reusable widgets, form validation feedback,
BLoCs, UI state. - Must not directly query or mutate database tables. -
Must not contain authoritative financial calculations.

**Application/domain** - Entities/value objects, use cases, business
validation, financial rules, repository interfaces, typed failures. -
Pure calculations should be independently unit-testable.

**Data** - Drift tables/DAOs, repository implementations, database
migrations, backup serialization, CSV mapping. - Translate database
errors into typed failures. - Keep writes transactional.

**Core** - Money/currency utilities, date-range helpers, error types,
shared design tokens, reusable components.

### 8.3 Suggested folder structure

``` text
lib/
  app/
    app.dart
    router.dart
    theme/
  core/
    database/
    errors/
    money/
    dates/
    export/
    widgets/
  features/
    dashboard/
      data/
      domain/
      presentation/
    accounts/
      data/
      domain/
      presentation/
    transactions/
      data/
      domain/
      presentation/
    categories/
      data/
      domain/
      presentation/
    budgets/
      data/
      domain/
      presentation/
    reports/
      data/
      domain/
      presentation/
    settings/
      data/
      domain/
      presentation/
  main.dart
```

Create debt, recurring transaction, and savings-goal features only when
those phases are approved.

### 8.4 State and data flow

1.  UI dispatches a user-intent event to a BLoC.
2.  BLoC calls a use case.
3.  Use case validates domain rules and invokes a repository contract.
4.  Repository performs the database operation, using a database
    transaction when multiple writes must be atomic.
5.  Repository returns success or a typed failure.
6.  BLoC emits a state suitable for the UI.
7.  Database-backed reactive queries refresh the transaction list,
    balances, budgets, and reports.
8.  Success is displayed only after the database commit succeeds.

------------------------------------------------------------------------

## 9. UI/UX requirements

### Visual direction

-   Calm, professional, finance-focused visual language.
-   Clear typographic hierarchy and highly legible amounts.
-   Consistent spacing, icons, colors, and component states.
-   Support light, dark, and system themes.
-   Use color plus text/icon labels; never communicate income/expense
    status by color alone.
-   Avoid excessive animation and unnecessary decoration.
-   Make adding a transaction a short, low-friction flow.

### Dashboard hierarchy

1.  Total recorded balance, clearly labeled with currency.
2.  Income, expenses, and net cash flow for the selected period.
3.  Account breakdown.
4.  Budget status.
5.  Recent transactions.
6.  Spending category chart or trend.

### Forms

-   Amount input uses a numeric keypad and clear currency formatting.
-   Validate empty, zero, negative, malformed, and excessively large
    amounts.
-   Preserve form input when a recoverable operation fails.
-   Show inline field errors and a concise overall error when needed.
-   Avoid double submissions while a write is in progress.
-   Ask for confirmation before destructive actions.

### Accessibility

-   Support screen readers and semantic labels.
-   Respect text scaling and safe areas.
-   Maintain sufficient contrast.
-   Provide adequately sized touch targets.
-   Do not rely on color alone for chart interpretation.
-   Handle keyboard focus and form navigation.

------------------------------------------------------------------------

## 10. Error handling and resilience

The app must handle: - Database open/write failures. - Migration
failures and unsupported database versions. - Invalid user input. -
Missing or archived referenced categories/accounts. - Invalid or
corrupted backup files. - Unsupported backup versions. - File
access/share failures during export. - Duplicate taps/submissions. -
Empty data and no-filter-results states. - Interrupted app lifecycle
during a form operation.

Rules: - Never silently discard a financial write. - Never display a
successful save before commit. - Do not swallow exceptions without
logging useful, privacy-safe diagnostic information. - Do not put
transaction notes, balances, or other sensitive content into production
logs. - If restore fails, the existing saldo must remain intact. -
Destructive recovery procedures require explicit user confirmation.

------------------------------------------------------------------------

## 11. Security and privacy requirements

-   No user registration or backend is required for MVP.
-   No core workflow may depend on network access.
-   Request no unnecessary permissions.
-   Do not send financial records to analytics or remote services.
-   Explain the privacy implications of exporting an unencrypted backup.
-   Use platform secure storage for secrets/keys if a lock or encryption
    feature is added.
-   Biometric locking alone is not database encryption.
-   If database encryption is added, define key generation, storage,
    rotation, recovery, and backup behavior.
-   Clear sensitive temporary files when practical and avoid retaining
    exported copies inside app-controlled temporary storage longer than
    necessary.
-   A user must be able to intentionally delete local data after a clear
    confirmation.

------------------------------------------------------------------------

## 12. Non-functional requirements

### Reliability

-   Database operations preserve defined invariants.
-   Transfers and restore operations are atomic.
-   A normal app restart preserves all committed records.
-   Reports reconcile with underlying records.

### Performance

-   Common dashboard and history queries should feel responsive on a
    mid-range device with several thousand transactions.
-   Avoid loading an unbounded transaction history into memory.
-   Use database aggregation and pagination where appropriate.
-   Profile performance before optimizing speculative bottlenecks.

### Maintainability

-   Business rules do not depend on Flutter widgets.
-   Repositories isolate persistence details.
-   Use consistent naming, formatting, lint rules, and documentation.
-   Avoid unnecessary abstraction and duplicate sources of truth.
-   Migrations are versioned and tested.

### Portability

-   Build for Android first if a single initial platform is needed; keep
    platform-specific file and biometric code behind abstractions.
-   iOS should be supported if included in the project's agreed delivery
    scope.
-   Do not promise platform parity for APIs that differ without testing
    both platforms.

------------------------------------------------------------------------

## 13. Testing strategy

### Unit tests

Test: - Money parsing/formatting and currency precision. - Balance
calculation. - Period totals and date boundaries. - Budget
spent/remaining/overspend calculations. - Savings-rate zero-income
behavior. - Transaction/category type validation. - Transfer
invariants. - Backup schema validation. - CSV escaping and output
mapping.

### Repository/database tests

Test: - Create, edit, and delete income/expense transactions. - Atomic
transfer creation/edit/deletion. - Foreign-key and category
constraints. - Database migrations from prior schema versions. -
Reactive query updates. - Backup/restore round-trip. - Failed restore
leaves current data unchanged. - Large transaction query/filter
correctness.

### Widget tests

Test: - Dashboard loading, empty, success, and error states. -
Transaction form validation. - Category and account selection. -
Confirmation dialogs. - Budget usage display. - Search and combined
filters. - Accessible labels and key navigation behavior where feasible.

### Integration tests

Test complete flows: 1. First launch → create account → record income →
verify balance. 2. Record expense → verify balance, category spending,
and report totals. 3. Transfer funds → verify both accounts change and
cash-flow totals do not. 4. Edit/delete a transaction → verify dependent
screens reconcile. 5. Create budget → record expenses → verify remaining
budget. 6. Export CSV → verify selected rows and valid escaping. 7.
Backup → clear/replace only after confirmation → restore → verify
records. 8. Use all core features with network disabled.

### Required financial invariants

-   Account balance equals opening balance plus committed income and
    transfers in minus committed expenses and transfers out.
-   A same-currency transfer changes the two account balances by equal
    and opposite amounts.
-   Transfers never affect income/expense totals.
-   Dashboard/report totals reconcile with transaction queries for the
    same period and inclusion rules.
-   Failed atomic operations leave no partial state.
-   Restoring invalid data never damages current data.

------------------------------------------------------------------------

## 14. Acceptance criteria for MVP completion

The MVP is complete only when all of the following are true:

1.  A user can install and use the app without registration or internet.
2.  A user can create accounts with opening balances.
3.  Income, expenses, and transfers can be recorded, edited, inspected,
    and deleted.
4.  Transfer operations are atomic and do not distort income/expense
    reports.
5.  Transaction history supports search and useful filters.
6.  Dashboard balances and period totals reconcile with database
    records.
7.  Monthly category budgets correctly show spending, remaining amounts,
    and overspending.
8.  CSV export reflects the selected transactions and correctly escapes
    values.
9.  Backups are versioned, validated, and restorable.
10. Failed restore or database operations do not falsely report success
    or leave partial data.
11. Core financial rules have automated unit tests; database and key
    user flows have integration coverage.
12. Light/dark/system appearance, empty states, validation errors, and
    destructive confirmations are implemented.
13. README documents setup, architecture, features, limitations, and
    test commands.
14. No P0 feature depends on a remote API.

------------------------------------------------------------------------

## 15. Implementation plan for an AI coding agent

The agent must work incrementally and preserve a runnable project at
every milestone.

### Milestone 0 --- Inspect and plan

-   Inspect the existing repository before changing files.
-   Identify Flutter/Dart versions, current architecture, dependencies,
    tests, and project conventions.
-   Do not overwrite existing work without understanding it.
-   Write a concise implementation plan and identify any blocking
    ambiguity.
-   If no repository exists, create a standard Flutter project with null
    safety and linting.

### Milestone 1 --- Foundation

-   Establish app theme, routing, dependency injection, database setup,
    error types, and core money/date utilities.
-   Add database migration infrastructure and tests.
-   Ensure the app launches.

### Milestone 2 --- Domain and persistence

-   Implement Account, Category, Transaction, and Budget domain models.
-   Define repository interfaces and typed failures.
-   Implement Drift tables/DAOs and constraints.
-   Implement balance and reporting queries.
-   Add unit and database tests before building dependent screens.

### Milestone 3 --- Core transaction workflows

-   Implement account CRUD/archive.
-   Implement income and expense create/edit/delete.
-   Implement atomic transfers.
-   Implement transaction history, search, filters, and details.
-   Verify financial invariants with automated tests.

### Milestone 4 --- Dashboard and budgets

-   Implement reactive dashboard queries and period selection.
-   Implement monthly category budgets.
-   Add report charts and transaction drill-down.
-   Reconcile all displayed totals against persisted records.

### Milestone 5 --- Export and recovery

-   Implement filtered CSV export.
-   Implement versioned backup serialization, validation, and atomic
    restore.
-   Add round-trip and failure-path tests.

### Milestone 6 --- Product polish

-   Implement empty/loading/error states, accessibility, dark/light
    themes, confirmations, and sample/demo data.
-   Run formatter, analyzer, unit tests, widget tests, and integration
    tests.
-   Resolve all critical failures before declaring completion.

### Milestone 7 --- Handoff

-   Update README and architecture documentation.
-   Document data model and key financial rules.
-   Provide setup/run/test commands.
-   Summarize implemented features, tests run, known limitations, and
    any remaining work.
-   Do not claim tests passed unless they were actually run.

### Agent operating rules

-   Prefer small, coherent changes over generating the entire app in one
    pass.
-   Do not invent backend services or add network dependencies to solve
    local requirements.
-   Do not add a package without a clear purpose; use compatible
    maintained packages.
-   Keep financial arithmetic out of widgets.
-   Never use `double` as the authoritative representation of money.
-   Use database transactions for multi-record operations.
-   Add tests with each business feature.
-   Do not replace real persistence with in-memory mock data for the
    finished app.
-   Do not leave core features as TODOs while claiming the MVP is
    complete.
-   Ask a concise question only when a genuinely blocking product
    decision cannot be safely resolved from this document; otherwise use
    the defaults stated here and document the decision.

------------------------------------------------------------------------

## 16. Explicit assumptions and decisions

These defaults remove ambiguity for the initial implementation:

-   Product name: **Saldo**; keep branding easy to change.
-   Initial target: Android-first Flutter app, with platform
    abstractions kept portable.
-   Default currency: configurable; NGN may be the initial demo/default
    locale, but must not be hardcoded into calculations.
-   Storage: local SQLite database using Drift.
-   Authentication: none in MVP.
-   Network: not required for any P0 workflow.
-   Account balances: allow negative balances unless a clear product
    rule later disallows them.
-   Transfers: same-currency only in MVP.
-   Budgets: monthly, category-based, single currency per budget.
-   Delete behavior: confirm destructive deletes; preserve referential
    integrity.
-   Backup restore: validate first and require explicit confirmation
    before replacing data.
-   Analytics: no remote analytics containing financial data.
-   Scope: do not add debt, recurring transactions, savings goals, PDF
    reports, cloud sync, or bank integrations to MVP without explicit
    approval.

------------------------------------------------------------------------

## 17. Definition of done for every feature

A feature is done only when: - Its behavior matches the requirements and
edge cases. - Domain logic is separated from presentation. - Persistence
and error states are implemented. - Relevant automated tests pass. -
Loading, empty, success, and failure UI states are considered. -
Accessibility and theme behavior are checked. - No unrelated feature
regresses. - Documentation is updated where necessary. - The
implementation agent reports exactly what changed and what was actually
verified.





Use a deep midnight navy theme with muted emerald accents and a clean Inter typography system. It should feel calm, private, trustworthy, and premium — like a serious financial tool, not a flashy crypto app.

## 1. Color palette

Saldo

# ₦248,500.00

Total recorded balance

Income

\+ ₦85,000

Expenses

− ₦32,500

Recent transactions

See all

Groceries

Today

− ₦4,500

Freelance income

Yesterday

\+ ₦25,000

Transport

Yesterday

− ₦1,200

Illustrative direction for the dark-only interface.

### Exact color tokens

Background

Main app background

\#0B0F14

Surface

Cards and bottom navigation

\#121821

Elevated surface

Input fields, dialogs, selected items

\#1B2430

Primary accent

Primary actions, income, progress

\#34D399

Primary text

Headings and important amounts

\#F1F5F9

Secondary text

Labels, dates, descriptions

\#94A3B8

Expense

Expense amounts and spending indicators

\#FB7185

Borders

Dividers and card outlines

\#263241

The green should be restrained. Use it for primary buttons, positive balances, income, and progress indicators — not as a background for every card.

## 2. Font

[Fintech Mobile App UI Design Dashboard by Ronas IT | UI/UX Team on Dribbble](https://images.openai.com/static-rsc-4/fPJQwDzZLUyXeW726wZh7Yk5icLFvIrp8pnxuH6Trf6P4VsOP37W-OknL_8I_MIErUfPMpRNA9UMKLt8YQYOiaidxNumfJYiPVdFO9TzqJ5pcJC0g5T75T-dXEW6HGKG9FaPh3H6CwTuFwQOwWj8rD8_0GTVNWHEBYC_tXgN5OY?purpose=inline)

1\. Inter — my first choice

Recommended

Clean, modern, and highly readable on mobile. Excellent for transaction lists, labels, forms, and dashboards.

Weights: 400 Regular, 500 Medium, 600 SemiBold, 700 Bold.

[Pasha Rewards - Project for #PashaHackathon2.0 by Fuad Iskanderov on Dribbble](https://images.openai.com/static-rsc-4/yle342QvHhkKH6Vt84e7tuUawqanvQYjRJumyzuM9OuEbr-LUGaGS5MIVN9p9ha_V68JMRli4pcAc6RhYWozy9QgsF4njhy4o58IJpdVl1-6-Q4NVaU88RVUF6ogAjZb1tyaRat4tMZwn98WBVVNX7BZO7jA_OTA7elHFXyDZxI?purpose=inline)

2\. Manrope — more distinctive

Slightly more geometric and expressive. A good alternative if you want Saldo to feel more boutique and design-led.

[Rapidobox webapp dashboard :: Behance](https://images.openai.com/static-rsc-4/0b4rV88FQXmL0bc5uMj2K16fOdizxxubRxZGgHhz40tw0Lk9neMCDttU9Ftjv06ZV8K6QU838khvb3OTualDho98kT87-DF4x3KmPHaJGwyZrRjTyvNfr0siyn81KAmoY-XO_7sZmjx896Qr5CASOfHCCbtbxkzrQTWzZ4IEoHM?purpose=inline)

3\. IBM Plex Sans — more technical

A strong choice if you want a utilitarian, accounting-oriented interface with a more technical character.

I'd use Inter throughout the app, with tabular numerals for balances and transaction amounts so the digits align neatly. You don't need a second font.

Suggested type scale:

| Element             | Size  | Weight           |
| ------------------- | ----- | ---------------- |
| Main balance        | 32 px | Bold             |
| Screen title        | 24 px | SemiBold         |
| Section heading     | 18 px | SemiBold         |
| Transaction title   | 15 px | Medium           |
| Body and amounts    | 14 px | Regular / Medium |
| Labels and metadata | 12 px | Regular          |

## 3. The design rules

- Dark mode only: no light theme toggle or alternate light palette.
- Rounded corners: 14–16 px for cards and 10–12 px for inputs and buttons.
- Subtle borders: prefer a thin slate border over heavy shadows.
- Minimal gradients: use solid backgrounds to keep the interface calm.
- Consistent financial colors: emerald for income, coral for expenses, neutral text for transfers.
- Comfortable spacing: an 8 px spacing system with generous padding around the main balance.
- Accessible contrast: secondary text should remain readable against the background.

## 4. Flutter implementation

Define the palette centrally rather than scattering hexadecimal values across widgets.

```
abstract final class SaldoColors {
  static const background = Color(0xFF0B0F14);
  static const surface = Color(0xFF121821);
  static const elevated = Color(0xFF1B2430);
  static const primary = Color(0xFF34D399);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const expense = Color(0xFFFB7185);
  static const border = Color(0xFF263241);
}
```

Bundle the Inter font files with your Flutter app so the typography is consistent across supported devices, and configure a single dark `ThemeData` for Material 3.

My final pick: Midnight Navy `#0B0F14` + Emerald `#34D399` + Inter. It gives Saldo a recognizable visual identity while keeping financial information easy to scan.
