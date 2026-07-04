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
  // Serializes throttle turns so concurrent callers (e.g. a basket comparison
  // fetching many items at once via Future.wait) still space out request
  // *starts* by minGap, instead of all reading the stale _lastRequest at once
  // and firing simultaneously.
  Future<void> _throttleQueue = Future.value();

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

    var results = await _rawSearch(normalized, zipCode: zipCode, limit: limit);

    // Branded/compound/specific terms often miss (e.g. "golden toast" → 0, or
    // "Toastbrötchen" → only one store). Retry with a broader generic stem and
    // merge in the comparable products so all stores show up. The stem-matched
    // fallback is relevance-guarded (product name must contain the stem) so a
    // short prefix can't pull in unrelated items.
    final generic = _genericTerm(normalized);
    final retailerCount = results.map((o) => o.retailerUniqueName).toSet().length;
    if (generic != null && generic != normalized && retailerCount < 2) {
      final fallback = await _rawSearch(generic, zipCode: zipCode, limit: limit);
      final seen = results.map((o) => o.id).toSet();
      results = [
        ...results,
        ...fallback.where((o) =>
            seen.add(o.id) && o.productName.toLowerCase().contains(generic)),
      ]..sort((a, b) => a.price.compareTo(b.price));
    }

    _searchCache[cacheKey] = _CachedOffers(DateTime.now(), results);
    return results;
  }

  Future<List<StoreOffer>> _rawSearch(
    String q, {
    required String zipCode,
    required int limit,
  }) async {
    await _ensureKeys();
    await _throttle();

    final uri = Uri.parse('$_baseUrl/offers/search').replace(
      queryParameters: {
        'as': 'web',
        'q': q,
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
        print('❌ [OFFERS] Search failed (${response.statusCode}) for "$q"');
        return const [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (data['results'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(StoreOffer.fromJson)
          .whereType<StoreOffer>()
          .where((o) => _isGrocery(o.retailerUniqueName))
          .where((o) => o.isFood)
          .where((o) => o.isValidNow)
          .toList()
        ..sort((a, b) => a.price.compareTo(b.price));

      print('✅ [OFFERS] "$q" @$zipCode → ${results.length} offers');
      return results;
    } catch (e) {
      print('❌ [OFFERS] Search error for "$q": $e');
      return const [];
    }
  }

  /// Reduce a branded/compound/specific query to a broader stem so the API
  /// returns comparable products across stores.
  ///
  /// Multi-word: German compounds put the head noun last ("Golden Toast" →
  /// "toast", "Bio Vollmilch 3,5%" → "vollmilch"). Single long word: use a
  /// short prefix stem ("Toastbrötchen" → "toast", "Schweinerippe" →
  /// "schwe") — callers relevance-filter fallback hits by this stem, so an
  /// over-broad prefix can't introduce noise. Returns null when nothing
  /// sensible remains.
  String? _genericTerm(String query) {
    final cleaned = query
        .toLowerCase()
        // strip quantities/units/percentages
        .replaceAll(
            RegExp(r'\b\d+([.,]\d+)?\s*(g|kg|ml|l|%|x|stk|stück|pck|er)?\b'), ' ')
        .replaceAll(RegExp(r'[^a-zäöüß\s-]'), ' ');
    final words = cleaned
        .split(RegExp(r'[\s-]+'))
        .where((w) => w.length >= 3 && !_stopWords.contains(w))
        .toList();
    if (words.isEmpty) return null;
    if (words.length >= 2) return words.last;
    // Single word: broaden long words to a 5-char stem, else keep as-is.
    final word = words.first;
    return word.length >= 7 ? word.substring(0, 5) : word;
  }

  static const Set<String> _stopWords = {
    'bio', 'frische', 'frisch', 'die', 'der', 'das', 'mit', 'ohne', 'und',
    'aus', 'von', 'fein', 'gut', 'natur', 'classic', 'original',
  };

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

  Future<void> _throttle() {
    // Chain onto the queue so each caller's wait+timestamp-update runs to
    // completion before the next one reads _lastRequest — without this, N
    // concurrent callers (Future.wait) would all see the same stale
    // _lastRequest and pass the gap check together.
    final turn = _throttleQueue.then((_) async {
      const minGap = Duration(milliseconds: 250);
      final elapsed = DateTime.now().difference(_lastRequest);
      if (elapsed < minGap) {
        await Future.delayed(minGap - elapsed);
      }
      _lastRequest = DateTime.now();
    });
    // Keep the queue alive even if this turn's caller later fails downstream;
    // failures happen after _throttle() resolves, so this future itself
    // never rejects.
    _throttleQueue = turn;
    return turn;
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
