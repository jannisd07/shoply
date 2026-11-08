import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/core/constants/categories.dart';

/// The edge function `ai` builds the `category_id` enum of its `categorize`
/// schema from `supabase/functions/_shared/categories.json`. This test keeps
/// that file equal to the app's categories, so Claude can only answer ids the
/// app knows.
void main() {
  List<Map<String, dynamic>> readEntries() {
    final file = File('supabase/functions/_shared/categories.json');
    final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return (decoded['categories'] as List).cast<Map<String, dynamic>>();
  }

  test('categories.json lists exactly the ids of Categories.all, in order', () {
    final ids = [for (final entry in readEntries()) entry['id']];
    expect(ids, Categories.all.map((c) => c.id).toList());
  });

  test('categories.json uses the app names in German and English', () {
    final entries = readEntries();
    for (var i = 0; i < entries.length; i++) {
      final category = Categories.all[i];
      expect(entries[i]['de'], category.getName('de'), reason: category.id);
      expect(entries[i]['en'], category.getName('en'), reason: category.id);
    }
  });

  test('every category has German and English examples for the prompt', () {
    for (final entry in readEntries()) {
      for (final key in ['examples_de', 'examples_en']) {
        final examples = (entry[key] as List?)?.cast<String>() ?? const [];
        expect(examples, isNotEmpty, reason: '${entry['id']} $key');
      }
    }
  });
}
