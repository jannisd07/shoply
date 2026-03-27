import 'package:shoply/data/models/product_category.dart';

/// Service for intelligent product classification
/// Uses a hybrid approach: keyword matching + ML-based classification
class ProductClassifierService {
  static final ProductClassifierService _instance = ProductClassifierService._();
  static ProductClassifierService get instance => _instance;
  
  ProductClassifierService._();

  /// Initialize the classifier (load ML model if available)
  Future<void> initialize() async {
    // TODO: Load TensorFlow Lite model when available
  }

  /// Classify a product name into a category
  /// Uses intelligent keyword matching with confidence scoring
  ProductClassificationResult classify(String productName) {
    final name = _normalizeProductName(productName);
    
    // Try each category and calculate confidence score
    final scores = <ProductCategory, double>{};
    
    for (final category in ProductCategory.values) {
      final score = _calculateCategoryScore(name, category);
      if (score > 0) {
        scores[category] = score;
      }
    }
    
    // Get best match
    if (scores.isEmpty) {
      return ProductClassificationResult(
        category: ProductCategory.staples,
        confidence: 0.3,
        method: ClassificationMethod.fallback,
      );
    }
    
    // Sort by score and get top match
    final sortedEntries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final bestMatch = sortedEntries.first;
    
    return ProductClassificationResult(
      category: bestMatch.key,
      confidence: bestMatch.value,
      method: ClassificationMethod.keywordMatching,
      alternativeCategories: sortedEntries.skip(1).take(2).map((e) => e.key).toList(),
    );
  }

