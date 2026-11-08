import 'package:flutter/foundation.dart';

import 'package:shoply/core/constants/categories.dart';
import 'package:shoply/core/utils/product_name_normalizer.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/open_food_facts_service.dart'
    show isValidBarcode;

/// Normalized item name → illustration key; the picture is
/// `assets/illustrations/<key>.webp` (naming: `assets/illustrations/README.md`).
///
/// Empty until the owner has made the pictures
/// (`docs/redesign/artikelbilder-prompts.md`). Keys are written the way
/// [normalizeProductName] returns them ("gruene bohnen", not "Grüne
/// Bohnen"); several names may share one picture. A test fails when a key is
/// not normalized, its file is missing or `pubspec.yaml` does not bundle
/// `assets/illustrations/`.
const Map<String, String> articleIllustrationKeys = {};

/// One picture an article image can show. [ArticleImageResolver] lists them
/// in priority order; the widget shows the first one that is available.
@immutable
sealed class ArticleImageSource {
  const ArticleImageSource();
}

/// An own illustration (in the D2 style of cut-out product photos).
final class IllustrationImage extends ArticleImageSource {
  const IllustrationImage(this.key);

  final String key;

  String get assetPath => 'assets/illustrations/$key.webp';

  @override
  bool operator ==(Object other) =>
      other is IllustrationImage && other.key == key;

  @override
  int get hashCode => Object.hash(IllustrationImage, key);

  @override
  String toString() => 'IllustrationImage($key)';
}

/// The Open Food Facts front photo of a scanned product (CC BY-SA, with
/// credit). Only for items with a valid barcode, never for loose goods.
final class OffPhotoImage extends ArticleImageSource {
  const OffPhotoImage(this.barcode);

  final String barcode;

  @override
  bool operator ==(Object other) =>
      other is OffPhotoImage && other.barcode == barcode;

  @override
  int get hashCode => Object.hash(OffPhotoImage, barcode);

  @override
  String toString() => 'OffPhotoImage($barcode)';
}

/// The symbol of the item's category: a built-in category ID such as
/// `'dairy'`, or [ArticleImageResolver.customCategory] for own categories.
final class CategorySymbolImage extends ArticleImageSource {
  const CategorySymbolImage(this.categoryId);

  final String categoryId;

  @override
  bool operator ==(Object other) =>
      other is CategorySymbolImage && other.categoryId == categoryId;

  @override
  int get hashCode => Object.hash(CategorySymbolImage, categoryId);

  @override
  String toString() => 'CategorySymbolImage($categoryId)';
}

/// A neutral square in `fill`: keeps the row's layout when nothing else is
/// available.
final class NeutralImage extends ArticleImageSource {
  const NeutralImage();

  @override
  bool operator ==(Object other) => other is NeutralImage;

  @override
  int get hashCode => (NeutralImage).hashCode;

  @override
  String toString() => 'NeutralImage()';
}

/// Decides which pictures an item can have (B4, Recht: research
/// "Preise Angebote und Artikelbilder"):
///
/// 1. own illustration, when the name maps to a key in [illustrations];
/// 2. Open Food Facts photo, only with a barcode (a scanned or picked brand
///    product); never retailer or leaflet pictures;
/// 3. category symbol;
/// 4. neutral square.
///
/// A brand product counts as recognized only through its barcode: finding a
/// photo from the name alone would cost one OFF search per row (10 per
/// minute) and often pick the wrong product.
class ArticleImageResolver {
  const ArticleImageResolver({this.illustrations = articleIllustrationKeys});

  /// Category ID of [CategorySymbolImage] for categories the person made.
  static const String customCategory = 'custom';

  final Map<String, String> illustrations;

  /// All pictures [item] can show, best first; always ends with
  /// [NeutralImage].
  List<ArticleImageSource> candidatesFor(ShoppingItemModel item) {
    final key = illustrationKeyFor(item.name);
    final code = item.barcode?.trim() ?? '';
    final category = _categoryOf(item);
    return [
      if (key != null) IllustrationImage(key),
      if (isValidBarcode(code)) OffPhotoImage(code),
      if (category != null) CategorySymbolImage(category),
      const NeutralImage(),
    ];
  }

  /// The illustration key for [name]: the normalized name, then the name
  /// without number words ("milch 15" from "Milch 1,5 %"), then its last
  /// word (German head noun: "Frische Milch" → "milch"). Never a part of a
  /// word, so "Milchreis" does not become milk.
  String? illustrationKeyFor(String name) {
    if (illustrations.isEmpty) return null;
    final normalized = normalizeProductName(name);
    if (normalized.isEmpty) return null;
    final words = normalized
        .split(' ')
        .where((w) => !RegExp(r'^\d+$').hasMatch(w))
        .toList();
    for (final candidate in [
      normalized,
      words.join(' '),
      if (words.isNotEmpty) words.last,
    ]) {
      final key = illustrations[candidate];
      if (key != null) return key;
    }
    return null;
  }

  static String? _categoryOf(ShoppingItemModel item) {
    final raw = (item.categoryId ?? item.category)?.trim() ?? '';
    if (raw.isEmpty) return null;
    if (Categories.allIds.contains(raw)) return raw;
    return Categories.getIdByName(raw, 'de') ??
        Categories.getIdByName(raw, 'en') ??
        customCategory;
  }
}
