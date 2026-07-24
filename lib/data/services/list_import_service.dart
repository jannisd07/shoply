import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdfx/pdfx.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:shoply/core/config/env.dart';

/// One item extracted from a photographed/scanned shopping list.
class ExtractedListItem {
  String name;
  double? quantity;
  String? unit;
  final double? confidence;

  ExtractedListItem({
    required this.name,
    this.quantity,
    this.unit,
    this.confidence,
  });

  factory ExtractedListItem.fromJson(Map<String, dynamic> json) {
    return ExtractedListItem(
      name: (json['name'] as String? ?? '').trim(),
      quantity: (json['quantity'] as num?)?.toDouble(),
      unit: (json['unit'] as String?)?.trim(),
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }

  bool get isLowConfidence => confidence != null && confidence! < 0.75;
}

/// Successful extraction result from the Edge Function.
class ListImportResult {
  final List<ExtractedListItem> items;
  final List<String> unparsedLines;

  const ListImportResult({required this.items, required this.unparsedLines});
}

/// Typed failure with the Edge Function's machine-readable code — the UI
/// maps these to localized messages and never shows a raw provider error.
class ListImportException implements Exception {
  /// One of: no_items_found, unreadable_image, rate_limited, provider_error,
  /// timeout, network_error, not_signed_in, cancelled.
  final String code;

  const ListImportException(this.code);

  @override
  String toString() => 'ListImportException($code)';
}

/// Top-level so it can run in a background isolate via [compute] — image
/// decode/re-encode of a camera photo takes hundreds of ms and must not
/// block the UI thread mid-animation.
Uint8List _compressForUpload(Uint8List raw) {
  final decoded = img.decodeImage(raw);
  if (decoded == null) {
    // Undecodable here (e.g. HEIC) — the caller decides what to do.
    throw const FormatException('undecodable');
  }
  img.Image resized = decoded;
  const maxLongEdge = 2000;
  final longEdge =
      decoded.width > decoded.height ? decoded.width : decoded.height;
  if (longEdge > maxLongEdge) {
    if (decoded.width >= decoded.height) {
      resized = img.copyResize(decoded, width: maxLongEdge);
    } else {
      resized = img.copyResize(decoded, height: maxLongEdge);
    }
  }
  return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
}

/// Client side of the photo/PDF → shopping-list-items import flow:
/// compress → upload to the private `list-imports` bucket → call the
/// `extract-shopping-list` Edge Function → typed result.
///
/// Privacy: the Edge Function deletes the uploaded image right after
/// extraction; on cancel/failure this service best-effort deletes it too.
class ListImportService {
  ListImportService._();
  static final ListImportService instance = ListImportService._();

  static const String _bucket = 'list-imports';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Renders page 1 of a PDF to PNG bytes at roughly the target resolution.
  /// Runs on the main isolate (pdfx uses platform channels) — the render
  /// itself is native-side, so the Dart thread is not blocked.
  Future<Uint8List> _pdfFirstPageToImage(Uint8List pdfBytes) async {
    final doc = await PdfDocument.openData(pdfBytes);
    try {
      final page = await doc.getPage(1);
      try {
        final scale = 2000 / (page.width > page.height ? page.width : page.height);
        final rendered = await page.render(
          width: page.width * scale,
          height: page.height * scale,
          format: PdfPageImageFormat.png,
        );
        if (rendered == null) throw const ListImportException('unreadable_image');
        return rendered.bytes;
      } finally {
        await page.close();
      }
    } finally {
      await doc.close();
    }
  }

  /// Full pipeline. [isPdf] switches on the PDF page-render path.
  /// [cancelToken] aborts the network call; between stages the token's
  /// cancellation flag is checked so a cancel mid-compress also stops
  /// before uploading.
  Future<ListImportResult> importFromBytes(
    Uint8List raw, {
    required bool isPdf,
    required CancelToken cancelToken,
  }) async {
    final session = _supabase.auth.currentSession;
    final userId = _supabase.auth.currentUser?.id;
    if (session == null || userId == null) {
      throw const ListImportException('not_signed_in');
    }

    // 1. Normalize to a reasonably-sized JPEG.
    Uint8List imageBytes = raw;
    if (isPdf) {
      imageBytes = await _pdfFirstPageToImage(raw);
    }
    _throwIfCancelled(cancelToken);
    try {
      imageBytes = await compute(_compressForUpload, imageBytes);
    } on FormatException {
      // Undecodable in Dart (HEIC etc.) — upload the original if it's not
      // huge; the vision model reads HEIC fine.
      if (raw.lengthInBytes > 8 * 1024 * 1024) {
        throw const ListImportException('unreadable_image');
      }
      imageBytes = raw;
    }
    _throwIfCancelled(cancelToken);

    // 2. Upload to the caller's own folder in the private bucket — the Edge
    // Function refuses paths outside `<uid>/`.
    final imagePath = '$userId/${const Uuid().v4()}.jpg';
    try {
      await _supabase.storage.from(_bucket).uploadBinary(
            imagePath,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
    } catch (e) {
      debugPrint('❌ [LIST_IMPORT] Upload failed: $e');
      throw const ListImportException('network_error');
    }
    if (cancelToken.isCancelled) {
      _deleteUpload(imagePath);
      throw const ListImportException('cancelled');
    }

    // 3. Call the Edge Function.
    try {
      final locale = _supabase.auth.currentUser?.userMetadata?['locale']
              as String? ??
          'de-DE';
      final response = await _dio.post<Map<String, dynamic>>(
        '${Env.supabaseUrl}/functions/v1/extract-shopping-list',
        data: {'image_path': imagePath, 'locale': locale},
        options: Options(
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
            'apikey': Env.supabaseAnonKey,
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.json,
          validateStatus: (_) => true,
        ),
        cancelToken: cancelToken,
      );

      final body = _asJsonMap(response.data);
      if (response.statusCode == 200 && body != null) {
        final items = ((body['items'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ExtractedListItem.fromJson)
            .where((i) => i.name.isNotEmpty)
            .toList();
        final unparsed = ((body['unparsed_lines'] as List?) ?? const [])
            .whereType<String>()
            .toList();
        if (items.isEmpty) throw const ListImportException('no_items_found');
        return ListImportResult(items: items, unparsedLines: unparsed);
      }

      final code = body?['code'] as String?;
      throw ListImportException(_isKnownCode(code) ? code! : 'provider_error');
    } on DioException catch (e) {
      _deleteUpload(imagePath);
      switch (e.type) {
        case DioExceptionType.cancel:
          throw const ListImportException('cancelled');
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          throw const ListImportException('timeout');
        default:
          throw const ListImportException('network_error');
      }
    }
  }

  static bool _isKnownCode(String? code) => const {
        'no_items_found',
        'unreadable_image',
        'rate_limited',
        'provider_error',
        'timeout',
      }.contains(code);

  Map<String, dynamic>? _asJsonMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return null;
  }

  void _throwIfCancelled(CancelToken token) {
    if (token.isCancelled) throw const ListImportException('cancelled');
  }

  /// Best-effort cleanup — the Edge Function also deletes after itself, this
  /// covers cancel/failure before the function ever ran.
  void _deleteUpload(String path) {
    _supabase.storage.from(_bucket).remove([path]).catchError((Object e) {
      debugPrint('⚠️ [LIST_IMPORT] Cleanup failed for $path: $e');
      return <FileObject>[];
    });
  }
}
