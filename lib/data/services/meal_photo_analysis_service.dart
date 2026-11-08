import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'package:shoply/data/models/meal_photo_estimate.dart';
import 'package:shoply/data/services/claude_service.dart';
import 'package:shoply/data/services/meal_photo_storage_service.dart';

export 'package:shoply/data/models/meal_photo_estimate.dart';

/// A meal photo Avo could not estimate, as one of [codes]. The UI maps the
/// code to its own text and offers manual entry; it never shows a raw error.
class MealPhotoException implements Exception {
  const MealPhotoException(this.code);

  final String code;

  /// `no_food_detected` (no food or drink on the photo), `unreadable_image`
  /// (no readable photo), `refused` (Claude will not estimate this photo),
  /// `ai_disabled` (kill switch), `quota_exceeded` (daily photo limit reached),
  /// `rate_limited`, `timeout`, `network_error`, `not_signed_in` and
  /// `provider_error` (anything else).
  static const Set<String> codes = {
    'no_food_detected',
    'unreadable_image',
    'refused',
    'ai_disabled',
    'quota_exceeded',
    'rate_limited',
    'timeout',
    'network_error',
    'not_signed_in',
    'provider_error',
  };

  @override
  String toString() => 'MealPhotoException($code)';
}

/// A photo ready for Claude: JPEG, PNG or WebP, at most [MealPhotoAnalysisService.maxImageBase64Chars]
/// as base64.
typedef _Photo = ({Uint8List bytes, String mediaType});

/// Re-encodes a photo Claude cannot take as it is (another format, or too
/// large) as a JPEG with a long edge of at most 1568 px, the size Claude
/// reads photos at. Null when the bytes are no image this package decodes.
/// Top-level so it can run in a background isolate via [compute].
Uint8List? _reencodeAsJpeg(Uint8List raw) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(raw);
  } catch (_) {
    return null;
  }
  if (decoded == null) return null;
  const maxLongEdge = 1568;
  final image = decoded.width >= decoded.height
      ? (decoded.width > maxLongEdge ? img.copyResize(decoded, width: maxLongEdge) : decoded)
      : (decoded.height > maxLongEdge ? img.copyResize(decoded, height: maxLongEdge) : decoded);
  return Uint8List.fromList(img.encodeJpg(image, quality: 80));
}

/// Estimates the nutrition of a meal photo through the `ai` task
/// `meal_photo` (Claude, server-side prompt and quota).
class MealPhotoAnalysisService {
  MealPhotoAnalysisService({ClaudeService Function()? claude})
      : _claude = claude ?? (() => ClaudeService.instance);

  static final MealPhotoAnalysisService instance = MealPhotoAnalysisService();

  /// Photo deadline (plan, Global Constraints).
  static const Duration timeout = Duration(seconds: 30);

  /// Server limits of the task input.
  static const int maxMealChars = 300;
  static const int maxImageBase64Chars = 5 * 1024 * 1024;

  final ClaudeService Function() _claude;

  /// Avo's estimate of the meal on [imageBytes]. [meal] is the person's note
  /// (the dish, the meal of the day or the portion) and improves the guess.
  ///
  /// The result is a preview to check and edit, never a saved entry. Throws
  /// only [MealPhotoException]; the caller falls back to manual entry and
  /// never makes up numbers.
  Future<MealPhotoEstimate> analyzePhoto(Uint8List imageBytes, {String? meal}) async {
    final photo = await _prepare(imageBytes);
    final note = _note(meal);
    final claude = _claude();

    final Map<String, dynamic> result;
    try {
      result = await claude.run(
        'meal_photo',
        {
          'image_b64': base64Encode(photo.bytes),
          'media_type': photo.mediaType,
          'meal': ?note,
        },
        timeout: timeout,
      );
    } on ClaudeException catch (e) {
      throw MealPhotoException(_codeFor(e.code));
    }

    if (result['no_food'] == true) throw const MealPhotoException('no_food_detected');
    try {
      return MealPhotoEstimate.fromJson(
        result,
        fallbackName: claude.locale == 'de' ? 'Mahlzeit' : 'Meal',
      );
    } on FormatException catch (e) {
      debugPrint('❌ [MEAL_PHOTO] Broken estimate: ${e.message}');
      throw const MealPhotoException('provider_error');
    }
  }

  /// The photo as it is when Claude can read it, else re-encoded.
  Future<_Photo> _prepare(Uint8List bytes) async {
    final mediaType = MealPhotoStorageService.mediaTypeOf(bytes);
    if (mediaType != null && _fits(bytes)) return (bytes: bytes, mediaType: mediaType);

    final jpeg = await compute(_reencodeAsJpeg, bytes);
    if (jpeg == null || !_fits(jpeg)) {
      debugPrint('⚠️ [MEAL_PHOTO] Photo is no readable image');
      throw const MealPhotoException('unreadable_image');
    }
    return (bytes: jpeg, mediaType: 'image/jpeg');
  }

  static bool _fits(Uint8List bytes) => (bytes.length + 2) ~/ 3 * 4 <= maxImageBase64Chars;

  /// Trimmed and cut to the server's limit (never in the middle of an
  /// emoji); null when empty.
  static String? _note(String? meal) {
    final text = meal?.trim() ?? '';
    if (text.isEmpty) return null;
    if (text.length <= maxMealChars) return text;
    var end = maxMealChars;
    final last = text.codeUnitAt(end - 1);
    if (last >= 0xd800 && last <= 0xdbff) end--;
    return text.substring(0, end).trimRight();
  }

  static String _codeFor(String claudeCode) => switch (claudeCode) {
        'no_food_detected' => 'no_food_detected',
        'unreadable_image' => 'unreadable_image',
        'refused' => 'refused',
        'ai_disabled' => 'ai_disabled',
        'quota_exceeded' => 'quota_exceeded',
        'rate_limited' => 'rate_limited',
        'timeout' => 'timeout',
        'network_error' => 'network_error',
        'not_signed_in' || 'unauthorized' => 'not_signed_in',
        _ => 'provider_error',
      };
}
