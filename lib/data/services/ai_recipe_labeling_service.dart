import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/core/config/env.dart';

/// KI-basierter Service für intelligentes Rezept-Labeling mit Gemini AI
/// Analysiert Rezepte und vergibt automatisch passende Labels
class AIRecipeLabelingService {
  
  late final GenerativeModel _model;
  
  // Cache für bereits gelabelte Rezepte (verhindert Doppel-Anfragen)
  final Map<String, List<String>> _labelCache = {};
  
  AIRecipeLabelingService() {
    _model = GenerativeModel(
      model: 'gemini-pro',
      apiKey: Env.geminiApiKey,
    );
  }

  /// Analysiert ein Rezept mit KI und vergibt passende Labels
  Future<List<String>> labelRecipeWithAI(Recipe recipe) async {
    // Cache-Check
    final cacheKey = recipe.id;
    if (_labelCache.containsKey(cacheKey)) {
      return _labelCache[cacheKey]!;
    }

    try {
      final prompt = _buildLabelingPrompt(recipe);
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      if (response.text == null) {
        return _getFallbackLabels(recipe);
      }

      final labels = _parseLabelsFromResponse(response.text!);
      
      // Cache speichern
      _labelCache[cacheKey] = labels;
      
      return labels;
      
    } catch (e) {
      return _getFallbackLabels(recipe);
    }
  }

  /// Batch-Labeling für mehrere Rezepte
  Future<Map<String, List<String>>> labelMultipleRecipes(List<Recipe> recipes) async {
    final results = <String, List<String>>{};
    
    for (final recipe in recipes) {
      try {
        final labels = await labelRecipeWithAI(recipe);
        results[recipe.id] = labels;
        
        // Pause zwischen Anfragen (Rate Limiting)
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        results[recipe.id] = _getFallbackLabels(recipe);
      }
    }
    
    return results;
  }

  String _buildLabelingPrompt(Recipe recipe) {
    // Zutaten-Liste formatieren
    final ingredientsList = recipe.ingredients
        .map((ing) => '- ${ing.name} (${ing.amount} ${ing.unit})')
        .join('\n');
    
    return '''
Du bist ein Experte für Lebensmittel und Ernährung. Analysiere folgendes Rezept und vergib passende Labels/Tags.

REZEPT: ${recipe.name}

BESCHREIBUNG:
${recipe.description}

ZUTATEN:
$ingredientsList

ZUBEREITUNGSZEIT: ${recipe.prepTimeMinutes} Min. Vorbereitung + ${recipe.cookTimeMinutes} Min. Kochen

AUFGABE:
Analysiere das Rezept und vergib 3-8 passende Labels aus folgenden Kategorien:

ERNÄHRUNGSFORMEN:
- vegan (keine tierischen Produkte)
- vegetarisch (keine Fleisch/Fisch, aber Milch/Eier OK)
- pescetarian (kein Fleisch, aber Fisch OK)
- glutenfrei (keine glutenhaltigen Zutaten)
- laktosefrei (keine Milchprodukte)
- low-carb (wenig Kohlenhydrate)
- high-protein (viel Protein)
- keto (ketogene Ernährung)

KÜCHENSTIL:
- italienisch
- asiatisch
- mexikanisch
- mediterran
- amerikanisch
- orientalisch
- indisch
- thailändisch
- japanisch

GERICHT-TYP:
- frühstück
- mittagessen
- abendessen
- dessert
- snack
- beilage
- hauptgericht
- vorspeise
- suppe
- salat
- smoothie

SCHWIERIGKEIT & ZEIT:
- einfach (unter 30 Min gesamt)
- schnell (unter 20 Min gesamt)
- aufwendig (über 60 Min gesamt)

SAISON:
- sommer
- winter
- frühling
- herbst

BESONDERE EIGENSCHAFTEN:
- gesund
- kalorienarm
- familienfreundlich
- party-geeignet
- meal-prep
- one-pot (ein Topf)
- backen
- grillen

ANTWORT-FORMAT (nur Labels, kommagetrennt):
label1, label2, label3, label4, label5

Beispiel-Antwort: vegan, asiatisch, hauptgericht, schnell, gesund

Wichtig: 
- Nur Labels aus den obigen Kategorien verwenden
- 3-8 Labels vergeben
- Labels immer in Kleinbuchstaben
- Nur mit Komma trennen, keine Anführungszeichen
- Keine Erklärungen, nur die Labels

DEINE ANTWORT (nur Labels):
''';
  }

