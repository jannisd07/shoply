import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing user profile pictures
class ProfilePictureService {
  static const String _bucket = 'profile-pictures';

  final _supabase = SupabaseService.instance.client;

  /// Upload profile picture and update user profile. The previous picture
  /// is removed from storage afterwards so re-uploads don't leave orphans.
  Future<String> uploadProfilePicture(String filePath) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final previousPath = await _currentAvatarPath(user.id);

    // A new path per upload busts image caches keyed by URL.
    final fileName =
        '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _supabase.storage.from(_bucket).upload(
          fileName,
          File(filePath),
          fileOptions: const FileOptions(upsert: true),
        );

    final url = _supabase.storage.from(_bucket).getPublicUrl(fileName);
    await _supabase.from('users').update({
      'avatar_url': url,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);

    if (previousPath != null && previousPath != fileName) {
      try {
        await _supabase.storage.from(_bucket).remove([previousPath]);
      } catch (e) {
        debugPrint('⚠️ [PROFILE_PICTURE] Could not remove old avatar: $e');
      }
    }
    return url;
  }

  /// Delete profile picture
  Future<void> deleteProfilePicture() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final path = await _currentAvatarPath(user.id);
    if (path != null) {
      await _supabase.storage.from(_bucket).remove([path]);
    }

    await _supabase.from('users').update({
      'avatar_url': null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);
  }

  /// Storage path of the user's current avatar inside [_bucket], or null when
  /// there is none or it isn't stored in this bucket (e.g. an OAuth avatar).
  Future<String?> _currentAvatarPath(String userId) async {
    final response = await _supabase
        .from('users')
        .select('avatar_url')
        .eq('id', userId)
        .maybeSingle();

    final avatarUrl = response?['avatar_url'] as String?;
    if (avatarUrl == null) return null;

    // Public URLs look like .../object/public/profile-pictures/<path>
    final segments = Uri.parse(avatarUrl).pathSegments;
    final bucketIndex = segments.indexOf(_bucket);
    if (bucketIndex == -1 || bucketIndex == segments.length - 1) return null;
    return segments.skip(bucketIndex + 1).join('/');
  }
}
