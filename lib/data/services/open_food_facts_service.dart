import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/food_product.dart';

/// App version for the Open Food Facts User-Agent: `version:` in
/// `pubspec.yaml` without the build number (`package_info_plus` is not a
/// dependency). A test compares it with `pubspec.yaml`; a build can set it
/// with `--dart-define=AVO_APP_VERSION=…`.
const String offAppVersion = String.fromEnvironment(
  'AVO_APP_VERSION',
  defaultValue: '1.1.4',
);

/// Contact address Open Food Facts asks for in the User-Agent.
// TODO(owner): replace with the real contact address (docs/OPEN-ISSUES.md).
const String offContactEmail = 'kontakt@example.invalid';

/// How every request to Open Food Facts (also Open Prices) names the app:
/// `AppName/Version (ContactEmail)`, as the OFF API terms ask.
const String offUserAgent = 'Avo/$offAppVersion ($offContactEmail)';

/// Counts events in a sliding window: at most [maxEvents] in any [window].
class SlidingWindowRateLimiter {
  SlidingWindowRateLimiter({
    required this.maxEvents,
    required this.window,
    DateTime Function()? clock,
  }) : _clock = clock ?? _monotonicNow;

  /// The default clock runs on a stopwatch, so a device clock set back does
  /// not keep old events in the window (and block every request) for hours.
  static final DateTime _start = DateTime.now();
  static final Stopwatch _elapsed = Stopwatch()..start();
  static DateTime _monotonicNow() => _start.add(_elapsed.elapsed);

  final int maxEvents;
  final Duration window;
  final DateTime Function() _clock;
  final Queue<DateTime> _events = Queue<DateTime>();

  void _prune(DateTime now) {
    while (_events.isNotEmpty && now.difference(_events.first) >= window) {
      _events.removeFirst();
    }
  }

  /// Takes a slot if fewer than `maxEvents - keepFree` are in use, so
  /// background work can leave room for what the person asked for.
  bool tryAcquire({int keepFree = 0}) {
    final now = _clock();
    _prune(now);
    if (_events.length >= maxEvents - keepFree) return false;
    _events.addLast(now);
    return true;
  }

  /// How long until [tryAcquire] with the same [keepFree] succeeds again.
  Duration timeUntilFree({int keepFree = 0}) {
    final now = _clock();
    _prune(now);
    final allowed = maxEvents - keepFree;
    if (_events.length < allowed) return Duration.zero;
    // The oldest `length - allowed + 1` events have to leave the window.
    final last = _events.elementAt(_events.length - allowed);
    return last.add(window).difference(now);
  }
}

/// A lookup was skipped because the Open Food Facts limit is reached; ask
/// again after [retryAfter].
class OffRateLimited implements Exception {
  const OffRateLimited(this.retryAfter);

  final Duration retryAfter;

  @override
  String toString() => 'OffRateLimited(retry after $retryAfter)';
}

/// An Open Food Facts request failed (no connection, timeout, server
/// error). Search and barcode lookup throw it instead of answering "no
/// results" (`kalorien.md` §7.2: a network error never looks like "nothing
/// found").
class OffRequestFailed implements Exception {
  const OffRequestFailed(this.reason);

  /// `network`, `timeout` or `http_<status>`; never contains user input.
  final String reason;

  @override
  String toString() => 'OffRequestFailed($reason)';
}

/// The per-IP limits of the Open Food Facts API: 10 searches and 15 product
/// reads per minute. Above that OFF may block the IP, so every OFF caller
/// (this service and the name search of `OpenPricesService`) shares
/// [shared].
class OffRateLimits {
  OffRateLimits({DateTime Function()? clock})
    : search = SlidingWindowRateLimiter(
        maxEvents: 10,
        window: const Duration(minutes: 1),
        clock: clock,
      ),
      product = SlidingWindowRateLimiter(
        maxEvents: 15,
        window: const Duration(minutes: 1),
        clock: clock,
      );

  static final OffRateLimits shared = OffRateLimits();

  /// Slots that background work (article photos, Open Prices) leaves free
  /// in each window for what the person asked for.
  static const int backgroundKeepFree = 3;

  final SlidingWindowRateLimiter search;
  final SlidingWindowRateLimiter product;
}

/// The front photo of a product on Open Food Facts (CC BY-SA). Shown as it
/// is (white background, never cut out) and always with the credit
/// "Foto: Open Food Facts, CC BY-SA" linking to [productPage].
@immutable
class OffProductPhoto {
  const OffProductPhoto({
    required this.barcode,
    required this.smallUrl,
    this.displayUrl,
  });

  final String barcode;

  /// About 200 px wide, enough for 44 and 52 pt.
  final String smallUrl;

  /// About 400 px wide, for 88 pt (article detail).
  final String? displayUrl;

  String urlFor(double size) => size > 52 ? (displayUrl ?? smallUrl) : smallUrl;

  Uri get productPage => offProductPageUrl(barcode);
}

/// The public Open Food Facts page of [barcode] (target of the photo credit).
Uri offProductPageUrl(String barcode) =>
    Uri.parse('https://world.openfoodfacts.org/product/$barcode');

