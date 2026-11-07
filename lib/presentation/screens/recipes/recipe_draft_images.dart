import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Keeps recipe-draft photos in the app's documents folder.
///
/// image_picker returns a file in the app's tmp folder, which iOS purges,
/// so a draft that stored that path lost its photo. Drafts now store a copy
/// under `Documents/recipe_drafts/<draftId>.jpg`. Because the absolute app
/// container path changes across app updates, lookups fall back to the
/// same file name inside the current documents folder.
class RecipeDraftImages {
  RecipeDraftImages._();

  static Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/recipe_drafts');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _fileName(String path) => path.split(Platform.pathSeparator).last;

  /// Copies [source] into the drafts folder for [draftId] and returns the
  /// stored path. A file already stored there is returned unchanged.
  static Future<String> persist(String draftId, File source) async {
    final dir = await _dir();
    final target = '${dir.path}/$draftId.jpg';
    if (source.path == target) return target;
    await source.copy(target);
    return target;
  }

  /// The draft photo for [storedPath], or null when it no longer exists.
  static Future<File?> resolve(String? storedPath) async {
    if (storedPath == null || storedPath.isEmpty) return null;
    final direct = File(storedPath);
    if (await direct.exists()) return direct;
    final relocated = File('${(await _dir()).path}/${_fileName(storedPath)}');
    return await relocated.exists() ? relocated : null;
  }

  /// Deletes the stored draft photo, if any. Never throws.
  static Future<void> delete(String? storedPath) async {
    try {
      final file = await resolve(storedPath);
      // Only delete our own copies, never a file outside the drafts folder.
      if (file != null && file.path.contains('/recipe_drafts/')) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('⚠️ [RECIPE_DRAFTS] Could not delete draft image: $e');
    }
  }
}
