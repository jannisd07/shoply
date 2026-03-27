import 'package:flutter/material.dart';
import 'package:shoply/core/constants/app_colors.dart';

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
    final emptyColor = widget.emptyColor ?? AppColors.recipeBorderColor(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starNumber = index + 1;
        return MouseRegion(
          onEnter: widget.readOnly ? null : (_) {
            setState(() => _hoverRating = starNumber.toDouble());
          },
          onExit: widget.readOnly ? null : (_) {
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

    return Icon(
      icon,
      size: widget.size,
      color: color,
    );
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
            'No ratings yet',
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

/// Large star rating display for recipe detail page
/// Shows stars, numeric rating, and allows user to rate
class LargeStarRating extends StatelessWidget {
  final double averageRating;
  final int ratingCount;
  final int? userRating;
  final Function(double) onRate;

  const LargeStarRating({
    super.key,
    required this.averageRating,
    required this.ratingCount,
    this.userRating,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Average rating display
        Row(
          children: [
            Text(
              averageRating.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CompactStarRating(
                  averageRating: averageRating,
                  ratingCount: ratingCount,
                  starSize: 20,
                  showCount: false,
                ),
                Text(
                  '$ratingCount rating${ratingCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        // User rating section - always show rating widget
        Text(
          userRating == null ? 'Rate this recipe:' : 'Your rating:',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        StarRatingWidget(
          key: ValueKey(userRating), // Force rebuild when rating changes
          initialRating: userRating?.toDouble() ?? 0,
          onRatingChanged: onRate,
          size: 32,
        ),
      ],
    );
  }
}
