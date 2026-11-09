// Photo of a shopping list -> items (plan B1.7, client half).
//
// What matters: the photo goes to the `ai` task `list_import` (no storage
// upload any more), the answer arrives as the same ExtractedListItem rows
// the review screen edits, now with the category id, and every failure
// arrives as one of the 8 codes attachment_sheet.dart maps to its texts.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:shoply/data/services/claude_service.dart';
import 'package:shoply/data/services/list_import_service.dart';

typedef _Call = ({String task, Map<String, dynamic> input, Duration timeout});

/// Answers `run` without any network; records what was asked.
class _FakeClaude extends ClaudeService {
  _FakeClaude(this._answer);

  final Future<Map<String, dynamic>> Function() _answer;
  final List<_Call> calls = [];

  @override
  Future<Map<String, dynamic>> run(
    String task,
    Map<String, dynamic> input, {
    required Duration timeout,
  }) {
    calls.add((task: task, input: input, timeout: timeout));
    return _answer();
  }
}

Uint8List _jpeg({int width = 8, int height = 8}) =>
    Uint8List.fromList(img.encodeJpg(img.Image(width: width, height: height)));

Map<String, dynamic> _answer() => {
      'items': [
        {'name': 'Vollmilch', 'quantity': 2, 'unit': 'l', 'category_id': 'dairy', 'confidence': 0.95},
        {'name': 'Tomaten', 'quantity': null, 'unit': null, 'category_id': 'fruits_vegetables', 'confidence': 0.4},
        {'name': '  ', 'quantity': 1, 'unit': null, 'category_id': 'other', 'confidence': 0.95},
      ],
      'unparsed_lines': ['Oma anrufen', 3],
    };

const _allCodes = {
  'no_items_found',
  'unreadable_image',
  'rate_limited',
  'provider_error',
  'timeout',
  'network_error',
  'not_signed_in',
  'cancelled',
};

