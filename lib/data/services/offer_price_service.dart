import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/utils/request_throttle.dart';
import 'package:shoply/data/models/store_offer.dart';

/// Live supermarket offers via the marktguru API (unofficial).
///
/// marktguru aggregates the current Angebote of the big German grocery
/// chains (REWE, Lidl, Kaufland, Netto, PENNY, Aldi, Edeka, …) per zip code.
/// One search per term and zip code, never whole catalogues or several zip
/// codes in advance (§ 87b UrhG, Kap. 12 rule 10); callers ask only with a
/// real region and while offers are available.
/// The API keys ship embedded in the marktguru web app and are extracted here
/// at runtime. There is no bundled fallback pair: without keys the lookup
/// returns null and the offer widgets show nothing.
///
/// Note: regular shelf prices are not publicly available for German
/// supermarkets — price data therefore covers current offers only.
class OfferPriceService {
  OfferPriceService._(
    this._client, {
    Duration requestGap = _requestGap,
    DateTime Function() now = DateTime.now,
  })  : _throttle = RequestThrottle(requestGap),
        _now = now;
  static final OfferPriceService instance = OfferPriceService._(http.Client());

  /// A fresh instance on a fake HTTP client, for tests; requests are not
  /// spaced out unless [requestGap] says so.
  @visibleForTesting
  factory OfferPriceService.forTesting(
    http.Client client, {
    Duration requestGap = Duration.zero,
    DateTime Function() now = DateTime.now,
  }) =>
      OfferPriceService._(client, requestGap: requestGap, now: now);

  /// Minimum time between two request starts to the offers source.
  static const _requestGap = Duration(milliseconds: 250);

  final http.Client _client;

  /// Clock of the search and key caches; a fake one in tests.
  final DateTime Function() _now;

  static const _baseUrl = 'https://api.marktguru.de/api/v1';
  static const _keysPrefsKey = 'marktguru_keys_v1';
  static const _keysMaxAge = Duration(days: 7);

  /// After a failed extraction the homepage is not downloaded again for this
  /// long, so typing in the add field never hammers marktguru.de.
  static const _keysRetryCooldown = Duration(minutes: 30);
  DateTime? _keysFailedAt;

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

  /// Raw search results per query, zip and limit; least recently used out
  /// beyond [_searchCacheSize] entries (Kap. 12, rule 10).
  final LinkedHashMap<String, _CachedOffers> _searchCache = LinkedHashMap();
  static const _searchCacheTtl = Duration(minutes: 30);
  static const _searchCacheSize = 200;

  /// Identical concurrent searches share one request.
  final Map<String, Future<List<StoreOffer>?>> _inFlight = {};

  /// Concurrent callers (a list's offer sync) still space out request
  /// starts.
  final RequestThrottle _throttle;

  /// A single key re-extraction shared by all concurrent callers.
  Future<void>? _keysRefresh;

  /// Current offers for [query] around [zipCode], in the order of the source
  /// (relevance), grocery chains only; empty when nothing was found or the
  /// request failed. With [chainId] only that market's offers come back.
  Future<List<StoreOffer>> searchOffers(
    String query, {
    required String zipCode,
    String? chainId,
    int limit = 30,
  }) async {
    return await trySearchOffers(
          query,
          zipCode: zipCode,
          chainId: chainId,
          limit: limit,
        ) ??
        const [];
  }

