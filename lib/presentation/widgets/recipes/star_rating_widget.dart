import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

/// Stars stop growing with Dynamic Type at xxxL (glyphs, Konzept 00 E-04).
const double _starGrowthLimit = 23 / 17;

/// Star glyph at the default text size (SF Symbol next to 17 pt text).
const double _starSize = 24;

/// "Deine Bewertung" with five stars in the accent colour (Konzept 13
/// §12.1 Nr. 10, D2): every star is a 44 pt target; tapping star 4 fills
/// 1 to 4, dragging across follows the finger with the selection haptic per
/// star (Konzept 13 E-13). VoiceOver: one adjustable element, "Deine
/// Bewertung, 4 von 5 Sternen", swipe up or down to change. From AX1 on the
/// stars move below the title.
class RecipeRatingRow extends StatefulWidget {
  const RecipeRatingRow({
    super.key,
    required this.rating,
    required this.onRate,
  });

  /// The person's rating, 1 to 5; null when not rated yet.
  final int? rating;

  /// Called with the new rating (1 to 5).
  final ValueChanged<int> onRate;

  @override
  State<RecipeRatingRow> createState() => _RecipeRatingRowState();
}

class _RecipeRatingRowState extends State<RecipeRatingRow> {
  int? _dragging;

  int _starAt(double dx) => (dx / AvoSizes.hitTarget).floor().clamp(0, 4) + 1;

  void _dragTo(double dx) {
    final star = _starAt(dx);
    if (star == _dragging) return;
    setState(() => _dragging = star);
    unawaited(AvoHaptics.selection());
  }

  void _endDrag() {
    final star = _dragging;
    setState(() => _dragging = null);
    if (star != null) widget.onRate(star);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shown = _dragging ?? widget.rating ?? 0;
    final scale =
        (context.typography.sizeOf(AvoTextStyle.body) /
                AvoTypography.forFactor(1).sizeOf(AvoTextStyle.body))
            .clamp(1.0, _starGrowthLimit);
    final title = context.tr('recipe_detail_your_rating');
    final value = widget.rating == null
        ? context.tr('recipe_detail_not_rated')
        : context.tr('recipe_detail_stars', params: {'n': '${widget.rating}'});
    final current = widget.rating ?? 0;

    final stars = GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTapUp: (d) => widget.onRate(_starAt(d.localPosition.dx)),
      onHorizontalDragStart: (d) => _dragTo(d.localPosition.dx),
      onHorizontalDragUpdate: (d) => _dragTo(d.localPosition.dx),
      onHorizontalDragEnd: (_) => _endDrag(),
      onHorizontalDragCancel: () => setState(() => _dragging = null),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            SizedBox.square(
              dimension: AvoSizes.hitTarget,
              child: Center(
                child: AvoIcon(
                  AvoIcons.star,
                  filled: i <= shown,
                  size: _starSize * scale,
                  color: colors.tint,
                ),
              ),
            ),
        ],
      ),
    );

    final label = Text(title, style: context.text(AvoTextStyle.body));
    return Semantics(
      container: true,
      label: title,
      value: value,
      increasedValue: context.tr(
        'recipe_detail_stars',
        params: {'n': '${(current + 1).clamp(1, 5)}'},
      ),
      decreasedValue: context.tr(
        'recipe_detail_stars',
        params: {'n': '${(current - 1).clamp(1, 5)}'},
      ),
      onIncrease: current < 5 ? () => widget.onRate(current + 1) : null,
      onDecrease: current > 1 ? () => widget.onRate(current - 1) : null,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AvoSpacing.l,
            vertical: AvoSpacing.xs,
          ),
          child: context.isAccessibilityText
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: AvoSpacing.s),
                      child: label,
                    ),
                    stars,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: label),
                    const SizedBox(width: AvoSpacing.s),
                    stars,
                  ],
                ),
        ),
      ),
    );
  }
}
