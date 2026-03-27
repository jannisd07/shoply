import 'package:shoply/data/models/user_model.dart';
import 'package:shoply/data/services/supabase_service.dart';

class UserService {
  static final UserService instance = UserService();
  final _supabase = SupabaseService.instance.client;

  /// Update user profile
  Future<void> updateUserProfile(UserModel user) async {
    // Aktualisiere updated_at Timestamp
    final updatedData = user.copyWith(
      updatedAt: DateTime.now(),
    ).toJson();
    
    await _supabase
        .from('users')
        .update(updatedData)
        .eq('id', user.id);
    
  }

  /// Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return UserModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }
}
