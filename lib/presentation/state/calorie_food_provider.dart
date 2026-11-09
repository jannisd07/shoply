import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/food_product.dart';
import 'package:shoply/data/models/user_food.dart';
import 'package:shoply/data/services/calorie_day_store.dart';
import 'package:shoply/data/services/calorie_write_queue.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/open_food_facts_service.dart';
import 'package:shoply/data/services/user_food_service.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';

// Foods for logging (S3, S6, S7, S8): the B6 schema flag, the product cache
// on this device, own foods (`user_food`), the barcode lookup and the food
// search. Local first; every outside call sits behind a provider.

// ── Flags ───────────────────────────────────────────────────────────────

/// The B6 migration is applied (`app_flags.calories_schema_v2`): own foods
/// (`user_food`) exist and entries may carry the new sources.
final calorieSchemaV2Provider = Provider<bool>(
  (ref) => ref.watch(appFlagsProvider.select((f) => f.isEnabled(calorieSchemaV2FlagKey, fallback: false))),
);

// ── Product cache and "Zuletzt gescannt" ───────────────────────────────

/// How many products this device keeps, and how many scans S3 lists.
const int _kCachedProducts = 200;
const int kCalorieRecentScans = 5;

@immutable
class CalorieProductCacheState {
  const CalorieProductCacheState({this.products = const {}, this.scanned = const []});

  /// By barcode.
  final Map<String, FoodProduct> products;

  /// Barcodes scanned or typed, newest first.
  final List<String> scanned;

  List<FoodProduct> get recentScans => [
        for (final code in scanned)
          if (products[code] case final p?) p,
      ];
}

/// Products looked up by barcode, kept on the device so a known product
/// opens offline and in the first frame (S3, S6, S7).
class CalorieProductCache extends StateNotifier<CalorieProductCacheState> {
  CalorieProductCache(this._key, this._read, this._write) : super(const CalorieProductCacheState()) {
    _load();
  }

  final String? _key;
  final String? Function(String key)? _read;
  final Future<bool> Function(String key, String value)? _write;

  void _load() {
    final key = _key;
    final raw = key == null ? null : _read?.call(key);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      state = CalorieProductCacheState(
        products: {
          for (final p in (json['products'] as List? ?? const []))
            (p as Map<String, dynamic>)['barcode'] as String: FoodProduct.fromCacheJson(p),
        },
        scanned: [...(json['scanned'] as List? ?? const []).cast<String>()],
      );
    } catch (e) {
      debugPrint('⚠️ [CalorieProducts] Stored products unreadable: ${e.runtimeType}');
    }
  }

  FoodProduct? find(String barcode) => state.products[barcode];

  /// Keeps [product]; [scanned] also puts it first in "Zuletzt gescannt".
  void put(FoodProduct product, {bool scanned = false}) {
    if (product.barcode.isEmpty) return;
    final products = {...state.products}..remove(product.barcode);
    products[product.barcode] = product;
    while (products.length > _kCachedProducts) {
      products.remove(products.keys.first);
    }
    final list = scanned
        ? [product.barcode, ...state.scanned.where((c) => c != product.barcode)].take(kCalorieRecentScans).toList()
        : state.scanned;
    state = CalorieProductCacheState(products: products, scanned: list);
    final key = _key;
    if (key != null) {
      unawaited(_write?.call(
        key,
        jsonEncode({
          'products': [for (final p in products.values) p.toCacheJson()],
          'scanned': list,
        }),
      ));
    }
  }
}

final calorieProductCacheProvider =
    StateNotifierProvider<CalorieProductCache, CalorieProductCacheState>((ref) {
  final userId = ref.watch(authUserIdProvider);
  final prefs = ref.watch(calorieSharedPreferencesProvider).valueOrNull;
  return CalorieProductCache(
    userId == null || prefs == null ? null : 'cal_products_v1_$userId',
    prefs?.getString,
    prefs?.setString,
  );
});

// ── Own foods ("Eigene") ───────────────────────────────────────────────

/// Loads the person's own foods from the server; override in tests.
final userFoodsRemoteProvider = Provider<Future<List<UserFood>> Function()>(
  (ref) => () => UserFoodService.instance.getAll(),
);

/// Own foods, newest first: stored on the device, refreshed from
/// `user_food` once the migration is there, added to at once when one is
/// saved (S7, S8, S9) and written through the queue.
class UserFoodsNotifier extends StateNotifier<List<UserFood>> {
  UserFoodsNotifier(this._ref, this._key) : super(const []) {
    _load();
  }

  final Ref _ref;
  final String? _key;
  final Completer<void> _ready = Completer<void>();

  /// Completes once the first server answer is in (or failed, or there is
  /// none to wait for), so a barcode lookup sees own foods first.
  Future<void> get ready => _ready.future;

  void _load() {
    final key = _key;
    final prefs = _ref.read(calorieSharedPreferencesProvider).valueOrNull;
    final raw = key == null ? null : prefs?.getString(key);
    if (raw != null) {
      try {
        state = [for (final f in jsonDecode(raw) as List) UserFood.fromJson(f as Map<String, dynamic>)];
      } catch (e) {
        debugPrint('⚠️ [UserFoods] Stored foods unreadable: ${e.runtimeType}');
      }
    }
    if (key != null && _ref.read(calorieSchemaV2Provider)) {
      unawaited(_refresh());
    } else {
      _ready.complete();
    }
  }

