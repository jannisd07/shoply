import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/user_model.dart';
import 'package:shoply/data/services/offline_cache_service.dart';
import 'package:shoply/data/services/onboarding_answers_service.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for current auth user
final authUserProvider = StreamProvider<User?>((ref) {
  return SupabaseService.instance.authStateChanges.map((state) => state.session?.user);
});

/// Provider for current user model. Caches the display_name/onboarding flag
/// in [OfflineCacheService] on every successful fetch so the router can still
/// make redirect decisions when the device is offline.
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final authUser = await ref.watch(authUserProvider.future);
  if (authUser == null) return null;

  try {
    final response = await SupabaseService.instance
        .from('users')
        .select()
        .eq('id', authUser.id)
        .maybeSingle();

    if (response == null) {
      // Create user record if it doesn't exist
      final newUser = {
        'id': authUser.id,
        'email': authUser.email,
        'display_name': authUser.userMetadata?['display_name'] ?? authUser.email?.split('@')[0],
        'auth_provider': authUser.appMetadata['provider'],
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      var created = await SupabaseService.instance
          .from('users')
          .insert(newUser)
          .select()
          .single();

      // Onboarding (diet preferences, calorie-tracking opt-in, goal
      // answers) runs before an account exists, so it stashes its answers
      // locally — this is the first point a real user id exists to apply
      // them to. Runs at most once per device.
      final applied = await OnboardingAnswersService.instance
          .applyPendingAnswersToAccount(authUser.id);
      if (applied) {
        created = await SupabaseService.instance
            .from('users')
            .select()
            .eq('id', authUser.id)
            .single();
      }

      final model = UserModel.fromJson(created);
      await OfflineCacheService.instance.cacheUserProfile(
        userId: authUser.id,
        displayName: model.displayName,
        onboardingCompleted: created['onboarding_completed'] as bool?,
      );
      return model;
    }

    final applied = await OnboardingAnswersService.instance
        .applyPendingAnswersToAccount(authUser.id);
    final freshRow = applied
        ? await SupabaseService.instance
            .from('users')
            .select()
            .eq('id', authUser.id)
            .single()
        : response;

    final model = UserModel.fromJson(freshRow);
    await OfflineCacheService.instance.cacheUserProfile(
      userId: authUser.id,
      displayName: model.displayName,
      onboardingCompleted: freshRow['onboarding_completed'] as bool?,
    );
    return model;
  } catch (e) {
    // Network/Supabase error: return null so existing consumers keep their
    // current fallback behavior. The cached profile is still used directly by
    // the router redirect – this provider is only for richer profile UI.
    return null;
  }
});

/// Auth service provider
class AuthService {
  final SupabaseService _supabase = SupabaseService.instance;

  Future<void> signIn(String email, String password) async {
    await _supabase.signInWithEmail(email, password);
  }

  Future<void> signUp(String email, String password, String displayName) async {
    final response = await _supabase.signUpWithEmail(email, password);
    
    if (response.user != null) {
      // Create user profile
      await _supabase.from('users').insert({
        'id': response.user!.id,
        'email': email,
        'display_name': displayName,
        'auth_provider': 'email',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> signOut() async {
    await _supabase.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _supabase.resetPassword(email);
  }

  Future<void> updateDisplayName(String displayName) async {
    try {
      await _supabase.updateUserMetadata({'display_name': displayName});
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateDietPreferences(List<String> preferences) async {
    try {
      await _supabase.updateUserMetadata({'diet_preferences': preferences});
    } catch (e) {
      rethrow;
    }
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
