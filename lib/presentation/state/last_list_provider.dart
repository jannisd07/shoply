import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for tracking the last accessed shopping list
final lastAccessedListProvider = StateNotifierProvider<LastAccessedListNotifier, AsyncValue<String?>>((ref) {
  return LastAccessedListNotifier();
});

class LastAccessedListNotifier extends StateNotifier<AsyncValue<String?>> {
  LastAccessedListNotifier() : super(const AsyncValue.loading()) {
    _loadLastAccessedList();
  }

  final _supabase = Supabase.instance.client;

  /// Load the last accessed list from database
  Future<void> _loadLastAccessedList() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        state = const AsyncValue.data(null);
        return;
      }

      // Query for the most recently accessed list
      final response = await _supabase
          .from('shopping_lists')
          .select('id')
          .eq('user_id', userId)
          .not('last_accessed_at', 'is', null)
          .order('last_accessed_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        state = AsyncValue.data(response['id'] as String);
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Update the last accessed list
  Future<void> setLastAccessedList(String listId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Update the last_accessed_at timestamp
      await _supabase
          .from('shopping_lists')
          .update({'last_accessed_at': DateTime.now().toIso8601String()})
          .eq('id', listId)
          .eq('user_id', userId);

      // Update state
      state = AsyncValue.data(listId);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Clear the last accessed list
  void clearLastAccessedList() {
    state = const AsyncValue.data(null);
  }

  /// Refresh the last accessed list
  Future<void> refresh() async {
    await _loadLastAccessedList();
  }
}