  /// Like [searchOffers], but returns null when a request failed (network,
  /// timeout, non-200) so callers can tell "no offers" from "don't know"
  /// and avoid caching a failure. Failures are not cached here either.
  ///
  /// With [chainId] and no exact hit at that market, the search is
  /// broadened once to the head word ("Golden Toast" → "toast"); what the
  /// market has under it comes back flagged [StoreOffer.isBroadMatch].
  /// Other markets never trigger or take part in that.
  Future<List<StoreOffer>?> trySearchOffers(
    String query, {
    required String zipCode,
    String? chainId,
    int limit = 30,
  }) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.length < 2) return const <StoreOffer>[];

    final results = await _cachedSearch(normalized, zipCode, limit);
    if (results == null || chainId == null) return results;

    final atChain = [
      for (final offer in results)
        if (offer.isFromChain(chainId)) offer,
    ];
    if (atChain.isNotEmpty) return atChain;

    final generic = _genericTerm(normalized);
    if (generic == null || generic == normalized) return atChain;
    final broader = await _cachedSearch(generic, zipCode, limit);
    if (broader == null) return null;
    return [
      for (final offer in broader)
        if (offer.isFromChain(chainId) &&
            offer.productName.toLowerCase().contains(generic))
          offer.asBroadMatch(),
    ];
  }

  /// What an earlier search for [query] around [zipCode] left in the cache
  /// (at most 30 min old), only [chainId]'s offers when given, without any
  /// request; null when nothing is cached. For surfaces that may show only
  /// what the device has ("Weitere Angebote" in the offer detail).
  List<StoreOffer>? cachedOffers(
    String query, {
    required String zipCode,
    String? chainId,
    int limit = 30,
  }) {
    final cached = _searchCache['${query.trim().toLowerCase()}|$zipCode|$limit'];
    if (cached == null ||
        _now().difference(cached.fetchedAt) >= _searchCacheTtl) {
      return null;
    }
    if (chainId == null) return cached.offers;
    return [
      for (final offer in cached.offers)
        if (offer.isFromChain(chainId)) offer,
    ];
  }

  Future<List<StoreOffer>?> _cachedSearch(
    String normalized,
    String zipCode,
    int limit,
  ) {
    final cacheKey = '$normalized|$zipCode|$limit';
    final cached = _searchCache.remove(cacheKey);
    if (cached != null &&
        _now().difference(cached.fetchedAt) < _searchCacheTtl) {
      _searchCache[cacheKey] = cached;
      return Future.value(cached.offers);
    }

    // Block body on purpose: an arrow would return the removed future, which
    // is this very future, and whenComplete would then wait on itself forever.
    return _inFlight[cacheKey] ??=
        _rawSearch(normalized, zipCode: zipCode, limit: limit).then((offers) {
      if (offers != null) {
        _searchCache[cacheKey] = _CachedOffers(_now(), offers);
        while (_searchCache.length > _searchCacheSize) {
          _searchCache.remove(_searchCache.keys.first);
        }
      }
      return offers;
    }).whenComplete(() {
      _inFlight.remove(cacheKey);
    });
  }

  /// One API search; null when the request failed.
  Future<List<StoreOffer>?> _rawSearch(
    String q, {
    required String zipCode,
    required int limit,
  }) async {
    if (!await _ensureKeys()) return null;
    await _throttle.wait();

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
        _apiKey = null;
        _clientKey = null;
        await _refreshKeys();
        if (!_hasKeys) return null;
        response = await _get(uri);
      }
      if (response.statusCode != 200) {
        debugPrint('❌ [OFFERS] Search failed (${response.statusCode}) for "$q"');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (data['results'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(StoreOffer.fromJson)
          .whereType<StoreOffer>()
          .where((o) => _isGrocery(o.retailerUniqueName))
          .where((o) => o.isFood)
          .where((o) => o.isValidNow)
          .toList();

      debugPrint('✅ [OFFERS] "$q" @$zipCode → ${results.length} offers');
      return results;
    } catch (e) {
      debugPrint('❌ [OFFERS] Search error for "$q": $e');
      return null;
    }
  }

  /// Reduce a branded/compound/specific query to a broader stem.
  ///
  /// German compounds carry their meaning in the **last** element: "Olivenöl"
  /// is a kind of Öl, not a kind of Olive. Multi-word queries therefore keep
  /// the last word ("Bio Vollmilch 3,5%" → "vollmilch").
  ///
  /// A single word is returned unchanged, which makes the caller skip the
  /// broadening entirely: every way of shortening a German compound drifts
  /// the meaning — a prefix keeps the qualifier ("olivenöl" → "olive", a jar
  /// of olives), splitting at the head drops it ("vollmilch" → "milch", any
  /// fat content). No match beats a wrong match.
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
    return words.last;
  }

  static const Set<String> _stopWords = {
    'bio', 'frische', 'frisch', 'die', 'der', 'das', 'mit', 'ohne', 'und',
    'aus', 'von', 'fein', 'gut', 'natur', 'classic', 'original',
  };

  /// Exposes the compound-splitting stem for tests — this is where the
  /// "Olivenöl priced as olives" class of bug lives.
  @visibleForTesting
  String? debugGenericTerm(String query) => _genericTerm(query);

  bool _isGrocery(String uniqueName) {
    final name = uniqueName.toLowerCase();
    return groceryRetailers.any((r) => name == r || name.startsWith('$r-'));
  }

  bool get _hasKeys => _apiKey != null && _clientKey != null;

  Future<http.Response> _get(Uri uri) {
    return _client.get(uri, headers: {
      'x-apikey': _apiKey!,
      'x-clientkey': _clientKey!,
      'accept': 'application/json',
      'user-agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)',
    }).timeout(const Duration(seconds: 12));
  }

  /// True when a usable key pair is loaded (memory, prefs or a fresh
  /// extraction). False while the retry cooldown runs.
  Future<bool> _ensureKeys() async {
    if (_hasKeys) return true;

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keysPrefsKey);
    if (stored != null) {
      try {
        final json = jsonDecode(stored) as Map<String, dynamic>;
        final fetchedAt = DateTime.tryParse(json['fetchedAt'] as String? ?? '');
        if (fetchedAt != null &&
            _now().difference(fetchedAt) < _keysMaxAge) {
          _apiKey = json['apiKey'] as String?;
          _clientKey = json['clientKey'] as String?;
          if (_hasKeys) return true;
        }
      } catch (_) {}
    }

    final failedAt = _keysFailedAt;
    if (failedAt != null &&
        _now().difference(failedAt) < _keysRetryCooldown) {
      return false;
    }
    await _refreshKeys();
    return _hasKeys;
  }

  /// Re-extract the public API keys from the marktguru web app config.
  /// Concurrent callers (cold start, or several 401s at once) share one
  /// download of the marktguru homepage.
  Future<void> _refreshKeys() {
    return _keysRefresh ??=
        _downloadKeys().whenComplete(() => _keysRefresh = null);
  }

  Future<void> _downloadKeys() async {
    try {
      final response = await _client.get(
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
          _keysFailedAt = null;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            _keysPrefsKey,
            jsonEncode({
              'apiKey': apiKey,
              'clientKey': clientKey,
              'fetchedAt': _now().toIso8601String(),
            }),
          );
          debugPrint('✅ [OFFERS] Refreshed marktguru API keys');
          return;
        }
      }
      debugPrint('⚠️ [OFFERS] Could not extract keys, offers paused');
    } catch (e) {
      debugPrint('⚠️ [OFFERS] Key refresh failed ($e), offers paused');
    }
    _keysFailedAt = _now();
  }
}

class _CachedOffers {
  final DateTime fetchedAt;
  final List<StoreOffer> offers;
  _CachedOffers(this.fetchedAt, this.offers);
}
