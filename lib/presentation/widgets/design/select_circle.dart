import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/check_circle.dart';

// D2 selection circle (E-08): 22 pt glyph in a 44 pt target, stroke like the
// check circle's ring.
const double _ring = 1.6; // D2, as CheckCircle
const double _fadeOpacity = 0.45; // iOS, as CheckCircle's disabled dimming

/// The circle of a row that is selected, not done (A-C9 / A-V2): choose
/// recipes, stores or items for a bulk action.
///
/// Selected: [AvoIcons.checkmarkCircleFill] in `tint`. Not selected: a ring
/// in `uncheckedRing`. It is deliberately not a [CheckCircle]: no strike
/// through, no haptic, no spring. VoiceOver reads it as a switch (`toggled`)
/// with [semanticLabel] ("Spaghetti Bolognese"). A tap reports `!selected`;
/// null [onChanged] disables it (dimmed).
class SelectCircle extends StatelessWidget {
  /// Creates a selection circle.
  const SelectCircle({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.semanticLabel,
  });

  /// Whether the row is selected.
  final bool selected;

  /// Called with `!selected` on tap; null disables the circle.
  final ValueChanged<bool>? onChanged;

  /// VoiceOver name of what is being selected.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onChanged != null;
    const diameter = CheckCircle.smallDiameter;

    Widget glyph = SizedBox.square(
      dimension: AvoSizes.hitTarget,
      child: Center(
        child: selected
            ? AvoIcon(
                AvoIcons.checkmarkCircleFill,
                size: diameter,
                color: colors.tint,
              )
            : SizedBox.square(
                dimension: diameter,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: CircleBorder(
                      side: BorderSide(
                        color: colors.uncheckedRing,
                        width: _ring,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
    if (!enabled) glyph = Opacity(opacity: _fadeOpacity, child: glyph);

    return Semantics(
      container: true,
      toggled: selected,
      enabled: enabled,
      label: semanticLabel,
      onTap: enabled ? () => onChanged!(!selected) : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: enabled ? () => onChanged!(!selected) : null,
          child: glyph,
        ),
      ),
    );
  }
}
