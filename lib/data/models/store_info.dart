import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart' show Color;

/// The market of a list as the screens show it: StoreChip, shopping mode,
/// presence text ("Lena kauft gerade bei Lidl ein"), aisle order.
@immutable
class StoreInfo {
  const StoreInfo({
    required this.id,
    required this.name,
    required this.shortLabel,
    this.brandColor,
  });

  /// Chain id, e.g. `lidl`, `aldi-sued`.
  final String id;

  /// Display name, e.g. "Lidl", "Aldi Süd".
  final String name;

  /// One or two letters for the D2 letter tile, e.g. "L", "AS".
  final String shortLabel;

  /// Colour of the letter tile; null when none is on file.
  final Color? brandColor;

  @override
  bool operator ==(Object other) =>
      other is StoreInfo &&
      other.id == id &&
      other.name == name &&
      other.shortLabel == shortLabel &&
      other.brandColor == brandColor;

  @override
  int get hashCode => Object.hash(id, name, shortLabel, brandColor);
}
