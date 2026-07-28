import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/personalized_deals_service.dart';

ShoppingItemModel item(String name) {
  final now = DateTime(2026, 1, 1);
  return ShoppingItemModel(
    id: name,
    listId: 'list-1',
    name: name,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('selectCandidateNames', () {
    test('skips too-short names but keeps short real item names like "Ei"', () {
      final names = PersonalizedDealsService.selectCandidateNames([
        item('Ei'), // 2 chars — kept (unlike RecipeOfferService's 3-char rule)
        item('X'), // 1 char — skipped
        item('Milch'),
      ]);
      expect(names, ['Ei', 'Milch']);
    });

    test('does not skip pantry staples — unlike recipe ingredient matching',
        () {
      final names = PersonalizedDealsService.selectCandidateNames([
        item('Salz'),
        item('Wasser'),
      ]);
      expect(names, ['Salz', 'Wasser']);
    });

    test('de-duplicates case-insensitively, keeping the first spelling', () {
      final names = PersonalizedDealsService.selectCandidateNames(
          [item('Tomaten'), item('tomaten'), item(' TOMATEN '), item('Zwiebeln')]);
      expect(names, ['Tomaten', 'Zwiebeln']);
    });

    test('caps at maxCheckedItems, preserving order', () {
      final items = List.generate(20, (i) => item('Artikel$i'));
      final names = PersonalizedDealsService.selectCandidateNames(items);
      expect(names.length, PersonalizedDealsService.maxCheckedItems);
      expect(names.first, 'Artikel0');
      expect(names.last, 'Artikel9');
    });

    test('empty input yields empty output', () {
      expect(PersonalizedDealsService.selectCandidateNames([]), isEmpty);
    });
  });
}
