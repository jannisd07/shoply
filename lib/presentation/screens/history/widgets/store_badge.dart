import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/data/services/store_chain_directory.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

// D2-FuerDich §9 store tile: 40 × 40, radius 10, the brand at 12 % on the
// surface, the first letter 17/22 bold in the brand colour.
const double _kTile = 40; // D2
const double _kTint = 0.12; // D2
const double _kGlyph = 20; // D2 cart without a store
const double _kMinContrast = 4.5;

/// The market of a trip as a pastel tile with its first letter
/// (verlauf-kosten.md 2.3, owner question 1). Without a chain: `cart` on
/// `fill`. Decorative for VoiceOver; the name stands beside it.
///
/// The letter is darkened (light mode) or lightened (dark mode) until it
/// reaches 4.5:1 against the tile, in every mode.
class StoreBadge extends StatelessWidget {
  const StoreBadge({super.key, required this.chainId});

  final String? chainId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final id = chainId;
    final chain = id == null ? null : StoreChainDirectory.byId(id);
    final brand = chain?.brandColor;
    final Color fill;
    final Widget content;
    if (chain == null) {
      fill = colors.fill;
      content = AvoIcon(
        AvoIcons.cart,
        size: _kGlyph,
        color: colors.secondaryLabel,
      );
    } else {
      fill = brand == null
          ? colors.fill
          : Color.alphaBlend(brand.withValues(alpha: _kTint), colors.surface);
      // `label` is dark in light mode and light in dark mode: the letter
      // moves towards it until it reads.
      final ink = brand == null
          ? colors.label
          : readableInk(brand, fill, towards: colors.label);
      content = Text(
        chain.displayName.characters.first.toUpperCase(),
        style: context.text(
          AvoTextStyle.headline,
          color: ink,
          weight: FontWeight.w700,
        ),
        textScaler: TextScaler.noScaling,
      );
    }
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: _kTile,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AvoRadii.imageSmall),
          ),
          child: Center(child: content),
        ),
      ),
    );
  }
}

/// [brand] moved towards [towards] until it reads at 4.5:1 on
/// [background].
Color readableInk(Color brand, Color background, {required Color towards}) {
  final target = towards;
  var ink = brand;
  for (var i = 0; i <= 20; i++) {
    if (contrastRatio(ink, background) >= _kMinContrast) return ink;
    ink = Color.lerp(brand, target, i / 20)!;
  }
  return target;
}

/// WCAG contrast of two opaque colours.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
