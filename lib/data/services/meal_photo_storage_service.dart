import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uploads meal photos (from the food log's photo-tracking flow) to the
/// `meal-photos` bucket so they survive past the one-shot Gemini vision
/// estimate instead of being discarded. Best-effort: a failed upload never
/// blocks logging the food entry, it just leaves `photo_url` unset.
class MealPhotoStorageService {
  MealPhotoStorageService._();
  static final MealPhotoStorageService instance = MealPhotoStorageService._();

  final _supabase = Supabase.instance.client;

  Future<String?> uploadPhoto(Uint8List bytes) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _supabase.storage.from('meal-photos').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
      return _supabase.storage.from('meal-photos').getPublicUrl(path);
    } catch (e) {
      debugPrint('⚠️ [MealPhotoStorage] Upload failed: $e');
      return null;
    }
  }
}
