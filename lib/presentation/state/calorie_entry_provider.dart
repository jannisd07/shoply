import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/dietary_preference.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/food_product.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/user_food.dart';
import 'package:shoply/data/models/user_model.dart';
import 'package:shoply/data/services/allergen_matcher.dart';
import 'package:shoply/data/services/claude_service.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/meal_photo_analysis_service.dart';
import 'package:shoply/data/services/meal_photo_storage_service.dart';
import 'package:shoply/data/services/native/barcode_scanner_channel.dart';
import 'package:shoply/data/services/native/meal_camera_channel.dart';
import 'package:shoply/data/services/open_food_facts_service.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/data/services/user_food_service.dart';
import 'package:shoply/data/services/user_service.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';

// State for logging food (S4–S10) and the goal screens (S13, S14) of
// `docs/redesign/b-screens/kalorien.md`: product cache and own foods (local
// first), barcode lookup and food search, the camera, the AI estimates and
// the person's profile. Every outside call sits behind a provider, so the
// screens run on fakes in tests.

// ── Flags ───────────────────────────────────────────────────────────────

/// The B6 migration is applied (`app_flags.calories_schema_v2`): own foods
/// (`user_food`) exist and entries may carry the new sources.
final calorieSchemaV2Provider = Provider<bool>(
  (ref) => ref.watch(appFlagsProvider.select((f) => f.isEnabled(calorieSchemaV2FlagKey, fallback: false))),
);

// ── Camera ──────────────────────────────────────────────────────────────

/// What the photo (S4) and barcode (S6) screens need from the device. The
/// native screens cannot run in tests; a fake stands in.
abstract class CalorieCamera {
  /// The VisionKit barcode scanner exists (iOS 16+, A12 or newer).
  Future<bool> scannerSupported();

  /// A back camera exists.
  Future<bool> cameraAvailable();
  Future<CameraPermission> permission();

  /// Shows the system camera question (only after the app's own alert).
  Future<bool> requestAccess();
  Future<BarcodeScanResult> scan(BarcodeScannerLabels labels);
  Future<MealPhotoResult> takePhoto(MealCameraLabels labels);
  Future<MealPhotoResult> pickPhoto();
}

class NativeCalorieCamera implements CalorieCamera {
  NativeCalorieCamera({BarcodeScannerChannel? scanner, MealCameraChannel? camera})
      : _scanner = scanner ?? BarcodeScannerChannel.instance,
        _camera = camera ?? MealCameraChannel.instance;

  final BarcodeScannerChannel _scanner;
  final MealCameraChannel _camera;

  @override
  Future<bool> scannerSupported() => _scanner.isSupported();
  @override
  Future<bool> cameraAvailable() => _camera.isAvailable();
  @override
  Future<CameraPermission> permission() => _scanner.cameraPermission();
  @override
  Future<bool> requestAccess() => _scanner.requestCameraAccess();
  @override
  Future<BarcodeScanResult> scan(BarcodeScannerLabels labels) => _scanner.scan(labels: labels);
  @override
  Future<MealPhotoResult> takePhoto(MealCameraLabels labels) => _camera.takePhoto(labels: labels);
  @override
  Future<MealPhotoResult> pickPhoto() => _camera.pickPhoto();
}

final calorieCameraProvider = Provider<CalorieCamera>((ref) => NativeCalorieCamera());

