import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';

/// Footnote under a group: 6 pt below it, 32 pt from the screen edges (D2
/// X-Angebote `.ft`), 16 pt from AX1 on where groups run edge to edge.
const double _kTop = 6; // D2
const double _kSide = AvoSpacing.xxxl; // D2 32

/// The source footnote of every surface with price details (`angebote.md`
/// 3.3): "Angebote gelten für deine Region, nicht für einen bestimmten
/// Markt. Preise sind Angaben des Händlers; Normalpreise kennt die App
/// nicht. Quelle: Händlerprospekte." One widget, so the mandatory wording
/// never drifts apart. 13/18 `secondaryLabel`.
class OffersSourceFootnote extends StatelessWidget {
  const OffersSourceFootnote({super.key});

  @override
  Widget build(BuildContext context) {
    final side = context.isAccessibilityText ? AvoSpacing.l : _kSide;
    return Padding(
      padding: EdgeInsets.fromLTRB(side, _kTop, side, 0),
      child: Text(
        context.tr(
          'offer_source_footnote',
          params: {'source': context.tr('offer_source_placeholder')},
        ),
        style: context.text(
          AvoTextStyle.footnote,
          color: context.colors.secondaryLabel,
        ),
      ),
    );
  }
}
