import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting, debugPrint;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/shelf_price.dart';

/// Regular shelf prices from Open Food Facts' **Open Prices** database.
///
/// This complements [OfferPriceService], which only ever sees promotional
/// Angebote: marktguru answers "what is on sale this week", Open Prices
/// answers "what does this normally cost".
///
/// Lookup is a two-step chain, because Open Prices is keyed by barcode while
/// the app only has free-text item names:
///
///   1. `search.openfoodfacts.org` resolves a name to candidate barcodes.
///      Note this is *not* `world.openfoodfacts.org/api/v2/search` — that
///      endpoint silently ignores `search_terms` and returns the whole
///      catalogue, so "Olivenöl" comes back as Kefir and Nutella.
///   2. `prices.openfoodfacts.org` returns observations for those barcodes.
///      It has no country filter, so German observations are selected client
///      side from each price's OSM location.
///
/// Both endpoints ignore unknown query parameters instead of rejecting them,
/// so every parameter used here was verified against the live API.
///
/// **Licensing:** Open Prices data is ODbL. Any screen that shows one of
/// these prices must credit Open Prices / Open Food Facts.
class OpenPricesService {
  OpenPricesService._();
  static final OpenPricesService instance = OpenPricesService._();

  static const _searchUrl = 'https://search.openfoodfacts.org/search';
  static const _pricesUrl = 'https://prices.openfoodfacts.org/api/v1/prices';

  /// Open Food Facts asks every client to identify itself; anonymous or
  /// browser-spoofing agents get rate limited.
  static const _userAgent = 'Shoply/1.1.4 (com.dominik.shoply)';

  static const _cachePrefix = 'open_prices_v1_';
  static const _cacheTtl = Duration(days: 7);

  /// Only observations from this country are used.
  static const _country = 'DE';

  /// Older observations are ignored outright; between this and
  /// [ShelfPrice.staleAfter] they are used but flagged stale.
  static const _maxAge = Duration(days: 365);

  final Map<String, ShelfPrice?> _memory = {};
  DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> _throttleQueue = Future.value();

  /// Best-guess regular price for [name], or null when nothing usable was
  /// found. Results are cached for [_cacheTtl] — shelf prices move slowly and
  /// the upstream services are volunteer-funded.
  Future<ShelfPrice?> lookupByName(String name) async {
    final query = name.trim().toLowerCase();
    if (query.length < 3) return null;

    if (_memory.containsKey(query)) return _memory[query];

    final cached = await _readCache(query);
    if (cached != null) {
      _memory[query] = cached.price;
      return cached.price;
    }

    try {
      final hits = await _searchHits(query);
      final barcodes = hitsToBarcodes(hits, query);
      final categoryTag = pickCategoryTag(hits, query);

      var observations = barcodes.isEmpty
          ? <PriceObservation>[]
          : await _fetchObservations(productCodes: barcodes);

      // Exact-barcode hits are the precise answer but usually come up empty;
      // fall back to the narrow category, which is where the German data
      // actually lives.
      if (observations.length < 3 && categoryTag != null) {
        observations = [
          ...observations,
          ...await _fetchObservations(categoryTag: categoryTag),
        ];
      }

      final result = aggregate(observations);
      await _writeCache(query, result);
      _memory[query] = result;
      return result;
    } catch (e) {
      debugPrint('❌ [OPENPRICES] Lookup failed for "$name": $e');
      return null;
    }
  }

