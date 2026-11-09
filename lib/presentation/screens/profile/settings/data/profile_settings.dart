import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/models/dietary_preference.dart';
import 'package:shoply/data/models/user_model.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/onboarding_answers_service.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

/// Writes the account values of the settings pages, each as a targeted
/// update of its own `users` columns (never the whole row). Overridden in
/// tests.
abstract interface class ProfileSettingsBackend {
  /// `users.diet_preferences` and `users.allergies` (Konzept 17 §9.7).
  Future<void> saveDiet({
    required List<String> dietPreferences,
    required List<String> allergies,
  });

  /// `users.age`, `users.height` (always in cm), `users.height_unit` (the
  /// unit shown) and `users.gender`.
  Future<void> savePersonal(PersonalSettings values);

  /// `users.language` (`de`/`en`), for server texts and a second device.
  Future<void> saveLanguage(String languageCode);
}

/// The Supabase implementation.
class SupabaseProfileSettingsBackend implements ProfileSettingsBackend {
  /// Creates the backend.
  const SupabaseProfileSettingsBackend();

  String _uid() {
    final id = SupabaseService.instance.currentUser?.id;
    if (id == null) throw StateError('Not signed in');
    return id;
  }

  @override
  Future<void> saveDiet({
    required List<String> dietPreferences,
    required List<String> allergies,
  }) => OnboardingAnswersService.instance.saveDiet(
    dietPreferences: dietPreferences,
    allergies: allergies,
  );