  List<String> _parseLabelsFromResponse(String responseText) {
    try {
      // Bereinige Response
      String cleaned = responseText.trim();
      
      // Entferne Markdown-Formatierung falls vorhanden
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.split('\n').skip(1).join('\n');
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.lastIndexOf('```'));
      }
      
      cleaned = cleaned.trim();
      
      // Splitte bei Komma
      final labels = cleaned
          .split(',')
          .map((label) => label.trim().toLowerCase())
          .where((label) => label.isNotEmpty && label.length > 2)
          .toList();
      
      // Validiere Labels (müssen aus vordefinierter Liste sein)
      final validLabels = labels.where(_isValidLabel).toList();
      
      if (validLabels.isEmpty) {
        return [];
      }
      
      return validLabels;
      
    } catch (e) {
      return [];
    }
  }

  bool _isValidLabel(String label) {
    // Vordefinierte Label-Liste zur Validierung
    const validLabels = [
      // Ernährungsformen
      'vegan', 'vegetarisch', 'pescetarian', 'glutenfrei', 'laktosefrei',
      'low-carb', 'high-protein', 'keto', 'paleo', 'halal', 'koscher',
      
      // Küchenstil
      'italienisch', 'asiatisch', 'mexikanisch', 'mediterran', 'amerikanisch',
      'orientalisch', 'indisch', 'thailändisch', 'japanisch', 'chinesisch',
      'französisch', 'spanisch', 'griechisch', 'türkisch',
      
      // Gericht-Typ
      'frühstück', 'mittagessen', 'abendessen', 'dessert', 'snack',
      'beilage', 'hauptgericht', 'vorspeise', 'suppe', 'salat', 'smoothie',
      'pasta', 'pizza', 'burger', 'sandwich', 'wrap',
      
      // Zeit & Schwierigkeit
      'einfach', 'schnell', 'aufwendig', 'anfänger',
      
      // Saison
      'sommer', 'winter', 'frühling', 'herbst',
      
      // Eigenschaften
      'gesund', 'kalorienarm', 'familienfreundlich', 'party-geeignet',
      'meal-prep', 'one-pot', 'backen', 'grillen', 'braten', 'kochen',
      'roh', 'warm', 'kalt', 'cremig', 'knusprig', 'würzig', 'süß', 'herzhaft',
    ];
    
    return validLabels.contains(label);
  }

  /// Fallback-Labels basierend auf einfacher Regel-Logik
  List<String> _getFallbackLabels(Recipe recipe) {
    final labels = <String>[];
    
    // Zubereitungszeit
    final totalTime = recipe.prepTimeMinutes + recipe.cookTimeMinutes;
    if (totalTime < 20) {
      labels.add('schnell');
    } else if (totalTime < 30) {
      labels.add('einfach');
    } else if (totalTime > 60) {
      labels.add('aufwendig');
    }
    
    // Basis-Analysen
    final name = recipe.name.toLowerCase();
    final description = recipe.description.toLowerCase();
    final allText = '$name $description';
    
    // Gericht-Typ
    if (allText.contains('frühstück') || allText.contains('pancake') || allText.contains('müsli')) {
      labels.add('frühstück');
    }
    if (allText.contains('suppe') || allText.contains('eintopf')) {
      labels.add('suppe');
    }
    if (allText.contains('salat')) {
      labels.add('salat');
    }
    if (allText.contains('dessert') || allText.contains('kuchen') || allText.contains('torte')) {
      labels.add('dessert');
    }
    
    // Küchenstil
    if (allText.contains('pasta') || allText.contains('italienisch') || allText.contains('pizza')) {
      labels.add('italienisch');
    }
    if (allText.contains('curry') || allText.contains('asiatisch') || allText.contains('wok')) {
      labels.add('asiatisch');
    }
    
    // Standard-Label wenn nichts gefunden
    if (labels.isEmpty) {
      labels.add('hauptgericht');
    }
    
    return labels;
  }

  /// Löscht den Cache (nützlich beim Neustart)
  void clearCache() {
    _labelCache.clear();
  }
}
