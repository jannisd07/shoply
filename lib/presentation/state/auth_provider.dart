import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/user_model.dart';
import 'package:shoply/data/services/offline_cache_service.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shoply/core/services/shared_preferences_provider.dart';

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
/// server, so Home can greet by name in the first frame.
final cachedUserProfileProvider = Provider<CachedUserProfile?>((ref) {
  final userId = ref.watch(authUserIdProvider);
  if (userId == null) return null;
  final prefs = ref.read(sharedPreferencesProvider).valueOrNull;
  if (prefs != null) OfflineCacheService.instance.attachPreferences(prefs);
  return OfflineCacheService.instance.getCachedUserProfileSync(userId);
});

/// Provider for current user model. Caches the display_name/onboarding flag
/// in [OfflineCacheService] on every successful fetch so the router can still
/// make redirect decisions when the device is offline.
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final userId = ref.watch(authUserIdProvider);
  final authUser = SupabaseService.instance.currentUser;
  if (userId == null || authUser == null) return null;

  try {
    // The onboarding writes its answers itself, with targeted updates
    // (Konzept 17 §1.2); there is no time-based sync here any more.
    final row = await _fetchUserRow(userId) ?? await _createUserRow(authUser);

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

/// First sign-in: create the `users` row from the auth account. The name is
/// only what the account brought (never the part of the e-mail address
/// before the @, Konzept 17 §3.8, Inventar Bug 13); Name fills it.
Future<Map<String, dynamic>> _createUserRow(User authUser) {
  final now = DateTime.now().toUtc().toIso8601String();
  return SupabaseService.instance
      .from('users')
      .insert({
        'id': authUser.id,
        'email': authUser.email,
        'display_name': authUser.userMetadata?['display_name'],
        'auth_provider': authUser.appMetadata['provider'],
        'created_at': now,
        'updated_at': now,
      })
      .select()
      .single();
}
