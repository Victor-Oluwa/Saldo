import 'package:flutter/material.dart';

/// Central Saldo color tokens — "Ruled Saldo": green-cast charcoal
/// surfaces, one restrained emerald accent for active states, progress and
/// positive amounts, coral reserved for expenses. Flat solids only, no
/// gradients. Do not scatter hex values across widgets; import from here.
abstract final class SaldoColors {
  static const background = Color(0xFF0F1312);
  static const surface = Color(0xFF161B19);
  static const elevated = Color(0xFF202724);
  static const primary = Color(0xFF34D399);
  static const textPrimary = Color(0xFFECF1EE);
  static const textSecondary = Color(0xFF93A39C);
  static const expense = Color(0xFFFB7185);
  static const border = Color(0xFF2A3430);

  /// Soft emerald tint used for the nav indicator and active chips —
  /// a quiet nod to the ruled lines of a paper saldo.
  static const primaryDim = Color(0x1F34D399);
}
