import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/home_price_highlight.dart';

/// Persistent cache for the home-screen price-comparison highlight
/// (Feature 8). `basketComparisonProvider` fires one live marktguru search
/// per open list item — safe to trigger when a user actively opens a list's
/// price sheet, but not something that should re-run on every single home
/// screen visit across every user. This wraps the (already-cheap-by-itself)
/// computation with a longer-lived, cross-session cache keyed by exactly
/// what's being compared, mirroring `AvoNudgeService`'s offer-nudge cache.
class HomePriceComparisonCacheService {
  static HomePriceComparisonCacheService? _instance;
  static HomePriceComparisonCacheService get instance {
    _instance ??= HomePriceComparisonCacheService._();
    return _instance!;
  }

  HomePriceComparisonCacheService._();

  static const _cacheKey = 'home_price_highlight_cache_v1';
  static const _dismissedSignatureKey = 'home_price_highlight_dismissed_v1';
  static const cacheTtl = Duration(hours: 6);

  /// A cached result for [signature], or null when there's nothing cached,
  /// the cache is for a different signature (list/items/zip changed), or the
  /// cache has aged out. The cached value itself may be null — meaning "we
  /// already checked this exact snapshot and found no meaningful highlight"
  /// — which is a valid, cacheable answer distinct from "not computed yet".
  Future<HomePriceCacheLookup> load(String signature) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return HomePriceCacheLookup.miss();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['signature'] != signature) return HomePriceCacheLookup.miss();
      final fetchedAt = DateTime.tryParse(decoded['fetchedAt'] as String? ?? '');
      if (fetchedAt == null || DateTime.now().difference(fetchedAt) > cacheTtl) {
        return HomePriceCacheLookup.miss();
      }
      final highlightJson = decoded['highlight'] as Map<String, dynamic>?;
      return HomePriceCacheLookup.hit(
        highlightJson != null ? HomePriceHighlight.fromJson(highlightJson) : null,
      );
    } catch (e) {
      debugPrint('💰 [HOME_PRICE] Failed to read cache: $e');
      return HomePriceCacheLookup.miss();
    }
  }

  Future<void> save(String signature, HomePriceHighlight? highlight) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode({
          'signature': signature,
          'fetchedAt': DateTime.now().toIso8601String(),
          'highlight': highlight?.toJson(),
        }),
      );
    } catch (e) {
      debugPrint('💰 [HOME_PRICE] Failed to write cache: $e');
    }
  }

  /// Whether the user already dismissed this exact highlight. Dismissing
  /// only suppresses the specific signature shown — a genuinely new
  /// comparison (list changed, prices moved) surfaces again normally.
  Future<bool> isDismissed(String signature) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_dismissedSignatureKey) == signature;
    } catch (_) {
      return false;
    }
  }

  Future<void> dismiss(String signature) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dismissedSignatureKey, signature);
    } catch (e) {
      debugPrint('💰 [HOME_PRICE] Failed to store dismissal: $e');
    }
  }
}

class HomePriceCacheLookup {
  final bool isHit;
  final HomePriceHighlight? highlight;

  const HomePriceCacheLookup._(this.isHit, this.highlight);

  factory HomePriceCacheLookup.hit(HomePriceHighlight? highlight) =>
      HomePriceCacheLookup._(true, highlight);
  factory HomePriceCacheLookup.miss() =>
      const HomePriceCacheLookup._(false, null);
}
