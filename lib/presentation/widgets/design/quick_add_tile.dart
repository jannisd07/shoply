import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';

// D2 "Schnell wieder hinzufügen" (D2-Komponenten): tile 82 high, radius 20,
// image 44 / radius 10 at 8 from the top, label 6 below, plus disc 20 at
// 6 / 6.
const double _minHeight = 82; // D2
const double _topPadding = 8; // D2 padding-top 8
const double _bottomPadding = 8; // D2: 82 - 8 - 44 - 6 - 16
const double _sidePadding = AvoSpacing.xs; // keeps a wrapped label off the edge
const double _labelGap = 6; // D2 margin-top 6
const double _plusDisc = 20; // D2
const double _plusInset = 6; // D2 `top:6px; right:6px`
const double _plusGlyph = 14; // D2-Home: an 8 pt cross (14 × 14 / 24)
const double _plusStroke = 3.4; // D2-Home stroke 2 pt, in 24-unit icon space

/// Konzept 00 §12.20: unavailable controls at 40 %.
const double _disabledOpacity = 0.4;

/// A D2 "Schnell wieder hinzufügen" tile: the item image, its name and a
/// green plus disc at the top corner, on a neutral [AvoColors.fill] tile.
///
/// It takes the width it is given (a grid cell) and is at least 82 pt high;
/// the label wraps instead of being cut. One VoiceOver button "{name}
/// wieder hinzufügen" (`common_readd`). Scales down while pressed; no
/// haptic (a plain button, Konzept 00 §11).
class QuickAddTile extends StatelessWidget {
  /// Creates a re-add tile.
  const QuickAddTile({
    super.key,
    required this.name,
    this.label,
    this.thumb,
    this.onTap,
  });

  /// The item's full name, for VoiceOver ("Vollkornbrot").
  final String name;

  /// The visible, possibly shorter name ("Brot"); defaults to [name].
  final String? label;

  /// The image, laid out at 44 pt and clipped to radius 10 (an [ItemThumb]
  /// or Teil B's `ArticleImage`); without it a neutral square.
  final Widget? thumb;

  /// Puts the item back on the list. Null shows the tile dimmed.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onTap != null;

    final image = SizedBox.square(
      dimension: AvoSizes.thumbSmall,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AvoRadii.imageSmall),
        child: thumb ?? const ItemThumb(),
      ),
    );

    final plus = DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.tintFill,
        shape: const CircleBorder(),
      ),
      child: SizedBox.square(
        dimension: _plusDisc,
        child: Center(
          child: AvoIcon(
            AvoIcons.plus,
            size: _plusGlyph,
            strokeWidth: _plusStroke,
            color: colors.onTint,
          ),
        ),
      ),
    );

    Widget tile = DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AvoRadii.card),
        ),
      ),
      child: Stack(
        // The content gets the cell's width, so it centres in the tile.
        fit: StackFit.passthrough,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: _minHeight,
              minWidth: AvoSizes.hitTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                _sidePadding,
                _topPadding,
                _sidePadding,
                _bottomPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  image,
                  const SizedBox(height: _labelGap),
                  Text(
                    label ?? name,
                    textAlign: TextAlign.center,
                    style: context.text(
                      AvoTextStyle.caption1,
                      weight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          PositionedDirectional(top: _plusInset, end: _plusInset, child: plus),
        ],
      ),
    );
    if (!enabled) tile = Opacity(opacity: _disabledOpacity, child: tile);

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: context.tr('common_readd', params: {'name': name.trim()}),
      onTap: onTap,
      excludeSemantics: true,
      child: PressableScale(onPressed: onTap, child: tile),
    );
  }
}
