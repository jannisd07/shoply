import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

// D2 offer pill (D2-Komponenten, D2-Liste, X-Einkaufsmodus `.offer`).
const EdgeInsets _kSmallPadding = EdgeInsets.symmetric(
  horizontal: 8,
  vertical: 3,
); // D2
const double _kSmallIcon = 11; // D2 questionmark.circle
const double _kSmallIconGap = 3; // D2

// Large price of the offer detail (S5).
const EdgeInsets _kLargePadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 6,
); // D2
const double _kLargeRadius = 22; // D2

/// The small pill grows with Dynamic Type up to AX2 (Konzept 00 §6.4).
const double _kSmallMaxScale = 33 / 17; // D2 AX2 cap (Konzept 00 §6.4)

/// The large price stops at AX3, where `title1` is 48 pt (at most 51 pt).
const double _kLargeMaxScale = 40 / 17; // D2 AX3 cap (angebote.md 2.3)

/// Size of an [OfferPriceTag].
enum OfferPriceTagSize {
  /// 11/13 semibold pill at item rows and offer rows.
  small,

  /// 28/34 bold price of the offer detail, at least 44 pt high.
  large,
}

/// The offer pill (`angebote.md` 2.3): green [AvoColors.tint] on
/// [AvoColors.tintSoft], tabular figures. Small: "0,99 €", with a market for
/// lists without one ("0,99 € · Lidl"), with a leading question mark for a
/// similar product. Large: the price of the offer detail.
///
/// It has no semantics of its own: the row it sits in says the whole
/// sentence ("im Angebot 0,99 Euro laut Händler").
class OfferPriceTag extends StatelessWidget {
  const OfferPriceTag({
    super.key,
    required this.price,
    this.store,
    this.uncertain = false,
    this.size = OfferPriceTagSize.small,
  });

  /// The formatted price, "0,99 €" / "€0.99".
  final String price;

  /// Market name after the price ("· Lidl"), only where markets mix.
  final String? store;

  /// A similar product, not the item itself: leading question mark.
  final bool uncertain;

  final OfferPriceTagSize size;

  @override
  Widget build(BuildContext context) {
    final large = size == OfferPriceTagSize.large;
    // The style is read below the clamp, so size and scale agree.
    return ExcludeSemantics(
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: large ? _kLargeMaxScale : _kSmallMaxScale,
        child: Builder(builder: _pill),
      ),
    );
  }

  Widget _pill(BuildContext context) {
    final colors = context.colors;
    final large = size == OfferPriceTagSize.large;
    final text = store == null ? price : '$price · $store';
    final style = large
        ? context.text(AvoTextStyle.title1, color: colors.tint, tabular: true)
        : context.text(
            AvoTextStyle.caption2,
            color: colors.tint,
            weight: FontWeight.w600,
            tabular: true,
          );
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (uncertain) ...[
          AvoIcon(
            OfferIcons.questionmarkCircle,
            size: large
                ? context.typography.sizeOf(AvoTextStyle.title1)
                : MediaQuery.textScalerOf(context).scale(_kSmallIcon),
            color: colors.tint,
          ),
          const SizedBox(width: _kSmallIconGap),
        ],
        Flexible(child: Text(text, style: style)),
      ],
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.tintSoft,
        shape: large
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_kLargeRadius),
              )
            : const StadiumBorder(),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: large ? AvoSizes.hitTarget : 0),
        child: Padding(
          padding: large ? _kLargePadding : _kSmallPadding,
          child: large ? Center(widthFactor: 1, child: content) : content,
        ),
      ),
    );
  }
}
