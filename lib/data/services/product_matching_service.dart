import 'package:shoply/data/models/extracted_deal_model.dart';
import 'package:shoply/data/services/deals_database_service.dart';
import 'package:string_similarity/string_similarity.dart';

/// Service für Produkt-Matching zwischen Einkaufslisten und Angeboten
class ProductMatchingService {
  /// Mindest-Ähnlichkeit für Match (0.0 - 1.0)
  static const double _minSimilarityThreshold = 0.6;

  /// Findet passende Angebote für ein Produkt
  static Future<List<ExtractedDeal>> findDealsForProduct(
    String productName, {
    double minSimilarity = _minSimilarityThreshold,
  }) async {
    // Alle aktiven Angebote laden
    final allDeals = await DealsDatabaseService.getActiveDeals();

    // Ähnlichkeit berechnen
    final scoredDeals = <({ExtractedDeal deal, double similarity})>[];

    for (final deal in allDeals) {
      final similarity = _calculateSimilarity(productName, deal.productName);

      if (similarity >= minSimilarity) {
        scoredDeals.add((deal: deal, similarity: similarity));
      }
    }

    // Nach Ähnlichkeit sortieren (höchste zuerst)
    scoredDeals.sort((a, b) => b.similarity.compareTo(a.similarity));

    return scoredDeals.map((item) => item.deal).toList();
  }

  /// Berechnet Ähnlichkeit zwischen zwei Produktnamen
  static double _calculateSimilarity(String a, String b) {
    // Text normalisieren
    final normalizedA = _normalizeProductName(a);
    final normalizedB = _normalizeProductName(b);

    // Levenshtein-basierte Ähnlichkeit
    final similarity = normalizedA.similarityTo(normalizedB);

    // Bonus für exakte Keyword-Treffer
    final bonusScore = _calculateKeywordMatchBonus(normalizedA, normalizedB);

    // Kombiniere beide Scores
    return (similarity * 0.7 + bonusScore * 0.3).clamp(0.0, 1.0);
  }

  /// Normalisiert Produktnamen für besseren Vergleich
  static String _normalizeProductName(String name) {
    return name
        .toLowerCase()
        .trim()
        // Entferne Sonderzeichen
        .replaceAll(RegExp(r'[^\w\s]'), '')
        // Mehrfache Leerzeichen zu einem
        .replaceAll(RegExp(r'\s+'), ' ')
        // Entferne Mengenangaben
        .replaceAll(RegExp(r'\d+\s*(?:kg|g|l|ml|stk|stück)', caseSensitive: false), '')
        .trim();
  }

  /// Berechnet Bonus für Keyword-Übereinstimmungen
  static double _calculateKeywordMatchBonus(String a, String b) {
    final wordsA = a.split(' ').where((w) => w.length > 2).toSet();
    final wordsB = b.split(' ').where((w) => w.length > 2).toSet();

    if (wordsA.isEmpty || wordsB.isEmpty) return 0.0;

    final matchingWords = wordsA.intersection(wordsB).length;
    final totalWords = wordsA.length;

    return matchingWords / totalWords;
  }

  /// Findet beste Angebot für ein Produkt
  static Future<ExtractedDeal?> findBestDealForProduct(
    String productName, {
    String? preferredSupermarket,
  }) async {
    final deals = await findDealsForProduct(productName);

    if (deals.isEmpty) return null;

    // Wenn Supermarkt bevorzugt, filtere danach
    if (preferredSupermarket != null) {
      final dealsFromPreferred = deals
          .where((deal) => deal.supermarket.toLowerCase() == preferredSupermarket.toLowerCase())
          .toList();

      if (dealsFromPreferred.isNotEmpty) {
        return dealsFromPreferred.first; // Höchster Rabatt
      }
    }

    return deals.first; // Bester Deal insgesamt
  }

  /// Batch-Matching für ganze Einkaufsliste
  static Future<Map<String, List<ExtractedDeal>>> findDealsForShoppingList(
    List<String> shoppingList,
  ) async {
    final results = <String, List<ExtractedDeal>>{};

    for (final item in shoppingList) {
      final deals = await findDealsForProduct(item);
      if (deals.isNotEmpty) {
        results[item] = deals;
      }
    }

    return results;
  }

