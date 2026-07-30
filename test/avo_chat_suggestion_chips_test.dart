import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/presentation/screens/ai/avo_chat_screen.dart';

void main() {
  group('buildSuggestionChipKeys', () {
    test('no priority key: takes the first 2 general keys as-is', () {
      expect(
        buildSuggestionChipKeys(
          shuffledGeneralKeys: ['a', 'b', 'c'],
          priorityKey: null,
        ),
        ['a', 'b'],
      );
    });

    test('priority key present: goes first, then 1 general key', () {
      expect(
        buildSuggestionChipKeys(
          shuffledGeneralKeys: ['a', 'b', 'c'],
          priorityKey: 'p',
        ),
        ['p', 'a'],
      );
    });

    test('priority key that also appears in the general pool is not '
        'duplicated', () {
      expect(
        buildSuggestionChipKeys(
          shuffledGeneralKeys: ['a', 'p', 'c'],
          priorityKey: 'p',
        ),
        ['p', 'a'],
      );
    });

    test('fewer than 2 general keys available: returns what it has', () {
      expect(
        buildSuggestionChipKeys(
          shuffledGeneralKeys: ['a'],
          priorityKey: null,
        ),
        ['a'],
      );
    });

    test('empty everything: returns an empty list', () {
      expect(
        buildSuggestionChipKeys(shuffledGeneralKeys: [], priorityKey: null),
        <String>[],
      );
    });
  });
}
