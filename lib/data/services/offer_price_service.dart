import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/store_offer.dart';

/// Live supermarket offers via the marktguru API (unofficial).
///
/// marktguru aggregates the current Angebote of the big German grocery
/// chains (REWE, Lidl, Kaufland, Netto, PENNY, Aldi, Edeka, …) per zip code.
/// The API keys are public: they ship embedded in the marktguru web app and
/// are re-extracted here at runtime (with a bundled fallback pair).
///
/// Note: regular shelf prices are not publicly available for German
/// supermarkets — price data therefore covers current offers only.
class OfferPriceService {
  OfferPriceService._();
  static final OfferPriceService instance = OfferPriceService._();

  static const _baseUrl = 'https://api.marktguru.de/api/v1';
  static const _keysPrefsKey = 'marktguru_keys_v1';
  static const _keysMaxAge = Duration(days: 7);

  // Fallback keys extracted from marktguru.de (2026-07); refreshed at runtime.
  static const _fallbackApiKey = '8Kk+pmbf7TgJ9nVj2cXeA7P5zBGv8iuutVVMRfOfvNE=';
  static const _fallbackClientKey =
      'WU/RH+PMGDi+gkZer3WbMelt6zcYHSTytNB7VpTia90=';

  /// Grocery chains we surface; drugstores etc. are filtered out.
  static const Set<String> groceryRetailers = {
    'rewe',
    'lidl',
    'kaufland',
    'netto-marken-discount',
    'netto',
    'penny',
    'aldi-sued',
    'aldi-nord',
    'aldi',
    'edeka',
    'norma',
    'nahkauf',
    'globus',
    'famila',
    'tegut',
  };

  String? _apiKey;
  String? _clientKey;

  final Map<String, _CachedOffers> _searchCache = {};
  static const _searchCacheTtl = Duration(minutes: 30);
  DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);

  /// Search current offers for [query] around [zipCode].
  /// Returns offers sorted by price (cheapest first), grocery chains only.
  Future<List<StoreOffer>> searchOffers(
    String query, {
    required String zipCode,
    int limit = 30,
  }) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.length < 2) return const [];

    final cacheKey = '$normalized|$zipCode';
    final cached = _searchCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _searchCacheTtl) {
      return cached.offers;
    }

    await _ensureKeys();
    await _throttle();

    final uri = Uri.parse('$_baseUrl/offers/search').replace(
      queryParameters: {
        'as': 'web',
        'q': normalized,
        'limit': '$limit',
        'offset': '0',
        'zipCode': zipCode,
      },
    );

    try {
      var response = await _get(uri);
      if (response.statusCode == 401 || response.statusCode == 403) {
        // Keys rotated — re-extract once and retry.
        await _refreshKeys();
        response = await _get(uri);
      }
      if (response.statusCode != 200) {
        print('❌ [OFFERS] Search failed (${response.statusCode}) for "$query"');
        return const [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (data['results'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(StoreOffer.fromJson)
          .whereType<StoreOffer>()
          .where((o) => _isGrocery(o.retailerUniqueName))
          .where((o) => o.isValidNow)
          .toList()
        ..sort((a, b) => a.price.compareTo(b.price));

      _searchCache[cacheKey] = _CachedOffers(DateTime.now(), results);
      print('✅ [OFFERS] "$query" @$zipCode → ${results.length} offers');
      return results;
    } catch (e) {
      print('❌ [OFFERS] Search error for "$query": $e');
      return const [];
    }
  }

  /// The cheapest offer per retailer for [query] (used for basket totals).
  Future<Map<String, StoreOffer>> cheapestPerRetailer(
    String query, {
    required String zipCode,
  }) async {
    final offers = await searchOffers(query, zipCode: zipCode);
    final byRetailer = <String, StoreOffer>{};
    for (final offer in offers) {
      // Offers are sorted by price, so the first one per retailer wins.
      byRetailer.putIfAbsent(offer.retailerUniqueName, () => offer);
    }
    return byRetailer;
  }

  bool _isGrocery(String uniqueName) {
    final name = uniqueName.toLowerCase();
    return groceryRetailers.any((r) => name == r || name.startsWith('$r-'));
  }

  Future<http.Response> _get(Uri uri) {
    return http.get(uri, headers: {
      'x-apikey': _apiKey ?? _fallbackApiKey,
      'x-clientkey': _clientKey ?? _fallbackClientKey,
      'accept': 'application/json',
      'user-agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)',
    }).timeout(const Duration(seconds: 12));
  }

  Future<void> _throttle() async {
    const minGap = Duration(milliseconds: 250);
    final elapsed = DateTime.now().difference(_lastRequest);
    if (elapsed < minGap) {
      await Future.delayed(minGap - elapsed);
    }
    _lastRequest = DateTime.now();
  }

  Future<void> _ensureKeys() async {
    if (_apiKey != null && _clientKey != null) return;

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keysPrefsKey);
    if (stored != null) {
      try {
        final json = jsonDecode(stored) as Map<String, dynamic>;
        final fetchedAt = DateTime.tryParse(json['fetchedAt'] as String? ?? '');
        if (fetchedAt != null &&
            DateTime.now().difference(fetchedAt) < _keysMaxAge) {
          _apiKey = json['apiKey'] as String?;
          _clientKey = json['clientKey'] as String?;
          if (_apiKey != null && _clientKey != null) return;
        }
      } catch (_) {}
    }

    await _refreshKeys();
  }

  /// Re-extract the public API keys from the marktguru web app config.
  Future<void> _refreshKeys() async {
    try {
      final response = await http.get(
        Uri.parse('https://www.marktguru.de'),
        headers: {'user-agent': 'Mozilla/5.0'},
      ).timeout(const Duration(seconds: 12));

      final match = RegExp(
        r'<script\s+type="application/json">(.*?)</script>',
        dotAll: true,
      ).allMatches(response.body).lastOrNull;

      if (match != null) {
        final config = jsonDecode(match.group(1)!) as Map<String, dynamic>;
        final inner = config['config'] as Map<String, dynamic>?;
        final apiKey = inner?['apiKey'] as String?;
        final clientKey = inner?['clientKey'] as String?;
        if (apiKey != null && clientKey != null) {
          _apiKey = apiKey;
          _clientKey = clientKey;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            _keysPrefsKey,
            jsonEncode({
              'apiKey': apiKey,
              'clientKey': clientKey,
              'fetchedAt': DateTime.now().toIso8601String(),
            }),
          );
          print('✅ [OFFERS] Refreshed marktguru API keys');
          return;
        }
      }
      print('⚠️ [OFFERS] Could not extract keys, using fallback');
    } catch (e) {
      print('⚠️ [OFFERS] Key refresh failed ($e), using fallback');
    }
    _apiKey = _fallbackApiKey;
    _clientKey = _fallbackClientKey;
  }
}

class _CachedOffers {
  final DateTime fetchedAt;
  final List<StoreOffer> offers;
  _CachedOffers(this.fetchedAt, this.offers);
}
