import 'package:flutter/widgets.dart';

/// Phone-only responsive tiers (see docs/plans/ui-redesign.md).
///
/// compact: <360dp (small phones) · standard: 360–414dp ·
/// large: >414dp (large phones, landscape widths).
enum SaldoWidthTier { compact, standard, large }

abstract final class SaldoBreakpoints {
  static const double compactMax = 360;
  static const double largeMin = 414;

  static SaldoWidthTier tierFor(double width) => width < compactMax
      ? SaldoWidthTier.compact
      : (width >= largeMin ? SaldoWidthTier.large : SaldoWidthTier.standard);
}

extension SaldoResponsive on BuildContext {
  double get saldoWidth => MediaQuery.sizeOf(this).width;

  SaldoWidthTier get saldoTier => SaldoBreakpoints.tierFor(saldoWidth);

  /// Page gutter: generous by default for a spacious, calm feel.
  double get saldoGutter => switch (saldoTier) {
    SaldoWidthTier.compact => 16,
    SaldoWidthTier.large => 24,
    SaldoWidthTier.standard => 20,
  };

  /// Hero numeral size for the balance display.
  double get saldoHeroSize => switch (saldoTier) {
    SaldoWidthTier.compact => 28,
    SaldoWidthTier.large => 34,
    SaldoWidthTier.standard => 30,
  };

  /// Account/card grid columns: two-up only on large phones.
  int get saldoGridColumns => saldoTier == SaldoWidthTier.large ? 2 : 1;
}
