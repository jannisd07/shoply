import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

/// The shopping list the signed-in user opened last.
///
/// Stored per user on the device rather than on the shared `shopping_lists`
/// row: "last opened" is personal (also for lists shared with you), and
/// writing it to the list row on every open broadcast a realtime change to
/// every member of that list.
final lastAccessedListProvider =
    StateNotifierProvider<LastAccessedListNotifier, AsyncValue<String?>>((ref) {
  return LastAccessedListNotifier(ref.watch(authUserIdProvider));
});

class LastAccessedListNotifier extends StateNotifier<AsyncValue<String?>> {
  LastAccessedListNotifier(this._userId) : super(const AsyncValue.loading()) {
    _load();
  }

  final String? _userId;

  String get _key => 'last_accessed_list_$_userId';

  Future<void> _load() async {
    if (_userId == null) {
      state = const AsyncValue.data(null);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) state = AsyncValue.data(prefs.getString(_key));
    } catch (e, stack) {
      if (mounted) state = AsyncValue.error(e, stack);
    }
  }

  /// Remember [listId] as the last opened list.
  Future<void> setLastAccessedList(String listId) async {
    if (_userId == null) return;
    state = AsyncValue.data(listId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, listId);
    } catch (e) {
      debugPrint('⚠️ [LAST_LIST] Failed to persist last list: $e');
    }
  }
}
