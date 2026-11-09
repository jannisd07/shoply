import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// The two storage calls the meal photos need, so tests can stand in for
/// Supabase.
abstract interface class MealPhotoBucket {
  Future<void> upload(String path, Uint8List bytes, {required String contentType});

  /// A link to [path] that works for [expiresIn] without signing in.
  Future<String> createSignedUrl(String path, Duration expiresIn);

  /// Deletes the objects at [paths].
  Future<void> remove(List<String> paths);
}

class _SupabaseMealPhotoBucket implements MealPhotoBucket {
  const _SupabaseMealPhotoBucket();

  StorageFileApi get _files =>
      Supabase.instance.client.storage.from(MealPhotoStorageService.bucketId);

  @override
  Future<void> upload(String path, Uint8List bytes, {required String contentType}) =>
      _files.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: contentType, upsert: false),
      );

  @override
  Future<String> createSignedUrl(String path, Duration expiresIn) =>
      _files.createSignedUrl(path, expiresIn.inSeconds);

  @override
  Future<void> remove(List<String> paths) => _files.remove(paths);
}

class _SignedUrl {
  const _SignedUrl(this.url, this.expiresAt);

  final String url;
  final DateTime expiresAt;
}

/// Keeps the photos of photo-tracked meals in the private `meal-photos`
/// bucket (`<uid>/<file>`, only the owner can read them). A food log entry
/// stores the storage path (`photo_path`); the app shows the photo through
/// a short-lived signed URL from [signedUrl], cached by path. Use the path,
/// not the URL, as an image cache key: the URL changes every hour.
class MealPhotoStorageService {
  MealPhotoStorageService({
    MealPhotoBucket? bucket,
    String? Function()? currentUserId,
    DateTime Function()? now,
    String Function()? newFileId,
  })  : _bucket = bucket ?? const _SupabaseMealPhotoBucket(),
        _currentUserId = currentUserId ?? _supabaseUserId,
        _now = now ?? DateTime.now,
        _newFileId = newFileId ?? const Uuid().v4;

  static final MealPhotoStorageService instance = MealPhotoStorageService();

  static const String bucketId = 'meal-photos';

  /// How long a signed URL works.
  static const Duration signedUrlLifetime = Duration(hours: 1);

  /// A cached URL is handed out only while it works at least this much
  /// longer, so an image never starts loading with a link about to expire.
  static const Duration _renewBefore = Duration(minutes: 5);
  static const int _maxCachedUrls = 200;

  static const Map<String, String> _extensionOf = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
  };

  final MealPhotoBucket _bucket;
  final String? Function() _currentUserId;
  final DateTime Function() _now;
  final String Function() _newFileId;

  /// Oldest first, so the cache drops the least recently signed URL.
  final LinkedHashMap<String, _SignedUrl> _urls = LinkedHashMap();
  final Map<String, Future<String?>> _signing = {};

  /// Uploads a meal photo into the signed-in person's folder and returns its
  /// storage path (`<uid>/<id>.jpg`), to be kept in `FoodLogEntry.photoPath`.
  /// Best effort: null when signed out, when [bytes] are no JPEG, PNG or
  /// WebP, or when the upload fails; logging the meal never waits on it.
  Future<String?> uploadPhoto(Uint8List bytes) async {
    final userId = _currentUserId();
    if (userId == null) return null;
    final mediaType = mediaTypeOf(bytes);
    if (mediaType == null) {
      debugPrint('⚠️ [MEAL_PHOTO] Upload skipped: no JPEG, PNG or WebP');
      return null;
    }
    final path = '$userId/${_newFileId()}.${_extensionOf[mediaType]}';
    try {
      await _bucket.upload(path, bytes, contentType: mediaType);
      return path;
    } catch (e) {
      debugPrint('⚠️ [MEAL_PHOTO] Upload failed: $e');
      return null;
    }
  }

  /// Deletes the photo at [path] from the bucket (an entry was deleted, or
  /// it was undone before its photo arrived). Only the signed-in person's
  /// own folder; true when it is gone. Never throws.
  Future<bool> deletePhoto(String path) async {
    final userId = _currentUserId();
    if (userId == null || !_isPhotoPath(path) || !path.startsWith('$userId/')) return false;
    _urls.remove(path);
    try {
      await _bucket.remove([path]);
      return true;
    } catch (e) {
      debugPrint('⚠️ [MEAL_PHOTO] Deleting a photo failed: ${e.runtimeType}');
      return false;
    }
  }

  /// A signed URL for the photo at [path], valid for at least five more
  /// minutes. Callers asking for the same path at the same time share one
  /// request. Null when [path] is no meal photo path or signing fails.
  Future<String?> signedUrl(String path) {
    if (!_isPhotoPath(path)) return Future.value();
    final cached = _urls[path];
    if (cached != null && _now().add(_renewBefore).isBefore(cached.expiresAt)) {
      return Future.value(cached.url);
    }
    // A block body: returning the removed future would make it wait on itself.
    return _signing[path] ??= _sign(path).whenComplete(() {
      _signing.remove(path);
    });
  }

  Future<String?> _sign(String path) async {
    final requested = _now();
    try {
      final url = await _bucket.createSignedUrl(path, signedUrlLifetime);
      _urls.remove(path);
      _urls[path] = _SignedUrl(url, requested.add(signedUrlLifetime));
      if (_urls.length > _maxCachedUrls) _urls.remove(_urls.keys.first);
      return url;
    } catch (e) {
      debugPrint('⚠️ [MEAL_PHOTO] Signing a photo URL failed: $e');
      return null;
    }
  }

  /// The storage path behind a stored photo reference: a path as such, or
  /// the path inside an old public link (`…/object/public/meal-photos/<path>`)
  /// or a signed one (`…/object/sign/meal-photos/<path>?token=…`). Null for
  /// anything else.
  static String? pathOf(String? stored) {
    if (stored == null || stored.isEmpty) return null;
    if (!stored.contains('://')) return _isPhotoPath(stored) ? stored : null;

    final uri = Uri.tryParse(stored);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    for (var i = 0; i + 2 < segments.length; i++) {
      if (segments[i] == 'object' &&
          (segments[i + 1] == 'public' || segments[i + 1] == 'sign') &&
          segments[i + 2] == bucketId) {
        final path = segments.sublist(i + 3).join('/');
        return _isPhotoPath(path) ? path : null;
      }
    }
    return null;
  }

  /// `<folder>/<file>`, without empty or dot segments.
  static bool _isPhotoPath(String path) {
    if (path.contains('://')) return false;
    final parts = path.split('/');
    return parts.length >= 2 &&
        parts.every((part) => part.isNotEmpty && part != '.' && part != '..');
  }

  /// `image/jpeg`, `image/png` or `image/webp` from the magic bytes, else
  /// null (HEIC, GIF, anything that is no photo).
  static String? mediaTypeOf(Uint8List bytes) {
    bool startsWith(List<int> head, [int offset = 0]) {
      if (bytes.length < offset + head.length) return false;
      for (var i = 0; i < head.length; i++) {
        if (bytes[offset + i] != head[i]) return false;
      }
      return true;
    }

    if (startsWith(const [0xff, 0xd8, 0xff])) return 'image/jpeg';
    if (startsWith(const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) return 'image/png';
    if (startsWith(const [0x52, 0x49, 0x46, 0x46]) && startsWith(const [0x57, 0x45, 0x42, 0x50], 8)) {
      return 'image/webp';
    }
    return null;
  }

  static String? _supabaseUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }
}
