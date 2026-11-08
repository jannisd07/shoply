import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/presentation/screens/recipes/widgets/cooking_mode_timers.dart';

/// Where someone stopped cooking a recipe (Konzept 13 §16.1, §19.2): page,
/// checked ingredients, servings and timers. Kept on this device for 24 h.
@immutable
class CookingProgress {
  const CookingProgress({
    required this.recipeId,
    required this.page,
    required this.servings,
    this.checked = const {},
    this.visited = const {},
    this.timers = const [],
    required this.savedAt,
  });

  final String recipeId;

  /// 0 = "Zutaten", 1 … n = step pages, n + 1 = "Fertig".
  final int page;

  final int servings;

  /// Checked ingredient indexes on the "Zutaten" page.
  final Set<int> checked;

  /// Pages seen so far (ticks in the overview).
  final Set<int> visited;

  final List<CookingTimer> timers;

  final DateTime savedAt;

  /// The step to continue with ("Weiter: Schritt 3"), null on "Zutaten".
  int? get stepNumber => page >= 1 ? page : null;

  Map<String, dynamic> toJson() => {
    'recipeId': recipeId,
    'page': page,
    'servings': servings,
    'checked': checked.toList()..sort(),
    'visited': visited.toList()..sort(),
    'timers': [for (final t in timers) t.toJson()],
    'savedAt': savedAt.toIso8601String(),
  };

  /// Null for a broken entry.
  static CookingProgress? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['recipeId'];
    final page = json['page'];
    final servings = json['servings'];
    final savedAt = DateTime.tryParse('${json['savedAt'] ?? ''}');
    if (id is! String || page is! int || servings is! int || savedAt == null) {
      return null;
    }
    Set<int> ints(Object? list) =>
        list is List ? list.whereType<int>().toSet() : <int>{};
    final timers = json['timers'];
    return CookingProgress(
      recipeId: id,
      page: page,
      servings: servings,
      checked: ints(json['checked']),
      visited: ints(json['visited']),
      timers: timers is List
          ? [
              for (final t in timers)
                if (CookingTimer.fromJson(t) case final timer?) timer,
            ]
          : const [],
      savedAt: savedAt,
    );
  }
}

/// Reads and writes [CookingProgress] in SharedPreferences.
abstract final class CookingProgressStore {
  static const String _prefix = 'cooking_progress_';
  static const String _hintKey = 'cooking_mode_hint_seen';

  /// How long a progress is kept (Konzept 13 §16.4).
  static const Duration maxAge = Duration(hours: 24);

  /// The saved progress of [recipeId], or null when there is none or it is
  /// older than [maxAge] (then it is deleted).
  static Future<CookingProgress?> load(String recipeId, {DateTime? now}) async {
    if (recipeId.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$recipeId');
      if (raw == null) return null;
      final progress = CookingProgress.fromJson(jsonDecode(raw));
      final age = (now ?? DateTime.now()).difference(
        progress?.savedAt ?? DateTime(0),
      );
      if (progress == null || age > maxAge) {
        await prefs.remove('$_prefix$recipeId');
        return null;
      }
      return progress;
    } catch (e) {
      debugPrint('⚠️ [COOKING] Progress not readable: $e');
      return null;
    }
  }

  static Future<void> save(CookingProgress progress) async {
    if (progress.recipeId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_prefix${progress.recipeId}',
        jsonEncode(progress.toJson()),
      );
    } catch (e) {
      debugPrint('⚠️ [COOKING] Progress not saved: $e');
    }
  }

  static Future<void> clear(String recipeId) async {
    if (recipeId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefix$recipeId');
    } catch (e) {
      debugPrint('⚠️ [COOKING] Progress not cleared: $e');
    }
  }

  /// Whether the one-time hint "Der Bildschirm bleibt an …" was shown.
  static Future<bool> hintSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_hintKey) ?? false;
    } catch (_) {
      return true;
    }
  }

  static Future<void> markHintSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hintKey, true);
    } catch (_) {
      // The hint shows once more; no harm.
    }
  }
}

/// The saved cooking progress of a recipe, for "Weiter: Schritt 3" in the
/// detail and "Weiter kochen" in the Rezepte tab. The cooking mode
/// invalidates it whenever it saves.
final cookingProgressProvider = FutureProvider.autoDispose
    .family<CookingProgress?, String>(
      (ref, recipeId) => CookingProgressStore.load(recipeId),
    );
