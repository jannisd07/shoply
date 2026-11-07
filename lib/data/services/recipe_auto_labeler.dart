/// Keyword-based recipe labeling used when a recipe is created or edited
/// without explicit labels.
///
/// **IMPORTANT**: Label IDs must match QuickFilters in recipe_filter.dart:
/// - Cuisine: italian, asian, mexican, mediterranean
/// - Diet: vegetarian, vegan, gluten-free, keto, low-carb
/// - Meal: breakfast, lunch, dinner, snack
/// - Time: quick, 30min, under-hour
/// - Difficulty: easy, medium, advanced
/// - Other: healthy, comfort-food, seafood, soup
library;

/// Category id -> (keyword -> weight). More specific keywords weigh more.
/// Diet types are only added when explicitly mentioned.
const Map<String, Map<String, int>> _categoryKeywords = {
  'italian': {
    'pasta': 3, 'pizza': 3, 'risotto': 3, 'lasagne': 3, 'italienisch': 3,
    'italian': 3, 'spaghetti': 3, 'carbonara': 3, 'bolognese': 3, 'pesto': 2,
    'mozzarella': 2, 'parmesan': 1, 'tiramisu': 3, 'gnocchi': 3, 'ravioli': 3,
    'bruschetta': 3, 'parmigiana': 3,
  },
  'asian': {
    'asiatisch': 3, 'chinese': 3, 'chinesisch': 3, 'japanese': 3,
    'japanisch': 3, 'thai': 3, 'vietnamese': 3, 'korean': 3, 'sushi': 3,
    'wok': 2, 'curry': 2, 'teriyaki': 3, 'ramen': 3, 'pho': 3, 'pad thai': 3,
    'gyoza': 3, 'miso': 2, 'kimchi': 3, 'sojasauce': 2, 'soy sauce': 2,
    'tofu': 2,
  },
  'mexican': {
    'mexican': 3, 'mexikanisch': 3, 'taco': 3, 'burrito': 3, 'enchilada': 3,
    'tex-mex': 3, 'quesadilla': 3, 'fajita': 3, 'nachos': 3, 'guacamole': 2,
    'salsa': 1, 'tortilla': 2, 'jalapeño': 2, 'chimichanga': 3, 'churro': 3,
  },
  'mediterranean': {
    'mediterran': 3, 'mediterranean': 3, 'greek': 3, 'griechisch': 3,
    'hummus': 3, 'falafel': 3, 'tzatziki': 3, 'feta': 2, 'pita': 2,
    'couscous': 3, 'tabouleh': 3, 'shakshuka': 3,
  },
  'breakfast': {
    'frühstück': 3, 'breakfast': 3, 'brunch': 3, 'pancake': 3, 'pfannkuchen': 3,
    'omelette': 3, 'müsli': 3, 'granola': 3, 'porridge': 3, 'waffel': 3,
    'waffle': 3, 'croissant': 3, 'french toast': 3,
  },
  'snack': {
    'snack': 3, 'dessert': 3, 'nachtisch': 3, 'kuchen': 3, 'cake': 3,
    'torte': 3, 'brownie': 3, 'cookie': 3, 'keks': 3, 'muffin': 3, 'cupcake': 3,
    'cheesecake': 3, 'eis': 2, 'ice cream': 3, 'pudding': 3,
  },
  'healthy': {
    'gesund': 3, 'healthy': 3, 'light': 2, 'salat': 2, 'salad': 2,
    'superfood': 3, 'quinoa': 2, 'bowl': 2, 'smoothie': 3, 'low-cal': 3,
    'kalorienarm': 3,
  },
  'comfort-food': {
    'comfort': 3, 'herzhaft': 2, 'soul food': 3, 'eintopf': 3, 'stew': 2,
    'auflauf': 3, 'gratin': 3, 'mac and cheese': 3, 'käsespätzle': 3,
    'schnitzel': 3, 'braten': 2,
  },
  'seafood': {
    'seafood': 3, 'meeresfrüchte': 3, 'fish': 2, 'fisch': 2, 'shrimp': 3,
    'garnelen': 3, 'salmon': 3, 'lachs': 3, 'tuna': 3, 'thunfisch': 3,
    'lobster': 3, 'hummer': 3, 'muscheln': 3, 'mussels': 3,
  },
  'soup': {
    'soup': 3, 'suppe': 3, 'brühe': 2, 'chowder': 3, 'bisque': 3, 'gazpacho': 3,
    'minestrone': 3,
  },
  'vegetarian': {
    'vegetarisch': 3, 'vegetarian': 3, 'veggie': 2,
  },
  'vegan': {
    'vegan': 3, 'pflanzlich': 2, 'plant-based': 3,
  },
  'gluten-free': {
    'glutenfrei': 3, 'gluten-free': 3, 'gluten free': 3,
  },
};

/// Returns 1-3 best-fitting labels for a recipe.
///
/// The top category needs a score >= 2, the second >= 3 and the third >= 4,
/// so most recipes get one label, some two and very few three. With no match
/// at all, long or ingredient-heavy recipes become 'comfort-food', the rest
/// 'healthy'.
List<String> autoLabelRecipe({
  required String name,
  required String description,
  required List<dynamic> ingredients,
  int? prepTime,
  int? cookTime,
}) {
  final ingredientNames = ingredients
      .map((i) => i is Map ? (i['name'] ?? '').toString() : i.toString())
      .join(' ');
  final searchText = '$name $description $ingredientNames'.toLowerCase();

  final categoryScores = <String, int>{};
  _categoryKeywords.forEach((categoryId, keywords) {
    var score = 0;
    keywords.forEach((keyword, weight) {
      if (searchText.contains(keyword)) score += weight;
    });
    if (score > 0) categoryScores[categoryId] = score;
  });

  final sortedCategories = categoryScores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final labels = <String>[];
  for (var i = 0; i < sortedCategories.length && labels.length < 3; i++) {
    final minScore = i == 0 ? 2 : (i == 1 ? 3 : 4);
    if (sortedCategories[i].value >= minScore) {
      labels.add(sortedCategories[i].key);
    }
  }

  if (labels.isEmpty) {
    final totalTime = (prepTime ?? 0) + (cookTime ?? 0);
    labels.add(
      totalTime >= 45 || ingredients.length >= 10 ? 'comfort-food' : 'healthy',
    );
  }
  return labels;
}
