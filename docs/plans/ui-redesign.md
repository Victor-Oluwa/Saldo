# UI Redesign — Plan (Saldo)

**Status: Implemented + verified (2026-10-10)**
**Verified:** `dart format` clean · `flutter analyze` no issues ·
`flutter test` **121/121 passed** (102 prior + 19 new).
**Decisions (user-confirmed):** dark-only stays · expressive motion ·
`fl_chart` + `animations` packages allowed · phones only (320–430dp) ·
display font Space Grotesk (bundled `.ttf`, offline-first) · Inter stays for body.

Hard constraints that still hold: offline-first (no runtime font fetch,
no network art), money as `int` minor units, income/expense never
color-alone, contrast + screen-reader labels, full test suite green.

## 1. Design direction

**Signature — "the living saldo line":** an animated area-sparkline of
the balance over time in a luminous mint→transparent gradient, woven
behind the home hero numeral. Draws itself on load, eases to new values
after every transaction, reappears as the reports trend chart. One
memorable element; everything else disciplined. This also moves the app
off the generic near-black + single-acid-accent default: a second gold
accent, layered surfaces with glows, and editorial display type.

**Palette (extends `lib/app/theme/colors.dart`):**

| Token | Value | Job |
|---|---|---|
| `background` | `0xFF060A10` | app bg (deeper, bluer) |
| `surface` | `0xFF0E1622` | cards + nav |
| `elevated` | `0xFF1D2A3D` | inputs, dialogs |
| `primary` | `0xFF3EE6A8` | primary actions, income (brightened emerald) |
| `expense` | `0xFFFF7A93` | expenses |
| `gold` | `0xFFF2C66D` | budgets, savings rate, premium moments (new) |
| `textPrimary` | `0xFFF4F7FB` | headings, amounts |
| `textSecondary` | `0xFF8FA1B8` | labels, dates |
| `border` | `0xFF263241` | hairlines (unchanged) |

Old values change: background/surface/elevated/primary/expense/text
hues shift. All references go through `SaldoColors`, so the rename is
contained. Depth = layered surfaces + hero-only glow, not shadows.

**Type:** Space Grotesk (600/700, tabular figures) for hero numerals +
screen titles; Inter for everything else (existing scale kept).
Bundled under `assets/fonts/`, declared in `pubspec.yaml`.

**Theme stays dark-only** (user-confirmed). Light "paper saldo" is out
of scope for this pass.

## 2. Screen-by-screen changes

- **Home** (`features/home/presentation/home_page.dart`): `CustomScrollView`
  + collapsing hero (greeting, animated count-up balance over the living
  saldo line, Add action), 3-tile income/expense/net strip, then budgets,
  accounts, recent. Staggered entrance; skeleton shimmer replaces bare
  spinners.
- **Reports** (`features/reports/presentation/reports_page.dart`): `fl_chart`
  donut (breakdown, tap drill-down kept), grouped bars (trend), area line
  echoing the signature. Animated period transitions.
- **Budgets**: `BudgetUsageRow` upgraded once (animated ring/bar,
  gold→coral overspend states) — Home + Budgets benefit together.
- **Lists** (transactions/accounts/categories): new tile design (tinted
  icon chip, title, meta, amount), date section dividers kept, redesigned
  filter sheet, `CustomPainter` saldo-motif illustrations replace the
  `inbox_outlined` empty states (`core/widgets/saldo_states.dart`).
- **Details**: tinted amount hero band per type; transfer legs become a
  from→to diagram; `Hero` transitions from list tiles.
- **Forms/sheets/dialogs**: section grouping, live amount preview,
  bottom-sheet handle + rounded-24 via theme.
- **Navigation** (`app/router.dart` shell): active-pill glow; shared-axis
  tab transitions via `animations` package.
- **Onboarding** (currently placeholder): real first-run flow — animated
  intro → currency picker → create account → optional demo data.
- **Cleanup**: delete dead `app/shell_placeholder.dart` + placeholder
  `features/transactions/presentation/transactions_page.dart`.