  @override
  Future<void> savePersonal(PersonalSettings values) async {
    await SupabaseService.instance
        .from('users')
        .update({
          'age': values.age,
          'height': values.heightCm,
          'height_unit': values.unit.storageKey,
          'gender': values.gender,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', _uid());
  }

  @override
  Future<void> saveLanguage(String languageCode) async {
    await SupabaseService.instance
        .from('users')
        .update({
          'language': languageCode,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', _uid());
  }
}

/// Where the settings pages write the account.
final profileSettingsBackendProvider = Provider<ProfileSettingsBackend>(
  (ref) => const SupabaseProfileSettingsBackend(),
);

/// Sends the newest value of a setting, one write at a time, and keeps a
/// failed value to send again (offline: local first, sync later; Konzept 18
/// §5 frame).
class _LatestWrite<T> {
  _LatestWrite(this._write, this._onSaved);

  final Future<void> Function(T value) _write;
  final VoidCallback _onSaved;
  T? _next;
  T? _failed;
  bool _running = false;

  /// A value is waiting or failed: account values must not replace the
  /// local state yet.
  bool get busy => _running || _next != null || _failed != null;

  /// The last write failed and waits for [retry].
  bool get failed => _failed != null;

  Future<void> push(T value) async {
    _next = value;
    _failed = null;
    if (_running) return;
    _running = true;
    try {
      while (_next != null) {
        final v = _next as T;
        _next = null;
        try {
          await _write(v);
        } catch (e) {
          debugPrint('⚠️ [SETTINGS] Saving failed, kept locally: $e');
          if (_next == null) _failed = v;
        }
      }
    } finally {
      _running = false;
    }
    if (_failed == null) _onSaved();
  }

  Future<void> retry() async {
    final v = _failed;
    if (v == null || _running) return;
    await push(v);
  }
}

// ------------------------------------------------------------------- diet

/// Ernährung & Allergien (Konzept 18 §5.2) as the chips show it.
@immutable
class DietSettings {
  /// Creates the state.
  const DietSettings({
    this.diet = const {},
    this.allergies = const {},
    this.otherAllergies = const [],
    this.loaded = false,
  });

  /// Diet chips ([kOnboardingDietIds]); empty means "no restriction".
  final Set<String> diet;

  /// Allergy chips ([AllergyType] names).
  final Set<String> allergies;

  /// Allergies saved as free text (by Avo, "Kiwi"): shown as chips and kept
  /// on every save, never dropped.
  final List<String> otherAllergies;

  /// The account values have been read (or there is no account).
  final bool loaded;

  /// All allergies, chips and free text.
  int get allergyCount => allergies.length + otherAllergies.length;

  /// The state from an account row: "frei von" diets of old rows show as
  /// allergies (Konzept 17 §9.7), but only when no allergy explains them
  /// already ([mergeDietAndAllergies] writes `nut_free` for peanuts, which
  /// must not come back as tree nuts).
  factory DietSettings.of(UserModel user) {
    final known = {for (final t in AllergyType.values) t.name};
    final stored = <String>{
      for (final a in user.allergies)
        if (known.contains(a)) a,
    };
    final explained = mergeDietAndAllergies(
      diet: const {},
      allergies: stored,
    ).dietPreferences.toSet();
    final allergies = <String>{
      ...stored,
      ...allergiesImpliedByDiet([
        for (final d in user.dietPreferences)
          if (!explained.contains(d)) d,
      ]),
    };
    final other = <String>[
      for (final a in user.allergies)
        if (!known.contains(a) && a.trim().isNotEmpty) a.trim(),
    ];
    return DietSettings(
      diet: {
        for (final d in user.dietPreferences)
          if (kOnboardingDietIds.contains(d)) d,
      },
      allergies: allergies,
      otherAllergies: other,
      loaded: true,
    );
  }

  DietSettings copyWith({
    Set<String>? diet,
    Set<String>? allergies,
    List<String>? otherAllergies,
  }) => DietSettings(
    diet: diet ?? this.diet,
    allergies: allergies ?? this.allergies,
    otherAllergies: otherAllergies ?? this.otherAllergies,
    loaded: true,
  );

  /// What is written: both columns through [mergeDietAndAllergies], the
  /// free-text allergies after the known ones.
  ({List<String> dietPreferences, List<String> allergies}) toColumns() {
    final merged = mergeDietAndAllergies(diet: diet, allergies: allergies);
    return (
      dietPreferences: merged.dietPreferences,
      allergies: [...merged.allergies, ...otherAllergies],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DietSettings &&
      other.loaded == loaded &&
      setEquals(other.diet, diet) &&
      setEquals(other.allergies, allergies) &&
      listEquals(other.otherAllergies, otherAllergies);

  @override
  int get hashCode => Object.hash(
    loaded,
    Object.hashAllUnordered(diet),
    Object.hashAllUnordered(allergies),
    Object.hashAll(otherAllergies),
  );
}

/// Chips change at once and are written in the background; account values
/// that arrive later (another device, Avo) replace them while nothing local
/// is waiting.
class DietSettingsNotifier extends StateNotifier<DietSettings> {
  DietSettingsNotifier(ProfileSettingsBackend backend, VoidCallback onSaved)
    : super(const DietSettings()) {
    _writer = _LatestWrite<DietSettings>((v) {
      final columns = v.toColumns();
      return backend.saveDiet(
        dietPreferences: columns.dietPreferences,
        allergies: columns.allergies,
      );
    }, onSaved);
  }

  late final _LatestWrite<DietSettings> _writer;

  /// The last save failed (offline); it is sent again when online.
  bool get syncFailed => _writer.failed;

  /// Takes the account values unless a local change is still waiting.
  void adopt(UserModel? user, {required bool known}) {
    if (_writer.busy) return;
    if (user == null) {
      if (known && !state.loaded) state = const DietSettings(loaded: true);
      return;
    }
    final next = DietSettings.of(user);
    if (next != state) state = next;
  }

  void setDiet(String id, bool on) {
    final diet = {...state.diet};
    on ? diet.add(id) : diet.remove(id);
    _change(state.copyWith(diet: diet));
  }

  void setAllergy(String name, bool on) {
    final allergies = {...state.allergies};
    on ? allergies.add(name) : allergies.remove(name);
    _change(state.copyWith(allergies: allergies));
  }

  /// Removes a free-text allergy (tapping its chip).
  void removeOtherAllergy(String text) {
    _change(
      state.copyWith(
        otherAllergies: [
          for (final a in state.otherAllergies)
            if (a != text) a,
        ],
      ),
    );
  }

  /// Undo of [removeOtherAllergy].
  void restoreOtherAllergy(String text) {
    if (state.otherAllergies.contains(text)) return;
    _change(state.copyWith(otherAllergies: [...state.otherAllergies, text]));
  }

  void _change(DietSettings next) {
    state = next;
    unawaited(_writer.push(next));
  }

  /// Sends a failed save again.
  Future<void> retry() => _writer.retry();
}

/// Ernährung & Allergien of the signed-in person. After a save the profile
/// ([currentUserProvider]) is read again, so recipes and Avo follow.
final dietSettingsProvider =
    StateNotifierProvider<DietSettingsNotifier, DietSettings>((ref) {
      ref.watch(authUserIdProvider);
      final notifier = DietSettingsNotifier(
        ref.watch(profileSettingsBackendProvider),
        () => ref.invalidate(currentUserProvider),
      );
      ref.listen<AsyncValue<UserModel?>>(currentUserProvider, (_, next) {
        notifier.adopt(next.valueOrNull, known: next.hasValue);
      }, fireImmediately: true);
      ref.listen<bool>(isOfflineProvider, (previous, offline) {
        if (previous == true && !offline) unawaited(notifier.retry());
      });
      return notifier;
    });

// ---------------------------------------------------------- auto adapting

/// "Rezepte automatisch anpassen" (Konzept 18 §5.2, default on), on this
/// device per account until `users` has a column for it.
class RecipeAutoAdaptNotifier extends StateNotifier<bool> {
  RecipeAutoAdaptNotifier(this._userId) : super(true) {
    unawaited(_load());
  }

  final String? _userId;
  bool _changed = false;

  String get _key => 'setp_recipe_auto_adapt_${_userId ?? 'anon'}';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_key);
      if (saved != null && mounted && !_changed) state = saved;
    } catch (e) {
      debugPrint('⚠️ [SETTINGS] Reading auto adapt failed: $e');
    }
  }

  Future<void> set(bool on) async {
    _changed = true;
    state = on;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, on);
    } catch (e) {
      debugPrint('⚠️ [SETTINGS] Saving auto adapt failed: $e');
    }
  }
}

/// Whether recipes replace ingredients that do not fit. The recipe screens
/// read it through `RecipeDietProfile.autoAdapt`.
final recipeAutoAdaptProvider =
    StateNotifierProvider<RecipeAutoAdaptNotifier, bool>(
      (ref) => RecipeAutoAdaptNotifier(ref.watch(authUserIdProvider)),
    );

// --------------------------------------------------------------- personal

/// How the height is shown (`users.height_unit`).
enum HeightUnit {
  cm('cm'),
  feet('ft');

