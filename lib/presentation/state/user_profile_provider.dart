import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/user_model.dart';
import 'package:shoply/data/services/user_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

/// StateNotifier for managing user profile updates
class UserProfileNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  UserProfileNotifier(this.ref) : super(const AsyncValue.loading()) {
    _init();
  }

  final Ref ref;
  final _userService = UserService();

  Future<void> _init() async {
    try {
      final user = await ref.read(currentUserProvider.future);
      state = AsyncValue.data(user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Update user profile and refresh state
  Future<void> updateProfile(UserModel updatedUser) async {
    try {
      state = const AsyncValue.loading();
      
      // Save to Supabase
      await _userService.updateUserProfile(updatedUser);
      
      // Update local state
      state = AsyncValue.data(updatedUser);
      
      // Invalidate auth provider to force refresh
      ref.invalidate(currentUserProvider);
      
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Refresh user data from database
  Future<void> refresh() async {
    try {
      state = const AsyncValue.loading();
      final user = await ref.read(currentUserProvider.future);
      state = AsyncValue.data(user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

/// Provider for user profile management
final userProfileProvider = StateNotifierProvider<UserProfileNotifier, AsyncValue<UserModel?>>((ref) {
  return UserProfileNotifier(ref);
});