  /// Name → Open Food Facts product hits (barcodes plus their categories).
  Future<List<Map<String, dynamic>>> _searchHits(String query) async {
    await _throttle();
    final uri = Uri.parse(_searchUrl).replace(queryParameters: {
      'q': query,
      'langs': 'de',
      'countries': 'Germany',
      'page_size': '10',
      'fields': 'code,product_name,product_name_de,categories_tags',
    });

    final response = await _get(uri);
    if (response.statusCode != 200) {
      debugPrint('❌ [OPENPRICES] Search ${response.statusCode} for "$query"');
      return const [];
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['hits'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// Pure part of [_resolveBarcodes], split out so the relevance guard can be
  /// tested without touching the network.
  @visibleForTesting
  static List<String> hitsToBarcodes(
    List<Map<String, dynamic>> hits,
    String query,
  ) {
    final codes = <String>[];
    for (final hit in relevantHits(hits, query)) {
      final code = hit['code']?.toString();
      if (code == null || code.isEmpty) continue;
      codes.add(code);
      if (codes.length >= 5) break;
    }
    return codes;
  }

  /// Hits whose name actually mentions the query. The search is fuzzy and
  /// returns loosely related products, so without this an "Olivenöl" lookup
  /// happily accepts a jar of Nutella.
  @visibleForTesting
  static List<Map<String, dynamic>> relevantHits(
    List<Map<String, dynamic>> hits,
    String query,
  ) {
    final needle = query.toLowerCase();
    return [
      for (final hit in hits)
        if ([
          hit['product_name_de']?.toString() ?? '',
          hit['product_name']?.toString() ?? '',
        ].join(' ').toLowerCase().contains(needle))
          hit,
    ];
  }

  /// The most specific Open Food Facts category shared by the relevant hits.
  ///
  /// Barcode lookups are precise but usually come up empty — the products the
  /// search surfaces are rarely the ones someone logged a price for. Querying
  /// by category covers far more, but only if the category is *narrow*:
  /// `en:olive-oils` has 823 prices and means olive oil, while
  /// `en:plant-based-foods` has 62 000 and means almost nothing.
  ///
  /// `categories_tags` is ordered general → specific, so only the tail of each
  /// hit's list is considered; the tag most hits agree on wins.
  @visibleForTesting
  static String? pickCategoryTag(
    List<Map<String, dynamic>> hits,
    String query, {
    int tailDepth = 3,
  }) {
    final counts = <String, int>{};
    for (final hit in relevantHits(hits, query)) {
      final tags = (hit['categories_tags'] as List?)?.cast<String>() ?? const [];
      if (tags.isEmpty) continue;
      final tail = tags.length <= tailDepth
          ? tags
          : tags.sublist(tags.length - tailDepth);
      for (final tag in tail) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    final best = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
    return best.key;
  }

  Future<List<PriceObservation>> _fetchObservations({
    List<String>? productCodes,
    String? categoryTag,
  }) async {
    await _throttle();
    final uri = Uri.parse(_pricesUrl).replace(queryParameters: {
      if (productCodes != null) 'product_code__in': productCodes.join(','),
      if (categoryTag != null) 'product__categories_tags__contains': categoryTag,
      'currency': 'EUR',
      'order_by': '-date',
      'size': '50',
    });

    final response = await _get(uri);
    if (response.statusCode != 200) {
      debugPrint('❌ [OPENPRICES] Prices ${response.statusCode}');
      return const [];
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (data['items'] as List? ?? []).cast<Map<String, dynamic>>();
    return [
      for (final item in items)
        if (parseObservation(item) case final o?) o,
    ];
  }

  @visibleForTesting
  static PriceObservation? parseObservation(Map<String, dynamic> json) {
    final price = (json['price'] as num?)?.toDouble();
    final date = DateTime.tryParse(json['date'] as String? ?? '');
    final code = json['product_code']?.toString();
    if (price == null || price <= 0 || date == null || code == null) {
      return null;
    }
    final location = json['location'] as Map<String, dynamic>?;
    return PriceObservation(
      price: price,
      currency: json['currency'] as String? ?? 'EUR',
      date: date,
      countryCode:
          (location?['osm_address_country_code'] as String? ?? '').toUpperCase(),
      barcode: code,
      retailer: location?['osm_name'] as String?,
      isDiscounted: json['price_is_discounted'] == true,
    );
  }

  /// Condense observations into one representative price.
  ///
  /// Uses the **median**, not the mean: crowdsourced entries include the
  /// occasional typo or a multipack logged as a single unit, and one €27
  /// outlier would drag an average far away from reality.
  ///
  /// Discounted observations are dropped when undiscounted ones exist — the
  /// whole point of this source is the *regular* price; marktguru already
  /// covers promotions.
  @visibleForTesting
  static ShelfPrice? aggregate(List<PriceObservation> observations) {
    final now = DateTime.now();
    var usable = observations
        .where((o) => o.countryCode == _country)
        .where((o) => now.difference(o.date) <= _maxAge)
        .toList();
    if (usable.isEmpty) return null;

    final regular = usable.where((o) => !o.isDiscounted).toList();
    if (regular.isNotEmpty) usable = regular;

    final sorted = [...usable]..sort((a, b) => a.price.compareTo(b.price));
    final mid = sorted.length ~/ 2;
    final median = sorted.length.isOdd
        ? sorted[mid].price
        : (sorted[mid - 1].price + sorted[mid].price) / 2;

    // Attribute the result to the most recent observation, so the date and
    // retailer shown alongside the price refer to something real.
    final newest =
        usable.reduce((a, b) => a.date.isAfter(b.date) ? a : b);

    return ShelfPrice(
      price: double.parse(median.toStringAsFixed(2)),
      currency: newest.currency,
      observedAt: newest.date,
      retailer: newest.retailer,
      barcode: newest.barcode,
      sampleSize: usable.length,
    );
  }

  // ---------------------------------------------------------------- caching

  Future<({ShelfPrice? price})?> _readCache(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_cachePrefix$query');
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final fetchedAt = DateTime.tryParse(json['fetchedAt'] as String? ?? '');
      if (fetchedAt == null ||
          DateTime.now().difference(fetchedAt) > _cacheTtl) {
        return null;
      }
      final payload = json['price'];
      if (payload == null) return (price: null); // cached "no result"
      return (price: ShelfPrice.fromJson(payload as Map<String, dynamic>));
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(String query, ShelfPrice? price) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_cachePrefix$query',
        jsonEncode({
          'fetchedAt': DateTime.now().toIso8601String(),
          'price': price?.toJson(),
        }),
      );
    } catch (_) {
      // Caching is best-effort.
    }
  }

  // ------------------------------------------------------------- transport

  Future<http.Response> _get(Uri uri) {
    return http.get(uri, headers: {
      'accept': 'application/json',
      'user-agent': _userAgent,
    }).timeout(const Duration(seconds: 15));
  }

  /// Space out request starts; these are free, volunteer-run services.
  Future<void> _throttle() {
    final turn = _throttleQueue.then((_) async {
      const minGap = Duration(milliseconds: 400);
      final elapsed = DateTime.now().difference(_lastRequest);
      if (elapsed < minGap) await Future.delayed(minGap - elapsed);
      _lastRequest = DateTime.now();
    });
    _throttleQueue = turn;
    return turn;
  }
}
