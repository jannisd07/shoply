/// Ernährungspräferenzen und Allergien
enum DietType {
  none('Keine Einschränkungen', '🍽️'),
  vegan('Vegan', '🌱'),
  vegetarian('Vegetarisch', '🥗'),
  pescetarian('Pescetarisch', '🐟'),
  flexitarian('Flexitarisch', '🌿'),
  keto('Ketogen', '🥑'),
  paleo('Paleo', '🥩'),
  lowCarb('Low Carb', '🥬'),
  halal('Halal', '☪️'),
  kosher('Koscher', '✡️');

  final String label;
  final String emoji;
  const DietType(this.label, this.emoji);
}

/// Alle gängigen Lebensmittelallergien und -intoleranzen
enum AllergyType {
  // Hauptallergene (EU-14)
  gluten('Gluten', '🌾', ['Weizen', 'Roggen', 'Gerste', 'Hafer', 'Dinkel', 'Kamut']),
  crustaceans('Krebstiere', '🦞', ['Garnelen', 'Krabben', 'Hummer', 'Krebse']),
  eggs('Eier', '🥚', ['Ei', 'Eier', 'Eigelb', 'Eiweiß']),
  fish('Fisch', '🐟', ['Fisch', 'Thunfisch', 'Lachs', 'Kabeljau']),
  peanuts('Erdnüsse', '🥜', ['Erdnuss', 'Erdnüsse', 'Erdnussbutter']),
  soy('Soja', '🫘', ['Soja', 'Tofu', 'Sojamilch', 'Sojasoße', 'Edamame']),
  milk('Milch/Laktose', '🥛', ['Milch', 'Sahne', 'Butter', 'Käse', 'Joghurt', 'Quark', 'Crème fraîche']),
  nuts('Nüsse', '🌰', ['Mandeln', 'Haselnüsse', 'Walnüsse', 'Cashews', 'Pistazien', 'Macadamia', 'Pekannüsse']),
  celery('Sellerie', '🥬', ['Sellerie', 'Staudensellerie', 'Knollensellerie']),
  mustard('Senf', '🌻', ['Senf', 'Senfkörner', 'Senfsaat']),
  sesame('Sesam', '🫑', ['Sesam', 'Sesamöl', 'Tahini', 'Gomasio']),
  sulfites('Sulfite', '🧪', ['Sulfite', 'Schwefeldioxid', 'Trockenfrüchte']),
  lupin('Lupinen', '🌺', ['Lupinen', 'Lupinenmehl']),
  molluscs('Weichtiere', '🦑', ['Muscheln', 'Schnecken', 'Tintenfisch', 'Austern']),
  
  // Zusätzliche häufige Intoleranzen
  lactose('Laktose', '🥛', ['Milch', 'Sahne', 'Joghurt', 'Quark']),
  fructose('Fruktose', '🍎', ['Honig', 'Agavendicksaft', 'Fruchtzucker']),
  histamine('Histamin', '🧀', ['Tomaten', 'Käse', 'Wein', 'Schokolade', 'Salami']),
  
  // Weitere
  nightshades('Nachtschattengewächse', '🍅', ['Tomaten', 'Paprika', 'Auberginen', 'Kartoffeln', 'Chili']),
  corn('Mais', '🌽', ['Mais', 'Maismehl', 'Maisstärke', 'Polenta']),
  yeast('Hefe', '🍞', ['Hefe', 'Backhefe']);

  final String label;
  final String emoji;
  final List<String> keywords;
  const AllergyType(this.label, this.emoji, this.keywords);

  /// Prüft ob eine Zutat diese Allergie enthält
  bool containsAllergen(String ingredient) {
    final lowerIngredient = ingredient.toLowerCase();
    return keywords.any((keyword) => 
      lowerIngredient.contains(keyword.toLowerCase())
    );
  }
}

/// Ersatzprodukt-Mapping
class IngredientSubstitution {
  final String original;
  final String substitute;
  final String reason;
  final List<AllergyType> avoidsAllergies;
  final List<DietType> suitableFor;

  const IngredientSubstitution({
    required this.original,
    required this.substitute,
    required this.reason,
    this.avoidsAllergies = const [],
    this.suitableFor = const [],
  });
}

