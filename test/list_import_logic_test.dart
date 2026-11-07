import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/services/list_import_service.dart';

void main() {
  group('ExtractedListItem.fromJson', () {
    test('parses a full row', () {
      final item = ExtractedListItem.fromJson({
        'name': '  Vollmilch ',
        'quantity': 2,
        'unit': ' l ',
        'confidence': 0.94,
      });
      expect(item.name, 'Vollmilch'); // trimmed
      expect(item.quantity, 2);
      expect(item.unit, 'l'); // trimmed
      expect(item.confidence, 0.94);
      expect(item.isLowConfidence, false);
    });

    test('tolerates missing/null quantity, unit, confidence', () {
      final item = ExtractedListItem.fromJson({'name': 'Bananen'});
      expect(item.name, 'Bananen');
      expect(item.quantity, isNull);
      expect(item.unit, isNull);
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
  });

  group('ListImportException', () {
    test('carries the machine-readable code', () {
      const e = ListImportException('rate_limited');
      expect(e.code, 'rate_limited');
      expect(e.toString(), contains('rate_limited'));
    });
  });
}
