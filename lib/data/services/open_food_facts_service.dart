import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shoply/data/models/food_product.dart';

/// Food search + barcode lookup via Open Food Facts — a free, keyless,
/// crowd-sourced product database (no API key needed, unlike the Gemini
/// integrations elsewhere in this app).
///
/// Two endpoints are used because OFF's data quality/availability differs
/// per operation: `search.openfoodfacts.org` (search-a-licious, OFF's
/// current text-search service) for name search, and the stable
/// `world.openfoodfacts.org/api/v2/product/{barcode}` for exact barcode
/// lookups (the legacy `cgi/search.pl` endpoint used to filter by barcode
/// too, but is being deprecated in favor of v2/search-a-licious).
class OpenFoodFactsService {
  OpenFoodFactsService._();
  static final OpenFoodFactsService instance = OpenFoodFactsService._();

  static const _searchBaseUrl = 'https://search.openfoodfacts.org/search';
  static const _productBaseUrl = 'https://world.openfoodfacts.org/api/v2/product';
  static const _fields = 'code,product_name,brands,nutriments,image_front_small_url';
  static const _userAgent = 'Shoply-App/1.0 (Flutter; shopping list & nutrition tracking)';
  static const _timeout = Duration(seconds: 8);

  /// Searches by free-text name. Returns an empty list (never throws) on
  /// network failure or no results, so callers can show a clean "no
  /// results" state instead of an error.
  Future<List<FoodProduct>> search(String query, {int limit = 15}) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];
    try {
      final uri = Uri.parse(_searchBaseUrl).replace(queryParameters: {
        'q': trimmed,
        'page_size': '$limit',
        'fields': _fields,
      });
      final response =
          await http.get(uri, headers: {'User-Agent': _userAgent}).timeout(_timeout);
      if (response.statusCode != 200) {
        debugPrint('⚠️ [OpenFoodFacts] Search returned ${response.statusCode}');
        return [];
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final hits = body['hits'] as List? ?? [];
      return hits
          .cast<Map<String, dynamic>>()
          .map(FoodProduct.fromOpenFoodFacts)
          .where((p) => p.barcode.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('⚠️ [OpenFoodFacts] Search failed: $e');
      return [];
    }
  }

  /// Exact-barcode lookup (e.g. from manual barcode entry). Returns null if
  /// not found or on network failure.
  Future<FoodProduct?> lookupBarcode(String barcode) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return null;
    try {
      final uri = Uri.parse('$_productBaseUrl/$trimmed.json')
          .replace(queryParameters: {'fields': _fields});
      final response =
          await http.get(uri, headers: {'User-Agent': _userAgent}).timeout(_timeout);
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['status'] == 0) return null; // OFF's "not found" marker
      final product = body['product'] as Map<String, dynamic>?;
      if (product == null) return null;
      // The v2 endpoint doesn't echo `code` inside `product` on every
      // response — fall back to the barcode we looked up.
      product['code'] ??= trimmed;
      return FoodProduct.fromOpenFoodFacts(product);
    } catch (e) {
      debugPrint('⚠️ [OpenFoodFacts] Barcode lookup failed: $e');
      return null;
    }
  }
}
