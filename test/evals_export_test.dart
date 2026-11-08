import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/core/constants/categories.dart';
import 'package:shoply/core/utils/product_name_normalizer.dart';
import 'package:shoply/data/services/product_classifier_service.dart';
import 'package:shoply/data/services/smart_categorization_service.dart';

/// Dataset of the promptfoo eval `supabase/evals/categorize` and the baseline
/// Claude is compared with: today's offline categorization of the same
/// entries (see supabase/evals/README.md).
///
/// Always checks the dataset. With `AVO_EVALS_BASELINE_OUT=<path>` it also
/// writes both baselines as JSON for the promptfoo baseline providers:
///   AVO_EVALS_BASELINE_OUT=supabase/evals/.results/baseline.json \
///     flutter test test/evals_export_test.dart
const _datasetPath = 'supabase/evals/categorize/dataset.json';
const _outEnv = 'AVO_EVALS_BASELINE_OUT';

const _tags = {
  'plain',
  'plural',
  'compound',
  'typo',
  'slang',
  'brand',
  'quantity',
  'ambiguous',
  'injection',
  'nonfood',
  'not_a_product',
  'gibberish',
};

/// Tags the plan asks for, with the least number of entries each.
const _requiredTags = {
  'brand': 30,
  'typo': 15,
  'plural': 30,
  'compound': 30,
  'ambiguous': 30,
  'quantity': 10,
  'injection': 6,
};

class _Entry {
  _Entry(Map<String, dynamic> json)
      : name = json['name'] as String,
        lang = json['lang'] as String,
        expected = json['expected'] as String,
        accept = [...?(json['accept'] as List?)?.cast<String>()],
        tags = [...?(json['tags'] as List?)?.cast<String>()],
        brand = json['brand'] as String?;

  final String name;
  final String lang;
  final String expected;
  final List<String> accept;
  final List<String> tags;
  final String? brand;

  bool accepts(String id) => id == expected || accept.contains(id);
}

List<_Entry> _readDataset() {
  final decoded =
      jsonDecode(File(_datasetPath).readAsStringSync()) as Map<String, dynamic>;
  return [
    for (final item in decoded['items'] as List) _Entry(item as Map<String, dynamic>),
  ];
}

void main() {
  final ids = Categories.all.map((c) => c.id).toSet();
  late final List<_Entry> entries = _readDataset();

  test('has at least 200 entries, German and English', () {
    expect(entries.length, greaterThanOrEqualTo(200));
    expect(entries.where((e) => e.lang == 'de').length, greaterThanOrEqualTo(120));
    expect(entries.where((e) => e.lang == 'en').length, greaterThanOrEqualTo(60));
    expect(entries.map((e) => e.lang).toSet(), {'de', 'en'});
  });

  test('every expected and accepted id is an app category', () {
    for (final entry in entries) {
      expect(ids, contains(entry.expected), reason: entry.name);
      for (final id in entry.accept) {
        expect(ids, contains(id), reason: entry.name);
        expect(id, isNot(entry.expected), reason: entry.name);
      }
    }
  });

  test('covers every category and the required kinds of entries', () {
    for (final id in ids) {
      expect(
        entries.where((e) => e.expected == id).length,
        greaterThanOrEqualTo(id == 'other' ? 15 : 20),
        reason: id,
      );
    }
    for (final entry in entries) {
      expect(entry.tags, isNotEmpty, reason: entry.name);
      expect(_tags, containsAll(entry.tags), reason: entry.name);
      // Alternatives exist exactly for the entries marked ambiguous.
      expect(entry.accept.isNotEmpty, entry.tags.contains('ambiguous'), reason: entry.name);
      if (entry.brand != null) expect(entry.tags, contains('brand'), reason: entry.name);
    }
    _requiredTags.forEach((tag, least) {
      expect(
        entries.where((e) => e.tags.contains(tag)).length,
        greaterThanOrEqualTo(least),
        reason: tag,
      );
    });
  });

  test('names are unique after normalization', () {
    final seen = <String>{};
    for (final entry in entries) {
      final key = '${entry.lang}:${normalizeProductName(entry.name)}';
      expect(seen.add(key), isTrue, reason: 'duplicate ${entry.name}');
    }
  });

  test('baselines answer an app category for every entry', () {
    final keywords = ProductClassifierService.instance;
    final local = SmartCategorizationService.forTesting(currentUserId: () => null);
    final answers = <String, Map<String, String>>{};
    var keywordHits = 0;
    var localHits = 0;

    for (final entry in entries) {
      final keyword =
          keywords.match(entry.name, preferredLanguage: entry.lang)?.categoryId ?? 'other';
      final offline = local.classify(entry.name).categoryId;
      expect(ids, contains(keyword), reason: entry.name);
      expect(ids, contains(offline), reason: entry.name);
      if (entry.accepts(keyword)) keywordHits++;
      if (entry.accepts(offline)) localHits++;
      answers[entry.name] = {'keywords': keyword, 'local': offline};
    }

    String share(int hits) => '$hits/${entries.length}';
    debugPrint('🔵 [EVALS] baseline keywords ${share(keywordHits)}, local ${share(localHits)}');

    final out = Platform.environment[_outEnv];
    if (out == null || out.isEmpty) return;
    final file = File(out)..createSync(recursive: true);
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
      'description': 'Offline categorization of $_datasetPath, written by '
          'test/evals_export_test.dart. keywords = ProductClassifierService.match '
          '(item language first, else other); local = SmartCategorizationService.classify '
          '(the app\'s offline answer without a signed-in user).',
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'count': entries.length,
      'hits': {'keywords': keywordHits, 'local': localHits},
      'answers': answers,
    }));
    debugPrint('✅ [EVALS] baseline written to $out');
  });
}
