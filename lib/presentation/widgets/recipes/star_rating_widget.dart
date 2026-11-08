import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';

/// Interactive 5-star rating widget
/// Supports:
/// - Interactive rating (tap to rate 1-5)
/// - Read-only display mode
/// - Half-star visual display
/// - Customizable size and colors
class StarRatingWidget extends StatefulWidget {
  final double initialRating; // 0.0 to 5.0
  final Function(double)? onRatingChanged;
  final bool readOnly;
  final double size;
  final Color? filledColor;
  final Color? emptyColor;

  const StarRatingWidget({
    super.key,
    this.initialRating = 0.0,
    this.onRatingChanged,
    this.readOnly = false,
    this.size = 24.0,
    this.filledColor,
    this.emptyColor,
  });

  @override
  State<StarRatingWidget> createState() => _StarRatingWidgetState();
}

class _StarRatingWidgetState extends State<StarRatingWidget> {
  late double _currentRating;
  double? _hoverRating;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialRating;
  }

  @override
  void didUpdateWidget(StarRatingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRating != oldWidget.initialRating) {
      setState(() {
        _currentRating = widget.initialRating;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayRating = _hoverRating ?? _currentRating;
    final filledColor = widget.filledColor ?? AppColors.recipeStarGold;
    final emptyColor =
        widget.emptyColor ?? AppColors.recipeBorderColor(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starNumber = index + 1;
        return MouseRegion(
          onEnter: widget.readOnly
              ? null
              : (_) {
                  setState(() => _hoverRating = starNumber.toDouble());
                },
          onExit: widget.readOnly
              ? null
              : (_) {
                  setState(() => _hoverRating = null);
                },
          child: GestureDetector(
            onTap: widget.readOnly || widget.onRatingChanged == null
                ? null
                : () {
                    setState(() => _currentRating = starNumber.toDouble());
                    widget.onRatingChanged!(starNumber.toDouble());
                  },
            child: _buildStar(
              starNumber.toDouble(),
              displayRating,
              filledColor,
              emptyColor,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStar(
    double starNumber,
    double rating,
    Color filledColor,
    Color emptyColor,
  ) {
    IconData icon;
    Color color;

    if (rating >= starNumber) {
      // Fully filled star
      icon = Icons.star;
      color = filledColor;
    } else if (rating >= starNumber - 0.5) {
      // Half-filled star
      icon = Icons.star_half;
      color = filledColor;
    } else {
      // Empty star
      icon = Icons.star_border;
      color = emptyColor;
    }

    return Icon(icon, size: widget.size, color: color);
  }
}

/// Compact star rating display with numeric rating
/// Format: "★★★★☆ 4.2/5 (47 ratings)"
class CompactStarRating extends StatelessWidget {
  final double averageRating; // 0.0 to 5.0
  final int ratingCount;
  final double starSize;
  final bool showCount;

  const CompactStarRating({
    super.key,
    required this.averageRating,
    required this.ratingCount,
    this.starSize = 16.0,
    this.showCount = true,
  });

  @override
  Widget build(BuildContext context) {
    if (ratingCount == 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...List.generate(
            5,
            (index) => Icon(
              Icons.star_border,
              size: starSize,
              color: AppColors.recipeBorderColor(context),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            context.tr('no_ratings_yet'),
            style: TextStyle(
              fontSize: starSize * 0.85,
              color: Colors.grey[600],
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Stars visual
        ...List.generate(5, (index) {
          final starNumber = index + 1;
          IconData icon;
          Color color;

          if (averageRating >= starNumber) {
            icon = Icons.star;
            color = AppColors.recipeStarColor(context);
          } else if (averageRating >= starNumber - 0.5) {
            icon = Icons.star_half;
            color = AppColors.recipeStarColor(context);
          } else {
            icon = Icons.star_border;
            color = AppColors.recipeBorderColor(context);
          }

          return Icon(icon, size: starSize, color: color);
        }),
        const SizedBox(width: 4),
        // Numeric rating
        Text(
          '${averageRating.toStringAsFixed(1)}/5',
          style: TextStyle(
            fontSize: starSize * 0.85,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        // Rating count
        if (showCount) ...[
          const SizedBox(width: 2),
          Text(
            '($ratingCount)',
            style: TextStyle(
              fontSize: starSize * 0.75,
              color: Colors.grey[500],
            ),
          ),
        ],
      ],
    );
  }
}

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
                child: Icon(
                  i <= shown ? CupertinoIcons.star_fill : CupertinoIcons.star,
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