/// The camera reads barcodes here (S3 "Kamera öffnen"); false on iOS 15,
/// devices before A12 and other platforms.
final calorieScannerSupportedProvider = FutureProvider<bool>(
  (ref) => ref.watch(calorieCameraProvider).scannerSupported(),
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
    if (key != null && _ref.read(calorieSchemaV2Provider)) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    try {
      final foods = await _ref.read(userFoodsRemoteProvider)();
      if (!mounted) return;
      final local = state.where((f) => !foods.any((s) => s.id == f.id));
      _set([...local, ...foods]);
    } catch (e) {
      debugPrint('⚠️ [UserFoods] Refresh failed: ${e is CalorieDataException ? e.code.name : e.runtimeType}');
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
    final existing = food.barcode == null ? null : byBarcode(food.barcode!);
    final toSave = existing == null || food.id.isNotEmpty
        ? food
        : UserFood.fromJson({...food.toJson(), 'id': existing.id, 'user_id': existing.userId});
    final saved = await _ref.read(calorieDiaryProvider).saveUserFood(toSave);
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
Future<FoodProduct?> lookupCalorieBarcode(Ref ref, String code, {bool scanned = true}) async {
  final cache = ref.read(calorieProductCacheProvider.notifier);
  final own = ref.read(userFoodsProvider.notifier).byBarcode(code);
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

// ── AI estimates ────────────────────────────────────────────────────────

/// The photo estimate of S5; override in tests.
final mealPhotoAnalyzerProvider = Provider<Future<MealPhotoEstimate> Function(Uint8List photo)>(
  (ref) => (photo) => MealPhotoAnalysisService.instance.analyzePhoto(photo),
);

/// A text estimate (task `nutrition_estimate`): per serving for a recipe,
/// as eaten for a food.
@immutable
class CalorieNutritionEstimate {
  const CalorieNutritionEstimate({
    required this.kcal,
    this.proteinG,
    this.carbsG,
    this.fatG,
    required this.confidence,
  });

  final int kcal;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final EstimateConfidence confidence;
}

typedef CalorieNutritionEstimator = Future<CalorieNutritionEstimate> Function(String text, {int? servings});

/// The server task leaves room inside a 10 s client deadline.
const Duration _kNutritionTimeout = Duration(seconds: 10);

/// "Kalorien schätzen lassen" (S8, S10). Throws [ClaudeException].
final calorieNutritionEstimatorProvider = Provider<CalorieNutritionEstimator>((ref) {
  return (String text, {int? servings}) async {
    final result = await ClaudeService.instance.run(
      'nutrition_estimate',
      {'text': text, if (servings != null && servings > 0) 'servings': servings},
      timeout: _kNutritionTimeout,
    );
    final kcal = result['kcal'];
    if (kcal is! num || !kcal.isFinite || kcal < 0) throw const ClaudeException('provider_error');
    double? grams(Object? v) => v is num && v.isFinite && v >= 0 ? v.toDouble() : null;
    return CalorieNutritionEstimate(
      kcal: kcal.round(),
      proteinG: grams(result['protein_g']),
      carbsG: grams(result['carbs_g']),
      fatG: grams(result['fat_g']),
      confidence: EstimateConfidenceX.fromDb(result['confidence'] as String?) ?? EstimateConfidence.low,
    );
  };
});

String _photoLimitKey(String userId) => 'cal_photo_limit_v1_$userId';

/// Today's photo estimates are used up (the server answered
/// `quota_exceeded` today). S3 then shows the limit instead of the camera.
final caloriePhotoLimitReachedProvider = StateNotifierProvider.autoDispose<CaloriePhotoLimit, bool>((ref) {
  final userId = ref.watch(authUserIdProvider);
  final prefs = ref.watch(calorieSharedPreferencesProvider).valueOrNull;
  final today = ref.watch(calorieTodayKeyProvider);
  final key = userId == null ? null : _photoLimitKey(userId);
  return CaloriePhotoLimit(
    reached: key != null && prefs?.getString(key) == today,
    save: key == null || prefs == null ? null : () => prefs.setString(key, today),
  );
});

class CaloriePhotoLimit extends StateNotifier<bool> {
  CaloriePhotoLimit({required bool reached, this.save}) : super(reached);

  final Future<bool> Function()? save;

  void markReached() {
    state = true;
    unawaited(save?.call());
  }
}

// ── Photos in the private bucket ────────────────────────────────────────

final mealPhotoStorageProvider = Provider<MealPhotoStorageService>((ref) => MealPhotoStorageService.instance);

/// A signed URL for a meal photo path (cached by path in the service).
final mealPhotoUrlProvider = FutureProvider.autoDispose.family<String?, String>(
  (ref, path) => ref.watch(mealPhotoStorageProvider).signedUrl(path),
);

// ── The person ──────────────────────────────────────────────────────────

/// The signed-in person's profile (allergies, age, sex, height); override in
/// tests.
final calorieUserProfileProvider = FutureProvider.autoDispose<UserModel?>(
  (ref) => ref.watch(currentUserProvider.future),
);

/// The person's allergies as the matcher reads them (S5).
final calorieAllergiesProvider = Provider.autoDispose<AllergenMatcher>((ref) {
  final user = ref.watch(calorieUserProfileProvider).valueOrNull;
  return AllergenMatcher(user?.allergies ?? const []);
});

typedef CalorieProfileWriter = Future<void> Function({required int age, required double heightCm, required String gender});

/// Keeps age, height and sex in the profile after "Übernehmen" (S14). Best
/// effort: the goal itself goes through the write queue.
final calorieProfileWriterProvider = Provider<CalorieProfileWriter>((ref) {
  return ({required int age, required double heightCm, required String gender}) async {
    final user = await ref.read(currentUserProvider.future);
    if (user == null) return;
    await UserService.instance.updateUserProfile(
      user.copyWith(age: age, height: heightCm, heightUnit: 'cm', gender: gender),
    );
    ref.invalidate(currentUserProvider);
  };
});

// ── Recipes (S10) ───────────────────────────────────────────────────────

/// Loads a recipe for `/calories/add/recipe/:recipeId` without an `extra`
/// (deep link); override in tests.
final calorieRecipeLoaderProvider = Provider<Future<Recipe> Function(String id)>(
  (ref) => RecipeService.instance.getRecipeById,
);

// ── "Essen eintragen" ───────────────────────────────────────────────────

/// The segments of S3.
enum CalorieInputMethod { photo, barcode, search }

String _inputMethodKey(String userId) => 'cal_input_method_v1_$userId';

/// The last segment the person used on S3 (first time: "Suche").
final calorieInputMethodProvider = StateNotifierProvider.autoDispose<CalorieInputMethodNotifier, CalorieInputMethod>((ref) {
  final userId = ref.watch(authUserIdProvider);
  final prefs = ref.watch(calorieSharedPreferencesProvider).valueOrNull;
  final key = userId == null ? null : _inputMethodKey(userId);
  final stored = key == null ? null : prefs?.getString(key);
  return CalorieInputMethodNotifier(
    CalorieInputMethod.values.where((m) => m.name == stored).firstOrNull ?? CalorieInputMethod.search,
    key == null || prefs == null ? null : (m) => prefs.setString(key, m.name),
  );
});

class CalorieInputMethodNotifier extends StateNotifier<CalorieInputMethod> {
  CalorieInputMethodNotifier(super.state, this._save);

  final Future<bool> Function(CalorieInputMethod)? _save;

  void choose(CalorieInputMethod method) {
    state = method;
    unawaited(_save?.call(method));
  }
}

/// A logged entry of [dateKey] by id, or null when it is gone (deleted
/// here or on another device).
final calorieEntryProvider =
    Provider.autoDispose.family<FoodLogEntry?, ({String dateKey, String id})>((ref, key) {
  final day = ref.watch(calorieDayProvider(key.dateKey)).day;
  return day?.entries.where((e) => e.id == key.id).firstOrNull;
});

/// Allergies of [allergies] that [estimate] likely contains: the types the
/// server named plus the keywords of the dish and its parts (compounds
/// too), each once.
List<AllergenMatch> estimateAllergyMatches(
  AllergenMatcher allergies, {
  required String dish,
  required Iterable<String> components,
  required Iterable<AllergyType> named,
}) {
  final found = <AllergenMatch>[
    ...allergies.matchesAll([dish, ...components]),
  ];
  for (final raw in allergies.allergies) {
    final type = AllergenMatcher.resolve(raw);
    if (type == null || !named.contains(type)) continue;
    if (found.any((m) => m.type == type || m.allergy == raw)) continue;
    found.add(AllergenMatch(allergy: raw, type: type, matchedText: type.name));
  }
  final seen = <String>{};
  return [for (final m in found) if (seen.add(m.type?.name ?? m.allergy)) m];
}
