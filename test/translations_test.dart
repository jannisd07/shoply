import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/localization/app_translations.dart';

/// Every literal key passed to `context.tr('...')` or
/// `AppTranslations.get('...')` must exist, otherwise users see the raw key.
void main() {
  test('all literal translation keys are defined', () {
    final pattern = RegExp(
      r"""(?:\.tr|AppTranslations\.get)\(\s*'([a-z0-9_]+)'""",
    );
    final missing = <String>{};
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      for (final m in pattern.allMatches(file.readAsStringSync())) {
        final key = m.group(1)!;
        // get() falls back to the key itself; a key whose English text equals
        // the key ('items' -> 'items') still differs in German.
        if (AppTranslations.get(key, 'en') == key &&
            AppTranslations.get(key, 'de') == key) {
          missing.add('$key (${file.path})');
        }
      }
    }
    expect(missing, isEmpty, reason: 'Missing translation keys');
  });
}
