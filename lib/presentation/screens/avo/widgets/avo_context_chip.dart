import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

// D2 context capsule (Kap. 2.9): fill, at least 32 high, padding 0 6 0 12,
// glyph 15, name 15/20, xmark 13 in its own 44 × 44 hit area.
const double _minHeight = 32; // D2
const double _padStart = 12; // D2
const double _padEnd = 6; // D2
const double _glyph = 15; // D2
const double _xmark = 13; // D2
const double _gap = 6; // D2

/// "Avo bezieht sich auf Wocheneinkauf": the screen Avo will read, left
/// above the composer, with an X to leave it out.
///
/// The name stays on one line, from AX1 it wraps to two.
class AvoContextChip extends StatelessWidget {
  const AvoContextChip({
    super.key,
    required this.name,
    required this.onRemove,
    this.icon = AvoIcons.cart,
  });

  final String name;
  final VoidCallback onRemove;
  final AvoIconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ax = context.isAccessibilityText;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: context.reduceTransparency ? colors.surface : colors.fill,
          shape: const StadiumBorder(),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minHeight),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: _padStart,
              end: _padEnd,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: AvoIcon(
                    icon,
                    size: _glyph,
                    color: colors.secondaryLabel,
                  ),
                ),
                const SizedBox(width: _gap),
                Flexible(
                  child: Semantics(
                    label: context.tr(
                      'avo_context_label',
                      params: {'name': name},
                    ),
                    child: ExcludeSemantics(
                      child: Text(
                        name,
                        maxLines: ax ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text(AvoTextStyle.subhead),
                      ),
                    ),
                  ),
                ),
                Semantics(
                  container: true,
                  button: true,
                  label: context.tr(
                    'avo_context_remove',
                    params: {'name': name},
                  ),
                  onTap: onRemove,
                  excludeSemantics: true,
                  child: PressableScale(
                    onPressed: onRemove,
                    child: SizedBox.square(
                      dimension: AvoSizes.hitTarget,
                      child: Center(
                        child: AvoIcon(
                          AvoIcons.xmark,
                          size: _xmark,
                          color: colors.secondaryLabel,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