  const HeightUnit(this.storageKey);

  /// Stored value.
  final String storageKey;

  static HeightUnit fromStorage(String? value) =>
      value == 'ft' ? HeightUnit.feet : HeightUnit.cm;
}

/// Genders of `users.gender`, in the order of the menu (Konzept 18 §5.3).
const List<String> kPersonalGenders = [
  'female',
  'male',
  'other',
  'prefer_not_to_say',
];

/// Centimetres per inch.
const double kCmPerInch = 2.54;

/// [cm] in whole feet and inches, cut like height charts do (182 cm = 5 ft
/// 11 in, not 6 ft).
({int feet, int inches}) cmToFeetInches(double cm) {
  // The tiny margin keeps a value from [feetInchesToCm] on its own inch.
  final total = (cm / kCmPerInch + 1e-6).floor();
  return (feet: total ~/ 12, inches: total % 12);
}

/// Feet and inches in centimetres, exactly (rounded only for display).
double feetInchesToCm(int feet, int inches) =>
    (feet * 12 + inches) * kCmPerInch;

/// Persönliche Daten (Konzept 18 §5.3). The height is kept in cm; old rows
/// that saved decimal feet ("5.7" with `ft`) are read as feet.
@immutable
class PersonalSettings {
  /// Creates the state.
  const PersonalSettings({
    this.age,
    this.heightCm,
    this.unit = HeightUnit.cm,
    this.gender,
    this.loaded = false,
  });

