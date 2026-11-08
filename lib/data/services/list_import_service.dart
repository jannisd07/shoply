import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdfx/pdfx.dart';

import 'package:shoply/data/services/claude_service.dart';

/// One item extracted from a photographed/scanned shopping list.
class ExtractedListItem {
  String name;
  double? quantity;

  /// Unit id as the item parser stores it (`g`, `kg`, `ml`, `l`, `pack`,
  /// `bottle`, `can`, `box`, `bunch`); null means pieces.
  String? unit;
  final double? confidence;

  /// Language-agnostic category id (`dairy`, `fruits_vegetables`, …) Avo
  /// picked for the item, so it needs no second categorization.
  final String? categoryId;

  ExtractedListItem({
    required this.name,
    this.quantity,
    this.unit,
    this.confidence,
    this.categoryId,
  });

  /// Values of the wrong type count as missing.
  factory ExtractedListItem.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final quantity = json['quantity'];
    final unit = json['unit'];
    final confidence = json['confidence'];
    final categoryId = json['category_id'];
    final category = categoryId is String ? categoryId.trim() : '';
    return ExtractedListItem(
      name: name is String ? name.trim() : '',
      quantity: quantity is num ? quantity.toDouble() : null,
      unit: unit is String ? unit.trim() : null,
      confidence: confidence is num ? confidence.toDouble() : null,
      categoryId: category.isEmpty ? null : category,
    );
  }

  bool get isLowConfidence => confidence != null && confidence! < 0.75;
}

/// Successful extraction result.
class ListImportResult {
  final List<ExtractedListItem> items;
  final List<String> unparsedLines;

  const ListImportResult({required this.items, required this.unparsedLines});

  /// Reads the `result` of the task `list_import`: rows without a name are
  /// dropped, as are unparsed lines that are no text.
  factory ListImportResult.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    final lines = json['unparsed_lines'];
    return ListImportResult(
      items: [
        if (items is List)
          for (final row in items.whereType<Map<String, dynamic>>())
            if (ExtractedListItem.fromJson(row) case final item when item.name.isNotEmpty) item,
      ],
      unparsedLines: [if (lines is List) ...lines.whereType<String>()],
    );
  }
}

/// Typed failure with a machine-readable [code]: the UI maps these to
/// localized messages and never shows a raw provider error.
class ListImportException implements Exception {
  /// One of [codes].
  final String code;

  const ListImportException(this.code);

  /// Every code [ListImportService.importFromBytes] throws.
  static const Set<String> codes = {
    'no_items_found',
    'unreadable_image',
    'rate_limited',
    'provider_error',
    'timeout',
    'network_error',
    'not_signed_in',
    'cancelled',
  };

  @override
  String toString() => 'ListImportException($code)';
}

/// Server limit of a photo in a task input, as base64.
const int _maxImageBase64Chars = 5 * 1024 * 1024;

/// Scales a photo to a long edge of at most 2000 px (handwriting stays
/// readable) and encodes it as JPEG, smaller steps only if it would not fit
/// the server limit. Null when the bytes are no image this package decodes
/// (HEIC, a broken file). Top-level so it can run in a background isolate
/// via [compute]: decoding a camera photo takes hundreds of ms.
Uint8List? _compressForClaude(Uint8List raw) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(raw);
  } catch (_) {
    return null;
  }
  if (decoded == null) return null;
  for (final (maxLongEdge, quality) in const [(2000, 80), (1568, 70), (1200, 60)]) {
    final image = decoded.width >= decoded.height
        ? (decoded.width > maxLongEdge ? img.copyResize(decoded, width: maxLongEdge) : decoded)
        : (decoded.height > maxLongEdge ? img.copyResize(decoded, height: maxLongEdge) : decoded);
    final jpeg = Uint8List.fromList(img.encodeJpg(image, quality: quality));
    if ((jpeg.length + 2) ~/ 3 * 4 <= _maxImageBase64Chars) return jpeg;
  }
  return null;
}

/// Client side of the photo/PDF → shopping-list-items import flow:
/// render (PDF) → compress → `ai` task `list_import` (one call and one
/// quota unit per note) → typed result. The photo goes inside the request
/// and is never stored.
class ListImportService {
  ListImportService({ClaudeService Function()? claude})
      : _claude = claude ?? (() => ClaudeService.instance);

  static final ListImportService instance = ListImportService();

  /// Photo deadline (plan, Global Constraints).
  static const Duration timeout = Duration(seconds: 30);

  final ClaudeService Function() _claude;

  /// Renders page 1 of a PDF to PNG bytes at roughly the target resolution.
  /// Runs on the main isolate (pdfx uses platform channels) — the render
  /// itself is native-side, so the Dart thread is not blocked.
  Future<Uint8List> _pdfFirstPageToImage(Uint8List pdfBytes) async {
    try {
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
    } on ListImportException {
      rethrow;
    } catch (e) {
      debugPrint('❌ [LIST_IMPORT] PDF could not be rendered: $e');
      throw const ListImportException('unreadable_image');
    }
  }

  /// Full pipeline. [isPdf] switches on the PDF page-render path.
  /// [cancelToken] stops the import: between stages, and while Avo reads
  /// the note the call ends right away with `cancelled`.
  /// Throws only [ListImportException] with one of its [ListImportException.codes].
  Future<ListImportResult> importFromBytes(
    Uint8List raw, {
    required bool isPdf,
    required CancelToken cancelToken,
  }) async {
    _throwIfCancelled(cancelToken);
    final imageBytes = isPdf ? await _pdfFirstPageToImage(raw) : raw;
    _throwIfCancelled(cancelToken);
    final jpeg = await compute(_compressForClaude, imageBytes);
    if (jpeg == null) {
      debugPrint('⚠️ [LIST_IMPORT] Photo is no readable image');
      throw const ListImportException('unreadable_image');
    }
    _throwIfCancelled(cancelToken);

    final Map<String, dynamic> body;
    try {
      body = await Future.any([
        _claude().run(
          'list_import',
          {'image_b64': base64Encode(jpeg), 'media_type': 'image/jpeg'},
          timeout: timeout,
        ),
        cancelToken.whenCancel.then<Map<String, dynamic>>(
          (_) => throw const ListImportException('cancelled'),
        ),
      ]);
    } on ClaudeException catch (e) {
      throw ListImportException(_codeFor(e.code));
    }

    final result = ListImportResult.fromJson(body);
    if (result.items.isEmpty) throw const ListImportException('no_items_found');
    debugPrint('✅ [LIST_IMPORT] ${result.items.length} items read');
    return result;
  }

  /// `ai` error codes in the 8 codes the import screen knows.
  static String _codeFor(String claudeCode) => switch (claudeCode) {
        'no_items_found' || 'no_food_detected' => 'no_items_found',
        'unreadable_image' || 'refused' => 'unreadable_image',
        'rate_limited' || 'quota_exceeded' => 'rate_limited',
        'timeout' => 'timeout',
        'network_error' => 'network_error',
        'not_signed_in' || 'unauthorized' => 'not_signed_in',
        _ => 'provider_error',
      };

  void _throwIfCancelled(CancelToken token) {
    if (token.isCancelled) throw const ListImportException('cancelled');
  }
}