/// EAN-8, UPC-A, EAN-13 and GTIN-14: only digits, one of these lengths.
bool isValidBarcode(String code) =>
    RegExp(r'^(\d{8}|\d{12}|\d{13}|\d{14})$').hasMatch(code);

/// Food search, barcode lookup and product photos via Open Food Facts, a
/// free crowd-sourced product database without an API key.
///
/// Two endpoints: `search.openfoodfacts.org` (search-a-licious) for name
/// search and `world.openfoodfacts.org/api/v2/product/{barcode}` for exact
/// barcodes. Requests stay within [OffRateLimits]; photos come only from
/// Open Food Facts' own image hosts, never from retailers or leaflets.
class OpenFoodFactsService {
  OpenFoodFactsService._({
    http.Client? client,
    OffRateLimits? limits,
    Future<void> Function(Duration)? delay,
  }) : _client = client,
       _limits = limits ?? OffRateLimits.shared,
       _delay = delay ?? Future<void>.delayed;

  static final OpenFoodFactsService instance = OpenFoodFactsService._();

  @visibleForTesting
  factory OpenFoodFactsService.forTesting({
    required http.Client client,
    required OffRateLimits limits,
    required Future<void> Function(Duration) delay,
  }) => OpenFoodFactsService._(client: client, limits: limits, delay: delay);

  static const _searchBaseUrl = 'https://search.openfoodfacts.org/search';
  static const _productBaseUrl =
      'https://world.openfoodfacts.org/api/v2/product';
  static const _fields =
      'code,product_name,brands,nutriments,image_front_small_url,'
      'serving_quantity,product_quantity,product_quantity_unit';
  static const _photoFields = 'code,image_front_small_url,image_front_url';
  static const _timeout = Duration(seconds: 8);

  static const _photoCachePrefix = 'off_photo_v1_';
  static const _photoTtl = Duration(days: 30);
  static const _noPhotoTtl = Duration(days: 7);

  final http.Client? _client;
  final OffRateLimits _limits;
  final Future<void> Function(Duration) _delay;

  int _searchGeneration = 0;
  final Map<String, OffProductPhoto?> _photos = {};
  final Map<String, Future<OffProductPhoto?>> _photoRequests = {};

  Future<http.Response> _get(Uri uri) {
    final headers = {'User-Agent': offUserAgent};
    final client = _client;
    final request = client == null
        ? http.get(uri, headers: headers)
        : client.get(uri, headers: headers);
    return request.timeout(_timeout);
  }

  /// Waits for a slot of [limiter], at most one window. False when
  /// [stillWanted] turns false while waiting.
  Future<bool> _acquire(
    SlidingWindowRateLimiter limiter, {
    bool Function()? stillWanted,
  }) async {
    while (!limiter.tryAcquire()) {
      await _delay(limiter.timeUntilFree());
      if (stillWanted != null && !stillWanted()) return false;
    }
    return true;
  }

