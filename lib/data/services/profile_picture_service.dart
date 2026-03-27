import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shoply/data/services/supabase_service.dart';

/// Service for managing user profile pictures
class ProfilePictureService {
  final _supabase = SupabaseService.instance.client;
  
  /// Upload profile picture and update user profile
  Future<String> uploadProfilePicture(String filePath) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    
    final file = File(filePath);
    final fileName = '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    try {
      // Upload to storage
      await _supabase.storage
          .from('profile-pictures')
          .upload(
            fileName,
            file,
            fileOptions: FileOptions(upsert: true),
          );
      
      // Get public URL
      final url = _supabase.storage
          .from('profile-pictures')
          .getPublicUrl(fileName);
      
      // Update user profile
      await _supabase.from('users').update({
        'avatar_url': url,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
      
      return url;
    } catch (e) {
      rethrow;
    }
  }
  
  /// Delete profile picture
  Future<void> deleteProfilePicture() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    
    try {
      // Get current avatar URL
      final response = await _supabase
          .from('users')
          .select('avatar_url')
          .eq('id', user.id)
          .maybeSingle();
      
      final avatarUrl = response?['avatar_url'] as String?;
      if (avatarUrl == null) return;
      
      // Extract file path from URL
      final uri = Uri.parse(avatarUrl);
      final pathSegments = uri.pathSegments;
      
      // Find 'profile-pictures' in path and get everything after it
      final bucketIndex = pathSegments.indexOf('profile-pictures');
      if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
        final path = pathSegments.skip(bucketIndex + 1).join('/');
        
        // Delete from storage
        await _supabase.storage.from('profile-pictures').remove([path]);
      }
      
      // Update user profile
      await _supabase.from('users').update({
        'avatar_url': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
    } catch (e) {
      rethrow;
    }
  }
}
