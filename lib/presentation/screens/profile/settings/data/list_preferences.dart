import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/presentation/state/auth_provider.dart';

/// The switches of Einstellungen › Listen (Konzept 18 §5.4). All on by
/// default.
@immutable
class ListPreferences {
  /// Creates the state.
  const ListPreferences({
    this.showItemImages = true,
    this.suggestions = true,
    this.keepScreenOn = true,
    this.sharePresence = true,
  });

  /// "Artikelbilder anzeigen": symbols and product photos next to names
  /// (Avo key `show_item_images`).
  final bool showItemImages;

  /// "Vielleicht auch": suggestions at the end of a list
  /// (`suggestions_enabled`).
  final bool suggestions;

  /// "Bildschirm anlassen" while shopping (`keep_screen_on`).
  final bool keepScreenOn;

  /// "Anderen zeigen, dass ich einkaufe" (`share_presence`, K18-07).
  final bool sharePresence;

  ListPreferences copyWith({
    bool? showItemImages,
    bool? suggestions,
    bool? keepScreenOn,
    bool? sharePresence,
  }) => ListPreferences(
    showItemImages: showItemImages ?? this.showItemImages,
    suggestions: suggestions ?? this.suggestions,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    sharePresence: sharePresence ?? this.sharePresence,
  );

  Map<String, bool> toJson() => {
    'show_item_images': showItemImages,
    'suggestions_enabled': suggestions,
    'keep_screen_on': keepScreenOn,
    'share_presence': sharePresence,
  };

  factory ListPreferences.fromJson(Map<String, dynamic> json) {
    bool read(String key) => json[key] is bool ? json[key] as bool : true;
    return ListPreferences(
      showItemImages: read('show_item_images'),
      suggestions: read('suggestions_enabled'),
      keepScreenOn: read('keep_screen_on'),
      sharePresence: read('share_presence'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ListPreferences &&
      other.showItemImages == showItemImages &&
      other.suggestions == suggestions &&
      other.keepScreenOn == keepScreenOn &&
      other.sharePresence == sharePresence;

  @override
  int get hashCode =>
      Object.hash(showItemImages, suggestions, keepScreenOn, sharePresence);
}

/// Prefix of the device storage key; one entry per account, so another
/// account on the device starts with the defaults.
const String kListPreferencesKeyPrefix = 'setp_list_prefs_v1_';

/// Keeps [ListPreferences] on the device per account. `share_presence`
/// belongs into the account as well (`users.share_presence`) once the column
/// exists.
class ListPreferencesNotifier extends StateNotifier<ListPreferences> {
  ListPreferencesNotifier(this._userId) : super(const ListPreferences()) {
    unawaited(_load());
  }

  final String? _userId;
  bool _changed = false;

  String get _key => '$kListPreferencesKeyPrefix${_userId ?? 'anon'}';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || !mounted || _changed) return;
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) {
        state = ListPreferences.fromJson(json);
      }
    } catch (e) {
      debugPrint('⚠️ [SETTINGS] Reading list settings failed: $e');
    }
  }

  /// Applies [next] at once and stores it.
  Future<void> update(ListPreferences next) async {
    _changed = true;
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(next.toJson()));
    } catch (e) {
      debugPrint('⚠️ [SETTINGS] Saving list settings failed: $e');
    }
  }
}

/// Einstellungen › Listen of the signed-in person. List detail, shopping mode
/// and presence read it.
final listPreferencesProvider =
    StateNotifierProvider<ListPreferencesNotifier, ListPreferences>(
      (ref) => ListPreferencesNotifier(ref.watch(authUserIdProvider)),
    );