  /// Searches by free-text name; an empty list means OFF knows nothing
  /// that matches. Throws [OffRequestFailed] on a network or server error.
  /// At the search limit it waits for a free slot (the caller keeps showing
  /// its loading state) rather than answering "no results"; a search still
  /// waiting is dropped with an empty answer when a newer one starts
  /// (typing).
  Future<List<FoodProduct>> search(String query, {int limit = 15}) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];
    final generation = ++_searchGeneration;
    final allowed = await _acquire(
      _limits.search,
      stillWanted: () => generation == _searchGeneration,
    );
    if (!allowed) {
      debugPrint('🔵 [OpenFoodFacts] Waiting search dropped for a newer one');
      return [];
    }
    final uri = Uri.parse(_searchBaseUrl).replace(
      queryParameters: {
        'q': trimmed,
        'page_size': '$limit',
        'fields': _fields,
      },
    );
    final response = await _send(uri, 'Search');
    if (response.statusCode != 200) {
      debugPrint('⚠️ [OpenFoodFacts] Search returned ${response.statusCode}');
      throw OffRequestFailed('http_${response.statusCode}');
    }
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final hits = body['hits'] as List? ?? [];
      return hits
          .cast<Map<String, dynamic>>()
          .map(FoodProduct.fromOpenFoodFacts)
          .where((p) => p.barcode.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('⚠️ [OpenFoodFacts] Search answer unreadable: ${e.runtimeType}');
      throw const OffRequestFailed('unreadable');
    }
  }

  /// Sends [uri]; network errors and timeouts become [OffRequestFailed].
  Future<http.Response> _send(Uri uri, String what) async {
    try {
      return await _get(uri);
    } on TimeoutException {
      debugPrint('⚠️ [OpenFoodFacts] $what timed out');
      throw const OffRequestFailed('timeout');
    } catch (e) {
      debugPrint('⚠️ [OpenFoodFacts] $what failed: ${e.runtimeType}');
      throw const OffRequestFailed('network');
    }
  }

  /// Exact-barcode lookup (scan or typed number). Null when OFF does not
  /// know the barcode; throws [OffRequestFailed] on a network or server
  /// error. At the product limit it waits for a free slot rather than
  /// answering "not found".
  Future<FoodProduct?> lookupBarcode(String barcode) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return null;
    await _acquire(_limits.product);
    final uri = Uri.parse(
      '$_productBaseUrl/$trimmed.json',
    ).replace(queryParameters: {'fields': _fields});
    final response = await _send(uri, 'Barcode lookup');
    // OFF answers an unknown barcode with 404 and `status: 0`.
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      debugPrint('⚠️ [OpenFoodFacts] Barcode lookup returned ${response.statusCode}');
      throw OffRequestFailed('http_${response.statusCode}');
    }
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('⚠️ [OpenFoodFacts] Barcode answer unreadable: ${e.runtimeType}');
      throw const OffRequestFailed('unreadable');
    }
    if (body['status'] == 0) return null; // OFF's "not found" marker
    final product = body['product'] as Map<String, dynamic>?;
    if (product == null) return null;
    // The v2 endpoint doesn't echo `code` inside `product` on every
    // response — fall back to the barcode we looked up.
    product['code'] ??= trimmed;
    return FoodProduct.fromOpenFoodFacts(product);
  }

  /// The front photo of [barcode] for article images, or null.
  ///
  /// Answers (also "no photo": an unknown barcode, which OFF answers with
  /// HTTP 404, or a product without a front photo) are kept in memory and
  /// on the device, so a list asks once per product. Server errors and
  /// timeouts answer null without being cached. A lookup never waits: it
  /// runs only while the product limit has room beyond
  /// [OffRateLimits.backgroundKeepFree]; otherwise it throws
  /// [OffRateLimited] saying when to ask again.
  Future<OffProductPhoto?> productPhoto(String barcode) {
    final code = barcode.trim();
    if (!isValidBarcode(code)) return Future.value(null);
    if (_photos.containsKey(code)) return Future.value(_photos[code]);
    // A block body: an arrow would hand the removed future itself back to
    // whenComplete, which would then wait for itself.
    return _photoRequests[code] ??= _loadPhoto(code).whenComplete(() {
      _photoRequests.remove(code);
    });
  }

  Future<OffProductPhoto?> _loadPhoto(String code) async {
    final cached = await _readPhotoCache(code);
    if (cached != null) {
      _photos[code] = cached.photo;
      return cached.photo;
    }
    const keepFree = OffRateLimits.backgroundKeepFree;
    if (!_limits.product.tryAcquire(keepFree: keepFree)) {
      throw OffRateLimited(_limits.product.timeUntilFree(keepFree: keepFree));
    }
    try {
      final uri = Uri.parse(
        '$_productBaseUrl/$code.json',
      ).replace(queryParameters: {'fields': _photoFields});
      final response = await _get(uri);
      final OffProductPhoto? photo;
      if (response.statusCode == 404) {
        photo = null; // OFF does not know the barcode.
      } else if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final product = body['status'] == 0
            ? null
            : body['product'] as Map<String, dynamic>?;
        photo = product == null ? null : _photoFrom(code, product);
      } else {
        debugPrint(
          '⚠️ [OpenFoodFacts] Photo lookup got ${response.statusCode}',
        );
        return null;
      }
      _photos[code] = photo;
      await _writePhotoCache(code, photo);
      return photo;
    } catch (e) {
      debugPrint('⚠️ [OpenFoodFacts] Photo lookup failed: $e');
      return null;
    }
  }

  static OffProductPhoto? _photoFrom(String code, Map<String, dynamic> p) {
    final small = _offImageUrl(p['image_front_small_url']);
    final display = _offImageUrl(p['image_front_url']);
    final first = small ?? display;
    if (first == null) return null;
    return OffProductPhoto(barcode: code, smallUrl: first, displayUrl: display);
  }

  /// Only https URLs on Open Food Facts' own hosts; anything else (a
  /// retailer or leaflet image) is dropped.
  static String? _offImageUrl(Object? raw) {
    if (raw is! String) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https') return null;
    final host = uri.host;
    if (host != 'openfoodfacts.org' && !host.endsWith('.openfoodfacts.org')) {
      return null;
    }
    return raw;
  }

  Future<({OffProductPhoto? photo})?> _readPhotoCache(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_photoCachePrefix$code');
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final at = DateTime.tryParse(json['at'] as String? ?? '');
      final small = json['small'] as String?;
      final ttl = small == null ? _noPhotoTtl : _photoTtl;
      if (at == null || DateTime.now().difference(at) > ttl) return null;
      if (small == null) return (photo: null);
      return (
        photo: OffProductPhoto(
          barcode: code,
          smallUrl: small,
          displayUrl: json['display'] as String?,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writePhotoCache(String code, OffProductPhoto? photo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_photoCachePrefix$code',
        jsonEncode({
          'at': DateTime.now().toIso8601String(),
          'small': photo?.smallUrl,
          'display': photo?.displayUrl,
        }),
      );
    } catch (_) {
      // Caching is best-effort.
    }
  }
}
