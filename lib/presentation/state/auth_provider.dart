import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/user_model.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for current auth user
final authUserProvider = StreamProvider<User?>((ref) {
  return SupabaseService.instance.authStateChanges.map((state) => state.session?.user);
});

/// Provider for current user model
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

      final created = await SupabaseService.instance
          .from('users')
          .insert(newUser)
          .select()
          .single();

      return UserModel.fromJson(created);
    }

    return UserModel.fromJson(response);
  } catch (e) {
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