  /// Findet beste Deals für jedes Produkt in einer Liste
  static Future<Map<String, ExtractedDeal>> findBestDealsForShoppingList(
    List<String> shoppingList, {
    String? preferredSupermarket,
  }) async {
    final results = <String, ExtractedDeal>{};

    for (final item in shoppingList) {
      final deal = await findBestDealForProduct(
        item,
        preferredSupermarket: preferredSupermarket,
      );

      if (deal != null) {
        results[item] = deal;
      }
    }

    return results;
  }

  /// Berechnet Gesamtersparnis für Einkaufsliste
  static double calculateTotalSavings(Map<String, ExtractedDeal> dealsMap) {
    return dealsMap.values.fold<double>(
      0.0,
      (sum, deal) => sum + deal.savings,
    );
  }

  /// Findet Angebote nach Kategorie für häufig gekaufte Produkte
  static Future<List<ExtractedDeal>> findDealsByCategory(
    String category,
  ) async {
    return await DealsDatabaseService.getDealsByCategory(category);
  }

  /// Analysiert Einkaufsliste und gibt Produktkategorien zurück
  static Map<String, List<String>> categorizeShoppingList(
    List<String> shoppingList,
  ) {
    final categories = <String, List<String>>{};

    for (final item in shoppingList) {
      final category = _detectCategory(item);
      if (category != null) {
        categories.putIfAbsent(category, () => []).add(item);
      } else {
        categories.putIfAbsent('Sonstiges', () => []).add(item);
      }
    }

    return categories;
  }

  /// Erkennt Produktkategorie
  static String? _detectCategory(String productName) {
    final lowerName = productName.toLowerCase();

    const categoryKeywords = {
      'Milchprodukte': ['milch', 'käse', 'butter', 'joghurt', 'quark'],
      'Backwaren': ['brot', 'brötchen', 'toast'],
      'Fleisch & Wurst': ['wurst', 'schinken', 'fleisch', 'hähnchen'],
      'Obst & Gemüse': ['apfel', 'banane', 'tomate', 'gurke', 'salat'],
      'Getränke': ['saft', 'wasser', 'cola', 'limonade', 'kaffee', 'tee'],
      'Süßwaren': ['schokolade', 'keks', 'eis'],
      'Grundnahrungsmittel': ['nudeln', 'reis', 'kartoffeln', 'mehl'],
    };

    for (final entry in categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (lowerName.contains(keyword)) {
          return entry.key;
        }
      }
    }

    return null;
  }

  /// Findet ähnliche Produkte in Angeboten
  static Future<List<ExtractedDeal>> findSimilarProducts(
    String productName, {
    int limit = 5,
  }) async {
    final deals = await findDealsForProduct(productName);
    return deals.take(limit).toList();
  }

  /// Smart Suggestions: Findet verwandte Produkte
  static Future<List<ExtractedDeal>> findRelatedProducts(
    String productName,
  ) async {
    // 1. Finde direkte Matches
    final directMatches = await findDealsForProduct(productName);

    if (directMatches.length >= 5) {
      return directMatches.take(5).toList();
    }

    // 2. Finde Produkte aus derselben Kategorie
    final category = _detectCategory(productName);
    if (category != null) {
      final categoryDeals = await DealsDatabaseService.getDealsByCategory(category);

      // Kombiniere und entferne Duplikate
      final combined = <String, ExtractedDeal>{};
      for (final deal in [...directMatches, ...categoryDeals]) {
        combined[deal.id] = deal;
      }

      return combined.values.take(5).toList();
    }

    return directMatches;
  }

  /// Prüft ob Produkt im Angebot ist
  static Future<bool> hasActiveDeals(String productName) async {
    final deals = await findDealsForProduct(productName, minSimilarity: 0.7);
    return deals.isNotEmpty;
  }

  /// Gibt Anzahl der Angebote für Produkt zurück
  static Future<int> countDealsForProduct(String productName) async {
    final deals = await findDealsForProduct(productName);
    return deals.length;
  }
}
