import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/user_model.dart';
import 'package:shoply/data/services/offline_cache_service.dart';
import 'package:shoply/data/services/onboarding_answers_service.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for current auth user. Emits on every auth event, including the
/// hourly token refresh — providers that only care about *who* is signed in
/// should watch [authUserIdProvider] instead.
final authUserProvider = StreamProvider<User?>((ref) {
  return SupabaseService.instance.authStateChanges.map(
    (state) => state.session?.user,
  );
});

/// The signed-in user's id, or null when signed out.
///
/// Only notifies dependents on sign-in, sign-out or an account switch (a
/// `Provider` skips equal values), so token refreshes no longer re-run every
/// account-scoped fetch. Before the first auth event it falls back to the
/// session Supabase restored at startup.
///
/// When the account changes, the offline cache of the previous account is
/// wiped so nothing of it leaks into the next session.
final authUserIdProvider = Provider<String?>((ref) {
  final auth = ref.watch(authUserProvider);
  final userId = auth.hasValue
      ? auth.value?.id
      : SupabaseService.instance.currentUser?.id;

  final previous = _lastSeenUserId;
  _lastSeenUserId = userId;
  if (previous != null && previous != userId) {
    unawaited(OfflineCacheService.instance.clearCache());
  }
  return userId;
});

String? _lastSeenUserId;

/// The profile saved on this device for the signed-in account (name,
/// onboarding flag), available before [currentUserProvider] has asked the
/// server, so Home can greet by name on a cold start.
final cachedUserProfileProvider = FutureProvider<CachedUserProfile?>((ref) {
  final userId = ref.watch(authUserIdProvider);
  if (userId == null) return null;
  return OfflineCacheService.instance.getCachedUserProfile(userId);
});

/// Provider for current user model. Caches the display_name/onboarding flag
/// in [OfflineCacheService] on every successful fetch so the router can still
/// make redirect decisions when the device is offline.
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final userId = ref.watch(authUserIdProvider);
  final authUser = SupabaseService.instance.currentUser;
  if (userId == null || authUser == null) return null;

  try {
    var row = await _fetchUserRow(userId) ?? await _createUserRow(authUser);

    // Onboarding (diet preferences, calorie-tracking opt-in, goal answers)
    // runs before an account exists, so it stashes its answers locally —
    // this is the first point a real user id exists to apply them to. Runs
    // at most once per device.
    final applied = await OnboardingAnswersService.instance
        .applyPendingAnswersToAccount(
          userId,
          accountCreatedAt: DateTime.tryParse(
            row['created_at'] as String? ?? '',
          ),
        );
    if (applied) row = await _fetchUserRow(userId) ?? row;

    final model = UserModel.fromJson(row);
    await OfflineCacheService.instance.cacheUserProfile(
      userId: userId,
      displayName: model.displayName,
      onboardingCompleted: row['onboarding_completed'] as bool?,
    );
    return model;
  } catch (e) {
    // Network/Supabase error: return null so existing consumers keep their
    // current fallback behavior (the router uses the cached profile
    // directly), and retry on our own instead of holding on to that null
    // until the next sign-in.
    debugPrint('⚠️ [AUTH] Loading user profile failed, retrying in 30s: $e');
    final retry = Timer(const Duration(seconds: 30), ref.invalidateSelf);
    ref.onDispose(retry.cancel);
    return null;
  }
});

Future<Map<String, dynamic>?> _fetchUserRow(String userId) {
  return SupabaseService.instance
      .from('users')
      .select()
      .eq('id', userId)
      .maybeSingle();
}

/// First sign-in: create the `users` row from the auth account.
Future<Map<String, dynamic>> _createUserRow(User authUser) {
  final now = DateTime.now().toIso8601String();
  return SupabaseService.instance
      .from('users')
      .insert({
        'id': authUser.id,
        'email': authUser.email,
        'display_name':
            authUser.userMetadata?['display_name'] ??
            authUser.email?.split('@')[0],
        'auth_provider': authUser.appMetadata['provider'],
        'created_at': now,
        'updated_at': now,
      })
      .select()
      .single();
}

/// Auth service provider
class AuthService {
  final SupabaseService _supabase = SupabaseService.instance;

  Future<void> updateDisplayName(String displayName) {
    return _supabase.updateUserMetadata({'display_name': displayName});
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