  /// Normalize product name for better matching
  /// Handles typos, special characters, and common variations
  String _normalizeProductName(String name) {
    return name
        .toLowerCase()
        .trim()
        // Remove special characters
        .replaceAll(RegExp(r'[^\w\s]'), '')
        // Normalize German umlauts
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss')
        // Common typos and variations
        .replaceAll('gauda', 'gouda')  // Gouda typo
        .replaceAll('jogurt', 'joghurt')  // Joghurt typo
        .replaceAll('yogurt', 'joghurt')  // English variant
        .replaceAll('yoghurt', 'joghurt')  // English variant
        .replaceAll('kaese', 'kaese')  // Käse without umlaut
        .replaceAll('broetchen', 'broetchen')  // Brötchen without umlaut
        // Remove extra spaces
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Calculate confidence score for a category based on keyword matching
  double _calculateCategoryScore(String productName, ProductCategory category) {
    final keywords = _getCategoryKeywords(category);

    double score = 0.0;
    int exactMatches = 0;
    int partialMatches = 0;

    for (final keyword in keywords) {
      // Normalize keyword for comparison
      final normalizedKeyword = _normalizeProductName(keyword);
      
      if (productName.contains(normalizedKeyword)) {
        // Exact match gets highest score
        if (productName == normalizedKeyword) {
          score += 2.0;  // Increased from 1.0
          exactMatches++;
        }
        // Starts with keyword (prefix match)
        else if (productName.startsWith(normalizedKeyword)) {
          score += 1.5;  // Increased from 0.9
          partialMatches++;
        }
        // Ends with keyword (suffix match)
        else if (productName.endsWith(normalizedKeyword)) {
          score += 1.2;  // Increased from 0.8
          partialMatches++;
        }
        // Contains keyword (substring match)
        else {
          // Longer keywords get higher weight
          final weight = (normalizedKeyword.length / productName.length).clamp(0.4, 0.9);
          score += weight;
          partialMatches++;
        }
      }
    }

    // Boost score if we have exact matches
    if (exactMatches > 0) {
      score *= (1.0 + exactMatches * 0.3);  // Increased boost
    }

    // Boost score if we have good partial matches
    if (partialMatches > 0) {
      score *= (1.0 + partialMatches * 0.15);  // Increased boost
    }

    // Normalize score (0.0 to 1.0)
    return score.clamp(0.0, 1.0);
  }

  /// Get keywords for each category
  List<String> _getCategoryKeywords(ProductCategory category) {
    switch (category) {
      case ProductCategory.fruitsVegetables:
        return ['apfel', 'äpfel', 'banane', 'orange', 'birne', 'traube', 'erdbeere', 'himbeere',
          'blaubeere', 'kirsche', 'pfirsich', 'pflaume', 'melone', 'ananas', 'mango',
          'kiwi', 'zitrone', 'limette', 'avocado', 'tomate', 'gurke', 'salat', 'kopfsalat',
          'karotte', 'möhre', 'kartoffel', 'zwiebel', 'knoblauch', 'paprika', 'zucchini',
          'aubergine', 'brokkoli', 'blumenkohl', 'kohl', 'spinat', 'pilz', 'champignon',
          'lauch', 'sellerie', 'radieschen', 'rettich', 'kürbis', 'mais', 'erbse',
          'bohne', 'obst', 'gemüse', 'kräuter', 'petersilie', 'basilikum'];

      case ProductCategory.meatFish:
        return ['fleisch', 'hähnchen', 'huhn', 'rind', 'schwein', 'lamm', 'pute', 'ente',
          'wurst', 'schinken', 'salami', 'bacon', 'speck', 'hack', 'hackfleisch',
          'steak', 'schnitzel', 'fisch', 'lachs', 'thunfisch', 'forelle', 'kabeljau',
          'garnele', 'shrimp', 'muschel', 'tofu', 'tempeh', 'seitan', 'veggie',
          'vegetarisch', 'vegan', 'fleischersatz', 'braten', 'brust', 'filet',
          'leber', 'wienerschnitzel', 'fleischwurst', 'mortadella', 'schwarzwälder',
          'bregenwurst', 'leberwurst', 'blutwurst', 'mett', 'gehacktes'];

      case ProductCategory.bakery:
        return ['brot', 'brötchen', 'toast', 'baguette', 'croissant', 'kuchen', 'torte',
          'gebäck', 'brezel', 'laugenbrezel', 'muffin', 'donut', 'berliner',
          'hörnchen', 'teilchen', 'plunder', 'strudel', 'zwieback'];
          
      case ProductCategory.flowersPlants:
        return ['blume', 'blumen', 'pflanze', 'pflanzen', 'rose', 'tulpe', 'orchidee',
          'kaktus', 'topfpflanze', 'schnittblumen', 'strauß', 'blumenstrauß',
          'zimmerpflanze', 'gartenpflanze', 'samen', 'blumenerde', 'dünger'];
          
      case ProductCategory.dairy:
        return ['milch', 'joghurt', 'quark', 'sahne', 'butter', 'margarine', 'käse', 'kaese',
          'frischkäse', 'frischkaese', 'mozzarella', 'gouda', 'gauda', 'emmentaler', 
          'parmesan', 'feta', 'cheddar', 'camembert', 'brie', 'edamer', 'tilsiter',
          'bergkäse', 'bergkaese', 'schnittkäse', 'schnittkaese', 'hartkäse', 'hartkaese',
          'ei', 'eier', 'pudding', 'dessert', 'aufstrich', 'hummus', 'frischmilch',
          'schmand', 'creme fraiche', 'mascarpone', 'ricotta', 'hüttenkäse', 'huettenkaese'];
          
      case ProductCategory.frozen:
        return ['tiefkühl', 'gefrier', 'frozen', 'tk', 'eis', 'eiscreme', 'pizza',
          'pommes', 'fischstäbchen', 'gemüsemix', 'tiefgefroren'];
          
      case ProductCategory.staples:
        return ['mehl', 'zucker', 'salz', 'reis', 'nudel', 'pasta', 'spaghetti',
          'penne', 'fusilli', 'getreide', 'quinoa', 'couscous', 'bulgur',
          'hirse', 'grieß', 'stärke', 'backpulver', 'hefe', 'natron'];
          
      case ProductCategory.canned:
        return ['dose', 'konserve', 'bohnen', 'kichererbsen', 'linsen', 'erbsen',
          'mais', 'tomatenmark', 'passata', 'tomatensauce', 'pesto',
          'nuss', 'nüsse', 'mandel', 'cashew', 'erdnuss', 'rosine',
          'trockenobst', 'datteln', 'feige'];
          
      case ProductCategory.spices:
        return ['gewürz', 'pfeffer', 'paprika', 'curry', 'kurkuma', 'zimt', 'muskat',
          'oregano', 'thymian', 'rosmarin', 'koriander', 'kreuzkümmel', 'chili',
          'cayenne', 'vanille', 'kardamom', 'ingwer', 'nelke', 'lorbeer',
          'safran', 'anis', 'fenchel', 'kümmel', 'majoran', 'salbei'];
          
      case ProductCategory.condiments:
        return ['essig', 'öl', 'olivenöl', 'sonnenblumenöl', 'rapsöl', 'senf',
          'ketchup', 'mayonnaise', 'soße', 'sauce', 'brühe', 'bouillon',
          'maggi', 'würze', 'dressing', 'marinade', 'sojasauce', 'tabasco',
          'worcester', 'balsamico', 'teriyaki', 'sriracha'];
          
      case ProductCategory.breakfast:
        return ['müsli', 'haferflocken', 'cornflakes', 'frühstück', 'cerealien',
          'marmelade', 'honig', 'nutella', 'aufstrich', 'konfitüre', 'gelee',
          'müsliriegel', 'granola', 'porridge', 'frühstücksflocken'];
          
      case ProductCategory.sweets:
        return ['schokolade', 'schoko', 'bonbon', 'gummibärchen', 'keks', 'cookie',
          'riegel', 'nachtisch', 'süß', 'candy', 'lutscher', 'praline',
          'trüffel', 'karamell', 'toffee', 'fudge', 'marshmallow', 'lakritze',
          'weingummi', 'fruchtgummi', 'kaugummi', 'drops'];
          
      case ProductCategory.snacks:
        return ['chips', 'snack', 'knabber', 'salzstange', 'cracker', 'popcorn',
          'flips', 'erdnüsse', 'nüsse', 'studentenfutter', 'trail mix',
          'brezel', 'nachos', 'tortilla', 'reiswaffel', 'maiswaffel'];
          
      case ProductCategory.beverages:
        return ['wasser', 'saft', 'limo', 'cola', 'fanta', 'sprite', 'bier', 'wein',
          'sekt', 'champagner', 'kaffee', 'tee', 'kakao', 'milch', 'smoothie',
          'energy', 'drink', 'getränk', 'mineralwasser', 'sprudel'];
          
      case ProductCategory.household:
        return ['haushalt', 'geschirr', 'besteck', 'teller', 'tasse', 'glas',
          'schüssel', 'topf', 'pfanne', 'messer', 'gabel', 'löffel',
          'küchenutensil', 'schneide', 'reibe', 'sieb', 'schale', 'dose',
          'box', 'behälter', 'aufbewahrung', 'frischhalte', 'alufolie'];
          
      case ProductCategory.cleaning:
        return ['putzen', 'reiniger', 'spülmittel', 'waschmittel', 'weichspüler',
          'allzweckreiniger', 'glasreiniger', 'badreiniger', 'wc-reiniger',
          'entkalker', 'scheuermilch', 'bleiche', 'fleckentferner',
          'schwamm', 'bürste', 'lappen', 'mikrofaser', 'staubwedel'];
          
      case ProductCategory.paper:
        return ['toilettenpapier', 'klopapier', 'küchenpapier', 'serviette',
          'taschentuch', 'tempo', 'zewa', 'papier', 'küchenrolle',
          'feuchttuch', 'kosmetiktuch', 'pappteller', 'pappbecher'];
          
      case ProductCategory.drugstore:
        return ['drogerie', 'pflaster', 'verband', 'schmerzmittel', 'aspirin',
          'ibuprofen', 'paracetamol', 'hustensaft', 'nasenspray',
          'vitamine', 'nahrungsergänzung', 'magnesium', 'vitamin',
          'erkältung', 'medikament', 'salbe', 'creme'];
          
      case ProductCategory.bodycare:
        return ['seife', 'shampoo', 'duschgel', 'badezusatz', 'schaumbad',
          'bodylotion', 'körperlotion', 'handcreme', 'fußcreme',
          'peeling', 'körperpflege', 'pflege', 'waschgel', 'reinigung'];
          
      case ProductCategory.cosmetics:
        return ['kosmetik', 'makeup', 'make-up', 'schminke', 'lippenstift',
          'mascara', 'wimperntusche', 'lidschatten', 'rouge', 'puder',
          'foundation', 'concealer', 'nagellack', 'parfüm', 'parfum',
          'eau de toilette', 'duftwasser', 'gesichtscreme', 'tagescreme'];
          
      case ProductCategory.hygiene:
        return ['zahnpasta', 'zahnbürste', 'zahnseide', 'mundspülung',
          'mundwasser', 'deo', 'deodorant', 'rasier', 'rasierer',
          'rasierschaum', 'rasiergel', 'aftershave', 'damenhygiene',
          'binde', 'tampon', 'slipeinlage', 'hygiene', 'intimpflege'];
          
      case ProductCategory.baby:
        return ['baby', 'windel', 'pampers', 'feuchttücher', 'babytücher',
          'babynahrung', 'babybrei', 'babymilch', 'fläschchen',
          'schnuller', 'nuckel', 'beißring', 'babypflege', 'wundcreme',
          'babyshampoo', 'babybad', 'babypuder'];
          
      case ProductCategory.petSupplies:
        return ['hund', 'katze', 'tier', 'futter', 'hundefutter', 'katzenfutter',
          'leckerli', 'streu', 'katzenstreu', 'napf', 'leine', 'spielzeug',
          'vogel', 'fisch', 'aquarium'];
          
      case ProductCategory.nonFood:
        return ['non-food', 'nonfood', 'batterie', 'glühbirne', 'kerze',
          'feuerzeug', 'streichholz', 'zeitschrift', 'zeitung', 'buch',
          'karte', 'geschenk', 'deko', 'dekoration'];
          
      case ProductCategory.appliances:
        return ['mixer', 'toaster', 'wasserkocher', 'kaffeemaschine',
          'staubsauger', 'bügeleisen', 'föhn', 'haartrockner',
          'elektro', 'gerät', 'küchengerät', 'haushaltsgerät'];
          
      case ProductCategory.stationery:
        return ['stift', 'kugelschreiber', 'bleistift', 'füller', 'marker',
          'textmarker', 'radiergummi', 'spitzer', 'lineal', 'schere',
          'kleber', 'klebestift', 'tesafilm', 'heft', 'block', 'notiz',
          'ordner', 'mappe', 'schreibwaren', 'büro'];
          
      case ProductCategory.textiles:
        return ['handtuch', 'geschirrtuch', 'waschlappen', 'bettwäsche',
          'bettlaken', 'kissenbezug', 'decke', 'kissen', 'textil',
          'stoff', 'tuch', 'serviette', 'tischdecke'];
          
      case ProductCategory.toys:
        return ['spielzeug', 'spiel', 'puzzle', 'puppe', 'teddy', 'kuscheltier',
          'lego', 'baustein', 'ball', 'auto', 'spielauto', 'actionfigur',
          'brettspiel', 'kartenspiel', 'malbuch', 'buntstift'];
          
      case ProductCategory.seasonal:
        return ['weihnachten', 'ostern', 'halloween', 'silvester', 'advent',
          'nikolaus', 'lebkuchen', 'spekulatius', 'christstollen',
          'osterei', 'schokoladenhase', 'adventskalender', 'lametta',
          'christbaumkugel', 'lichterkette', 'saison', 'saisonal'];
          
      case ProductCategory.householdDrugstore:
        return ['reiniger', 'putzmittel', 'spülmittel', 'waschmittel', 'weichspüler',
          'allzweckreiniger', 'glasreiniger', 'badreiniger', 'wc-reiniger',
          'entkalker', 'scheuermilch', 'bleiche', 'fleckentferner',
          'schwamm', 'bürste', 'lappen', 'mikrofaser', 'staubwedel',
          'toilettenpapier', 'klopapier', 'küchenpapier', 'serviette',
          'taschentuch', 'tempo', 'zewa', 'papier', 'küchenrolle',
          'feuchttuch', 'kosmetiktuch', 'pappteller', 'pappbecher',
          'seife', 'shampoo', 'duschgel', 'badezusatz', 'schaumbad',
          'bodylotion', 'körperlotion', 'handcreme', 'fußcreme',
          'zahnpasta', 'zahnbürste', 'deo', 'deodorant',
          'drogerie', 'pflaster', 'verband', 'vitamine'];
          
      case ProductCategory.checkout:
        return ['kaugummi', 'kasse', 'kassenbereich', 'zeitschrift',
          'lotterie', 'rubbellos', 'zigarette', 'tabak', 'feuerzeug',
          'pfandbon', 'gutschein', 'geschenkkarte', 'tüte', 'tragetasche'];
    }
  }

  /// Batch classify multiple products
  List<ProductClassificationResult> classifyBatch(List<String> productNames) {
    return productNames.map((name) => classify(name)).toList();
  }
}

/// Result of product classification
class ProductClassificationResult {
  final ProductCategory category;
  final double confidence; // 0.0 to 1.0
  final ClassificationMethod method;
  final List<ProductCategory> alternativeCategories;

  ProductClassificationResult({
    required this.category,
    required this.confidence,
    required this.method,
    this.alternativeCategories = const [],
  });

  bool get isHighConfidence => confidence >= 0.7;
  bool get isMediumConfidence => confidence >= 0.4 && confidence < 0.7;
  bool get isLowConfidence => confidence < 0.4;
}

enum ClassificationMethod {
  keywordMatching,
  machineLearning,
  fallback,
}