## 3. Motion system (`lib/app/theme/motion.dart`, new)

Tokenized durations/curves (150ms micro / 300ms component / 600ms hero);
`SaldoMotion` scope zeroes durations when
`MediaQuery.disableAnimations` is set. Toolkit: `TweenAnimationBuilder`
count-ups, staggered entrances, `Hero`, `AnimatedSwitcher` balances,
implicit progress animation. No heavyweight engine.

## 4. Phones-only responsive system

Today: zero responsive code. Tiers: compact `<360dp`, standard `360–414`,
large `>414` — adaptive hero type steps, stat strip wraps, account tiles
1-col → 2-col grid on large. Small heights: hero compacts via slivers.
Text scaling to 1.3×+, keyboard avoidance, 48dp targets, safe areas.
Tests: pump key screens at 320×640, 390×844, 430×932 (+1.3× text),
assert no overflow (no brittle goldens).

## 5. Packages

Add `fl_chart` + `animations` only (versions resolved via
`flutter pub add` at build time). Motion via framework, illustrations
via `CustomPainter`.

## 6. Build order (each slice ends green)

1. Tokens + theme (colors, font, full `ThemeData`, motion tokens).
2. Widget kit (hero, tiles, headers, rings, skeletons, empty states).
3. Home hero + dashboard.
4. Lists + details + Hero transitions.
5. Budgets + reports charts.
6. Forms + sheets + onboarding.
7. Polish (reduced-motion audit, responsive matrix, contrast, full verify).

**Test budget:** widget tests asserting on current widgets will be updated
as trees change (part of slices 2–6); text-finder journey tests should
largely survive. Final: `dart format`, `flutter analyze`, `flutter test`.

## 7. Completion notes (what actually happened)

- **Slices 1–7 all landed.** Added packages: `fl_chart ^1.2.0`
  (note: `duration`/`curve`, not the old `swapAnimation*` names),
  `animations` (installed for future shared-axis transitions; tab
  transitions stayed instant to protect journey-test determinism).
- **Motion:** every animation is one-shot (`TweenAnimationBuilder`,
  implicit) — no looping controllers, `pumpAndSettle`-safe. Reduced
  motion honored centrally via `SaldoMotion.resolve` (all kit widgets +
  charts snap when `MediaQuery.disableAnimations` is set). Only remaining
  indeterminate motion is genuine progress indicators.
- **Contrast (dark-only):** mint/coral/gold on ink all exceed 7:1;
  secondary `#8FA1B8` on background ≈ 5.5:1 — fine for secondary text.
  Type is never color-alone (labels/signs/semantics kept everywhere).
- **Responsive:** compact `<360dp` stacks the cash-flow strip and uses
  tighter gutters/hero; large `>414dp` gets 2-col account grids and roomier
  type. Matrix test (`responsive_matrix_test.dart`) pumps Home/Reports/
  transfer form at 320×640, 390×844, 430×932 × 1.0×/1.3× text.
- **Test-env lesson:** `flutter_test` renders variable fonts with 1em
  fallback advances (~2× real widths), flagging phantom overflows. The
  matrix loads both families via `FontLoader` in `setUpAll` so it measures
  device-faithful metrics. Journey scroll helpers were hardened the same
  week: sliver cache builds off-screen targets, so helpers finish with
  `ensureVisible(first)` + rest settle.
- **Deferred (documented, not forgotten):** amount previews on
  account/budget forms; `animations`-package tab transitions; light theme
  (explicitly out); on-device `integration_test` run (no device here —
  headless journey entries cover the flows).
- **Deleted dead code:** `app/shell_placeholder.dart`, placeholder
  `features/transactions/presentation/transactions_page.dart`.
- **Onboarding is real now:** `/onboarding` welcome → currency → first
  account, gated by `OnboardingGate` (set in `main()` from prefs; defaults
  to completed so tests land on `/`). New prefs keys
  (`onboardingCompleted`) are backup-tolerant (backup reads only known
  keys). Journey/widget tests pump past the gate unchanged.