  final int? age;
  final double? heightCm;
  final HeightUnit unit;

  /// One of [kPersonalGenders], or null when not given.
  final String? gender;
  final bool loaded;

  factory PersonalSettings.of(UserModel user) {
    final unit = HeightUnit.fromStorage(user.heightUnit);
    var height = user.height;
    // Before the redesign "5.7 ft" was stored as 5.7 with the unit `ft`.
    if (height != null && unit == HeightUnit.feet && height < 10) {
      height = (height * 12 * kCmPerInch).roundToDouble();
    }
    return PersonalSettings(
      age: user.age,
      heightCm: height,
      unit: unit,
      gender: kPersonalGenders.contains(user.gender) ? user.gender : null,
      loaded: true,
    );
  }

  PersonalSettings copyWith({
    int? age,
    double? heightCm,
    HeightUnit? unit,
    String? gender,
  }) => PersonalSettings(
    age: age ?? this.age,
    heightCm: heightCm ?? this.heightCm,
    unit: unit ?? this.unit,
    gender: gender ?? this.gender,
    loaded: true,
  );

  @override
  bool operator ==(Object other) =>
      other is PersonalSettings &&
      other.age == age &&
      other.heightCm == heightCm &&
      other.unit == unit &&
      other.gender == gender &&
      other.loaded == loaded;

  @override
  int get hashCode => Object.hash(age, heightCm, unit, gender, loaded);
}

/// Values change at once and are written in the background, like
/// [DietSettingsNotifier].
class PersonalSettingsNotifier extends StateNotifier<PersonalSettings> {
  PersonalSettingsNotifier(ProfileSettingsBackend backend, VoidCallback onSaved)
    : super(const PersonalSettings()) {
    _writer = _LatestWrite<PersonalSettings>(backend.savePersonal, onSaved);
  }

  late final _LatestWrite<PersonalSettings> _writer;

  void adopt(UserModel? user, {required bool known}) {
    if (_writer.busy) return;
    if (user == null) {
      if (known && !state.loaded) state = const PersonalSettings(loaded: true);
      return;
    }
    final next = PersonalSettings.of(user);
    if (next != state) state = next;
  }

  void setAge(int age) => _change(state.copyWith(age: age));

  void setHeightCm(double cm) => _change(state.copyWith(heightCm: cm));

  /// Switches the unit; the height stays the same length (Konzept 18 §5.3).
  void setUnit(HeightUnit unit) => _change(state.copyWith(unit: unit));

  void setGender(String gender) => _change(state.copyWith(gender: gender));

  void _change(PersonalSettings next) {
    if (next == state) return;
    state = next;
    unawaited(_writer.push(next));
  }

  Future<void> retry() => _writer.retry();
}

/// Persönliche Daten of the signed-in person.
final personalSettingsProvider =
    StateNotifierProvider<PersonalSettingsNotifier, PersonalSettings>((ref) {
      ref.watch(authUserIdProvider);
      final notifier = PersonalSettingsNotifier(
        ref.watch(profileSettingsBackendProvider),
        () => ref.invalidate(currentUserProvider),
      );
      ref.listen<AsyncValue<UserModel?>>(currentUserProvider, (_, next) {
        notifier.adopt(next.valueOrNull, known: next.hasValue);
      }, fireImmediately: true);
      ref.listen<bool>(isOfflineProvider, (previous, offline) {
        if (previous == true && !offline) unawaited(notifier.retry());
      });
      return notifier;
    });
