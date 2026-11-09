import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';

/// D2 X-Wochenplan recipe photo: 56 × 56, radius 14 (A-K6 asks for tokens).
const double kPlanThumbSize = 56; // D2
const double _kThumbRadius = 14; // D2

/// The colour stored with a recipe snapshot (`#RRGGBB`), or null.
Color? planPhotoColor(String? hex) {
  final h = (hex ?? '').replaceFirst('#', '');
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

/// A recipe's photo in plan rows (S1, S2, S6, S8). Decorative for
/// VoiceOver (the title next to it says what it is). Until the photo is
/// there a flat surface in the stored photo colour, without a photo `fill`.
class PlanRecipeThumb extends StatelessWidget {
  const PlanRecipeThumb({super.key, this.imageUrl, this.photoColor, this.size = kPlanThumbSize});

  final String? imageUrl;
  final String? photoColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final url = imageUrl ?? '';
    final placeholder = planPhotoColor(photoColor) ?? colors.fill;
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kThumbRadius),
        child: SizedBox.square(
          dimension: size,
          child: url.isEmpty
              ? ColoredBox(color: colors.fill)
              : CachedNetworkImage(
                  imageUrl: url,
                  memCacheWidth: pixels,
                  fit: BoxFit.cover,
                  fadeInDuration: context.reduceMotion ? Duration.zero : AvoMotion.fadeReduced,
                  placeholder: (_, _) => ColoredBox(color: placeholder),
                  errorWidget: (_, _, _) => ColoredBox(color: colors.fill),
                ),
        ),
      ),
    );
  }
}