void main() {
  group('ExtractedListItem.fromJson', () {
    test('parses a full row', () {
      final item = ExtractedListItem.fromJson({
        'name': '  Vollmilch ',
        'quantity': 2,
        'unit': ' l ',
        'category_id': 'dairy',
        'confidence': 0.94,
      });
      expect(item.name, 'Vollmilch'); // trimmed
      expect(item.quantity, 2);
      expect(item.unit, 'l'); // trimmed
      expect(item.categoryId, 'dairy');
      expect(item.confidence, 0.94);
      expect(item.isLowConfidence, false);
    });

    test('tolerates missing/null quantity, unit, category, confidence', () {
      final item = ExtractedListItem.fromJson({'name': 'Bananen'});
      expect(item.name, 'Bananen');
      expect(item.quantity, isNull);
      expect(item.unit, isNull);
      expect(item.categoryId, isNull);
      expect(item.confidence, isNull);
      // No confidence signal → not flagged low-confidence.
      expect(item.isLowConfidence, false);
    });

    test('coerces integer-ish and double quantities', () {
      expect(
        ExtractedListItem.fromJson({'name': 'x', 'quantity': 1.5}).quantity,
        1.5,
      );
      expect(
        ExtractedListItem.fromJson({'name': 'x', 'quantity': 3}).quantity,
        3.0,
      );
    });

    test('low-confidence threshold is < 0.75', () {
      expect(
        ExtractedListItem.fromJson({'name': 'x', 'confidence': 0.74})
            .isLowConfidence,
        true,
      );
      expect(
        ExtractedListItem.fromJson({'name': 'x', 'confidence': 0.75})
            .isLowConfidence,
        false,
      );
    });

    test('empty unit string becomes empty (caller filters), name stays', () {
      final item = ExtractedListItem.fromJson({'name': 'Eier', 'unit': ''});
      expect(item.name, 'Eier');
      expect(item.unit, '');
    });

    test('values of the wrong type are treated as missing', () {
      final item = ExtractedListItem.fromJson({
        'name': 42,
        'quantity': 'zwei',
        'unit': 3,
        'category_id': ' ',
        'confidence': 'high',
      });
      expect(item.name, '');
      expect(item.quantity, isNull);
      expect(item.unit, isNull);
      expect(item.categoryId, isNull);
      expect(item.confidence, isNull);
    });
  });

  group('ListImportResult.fromJson', () {
    test('keeps named rows with their category and the unparsed lines', () {
      final result = ListImportResult.fromJson(_answer());

      expect(result.items.map((i) => (i.name, i.quantity, i.unit, i.categoryId)), [
        ('Vollmilch', 2.0, 'l', 'dairy'),
        ('Tomaten', null, null, 'fruits_vegetables'),
      ]);
      expect(result.items[1].isLowConfidence, isTrue);
      expect(result.unparsedLines, ['Oma anrufen']);
    });

    test('a result without lists is empty', () {
      final result = ListImportResult.fromJson(const {});
      expect(result.items, isEmpty);
      expect(result.unparsedLines, isEmpty);
    });
  });

  group('ListImportException', () {
    test('carries the machine-readable code', () {
      const e = ListImportException('rate_limited');
      expect(e.code, 'rate_limited');
      expect(e.toString(), contains('rate_limited'));
    });

    test('there are exactly the 8 codes the import screen maps', () {
      expect(ListImportException.codes, _allCodes);
    });
  });

  group('ListImportService.importFromBytes', () {
    test('sends the photo as a base64 JPEG to list_import with the 30 s photo deadline', () async {
      final claude = _FakeClaude(() async => _answer());
      final service = ListImportService(claude: () => claude);

      final result = await service.importFromBytes(
        _jpeg(),
        isPdf: false,
        cancelToken: CancelToken(),
      );

      expect(result.items.map((i) => i.categoryId), ['dairy', 'fruits_vegetables']);
      final call = claude.calls.single;
      expect(call.task, 'list_import');
      expect(call.timeout, const Duration(seconds: 30));
      expect(call.input.keys.toSet(), {'image_b64', 'media_type'});
      expect(call.input['media_type'], 'image/jpeg');
      final sent = base64Decode(call.input['image_b64'] as String);
      expect(sent.sublist(0, 3), [0xff, 0xd8, 0xff]);
    });

    test('a large photo is scaled to a 2000 px long edge before sending', () async {
      final claude = _FakeClaude(() async => _answer());
      final service = ListImportService(claude: () => claude);

      await service.importFromBytes(
        _jpeg(width: 3000, height: 1200),
        isPdf: false,
        cancelToken: CancelToken(),
      );

      final sent = img.decodeImage(base64Decode(claude.calls.single.input['image_b64'] as String))!;
      expect((sent.width, sent.height), (2000, 800));
    });

    test('no named row at all is no_items_found', () async {
      final claude = _FakeClaude(() async => {
            'items': [
              {'name': ' ', 'category_id': 'other'},
            ],
            'unparsed_lines': <String>[],
          });
      final service = ListImportService(claude: () => claude);

      await expectLater(
        service.importFromBytes(_jpeg(), isPdf: false, cancelToken: CancelToken()),
        throwsA(isA<ListImportException>().having((e) => e.code, 'code', 'no_items_found')),
      );
    });

    test('bytes that are no photo are unreadable_image and cost no request', () async {
      final claude = _FakeClaude(() async => _answer());
      final service = ListImportService(claude: () => claude);

      await expectLater(
        service.importFromBytes(
          Uint8List.fromList(utf8.encode('ftypheic but not really')),
          isPdf: false,
          cancelToken: CancelToken(),
        ),
        throwsA(isA<ListImportException>().having((e) => e.code, 'code', 'unreadable_image')),
      );
      expect(claude.calls, isEmpty);
    });

    test('a cancel before the request sends nothing', () async {
      final claude = _FakeClaude(() async => _answer());
      final service = ListImportService(claude: () => claude);
      final token = CancelToken()..cancel();

      await expectLater(
        service.importFromBytes(_jpeg(), isPdf: false, cancelToken: token),
        throwsA(isA<ListImportException>().having((e) => e.code, 'code', 'cancelled')),
      );
      expect(claude.calls, isEmpty);
    });

    test('a cancel while Avo reads ends right away with cancelled', () async {
      final never = Completer<Map<String, dynamic>>();
      final claude = _FakeClaude(() => never.future);
      final service = ListImportService(claude: () => claude);
      final token = CancelToken();

      final pending = service.importFromBytes(_jpeg(), isPdf: false, cancelToken: token);
      while (claude.calls.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      token.cancel();

      await expectLater(
        pending,
        throwsA(isA<ListImportException>().having((e) => e.code, 'code', 'cancelled')),
      );
    });

    const mapping = {
      'no_items_found': 'no_items_found',
      'no_food_detected': 'no_items_found',
      'unreadable_image': 'unreadable_image',
      'refused': 'unreadable_image',
      'quota_exceeded': 'rate_limited',
      'rate_limited': 'rate_limited',
      'timeout': 'timeout',
      'network_error': 'network_error',
      'not_signed_in': 'not_signed_in',
      'unauthorized': 'not_signed_in',
      'ai_disabled': 'provider_error',
      'bad_request': 'provider_error',
      'provider_error': 'provider_error',
      'something_new': 'provider_error',
    };
    for (final MapEntry(key: server, value: expected) in mapping.entries) {
      test('server code $server -> $expected', () async {
        final claude = _FakeClaude(() async => throw ClaudeException(server));
        final service = ListImportService(claude: () => claude);

        await expectLater(
          service.importFromBytes(_jpeg(), isPdf: false, cancelToken: CancelToken()),
          throwsA(isA<ListImportException>()
              .having((e) => e.code, 'code', expected)
              .having((e) => e.serverCode, 'serverCode', server)),
        );
        expect(_allCodes, contains(expected));
      });
    }
  });
}
