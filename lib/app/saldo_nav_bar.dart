import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme/colors.dart';
import 'theme/motion.dart';

/// One destination in the [SaldoNavBar].
class SaldoNavDestination {
  const SaldoNavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Saldo's signature navigation — a floating charcoal capsule with
/// minimal line icons and a soft emerald indicator that glides between
/// destinations. Selection fires a restrained haptic tick; motion honors
/// the platform reduced-motion setting. No glow, no gradients.
class SaldoNavBar extends StatelessWidget {
  const SaldoNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<SaldoNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const double barHeight = 66;
  static const double _iconZoneHeight = 34;

  @override
  Widget build(BuildContext context) {
    final durations = SaldoMotion.resolve(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: SaldoColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SaldoColors.border, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: barHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final count = destinations.length;
              final itemWidth = constraints.maxWidth / count;
              final pillWidth = (itemWidth - 12).clamp(40.0, 56.0);
              final pillLeft =
                  itemWidth * selectedIndex + (itemWidth - pillWidth) / 2;

              return Stack(
                children: [
                  // Gliding emerald indicator — the app's "ruling line".
                  AnimatedPositioned(
                    duration: durations.component,
                    curve: SaldoCurves.standard,
                    left: pillLeft,
                    top: 7,
                    child: IgnorePointer(
                      child: Container(
                        width: pillWidth,
                        height: _iconZoneHeight,
                        decoration: BoxDecoration(
                          color: SaldoColors.primaryDim,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < count; i++)
                        Expanded(
                          child: _NavItem(
                            destination: destinations[i],
                            selected: i == selectedIndex,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onDestinationSelected(i);
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final SaldoNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.labelSmall;
    final labelStyle = (base ?? const TextStyle()).copyWith(
      fontSize: 10.5,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      color: selected ? SaldoColors.primary : SaldoColors.textSecondary,
    );

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        splashColor: SaldoColors.primaryDim,
        highlightColor: SaldoColors.primaryDim,
        child: Column(
          children: [
            const SizedBox(height: 7),
            SizedBox(
              height: SaldoNavBar._iconZoneHeight,
              child: Center(
                child: Icon(
                  selected ? destination.activeIcon : destination.icon,
                  size: 22,
                  color: selected
                      ? SaldoColors.primary
                      : SaldoColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 15,
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: SaldoMotion.resolve(context).micro,
                  style: labelStyle,
                  child: Text(destination.label, maxLines: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
