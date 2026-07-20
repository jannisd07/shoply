import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/recipe_offer_highlight.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/services/offer_price_service.dart';

/// Matches a recipe's ingredients against current supermarket offers
/// (Feature 8: "this recipe is cheaper this week — these ingredients are on
/// offer").
///
/// Cost discipline: one offer search per eligible ingredient (staples
/// skipped, capped at [maxCheckedIngredients]), all going through
/// [OfferPriceService]'s serialized throttle and 30-minute in-memory search
/// cache — plus a persistent 6h per-recipe cache here, so re-opening a
/// recipe (or re-opening the app) doesn't re-hit the API at all for an
/// unchanged recipe+zip snapshot. This runs only when a user actually opens
/// a recipe's detail screen, never as a background fan-out over many
/// recipes (that variant is a separately-flagged product decision).
class RecipeOfferService {
  RecipeOfferService._();
  static final RecipeOfferService instance = RecipeOfferService._();

  static const _cachePrefsKey = 'recipe_offers_cache_v1';
  static const cacheTtl = Duration(hours: 6);
  static const maxCheckedIngredients = 10;
  static const _maxCachedRecipes = 12;

  /// Pantry staples nobody buys because of a single recipe — skipped so the
  /// card never leads with "Salz ist im Angebot".
  static const Set<String> _staples = {
    'wasser',
    'water',
    'salz',
    'salt',
    'pfeffer',
    'pepper',
    'salz und pfeffer',
    'salz & pfeffer',
    'salt and pepper',
    'salt & pepper',
  };

  /// Offers for [ingredientNames] around [zipCode], via the persistent cache
  /// when the exact recipe+zip+ingredients snapshot was checked within
  /// [cacheTtl]. Never throws — a failed search for one ingredient simply
  /// yields no match for it (OfferPriceService already returns empty on any
  /// error).
  Future<RecipeOffersResult> getOffers({
    required String recipeId,
    required List<String> ingredientNames,
    required String zipCode,
  }) async {
    final names = eligibleIngredientNames(ingredientNames);
    final signature = '$recipeId|$zipCode|${names.join(',')}';

    final cached = await _loadCached(recipeId, signature);
    if (cached != null) return cached;

    // Concurrent fetch — the service's internal throttle still serializes
    // actual request starts (sequential awaits would add ~250ms of pure
    // queue latency per ingredient on top).
    final fetched = await Future.wait(names.map((name) async {
      final offers =
          await OfferPriceService.instance.searchOffers(name, zipCode: zipCode);
      return MapEntry(name, pickBestOffer(name, offers));
    }));

    final matches = <RecipeIngredientOffer>[
      for (final entry in fetched)
        if (entry.value != null)
          RecipeIngredientOffer.fromStoreOffer(entry.key, entry.value!),
    ];

    final result = RecipeOffersResult(
      recipeId: recipeId,
      zipCode: zipCode,
      checkedIngredientCount: names.length,
      matches: matches,
      signature: signature,
    );
    await _saveCached(result);
    return result;
  }

  /// Ingredient names worth searching: trimmed, ≥3 chars, no pantry staples,
  /// de-duplicated case-insensitively (keeping first spelling and order),
  /// capped at [maxCheckedIngredients] to bound API cost for very long
  /// ingredient lists.
  @visibleForTesting
  static List<String> eligibleIngredientNames(List<String> raw) {
    final seen = <String>{};
    final result = <String>[];
    for (final name in raw) {
      final trimmed = name.trim();
      final normalized = trimmed.toLowerCase();
      if (trimmed.length < 3) continue;
      if (_staples.contains(normalized)) continue;
      if (!seen.add(normalized)) continue;
      result.add(trimmed);
      if (result.length == maxCheckedIngredients) break;
    }
    return result;
  }

  /// The best current offer for one ingredient: the cheapest offer whose
  /// product name genuinely relates to the ingredient. Exact-term matches
  /// win over generic-stem broad matches; offers matching neither way are
  /// ignored entirely (no match beats a wrong product on a proactive
  /// surface). Returns null when nothing relevant is on offer.
  @visibleForTesting
  static StoreOffer? pickBestOffer(
      String ingredientName, List<StoreOffer> offers) {
    StoreOffer? bestExact;
    StoreOffer? bestBroad;
    for (final offer in offers) {
      if (isRelevantMatch(ingredientName, offer)) {
        if (bestExact == null || offer.price < bestExact.price) {
          bestExact = offer;
        }
      } else if (offer.isBroadMatch) {
        // Already stem-relevance-guarded by OfferPriceService's fallback.
        if (bestBroad == null || offer.price < bestBroad.price) {
          bestBroad = offer;
        }
      }
    }
    return bestExact ?? bestBroad;
  }

  /// Whether [offer]'s product name contains the full ingredient term, or —
  /// for multi-word ingredients — its head noun (German compounds put the
  /// head last: "passierte Tomaten" → "tomaten", mirroring
  /// OfferPriceService's generic-term rule).
  @visibleForTesting
  static bool isRelevantMatch(String ingredientName, StoreOffer offer) {
    final product = offer.productName.toLowerCase();
    final term = ingredientName.trim().toLowerCase();
    if (term.isEmpty) return false;
    if (product.contains(term)) return true;
    final words =
        term.split(RegExp(r'[\s-]+')).where((w) => w.length >= 4).toList();
    if (words.isEmpty) return false;
    return product.contains(words.last);
  }

  Future<RecipeOffersResult?> _loadCached(
      String recipeId, String signature) async {
    try {
      final entries = await _readCacheMap();
      final entry = entries[recipeId];
      if (entry == null) return null;
      if (entry['signature'] != signature) return null;
      final fetchedAt = DateTime.tryParse(entry['fetchedAt'] as String? ?? '');
      if (fetchedAt == null ||
          DateTime.now().difference(fetchedAt) > cacheTtl) {
        return null;
      }
      final resultJson = entry['result'] as Map<String, dynamic>?;
      if (resultJson == null) return null;
      return RecipeOffersResult.fromJson(resultJson);
    } catch (e) {
      debugPrint('⚠️ [RECIPE_OFFERS] Failed to read cache: $e');
      return null;
    }
  }

  Future<void> _saveCached(RecipeOffersResult result) async {
    try {
      final entries = await _readCacheMap();
      entries[result.recipeId] = {
        'signature': result.signature,
        'fetchedAt': DateTime.now().toIso8601String(),
        'result': result.toJson(),
      };

      // Prune to the most recently fetched recipes so the prefs entry
      // doesn't grow without bound.
      if (entries.length > _maxCachedRecipes) {
        final sortedIds = entries.keys.toList()
          ..sort((a, b) {
            final aTime =
                DateTime.tryParse(entries[a]!['fetchedAt'] as String? ?? '') ??
                    DateTime.fromMillisecondsSinceEpoch(0);
            final bTime =
                DateTime.tryParse(entries[b]!['fetchedAt'] as String? ?? '') ??
                    DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
        for (final id in sortedIds.skip(_maxCachedRecipes)) {
          entries.remove(id);
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachePrefsKey, jsonEncode(entries));
    } catch (e) {
      debugPrint('⚠️ [RECIPE_OFFERS] Failed to write cache: $e');
    }
  }

  Future<Map<String, Map<String, dynamic>>> _readCacheMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachePrefsKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return {};
    return {
      for (final entry in decoded.entries)
        if (entry.value is Map<String, dynamic>)
          entry.key: entry.value as Map<String, dynamic>,
    };
  }
}
