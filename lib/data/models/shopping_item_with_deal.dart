import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/extracted_deal_model.dart';

/// Erweitertes Model für ShoppingItems mit Deal-Informationen
class ShoppingItemWithDeal {
  final ShoppingItemModel item;
  final ExtractedDeal? activeDeal;
  final int availableDealsCount;

  const ShoppingItemWithDeal({
    required this.item,
    this.activeDeal,
    this.availableDealsCount = 0,
  });

  /// Prüft ob ein aktives Angebot vorhanden ist
  bool get hasActiveDeal => activeDeal != null;

  /// Gibt die Ersparnis zurück (falls Angebot vorhanden)
  double get savings => activeDeal?.savings ?? 0.0;

  /// Gibt den Rabatt-Prozentsatz zurück
  double get discountPercentage => activeDeal?.discountPercentage ?? 0.0;

  /// Formatierter Rabatt-Text
  String get discountText => activeDeal?.formattedDiscount ?? '';

  /// Preis mit Angebot
  String get dealPrice => activeDeal?.formattedDiscountedPrice ?? '';

  /// Ursprungspreis
  String get originalPrice => activeDeal?.formattedOriginalPrice ?? '';

  /// Supermarkt mit Angebot
  String get dealSupermarket => activeDeal?.supermarket ?? '';

  /// Erstellt eine Kopie mit Deal
  ShoppingItemWithDeal copyWith({
    ShoppingItemModel? item,
    ExtractedDeal? activeDeal,
    int? availableDealsCount,
  }) {
    return ShoppingItemWithDeal(
      item: item ?? this.item,
      activeDeal: activeDeal ?? this.activeDeal,
      availableDealsCount: availableDealsCount ?? this.availableDealsCount,
    );
  }
}
