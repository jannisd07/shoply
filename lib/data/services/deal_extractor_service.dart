import 'package:shoply/data/models/extracted_deal_model.dart';
import 'package:uuid/uuid.dart';

/// Service zum Extrahieren von Angeboten aus OCR-Text
class DealExtractorService {
  static const _uuid = Uuid();

  /// Produktkategorien für bessere Erkennung
  static const productCategories = {
    'Milchprodukte': ['milch', 'käse', 'butter', 'joghurt', 'quark', 'sahne', 'frischkäse'],
    'Backwaren': ['brot', 'brötchen', 'toast', 'croissant', 'kuchen'],
    'Fleisch & Wurst': ['wurst', 'schinken', 'fleisch', 'hackfleisch', 'hähnchen', 'pute', 'rind', 'schwein'],
    'Obst & Gemüse': ['apfel', 'banane', 'orange', 'tomate', 'gurke', 'salat', 'karotte', 'paprika'],
    'Getränke': ['saft', 'wasser', 'cola', 'limonade', 'bier', 'wein', 'kaffee', 'tee'],
    'Süßwaren': ['schokolade', 'keks', 'gummibärchen', 'chips', 'eis'],
    'Grundnahrungsmittel': ['nudeln', 'reis', 'kartoffeln', 'mehl', 'zucker', 'salz'],
    'Tiefkühlprodukte': ['pizza', 'pommes', 'fischstäbchen', 'gemüsemischung'],
  };

  /// Marken für bessere Produkterkennung
  static const commonBrands = [
    'Milka', 'Nutella', 'Coca-Cola', 'Pepsi', 'Nestlé', 'Ferrero', 'Dr. Oetker',
    'Müller', 'Weihenstephan', 'Milram', 'Arla', 'Danone', 'Ehrmann',
    'Barilla', 'Knorr', 'Maggi', 'Kellogg\'s', 'Haribo', 'Lindt', 'Ritter Sport',
    'Ja!', 'Gut & Günstig', 'K-Classic', 'Edeka', 'REWE', 'Lidl', 'Aldi'
  ];

  /// Extrahiert Preise aus Text
  static List<double> extractPrices(String text) {
    // Verschiedene Preisformate: 2,99 €, 2.99€, 2,99€, 2.99 EUR, etc.
    final pricePatterns = [
      RegExp(r'(\d+[,\.]\d{2})\s*€'),  // 2,99 € oder 2.99€
      RegExp(r'(\d+[,\.]\d{2})\s*EUR', caseSensitive: false),  // 2,99 EUR
      RegExp(r'€\s*(\d+[,\.]\d{2})'),  // € 2,99
      RegExp(r'(\d+[,\.]\d{2})'),      // 2,99 (ohne Symbol)
    ];

    Set<double> prices = {};

    for (final pattern in pricePatterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        try {
          final priceStr = match.group(1)!.replaceAll(',', '.');
          final price = double.parse(priceStr);
          if (price > 0 && price < 1000) {  // Sinnvoller Preisbereich
            prices.add(price);
          }
        } catch (e) {
          // Ignoriere ungültige Preise
        }
      }
    }

