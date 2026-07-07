import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shoply/data/models/nearby_store.dart';

/// Finds real, physical supermarket branches near a coordinate, via the
/// Overpass API (OpenStreetMap) — free, keyless, no rate-limit account
/// needed. This is what makes "closest reasonable store" a real distance
/// rather than just a chain name: marktguru's offer API only knows chains
/// and zip codes, not branch addresses.
///
/// Overpass is a shared community service with informal fair-use limits, so
/// results are cached in memory per rounded coordinate + radius and this
/// service is only ever called once per store-comparison-sheet open, not
/// polled.
class StoreLocatorService {
  StoreLocatorService._();
  static final StoreLocatorService instance = StoreLocatorService._();

  // Public Overpass instances; the mirror is tried if the primary times out
  // or errors, the same resilience pattern used for the marktguru key
  // refresh (best-effort, never crashes the feature it backs).
  static const _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  static const _defaultRadiusMeters = 8000.0;
  static const _cacheTtl = Duration(hours: 6);

  final Map<String, _CachedStores> _cache = {};

  /// Nearby supermarket branches, sorted closest-first. Returns an empty
  /// list (never throws) when Overpass is unreachable or returns nothing —
  /// callers must treat that the same as "no location data", i.e. just don't
  /// show distance info, since this is a nice-to-have on top of the
  /// zip-based offer comparison, not a requirement for it to work.
  Future<List<NearbyStore>> findNearbyStores({
    required double latitude,
    required double longitude,
    double radiusMeters = _defaultRadiusMeters,
  }) async {
    // Round to ~110m so nearby repeat calls (e.g. reopening the sheet) hit
    // the same cache entry instead of missing on float noise.
    final cacheKey =
        '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}@${radiusMeters.round()}';
    final cached = _cache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      return cached.stores;
    }

    final query = '[out:json][timeout:15];'
        'node["shop"="supermarket"](around:${radiusMeters.round()},$latitude,$longitude);'
        'out body;';

    for (final endpoint in _endpoints) {
      try {
        final response = await http
            .post(Uri.parse(endpoint), body: {'data': query})
            .timeout(const Duration(seconds: 18));

        if (response.statusCode != 200) {
          print('⚠️ [STORE_LOCATOR] $endpoint returned ${response.statusCode}');
          continue;
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final elements = (data['elements'] as List? ?? []).cast<Map<String, dynamic>>();

        final stores = elements
            .map((e) => _parseElement(e, latitude, longitude))
            .whereType<NearbyStore>()
            .toList()
          ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

        _cache[cacheKey] = _CachedStores(DateTime.now(), stores);
        print('✅ [STORE_LOCATOR] Found ${stores.length} branches within ${radiusMeters.round()}m');
        return stores;
      } catch (e) {
        print('❌ [STORE_LOCATOR] $endpoint failed: $e');
      }
    }

    print('⚠️ [STORE_LOCATOR] All endpoints failed; no distance data this time');
    return const [];
  }

  /// The nearest branch matching [retailerUniqueName] (marktguru's chain id),
  /// or null if none was found within the searched radius.
  NearbyStore? nearestOf(List<NearbyStore> stores, String retailerUniqueName) {
    for (final store in stores) {
      if (store.retailerUniqueName == retailerUniqueName) return store;
    }
    return null;
  }

  NearbyStore? _parseElement(
    Map<String, dynamic> element,
    double userLat,
    double userLon,
  ) {
    final lat = (element['lat'] as num?)?.toDouble();
    final lon = (element['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) return null;

    final tags = (element['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
    final brand = tags['brand'] as String?;
    final name = (tags['name'] as String?) ?? brand;
    if (name == null || name.isEmpty) return null;

    return NearbyStore(
      retailerUniqueName: _normalizeRetailer(brand ?? name),
      displayName: name,
      street: tags['addr:street'] as String?,
      houseNumber: tags['addr:housenumber'] as String?,
      city: tags['addr:city'] as String?,
      latitude: lat,
      longitude: lon,
      distanceMeters: NearbyStore.distanceBetween(userLat, userLon, lat, lon),
    );
  }

  /// Maps an OSM brand/name string to marktguru's retailer id (matching
  /// `OfferPriceService.groceryRetailers`), or null when it doesn't match a
  /// chain the price comparison knows about (still a valid nearby store to
  /// show, just not one we can price-compare).
  String? _normalizeRetailer(String raw) {
    final n = raw.toLowerCase();
    // Order matters: check the more specific compound names before the
    // generic chain name they contain (e.g. "netto marken-discount" before
    // "netto" — two different German chains share the "Netto" word).
    if (n.contains('netto marken-discount')) return 'netto-marken-discount';
    if (n.contains('netto')) return 'netto';
    if (n.contains('aldi süd') || n.contains('aldi sued')) return 'aldi-sued';
    if (n.contains('aldi nord')) return 'aldi-nord';
    if (n.contains('aldi')) return 'aldi';
    if (n.contains('rewe')) return 'rewe';
    if (n.contains('edeka')) return 'edeka';
    if (n.contains('lidl')) return 'lidl';
    if (n.contains('kaufland')) return 'kaufland';
    if (n.contains('penny')) return 'penny';
    if (n.contains('norma')) return 'norma';
    if (n.contains('nahkauf')) return 'nahkauf';
    if (n.contains('globus')) return 'globus';
    if (n.contains('famila')) return 'famila';
    if (n.contains('tegut')) return 'tegut';
    return null;
  }
}

class _CachedStores {
  final DateTime fetchedAt;
  final List<NearbyStore> stores;
  _CachedStores(this.fetchedAt, this.stores);
}