/// Vordefinierte Ersatzprodukte
class SubstitutionDatabase {
  static const Map<String, List<IngredientSubstitution>> substitutions = {
    // Milchprodukte
    'Milch': [
      IngredientSubstitution(
        original: 'Milch',
        substitute: 'Hafermilch',
        reason: 'Pflanzliche Alternative',
        avoidsAllergies: [AllergyType.milk, AllergyType.lactose],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
      IngredientSubstitution(
        original: 'Milch',
        substitute: 'Mandelmilch',
        reason: 'Pflanzliche Alternative',
        avoidsAllergies: [AllergyType.milk, AllergyType.lactose],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
      IngredientSubstitution(
        original: 'Milch',
        substitute: 'Sojamilch',
        reason: 'Pflanzliche Alternative',
        avoidsAllergies: [AllergyType.milk, AllergyType.lactose],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
    ],
    'Sahne': [
      IngredientSubstitution(
        original: 'Sahne',
        substitute: 'Hafersahne',
        reason: 'Pflanzliche Alternative',
        avoidsAllergies: [AllergyType.milk, AllergyType.lactose],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
      IngredientSubstitution(
        original: 'Sahne',
        substitute: 'Soja-Cuisine',
        reason: 'Pflanzliche Alternative',
        avoidsAllergies: [AllergyType.milk, AllergyType.lactose],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
    ],
    'Butter': [
      IngredientSubstitution(
        original: 'Butter',
        substitute: 'Vegane Margarine',
        reason: 'Pflanzliche Alternative',
        avoidsAllergies: [AllergyType.milk, AllergyType.lactose],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
      IngredientSubstitution(
        original: 'Butter',
        substitute: 'Kokosöl',
        reason: 'Pflanzliches Fett',
        avoidsAllergies: [AllergyType.milk, AllergyType.lactose],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
    ],
    'Käse': [
      IngredientSubstitution(
        original: 'Käse',
        substitute: 'Veganer Käse',
        reason: 'Pflanzliche Alternative',
        avoidsAllergies: [AllergyType.milk, AllergyType.lactose],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
      IngredientSubstitution(
        original: 'Käse',
        substitute: 'Hefeflocken',
        reason: 'Käsiger Geschmack',
        avoidsAllergies: [AllergyType.milk, AllergyType.lactose],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
    ],
    'Parmesan': [
      IngredientSubstitution(
        original: 'Parmesan',
        substitute: 'Veganer Parmesan',
        reason: 'Pflanzliche Alternative',
        avoidsAllergies: [AllergyType.milk, AllergyType.lactose],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
      IngredientSubstitution(
        original: 'Parmesan',
        substitute: 'Hefeflocken mit Mandeln',
        reason: 'Käsiger Geschmack',
        avoidsAllergies: [AllergyType.milk, AllergyType.lactose],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
    ],
    'Joghurt': [
      IngredientSubstitution(
        original: 'Joghurt',
        substitute: 'Sojajoghurt',
        reason: 'Pflanzliche Alternative',
        avoidsAllergies: [AllergyType.milk, AllergyType.lactose],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
      IngredientSubstitution(
        original: 'Joghurt',
        substitute: 'Kokosjoghurt',
        reason: 'Pflanzliche Alternative',
        avoidsAllergies: [AllergyType.milk, AllergyType.lactose],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
    ],

    // Eier
    'Ei': [
      IngredientSubstitution(
        original: 'Ei',
        substitute: 'Leinsamen-Ei (1 EL Leinsamen + 3 EL Wasser)',
        reason: 'Bindemittel',
        avoidsAllergies: [AllergyType.eggs],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
      IngredientSubstitution(
        original: 'Ei',
        substitute: 'Chia-Ei (1 EL Chiasamen + 3 EL Wasser)',
        reason: 'Bindemittel',
        avoidsAllergies: [AllergyType.eggs],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
      IngredientSubstitution(
        original: 'Ei',
        substitute: 'Apfelmus (60g)',
        reason: 'Bindemittel für Süßspeisen',
        avoidsAllergies: [AllergyType.eggs],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
    ],
    'Eier': [
      IngredientSubstitution(
        original: 'Eier',
        substitute: 'Leinsamen-Eier',
        reason: 'Bindemittel',
        avoidsAllergies: [AllergyType.eggs],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
    ],

    // Fleisch
    'Hähnchen': [
      IngredientSubstitution(
        original: 'Hähnchen',
        substitute: 'Tofu',
        reason: 'Pflanzliches Protein',
        avoidsAllergies: [],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
      IngredientSubstitution(
        original: 'Hähnchen',
        substitute: 'Tempeh',
        reason: 'Pflanzliches Protein',
        avoidsAllergies: [],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
      IngredientSubstitution(
        original: 'Hähnchen',
        substitute: 'Seitan',
        reason: 'Fleischähnliche Textur',
        avoidsAllergies: [],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
    ],
    'Hähnchenbrust': [
      IngredientSubstitution(
        original: 'Hähnchenbrust',
        substitute: 'Räuchertofu',
        reason: 'Pflanzliches Protein',
        avoidsAllergies: [],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
    ],
    'Rinderhackfleisch': [
      IngredientSubstitution(
        original: 'Rinderhackfleisch',
        substitute: 'Veganes Hackfleisch',
        reason: 'Pflanzliche Alternative',
        avoidsAllergies: [],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
      IngredientSubstitution(
        original: 'Rinderhackfleisch',
        substitute: 'Linsen',
        reason: 'Protein- und eisenreich',
        avoidsAllergies: [],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
    ],
    'Hackfleisch': [
      IngredientSubstitution(
        original: 'Hackfleisch',
        substitute: 'Veganes Hack',
        reason: 'Pflanzliche Alternative',
        avoidsAllergies: [],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
    ],
    'Rindfleisch': [
      IngredientSubstitution(
        original: 'Rindfleisch',
        substitute: 'Jackfruit (gezupft)',
        reason: 'Fleischähnliche Textur',
        avoidsAllergies: [],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
      IngredientSubstitution(
        original: 'Rindfleisch',
        substitute: 'Seitan',
        reason: 'Fleischähnliche Textur',
        avoidsAllergies: [],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
    ],
    'Schweinefleisch': [
      IngredientSubstitution(
        original: 'Schweinefleisch',
        substitute: 'Räuchertofu',
        reason: 'Pflanzliches Protein',
        avoidsAllergies: [],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
    ],
    'Speck': [
      IngredientSubstitution(
        original: 'Speck',
        substitute: 'Veganer Speck',
        reason: 'Pflanzliche Alternative',
        avoidsAllergies: [],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
      IngredientSubstitution(
        original: 'Speck',
        substitute: 'Räuchertofu-Streifen',
        reason: 'Rauchiges Aroma',
        avoidsAllergies: [],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
    ],
    'Pancetta': [
      IngredientSubstitution(
        original: 'Pancetta',
        substitute: 'Räuchertofu',
        reason: 'Rauchiges Aroma',
        avoidsAllergies: [],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
    ],

    // Fisch
    'Lachs': [
      IngredientSubstitution(
        original: 'Lachs',
        substitute: 'Geräucherter Karotten-Lachs',
        reason: 'Pflanzliche Alternative',
        avoidsAllergies: [AllergyType.fish],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
    ],
    'Thunfisch': [
      IngredientSubstitution(
        original: 'Thunfisch',
        substitute: 'Kichererbsen (zerdrückt)',
        reason: 'Ähnliche Textur',
        avoidsAllergies: [AllergyType.fish],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
    ],
    'Garnelen': [
      IngredientSubstitution(
        original: 'Garnelen',
        substitute: 'Konjaknudeln (geformt)',
        reason: 'Ähnliche Textur',
        avoidsAllergies: [AllergyType.crustaceans],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
    ],

    // Glutenhaltige Produkte
    'Weizenmehl': [
      IngredientSubstitution(
        original: 'Weizenmehl',
        substitute: 'Reismehl',
        reason: 'Glutenfrei',
        avoidsAllergies: [AllergyType.gluten],
        suitableFor: [],
      ),
      IngredientSubstitution(
        original: 'Weizenmehl',
        substitute: 'Mandelmehl',
        reason: 'Glutenfrei, Low Carb',
        avoidsAllergies: [AllergyType.gluten],
        suitableFor: [DietType.keto, DietType.paleo],
      ),
      IngredientSubstitution(
        original: 'Weizenmehl',
        substitute: 'Buchweizenmehl',
        reason: 'Glutenfrei',
        avoidsAllergies: [AllergyType.gluten],
        suitableFor: [],
      ),
    ],
    'Mehl': [
      IngredientSubstitution(
        original: 'Mehl',
        substitute: 'Glutenfreies Mehl',
        reason: 'Glutenfrei',
        avoidsAllergies: [AllergyType.gluten],
        suitableFor: [],
      ),
    ],
    'Spaghetti': [
      IngredientSubstitution(
        original: 'Spaghetti',
        substitute: 'Glutenfreie Pasta',
        reason: 'Glutenfrei',
        avoidsAllergies: [AllergyType.gluten],
        suitableFor: [],
      ),
      IngredientSubstitution(
        original: 'Spaghetti',
        substitute: 'Zucchini-Nudeln',
        reason: 'Low Carb, glutenfrei',
        avoidsAllergies: [AllergyType.gluten],
        suitableFor: [DietType.keto, DietType.paleo, DietType.lowCarb],
      ),
    ],
    'Pasta': [
      IngredientSubstitution(
        original: 'Pasta',
        substitute: 'Glutenfreie Pasta',
        reason: 'Glutenfrei',
        avoidsAllergies: [AllergyType.gluten],
        suitableFor: [],
      ),
    ],
    'Brot': [
      IngredientSubstitution(
        original: 'Brot',
        substitute: 'Glutenfreies Brot',
        reason: 'Glutenfrei',
        avoidsAllergies: [AllergyType.gluten],
        suitableFor: [],
      ),
    ],
    'Semmelbrösel': [
      IngredientSubstitution(
        original: 'Semmelbrösel',
        substitute: 'Glutenfreie Semmelbrösel',
        reason: 'Glutenfrei',
        avoidsAllergies: [AllergyType.gluten],
        suitableFor: [],
      ),
      IngredientSubstitution(
        original: 'Semmelbrösel',
        substitute: 'Gemahlene Mandeln',
        reason: 'Glutenfrei, Low Carb',
        avoidsAllergies: [AllergyType.gluten],
        suitableFor: [DietType.keto, DietType.paleo],
      ),
    ],

    // Sojaprodukte
    'Sojasoße': [
      IngredientSubstitution(
        original: 'Sojasoße',
        substitute: 'Tamari (glutenfrei)',
        reason: 'Glutenfrei',
        avoidsAllergies: [AllergyType.gluten],
        suitableFor: [],
      ),
      IngredientSubstitution(
        original: 'Sojasoße',
        substitute: 'Kokos-Aminos',
        reason: 'Soja- und glutenfrei',
        avoidsAllergies: [AllergyType.soy, AllergyType.gluten],
        suitableFor: [],
      ),
    ],

    // Nüsse
    'Mandeln': [
      IngredientSubstitution(
        original: 'Mandeln',
        substitute: 'Sonnenblumenkerne',
        reason: 'Nussfrei',
        avoidsAllergies: [AllergyType.nuts],
        suitableFor: [],
      ),
    ],
    'Walnüsse': [
      IngredientSubstitution(
        original: 'Walnüsse',
        substitute: 'Kürbiskerne',
        reason: 'Nussfrei',
        avoidsAllergies: [AllergyType.nuts],
        suitableFor: [],
      ),
    ],
    'Erdnussbutter': [
      IngredientSubstitution(
        original: 'Erdnussbutter',
        substitute: 'Sonnenblumenkernmus',
        reason: 'Nuss- und erdnussfrei',
        avoidsAllergies: [AllergyType.peanuts, AllergyType.nuts],
        suitableFor: [],
      ),
    ],

    // Honig
    'Honig': [
      IngredientSubstitution(
        original: 'Honig',
        substitute: 'Ahornsirup',
        reason: 'Vegan',
        avoidsAllergies: [],
        suitableFor: [DietType.vegan],
      ),
      IngredientSubstitution(
        original: 'Honig',
        substitute: 'Agavendicksaft',
        reason: 'Vegan',
        avoidsAllergies: [],
        suitableFor: [DietType.vegan],
      ),
    ],

    // Gelatine
    'Gelatine': [
      IngredientSubstitution(
        original: 'Gelatine',
        substitute: 'Agar-Agar',
        reason: 'Pflanzliches Geliermittel',
        avoidsAllergies: [],
        suitableFor: [DietType.vegan, DietType.vegetarian],
      ),
    ],
  };

  /// Findet Ersatzprodukte für eine Zutat basierend auf Allergien und Diät
  static List<IngredientSubstitution> findSubstitutes({
    required String ingredient,
    List<AllergyType> allergies = const [],
    List<DietType> diets = const [],
  }) {
    final results = <IngredientSubstitution>[];
    
    // Exakte Übereinstimmung
    if (substitutions.containsKey(ingredient)) {
      results.addAll(substitutions[ingredient]!);
    }
    
    // Teilweise Übereinstimmung (z.B. "Milch" in "Vollmilch")
    substitutions.forEach((key, subs) {
      if (ingredient.toLowerCase().contains(key.toLowerCase()) ||
          key.toLowerCase().contains(ingredient.toLowerCase())) {
        results.addAll(subs);
      }
    });

    // Filtern nach Allergien und Diät
    return results.where((sub) {
      // Muss mindestens eine Allergie vermeiden
      final avoidsNeededAllergies = allergies.isEmpty || 
        sub.avoidsAllergies.any((a) => allergies.contains(a));
      
      // Muss zur Diät passen
      final suitableForDiet = diets.isEmpty || 
        sub.suitableFor.any((d) => diets.contains(d));
      
      return avoidsNeededAllergies || suitableForDiet;
    }).toList();
  }
}