  /// Foods saved while [_refresh] waits for the server: its answer is older
  /// than them, even when their write has already left the queue.
  Set<String>? _savedDuringRefresh;

  Future<void> _refresh() async {
    final savedMeanwhile = _savedDuringRefresh = <String>{};
    try {
      final foods = await _ref.read(userFoodsRemoteProvider)();
      if (!mounted) return;
      // Foods still on their way to the server, or saved since the request
      // went out, win over the server's list; other local ones were deleted
      // elsewhere.
      final keep = {
        ...savedMeanwhile,
        for (final w in _ref.read(calorieBackendProvider).valueOrNull?.queue.writes ?? const <QueuedWrite>[])
          if (w.kind == CalorieWriteKinds.userFood) w.entityId,
      };
      final local = state.where((f) => keep.contains(f.id)).toList();
      final localIds = {for (final f in local) f.id};
      _set([...local, ...foods.where((f) => !localIds.contains(f.id))]);
    } catch (e) {
      debugPrint('⚠️ [UserFoods] Refresh failed: ${e is CalorieDataException ? e.code.name : e.runtimeType}');
    } finally {
      _savedDuringRefresh = null;
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  void _set(List<UserFood> foods) {
    state = foods;
    final key = _key;
    final prefs = _ref.read(calorieSharedPreferencesProvider).valueOrNull;
    if (key != null && prefs != null) {
      unawaited(prefs.setString(key, jsonEncode([for (final f in foods) f.toJson()])));
    }
  }

  /// The own food with [barcode], if there is one.
  UserFood? byBarcode(String barcode) => state.where((f) => f.barcode == barcode).firstOrNull;

  /// Saves [food] (new or changed, matched by id or barcode) and queues it.
  /// Does nothing before the migration: the table does not exist yet.
  Future<UserFood?> save(UserFood food) async {
    if (!_ref.read(calorieSchemaV2Provider)) return null;
    // Never queue a row the server rejects for good.
    if (!food.fitsServer) {
      debugPrint('⚠️ [UserFoods] Not saved: values outside the user_food limits');
      return null;
    }
    final existing = food.barcode == null ? null : byBarcode(food.barcode!);
    final toSave = existing == null || food.id.isNotEmpty
        ? food
        : UserFood.fromJson({...food.toJson(), 'id': existing.id, 'user_id': existing.userId});
    final saved = await _ref.read(calorieDiaryProvider).saveUserFood(toSave);
    _savedDuringRefresh?.add(saved.id);
    if (mounted) _set([saved, ...state.where((f) => f.id != saved.id)]);
    return saved;
  }
}

final userFoodsProvider = StateNotifierProvider<UserFoodsNotifier, List<UserFood>>((ref) {
  final userId = ref.watch(authUserIdProvider);
  ref.watch(calorieSharedPreferencesProvider);
  return UserFoodsNotifier(ref, userId == null ? null : 'cal_user_foods_v1_$userId');
});

// ── Barcode lookup and food search ─────────────────────────────────────

/// Open Food Facts behind providers, so tests never reach the network.
final calorieOffBarcodeProvider = Provider<Future<FoodProduct?> Function(String code)>(
  (ref) => OpenFoodFactsService.instance.lookupBarcode,
);
final calorieOffSearchProvider = Provider<Future<List<FoodProduct>> Function(String query)>(
  (ref) => OpenFoodFactsService.instance.search,
);

/// The product behind [code] (S3 number field, S6, S7): own foods win, then
/// the products on this device, then Open Food Facts. Null when nothing is
/// known about it; throws [OffRequestFailed] when it is not on the device
/// and Open Food Facts cannot be reached (offline: `offline`). A found
/// product is kept on the device and listed under "Zuletzt gescannt".
/// How long a lookup waits for the own foods to arrive from the server.
const Duration _kOwnFoodsWait = Duration(seconds: 3);

Future<FoodProduct?> lookupCalorieBarcode(Ref ref, String code, {bool scanned = true}) async {
  final cache = ref.read(calorieProductCacheProvider.notifier);
  final foods = ref.read(userFoodsProvider.notifier);
  if (!ref.read(isOfflineProvider)) {
    await foods.ready.timeout(_kOwnFoodsWait, onTimeout: () {});
  }
  final own = foods.byBarcode(code);
  if (own != null) {
    final product = own.toFoodProduct();
    cache.put(product, scanned: scanned);
    return product;
  }
  final cached = cache.find(code);
  if (cached != null) {
    cache.put(cached, scanned: scanned);
    return cached;
  }
  if (ref.read(isOfflineProvider)) throw const OffRequestFailed('offline');
  final product = await ref.read(calorieOffBarcodeProvider)(code);
  if (product == null || !product.hasName) return null;
  cache.put(product, scanned: scanned);
  return product;
}

/// [lookupCalorieBarcode] for widgets.
final calorieBarcodeLookupProvider = Provider<Future<FoodProduct?> Function(String code)>(
  (ref) => (code) => lookupCalorieBarcode(ref, code),
);

/// Open Food Facts hits for [query] (S3 "Lebensmittel"), only products with
/// a name. Throws on a network error (never an empty list for it).
final calorieFoodSearchProvider =
    FutureProvider.autoDispose.family<List<FoodProduct>, String>((ref, query) async {
  final hits = await ref.watch(calorieOffSearchProvider)(query);
  return hits.where((p) => p.hasName).toList();
});
