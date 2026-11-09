import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/constants/recipe_categories.dart';
import 'package:shoply/data/models/dietary_preference.dart';
import 'package:shoply/data/models/user_model.dart';
import 'package:shoply/presentation/screens/recipes/recipes_home_data.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_browse_state.dart';

import 'recipes_browse_fakes.dart';

Map<String, RecipeFit> _fits(RecipeDietProfile p) =>
    recipeFitsFor(browseCatalogue(), p);

RecipeSearchResults _search(String q) => searchRecipes(
  browseCatalogue(),
  q,
  categoryName: (c) => c.id,
  dietName: (d) => d,
);

void main() {
  group('allergies (Konzept 13 §2.3)', () {
    test('sesame without a substitute is a warning, never adapted', () {
      final salad = browseCatalogue().firstWhere((r) => r.id == 'salad');
      final fit = recipeFitOf(
        salad,
        const RecipeDietProfile(allergies: ['sesame']),
      );
      expect(fit.hasWarning, isTrue);
      expect(fit.unsafeAllergens.single.type, AllergyType.sesame);
      expect(fit.fitsMe, isFalse);
    });

    test('peanut butter has a safe substitute: adapted', () {
      final satay = browseCatalogue().firstWhere((r) => r.id == 'satay');
      final fit = recipeFitOf(
        satay,
        const RecipeDietProfile(allergies: ['peanuts']),
      );
      expect(fit.hasWarning, isFalse);
      expect(fit.adapted, 1);
    });

    test('milk with a safe plant milk is adapted, not a warning', () {
      final pancakes = browseCatalogue().firstWhere((r) => r.id == 'pancakes');
      final fit = recipeFitOf(
        pancakes,
        const RecipeDietProfile(allergies: ['milk']),
      );
      expect(fit.hasWarning, isFalse);
      expect(fit.adapted, greaterThan(0));
      expect(fit.fitsMe, isTrue);
    });

    test('without auto adapt the same milk is a warning', () {
      final pancakes = browseCatalogue().firstWhere((r) => r.id == 'pancakes');
      final fit = recipeFitOf(
        pancakes,
        const RecipeDietProfile(allergies: ['milk'], autoAdapt: false),
      );
      expect(fit.hasWarning, isTrue);
      expect(fit.adapted, 0);
    });

    test('a substitute with another own allergen is not safe', () {
      // Hafermilch, Mandelmilch and Sojamilch would replace milk, but gluten,
      // nuts and soy rule them out. Mehl still has Reismehl.
      final pancakes = browseCatalogue().firstWhere((r) => r.id == 'pancakes');
      final fit = recipeFitOf(
        pancakes,
        const RecipeDietProfile(allergies: ['milk', 'nuts', 'gluten', 'soy']),
      );
      expect(fit.hasWarning, isTrue);
      expect(fit.unsafeAllergens.map((m) => m.type), [AllergyType.milk]);
      expect(fit.adapted, 1);
    });

    test('Kokosmilch is no milk; no profile fits without remarks', () {
      final dal = browseCatalogue().firstWhere((r) => r.id == 'dal');
      expect(
        recipeFitOf(
          dal,
          const RecipeDietProfile(allergies: ['milk']),
        ).hasWarning,
        isFalse,
      );
      expect(recipeFitOf(dal, RecipeDietProfile.none), same(RecipeFit.neutral));
      expect(_fits(RecipeDietProfile.none), isEmpty);
    });

    test('diet ids that mean "must not eat" count as allergies', () {
      final user = UserModel(
        id: 'u1',
        email: 'a@b.c',
        dietPreferences: const ['gluten_free'],
        createdAt: browseNow,
        updatedAt: browseNow,
      );
      expect(RecipeDietProfile.of(user).allergies, ['gluten']);
    });

    test('a vegetarian diet: veggie fits, minced meat is adapted', () {
      final bolo = browseCatalogue().firstWhere((r) => r.id == 'bolo');
      final shakshuka = browseCatalogue().firstWhere(
        (r) => r.id == 'shakshuka',
      );
      const veggie = RecipeDietProfile(diets: ['vegetarian']);
      expect(recipeFitOf(shakshuka, veggie).adapted, 0);
      expect(recipeFitOf(bolo, veggie).dietMet, isTrue);
      expect(recipeFitOf(bolo, veggie).adapted, greaterThan(0));
      expect(
        recipeFitOf(
          bolo,
          const RecipeDietProfile(diets: ['vegetarian'], autoAdapt: false),
        ).dietMet,
        isFalse,
      );
    });
  });

  group('tab sections', () {
    test('chips: "Für dich" first, then only chips with recipes', () {
      expect(availableQuickFilters(browseCatalogue()), [
        RecipeQuickFilter.forYou,
        RecipeQuickFilter.quick,
        RecipeQuickFilter.vegetarian,
        RecipeQuickFilter.vegan,
        RecipeQuickFilter.healthy,
      ]);
      expect(availableQuickFilters(const []), [RecipeQuickFilter.forYou]);
    });

    test('the hero fits the list when two ingredients are on it', () {
      final home = buildRecipesHome(
        catalogue: browseCatalogue(),
        filter: RecipeQuickFilter.forYou,
        listItemStems: [
          nameStems('Tomate'),
          nameStems('Feta-Käse'),
          nameStems('Milch'),
        ],
      );
      expect(home.heroId, 'shakshuka');
      expect(home.heroKind, RecipeHeroKind.listMatch);
    });

    test('without a list match the recipe of the week, else the best', () {
      final week = buildRecipesHome(
        catalogue: browseCatalogue(),
        filter: RecipeQuickFilter.forYou,
        listItemStems: [nameStems('Kaffee')],
        weekId: 'paprika',
      );
      expect(week.heroId, 'paprika');
      expect(week.heroKind, RecipeHeroKind.recipeOfTheWeek);

      final pick = buildRecipesHome(
        catalogue: browseCatalogue(),
        filter: RecipeQuickFilter.forYou,
      );
      expect(pick.heroKind, RecipeHeroKind.pick);
      expect(pick.heroId, 'shakshuka');
    });

    test('"Für dich" leaves out own allergens, the hero never shows one', () {
      const profile = RecipeDietProfile(allergies: ['sesame']);
      final fits = _fits(profile);
      final forYou = buildRecipesHome(
        catalogue: browseCatalogue(),
        filter: RecipeQuickFilter.forYou,
        fits: fits,
        weekId: 'salad',
        popularIds: const ['salad', 'dal'],
      );
      expect(forYou.heroId, isNot('salad'));
      expect(forYou.popularIds, isNot(contains('salad')));
      expect(forYou.newestIds, isNot(contains('salad')));
      expect(forYou.poolCount, 9);

      // Other chips show it (with the warning), but never as the hero.
      final vegan = buildRecipesHome(
        catalogue: browseCatalogue(),
        filter: RecipeQuickFilter.vegan,
        fits: fits,
        weekId: 'salad',
      );
      expect(vegan.poolCount, 3);
      expect(vegan.heroId, isNot('salad'));
    });

    test('popular follows the server, newest is by date, no doubles', () {
      final home = buildRecipesHome(
        catalogue: browseCatalogue(),
        filter: RecipeQuickFilter.forYou,
        popularIds: const ['bolo', 'unknown', 'salad'],
      );
      expect(home.popularIds.take(2), ['bolo', 'salad']);
      expect(home.popularIds, hasLength(kHomePopularCount));
      final shown = {home.heroId, ...home.popularIds, ...home.newestIds};
      expect(
        shown,
        hasLength(1 + home.popularIds.length + home.newestIds.length),
      );
      final dates = [
        for (final id in home.newestIds)
          browseCatalogue().firstWhere((r) => r.id == id).createdAt,
      ];
      expect(dates, [...dates]..sort((a, b) => b.compareTo(a)));
    });

    test('below eight recipes "Beliebt" and "Neu" are left out', () {
      final home = buildRecipesHome(
        catalogue: browseCatalogue().take(5).toList(),
        filter: RecipeQuickFilter.forYou,
      );
      expect(home.heroId, isNotNull);
      expect(home.popularIds, isEmpty);
      expect(home.newestIds, isEmpty);
      expect(home.poolCount, 5);
    });

    test('a chip narrows every section; half rule per view', () {
      final home = buildRecipesHome(
        catalogue: browseCatalogue(),
        filter: RecipeQuickFilter.vegan,
      );
      final ids = {home.heroId, ...home.popularIds, ...home.newestIds};
      expect(ids.difference({'dal', 'soup', 'salad'}), isEmpty);
      expect(home.popularIds.length, lessThanOrEqualTo(1));
    });

    test('app language first', () {
      final catalogue = [
        browseRecipe('en', language: 'en', rating: 5, ratings: 99),
        ...browseCatalogue(),
      ];
      final home = buildRecipesHome(
        catalogue: catalogue,
        filter: RecipeQuickFilter.forYou,
        language: 'de',
      );
      expect(home.heroId, isNot('en'));
    });

    test('categories with recipes keep their order', () {
      final ids = categoriesWithRecipes(browseCatalogue()).map((c) => c.id);
      expect(ids.first, recipeCategories.first.id);
      expect(ids, contains('soup'));
      expect(ids, isNot(contains('seafood')));
    });
  });

  group('search (Konzept 13 §4)', () {
    test('title hits before ingredient hits, "Mit Zutat" from 3 letters', () {
      final r = _search('feta');
      expect(r.recipes.first.id, 'shakshuka');
      expect(r.ingredient, 'feta');
      expect(r.ingredientCount, 1);

      final paprika = _search('Paprika');
      expect(paprika.recipes.first.id, 'paprika');
      expect(
        paprika.recipes.map((x) => x.id),
        containsAll(['shakshuka', 'ofen']),
      );
      expect(paprika.ingredientCount, 3);
    });

    test('umlauts fold, creators and categories are found', () {
      expect(_search('kurbis').recipes.single.id, 'soup');
      expect(_search('deniz').authors.single.name, 'Deniz Aydın');
      expect(_search('soup').categories.map((c) => c.id), ['soup']);
      expect(_search('veg').dietLabels, containsAll(['vegetarian', 'vegan']));
      expect(_search('ve').ingredient, isNull);
    });

    test('nothing found', () {
      expect(_search('Halloumi-Burger').isEmpty, isTrue);
      expect(_search('  ').isEmpty, isTrue);
    });
  });

  group('diet filters check ingredients (owner, S5)', () {
    final honey = browseRecipe(
      'honey',
      labels: const ['vegan'],
      ingredients: const ['Haferflocken', 'Honig'],
    );
    final chicken = browseRecipe(
      'chicken',
      labels: const ['vegetarian'],
      ingredients: const ['Reis', 'Hähnchen'],
    );
    final catalogue = [honey, chicken, ...browseCatalogue()];

    test('a vegan label with honey counts as vegetarian, not vegan', () {
      expect(matchesQuickFilter(honey, RecipeQuickFilter.vegan), isFalse);
      expect(matchesQuickFilter(honey, RecipeQuickFilter.vegetarian), isTrue);
      expect(
        matchesListFilter(honey, RecipeListFilter.vegan, RecipeFit.neutral),
        isFalse,
      );
      expect(recipesInCategory(catalogue, 'vegan').map((r) => r.id), [
        'dal',
        'soup',
        'salad',
      ]);
    });

    test('a vegetarian label with meat matches no diet filter', () {
      expect(
        matchesQuickFilter(chicken, RecipeQuickFilter.vegetarian),
        isFalse,
      );
      expect(
        matchesListFilter(
          chicken,
          RecipeListFilter.vegetarian,
          RecipeFit.neutral,
        ),
        isFalse,
      );
      expect(
        recipesInCategory(catalogue, 'vegetarian').map((r) => r.id),
        isNot(contains('chicken')),
      );
    });

    test('"Passt zu mir" checks the ingredients behind a vegan label', () {
      final fit = recipeFitOf(honey, const RecipeDietProfile(diets: ['vegan']));
      // Before S5 the label alone met the diet, with nothing adapted.
      expect(fit.dietMet && fit.adapted == 0, isFalse);
    });
  });

  group('list pages (Konzept 13 §5–6)', () {
    test('categories match exact labels; ingredient pages by ingredient', () {
      final catalogue = [
        browseRecipe('x', labels: const ['non-vegetarian']),
        ...browseCatalogue(),
      ];
      expect(recipesInCategory(catalogue, 'vegetarian').map((r) => r.id), [
        'shakshuka',
        'pasta',
        'ofen',
      ]);
      expect(recipesInCategory(catalogue, 'ingredient:feta').map((r) => r.id), [
        'shakshuka',
      ]);
      expect(ingredientOfCategory('ingredient: Feta '), 'Feta');
      expect(ingredientOfCategory('soup'), isNull);
    });

    test('filters combine with AND and only occurring ones are offered', () {
      final veg = recipesInCategory(browseCatalogue(), 'vegetarian');
      final filters = availableListFilters(
        veg,
        hasProfile: false,
        categoryId: 'vegetarian',
      );
      expect(filters, isNot(contains(RecipeListFilter.fitsMe)));
      expect(filters, isNot(contains(RecipeListFilter.vegetarian)));
      expect(filters, contains(RecipeListFilter.under20));
      final quick = applyListFilters(veg, {RecipeListFilter.under20});
      expect(quick.map((r) => r.id), ['pasta']);
      expect(
        applyListFilters(veg, {
          RecipeListFilter.under20,
          RecipeListFilter.upTo30,
        }).map((r) => r.id),
        ['pasta'],
      );
      expect(
        availableListFilters(veg, hasProfile: true),
        contains(RecipeListFilter.fitsMe),
      );
    });

    test('"Passt zu mir" drops own allergens', () {
      const profile = RecipeDietProfile(allergies: ['sesame']);
      final out = applyListFilters(browseCatalogue(), {
        RecipeListFilter.fitsMe,
      }, fits: _fits(profile));
      expect(out.map((r) => r.id), isNot(contains('salad')));
      expect(out, hasLength(9));
    });

    test('sorting', () {
      final c = browseCatalogue();
      expect(sortRecipes(c, RecipeSort.newest).first.id, 'satay');
      expect(sortRecipes(c, RecipeSort.fastest).first.id, 'salad');
      expect(sortRecipes(c, RecipeSort.rating).first.id, 'dal');
      expect(RecipeSort.byId('newest'), RecipeSort.newest);
      expect(RecipeListFilter.byId('under-20'), RecipeListFilter.under20);
      expect(RecipeListFilter.byId('nope'), isNull);
    });

    test('popular: the server ranking first, then the local one', () {
      final out = popularRecipes(browseCatalogue(), const ['salad', 'gone']);
      expect(out.first.id, 'salad');
      expect(out, hasLength(10));
    });
  });

  group('state', () {
    test('a failed refresh keeps the local catalogue', () {
      final notifier = RecipeCatalogueNotifier(browseCatalogue());
      expect(notifier.state.known, isTrue);
      notifier.apply(const AsyncData([]));
      expect(notifier.state.recipes, hasLength(10));
      expect(notifier.state.refreshFailed, isTrue);
      notifier.apply(AsyncError(Exception('offline'), StackTrace.empty));
      expect(notifier.state.recipes, hasLength(10));
      notifier.apply(AsyncData(browseCatalogue().take(3).toList()));
      expect(notifier.state.recipes, hasLength(3));
      expect(notifier.state.refreshFailed, isFalse);
    });

    test('without local recipes the first answer decides', () {
      final notifier = RecipeCatalogueNotifier(null);
      expect(notifier.state.known, isFalse);
      notifier.apply(const AsyncLoading());
      expect(notifier.state.known, isFalse);
      notifier.apply(const AsyncData([]));
      expect(notifier.state.known, isTrue);
      expect(notifier.state.recipes, isEmpty);
    });

    test('recent searches: newest first, no doubles, at most five', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = RecipesBrowsePrefsNotifier('u1', prefs);
      for (final q in ['feta', 'pasta', 'Feta', 'a', 'b', 'c', 'd']) {
        store.addRecentSearch(q);
      }
      expect(store.state.recentSearches, ['d', 'c', 'b', 'a', 'Feta']);
      store.removeRecentSearch('a');
      expect(store.state.recentSearches, ['d', 'c', 'b', 'Feta']);
      store
        ..dismissDietHint()
        ..saveHighlights(
          const RecipeHighlights(popularIds: ['x'], weekId: 'w'),
        );
      // Read back like the next app start.
      final again = RecipesBrowsePrefsNotifier('u1', prefs);
      expect(again.state.recentSearches, ['d', 'c', 'b', 'Feta']);
      expect(again.state.dietHintDismissed, isTrue);
      expect(again.state.highlights?.weekId, 'w');
      // Another account starts empty.
      expect(
        RecipesBrowsePrefsNotifier('u2', prefs).state.recentSearches,
        isEmpty,
      );
    });
  });
}
