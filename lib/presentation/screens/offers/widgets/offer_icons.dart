import 'package:shoply/presentation/widgets/design/avo_icons.dart';

/// Glyphs the offer surfaces need and `AvoIcons` does not have yet (request
/// A-C10). Drawn on the 24 grid in the weight of the D2 set; they move to
/// `AvoIcons` once Teil A adds them.
abstract final class OfferIcons {
  /// Store front ("Markt wählen", "Anderer Markt …"), 16 pt in chips. // D2
  static const storefront = AvoIconData([
    AvoIconPath('M4.5 9.2 5.8 4h12.4l1.3 5.2'),
    AvoIconPath(
      'M4.5 9.2a2.5 2.5 0 0 0 5 0 2.5 2.5 0 0 0 5 0 2.5 2.5 0 0 0 5 0',
    ),
    AvoIconPath('M5.8 12v8h12.4v-8'),
    AvoIconPath('M10 20v-4.5h4V20'),
  ], strokeWidth: 1.8);

  /// Question mark in a circle: an offer for a similar product (11 pt in
  /// the pill, 22 pt in the detail). // D2
  static const questionmarkCircle = AvoIconData([
    AvoIconCircle(12, 12, 9),
    AvoIconPath('M9.6 9.6a2.5 2.5 0 0 1 4.9.6c0 1.7-2.5 2.1-2.5 3.9'),
    AvoIconCircle(12, 17.2, 1.1, style: AvoIconStyle.fill),
  ], strokeWidth: 2);
}
