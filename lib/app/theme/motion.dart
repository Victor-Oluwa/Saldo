import 'package:flutter/widgets.dart';

/// Tokenized motion durations for Saldo.
///
/// Tiers: [micro] for ripples/taps, [component] for cards/sheets/charts,
/// [hero] for the saldo-line draw and page entrances, [staggerStep] for
/// the gap between staggered list items.
class MotionDurations {
  final Duration micro;
  final Duration component;
  final Duration hero;
  final Duration staggerStep;

  const MotionDurations({
    required this.micro,
    required this.component,
    required this.hero,
    required this.staggerStep,
  });

  static const full = MotionDurations(
    micro: Duration(milliseconds: 150),
    component: Duration(milliseconds: 300),
    hero: Duration(milliseconds: 600),
    staggerStep: Duration(milliseconds: 60),
  );

  /// Reduced-motion variant: every duration collapses to zero so animated
  /// widgets snap to their end state instead of playing motion.
  static const reduced = MotionDurations(
    micro: Duration.zero,
    component: Duration.zero,
    hero: Duration.zero,
    staggerStep: Duration.zero,
  );

  bool get isReduced => micro == Duration.zero;
}

/// Curves used across the app's expressive motion.
abstract final class SaldoCurves {
  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutBack;
  static const Curve gentle = Curves.easeInOutCubic;
}

/// Inherited override for motion durations (tests, previews).
/// Falls back to [MotionDurations.full] when absent.
class SaldoMotion extends InheritedWidget {
  final MotionDurations durations;

  const SaldoMotion({
    super.key,
    this.durations = MotionDurations.full,
    required super.child,
  });

  static MotionDurations of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SaldoMotion>()?.durations ??
      MotionDurations.full;

  /// Resolves the effective durations: honors the platform
  /// reduced-motion setting first, then any inherited override.
  static MotionDurations resolve(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return MotionDurations.reduced;
    }
    return of(context);
  }

  @override
  bool updateShouldNotify(SaldoMotion oldWidget) =>
      durations != oldWidget.durations;
}
