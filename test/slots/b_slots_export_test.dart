// The single import of Teil A (docs/redesign/prompt-b-vorrang.md) must keep
// exporting every slot under its contract name and signature.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

void main() {
  test('b_slots.dart exports the contract', () {
    final item = ShoppingItemModel(
      id: 'i',
      listId: 'l',
      name: 'Milch',
      createdAt: DateTime(2026, 11, 8),
      updatedAt: DateTime(2026, 11, 8),
    );
    final widgets = <Widget>[
      const StoreChip(listId: 'l'),
      OfferSuggestionsBar(listId: 'l', query: 'milch', onAdded: () {}),
      ItemOfferBadge(listId: 'l', item: item, compact: true),
      ItemOfferCard(listId: 'l', item: item),
      const ListOfferSummary(listId: 'l'),
      const ListOfferCountBadge(listId: 'l'),
      ArticleImage(item: item, size: 88, radius: 20),
      OffersSetupStep(onDone: () {}),
    ];
    expect(widgets, hasLength(8));

    final Future<bool> Function(BuildContext, String) checkout =
        openCheckoutFlow;
    final Future<void> Function(BuildContext, Recipe) logRecipe =
        openLogRecipe;
    final Future<void> Function(WidgetRef, String, bool) hide =
        setOffersHiddenForList;
    final ProviderListenable<bool> hidden = offersHiddenForListProvider('l');
    final ProviderListenable<StoreInfo?> store = storeForListProvider('l');
    final providers = <ProviderListenable<bool>>[
      offersAvailableProvider,
      offersRemoteEnabledProvider,
      calorieTrackingEnabledProvider,
    ];
    expect([checkout, logRecipe, hide, hidden, store], hasLength(5));
    expect(providers, hasLength(3));
  });

  test('RecipeOffersCard takes a recipe', () {
    expect(RecipeOffersCard.new, isNotNull);
  });
}
