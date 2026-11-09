import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/food_product.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_amount_food.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/presentation/state/calorie_diary_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';

// D2 X-Essen cards: 300 high (at least; they grow with large text), radius
// 26, symbol 34; rows 60 with a 44 image.
const double _kCardMinHeight = 300; // D2
const double _kCardGlyph = 34; // D2
const double _kRowMin = 60; // D2
const double _kRowVertical = 9; // D2

final Uri _kOffSite = Uri.parse('https://world.openfoodfacts.org');

/// What the segments of S3 hand back to the screen: it knows meal, day and
/// where each next screen opens.
class CalorieAddActions {
  const CalorieAddActions({
    required this.openAmount,
    required this.openManual,
    required this.openScanner,
    required this.takePhoto,
    required this.pickPhoto,
    required this.logAgain,
  });

  /// S7 for this food.
  final void Function(CalorieAmountFood food) openAmount;

  /// S8, with the search text or a barcode.
  final void Function({String? name, String? barcode}) openManual;

  /// S6.
  final VoidCallback openScanner;

  /// The camera question, then S4.
  final Future<void> Function() takePhoto;

  /// The system photo picker, then S5.
  final Future<void> Function() pickPhoto;

  /// "Zuletzt gegessen": logs at once; true when it was queued.
  final Future<bool> Function(RecentFood food) logAgain;
}

/// "Skyr Natur · 63 kcal pro 100 g" (brand and kcal of a hit).
String calorieProductLine(BuildContext context, FoodProduct p) {
  final kcal = p.caloriesPer100g;
  final brand = p.brand?.trim();
  if (kcal == null) return brand ?? '';
  final per = context.tr(p.isLiquid ? 'cal_kcal_per_100ml' : 'cal_kcal_per_100g', params: {'kcal': context.kcal(kcal)});
  return brand == null || brand.isEmpty ? per : '$brand · $per';
}

/// The photo and barcode cards (D2 X-Essen: at least 300 high, radius 26,
/// `fill`, the symbol 34 in grey, a sentence, the actions).
class CalorieSegmentCard extends StatelessWidget {
  const CalorieSegmentCard({super.key, required this.glyph, required this.text, required this.children});

  /// The symbol (34 pt, grey from the card).
  final Widget glyph;
  final String text;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.fill, borderRadius: BorderRadius.circular(AvoRadii.group)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _kCardMinHeight, minWidth: double.infinity),
          child: Padding(
            padding: const EdgeInsets.all(AvoSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: IconStyleScope(size: _kCardGlyph, color: colors.secondaryLabel, child: glyph),
                ),
                const SizedBox(height: AvoSpacing.m),
                Text(text, textAlign: TextAlign.center, style: context.text(AvoTextStyle.body)),
                const SizedBox(height: AvoSpacing.l),
                for (final c in children) ...[c, const SizedBox(height: AvoSpacing.xs)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A food hit (own food, Open Food Facts, recent scan): optional 44 pt
/// product photo on white (gone from AX1 on), name, "Milbona · 63 kcal pro
/// 100 g", chevron; opens S7.
class CalorieFoodRow extends StatelessWidget {
  const CalorieFoodRow({
    super.key,
    required this.name,
    required this.subtitle,
    required this.onTap,
    this.imageUrl,
    this.reserveImage = false,
  });

  final String name;
  final String subtitle;
  final String? imageUrl;
  final bool reserveImage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final image = imageUrl;
    final showImage = reserveImage && !context.isAccessibilityText;
    return Semantics(
      container: true,
      button: true,
      label: [name, if (subtitle.isNotEmpty) subtitle].join(', '),
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _kRowMin),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l, vertical: _kRowVertical),
            child: Row(
              children: [
                if (showImage) ...[
                  SizedBox.square(
                    dimension: AvoSizes.thumbSmall,
                    child: image == null
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.fill,
                              borderRadius: BorderRadius.circular(AvoRadii.imageSmall),
                            ),
                          )
                        : ItemThumb(image: NetworkImage(image)),
                  ),
                  const SizedBox(width: AvoSpacing.m),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name, style: context.text(AvoTextStyle.body)),
                      if (subtitle.isNotEmpty)
                        Text(subtitle, style: context.text(AvoTextStyle.subhead, color: colors.secondaryLabel)),
                    ],
                  ),
                ),
                const SizedBox(width: AvoSpacing.s),
                ExcludeSemantics(
                  child: AvoIcon(AvoIcons.chevronRight, size: AvoSpacing.l, color: colors.tertiaryLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Daten: Open Food Facts" as a link (the source Open Food Facts asks for).
class OffSourceLink extends StatelessWidget {
  const OffSourceLink({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = context.tr('cal_off_source');
    void open() => unawaited(launchUrl(_kOffSite, mode: LaunchMode.externalApplication));
    return Semantics(
      link: true,
      label: text,
      onTap: open,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AvoSpacing.screen + AvoSpacing.l, AvoSpacing.s, AvoSpacing.screen, 0),
            child: Text(text, style: context.text(AvoTextStyle.footnote, color: color)),
          ),
        ),
      ),
    );
  }
}
