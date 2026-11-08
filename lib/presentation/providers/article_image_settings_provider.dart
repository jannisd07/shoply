import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/services/shared_preferences_provider.dart';

/// SharedPreferences key of the setting "Artikelbilder anzeigen".
const String showArticleImagesPrefsKey = 'show_article_images';

/// "Artikelbilder anzeigen" (settings page `/settings/lists`, Teil A): on by
/// default, kept on this device. Off hides every `ArticleImage` (and its
/// photo credit) without leaving a gap.
///
/// The saved choice is read synchronously from the SharedPreferences that
/// `main()` preloads (`sharedPreferencesProvider` override), so the
/// first frame already knows it. `null` only until those prefs are read
/// (tests, a failed preload): images stay hidden and nothing is asked from
/// Open Food Facts. A settings toggle shows `?? true`.
final showArticleImagesProvider =
    StateNotifierProvider<ShowArticleImagesNotifier, bool?>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return ShowArticleImagesNotifier(
        prefs.valueOrNull,
        known: prefs.hasValue || prefs.hasError,
      );
    });

/// Turns article images on or off and saves the choice.
Future<void> setShowArticleImages(WidgetRef ref, bool on) =>
    ref.read(showArticleImagesProvider.notifier).set(on);

class ShowArticleImagesNotifier extends StateNotifier<bool?> {
  /// [known] is false while SharedPreferences is still loading; without
  /// prefs (load failed) the default applies.
  ShowArticleImagesNotifier(this._prefs, {required bool known})
    : super(
        known ? (_prefs?.getBool(showArticleImagesPrefsKey) ?? true) : null,
      );

  final SharedPreferences? _prefs;

  /// Shows the change at once, then saves it; a failed save keeps the
  /// change for this session.
  Future<void> set(bool on) async {
    state = on;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setBool(showArticleImagesPrefsKey, on);
    } catch (e) {
      debugPrint('⚠️ [ARTICLE_IMAGES] Setting not saved: $e');
    }
  }
}