    return prices.toList()..sort();
  }

  /// Extrahiert Produktnamen aus Text
  static List<String> extractProductNames(String text) {
    List<String> foundProducts = [];
    final lines = text.toLowerCase().split('\n');

    for (final line in lines) {
      if (line.trim().isEmpty || line.length > 100) continue;

      // Prüfe ob Zeile Produktkeywords enthält
      bool hasProductKeyword = false;
      for (final keywords in productCategories.values) {
        for (final keyword in keywords) {
          if (line.contains(keyword)) {
            hasProductKeyword = true;
            break;
          }
        }
        if (hasProductKeyword) break;
      }

      if (hasProductKeyword) {
        foundProducts.add(line.trim());
      }
    }

    return foundProducts;
  }

  /// Erkennt Produktkategorie
  static String? detectCategory(String productName) {
    final lowerName = productName.toLowerCase();

    for (final entry in productCategories.entries) {
      for (final keyword in entry.value) {
        if (lowerName.contains(keyword)) {
          return entry.key;
        }
      }
    }

    return null;
  }

  /// Erkennt Marke im Produktnamen
  static String? detectBrand(String productName) {
    for (final brand in commonBrands) {
      if (productName.contains(brand)) {
        return brand;
      }
    }
    return null;
  }

  /// Extrahiert Mengenangaben (z.B. "1kg", "500g", "1L")
  static String? extractUnit(String text) {
    final unitPatterns = [
      RegExp(r'(\d+(?:[,.]\d+)?\s*(?:kg|g|l|ml|stk|stück))', caseSensitive: false),
      RegExp(r'(\d+\s*x\s*\d+\s*(?:g|ml|l))', caseSensitive: false),
    ];

    for (final pattern in unitPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1)?.trim();
      }
    }

    return null;
  }

  /// Extrahiert Rabatt-Prozentsatz aus Text
  static double? extractDiscountPercentage(String text) {
    final discountPatterns = [
      RegExp(r'(\d+)\s*%\s*(?:rabatt|günstiger|sparen)', caseSensitive: false),
      RegExp(r'(?:rabatt|günstiger|sparen)\s*(\d+)\s*%', caseSensitive: false),
      RegExp(r'-\s*(\d+)\s*%'),
    ];

    for (final pattern in discountPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final percent = int.tryParse(match.group(1)!);
        if (percent != null && percent > 0 && percent <= 99) {
          return percent.toDouble();
        }
      }
    }

    return null;
  }

  /// Hauptfunktion: Extrahiert alle Angebote aus OCR-Text
  static Future<List<ExtractedDeal>> extractDeals(
    String ocrText,
    String supermarket, {
    Function(String)? onProgress,
  }) async {
    List<ExtractedDeal> deals = [];

    if (onProgress != null) onProgress('Analysiere Text...');

    // Text in Seiten aufteilen
    final pages = ocrText.split('--- SEITE');

    int dealCount = 0;

    for (final page in pages) {
      if (page.trim().isEmpty) continue;

      // Zeilen extrahieren
      final lines = page.split('\n');

      // Für jede Zeile: Prüfe auf Angebotsmuster
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty || line.length > 150) continue;

        // Kontext: Nächste und vorherige Zeilen
        final contextBefore = i > 0 ? lines[i - 1].trim() : '';
        final contextAfter = i < lines.length - 1 ? lines[i + 1].trim() : '';
        final fullContext = '$contextBefore\n$line\n$contextAfter';

        // Extrahiere Preise aus Kontext
        final prices = extractPrices(fullContext);

        // Angebot nur wenn mindestens 2 Preise gefunden
        if (prices.length >= 2) {
          // Annahme: Erster Preis = Alter Preis, Letzter Preis = Neuer Preis
          final originalPrice = prices[0];
          final discountedPrice = prices[prices.length - 1];

          // Rabatt nur wenn neuer Preis niedriger
          if (discountedPrice < originalPrice) {
            final discount = ((originalPrice - discountedPrice) / originalPrice * 100);

            // Mindestrabatt: 5%
            if (discount >= 5) {
              dealCount++;

              // Produktname: Zeile ohne Preise
              String productName = line;
              for (final price in prices) {
                productName = productName.replaceAll('${price.toStringAsFixed(2)}', '');
                productName = productName.replaceAll('${price.toStringAsFixed(2).replaceAll('.', ',')}', '');
              }
              productName = productName
                  .replaceAll('€', '')
                  .replaceAll('EUR', '')
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .trim();

              if (productName.isEmpty) {
                productName = contextBefore.isNotEmpty ? contextBefore : 'Produkt $dealCount';
              }

              // Angebot erstellen
              deals.add(ExtractedDeal(
                id: _uuid.v4(),
                supermarket: supermarket,
                productName: productName,
                productBrand: detectBrand(fullContext),
                productCategory: detectCategory(fullContext),
                originalPrice: originalPrice,
                discountedPrice: discountedPrice,
                discountPercentage: discount,
                unit: extractUnit(fullContext),
                validFrom: DateTime.now(),
                validUntil: DateTime.now().add(const Duration(days: 7)), // Standard: 7 Tage
                scannedAt: DateTime.now(),
                isActive: true,
              ));

              if (onProgress != null) {
                onProgress('$dealCount Angebote gefunden...');
              }
            }
          }
        }
      }
    }


    return deals;
  }

  /// Verbesserte Extraktion mit AI (TODO: Claude API Integration)
  static Future<List<ExtractedDeal>> extractDealsWithAI(
    String ocrText,
    String supermarket, {
    Function(String)? onProgress,
  }) async {
    // TODO: Claude AI API Integration für bessere Produkterkennung
    // Vorerst: Fallback zu regulärer Extraktion
    return await extractDeals(ocrText, supermarket, onProgress: onProgress);
  }

  /// Filtert doppelte Angebote
  static List<ExtractedDeal> removeDuplicates(List<ExtractedDeal> deals) {
    final seen = <String>{};
    return deals.where((deal) {
      final key = '${deal.supermarket}_${deal.productName}_${deal.discountedPrice}';
      if (seen.contains(key)) {
        return false;
      }
      seen.add(key);
      return true;
    }).toList();
  }

  /// Sortiert Angebote nach Rabatt (höchster zuerst)
  static List<ExtractedDeal> sortByDiscount(List<ExtractedDeal> deals) {
    return deals..sort((a, b) => b.discountPercentage.compareTo(a.discountPercentage));
  }

  /// Filtert nach Mindestrabatt
  static List<ExtractedDeal> filterByMinimumDiscount(
    List<ExtractedDeal> deals,
    double minimumPercent,
  ) {
    return deals.where((deal) => deal.discountPercentage >= minimumPercent).toList();
  }

  /// Filtert nach Kategorie
  static List<ExtractedDeal> filterByCategory(
    List<ExtractedDeal> deals,
    String category,
  ) {
    return deals.where((deal) => deal.productCategory == category).toList();
  }
}
