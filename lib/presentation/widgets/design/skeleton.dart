import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';

/// Row height of an item row (D2 Komponenten: 60).
const double _kRowMinHeight = 60; // D2

/// Placeholder circle where the check circle sits (A2 digest: 24 pt).
const double _kCircleSize = 24;

/// Bar widths per row, repeating (A2 digest: 55/40/70/35/60 %).
const List<double> _kBarWidths = [0.55, 0.40, 0.70, 0.35, 0.60];

/// A bar is this share of the body text size high, so it grows with
/// Dynamic Type like the text it stands for.
const double _kBarToText = 0.7;

/// Calm placeholder of a list section for the very first load without any
/// local data (Konzept 00 §13): grey shapes in the `fill` colour where rows
/// will be. Static on purpose: no shimmer, no endless animation (owner rule).
///
/// VoiceOver sees one element, [loadingLabel] ("Wird geladen"). Like
/// `InsetSection` it turns plain from AX1 on and then drops the image
/// placeholders. Never use a spinner instead.
class SkeletonSection extends StatelessWidget {
  /// Creates a placeholder section with [rows] rows.
  const SkeletonSection({
    super.key,
    this.rows = 3,
    this.withImage = true,
    this.loadingLabel,
  }) : assert(rows > 0);

  /// Number of placeholder rows.
  final int rows;

  /// Shows a 44 pt image placeholder per row (item rows); hidden from AX1 on.
  final bool withImage;

  /// What VoiceOver reads; defaults to the existing `loading` text.
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final showImage = withImage && !context.isAccessibilityText;
    final barHeight =
        context.typography.sizeOf(AvoTextStyle.body) * _kBarToText;
    final shape = BoxDecoration(
      color: colors.fill,
      borderRadius: BorderRadius.circular(AvoRadii.capsule(barHeight)),
    );

    Widget row(int index) => ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kRowMinHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AvoSpacing.l,
          vertical: AvoSpacing.s,
        ),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.fill,
                shape: BoxShape.circle,
              ),
              child: const SizedBox.square(dimension: _kCircleSize),
            ),
            const SizedBox(width: AvoSpacing.m),
            if (showImage) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.fill,
                  borderRadius: BorderRadius.circular(AvoRadii.imageSmall),
                ),
                child: const SizedBox.square(dimension: AvoSizes.thumbSmall),
              ),
              const SizedBox(width: AvoSpacing.m),
            ],
            Expanded(
              child: FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: _kBarWidths[index % _kBarWidths.length],
                child: DecoratedBox(
                  decoration: shape,
                  child: SizedBox(height: barHeight),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      container: true,
      label: loadingLabel ?? context.tr('loading'),
      child: ExcludeSemantics(
        child: InsetSection(
          showSeparators: false,
          children: [for (var i = 0; i < rows; i++) row(i)],
        ),
      ),
    );
  }
}
