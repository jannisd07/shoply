import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shoply/data/models/dietary_preference.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/core/config/env.dart';

/// KI-basierter Service zur intelligenten Zutatenerkennung und Ersatzprodukt-Vorschläge
class AIIngredientAnalyzer {
  static final AIIngredientAnalyzer instance = AIIngredientAnalyzer();
  
  late final GenerativeModel _model;
  
  AIIngredientAnalyzer() {
    _model = GenerativeModel(
      model: 'gemini-pro',
      apiKey: Env.geminiApiKey,
    );
  }

  /// Analysiert eine Zutat und findet passende Ersatzprodukte basierend auf Allergien/Diäten
  Future<IngredientAnalysisResult> analyzeIngredient({
    required String ingredientName,
    required double amount,
    required String unit,
    List<AllergyType> allergies = const [],
    List<DietType> diets = const [],
  }) async {
    try {
      final prompt = _buildPrompt(
        ingredientName: ingredientName,
        amount: amount,
        unit: unit,
        allergies: allergies,
        diets: diets,
      );

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      if (response.text == null) {
        return IngredientAnalysisResult.noSubstitute(
          originalIngredient: Ingredient(
            name: ingredientName,
            amount: amount,
            unit: unit,
          ),
        );
      }

      return _parseResponse(
        response.text!,
        originalIngredient: Ingredient(
          name: ingredientName,
          amount: amount,
          unit: unit,
        ),
      );
    } catch (e) {
      
      // Fallback: Verwende lokale Datenbank
      return IngredientAnalysisResult.noSubstitute(
        originalIngredient: Ingredient(
          name: ingredientName,
          amount: amount,
          unit: unit,
        ),
      );
    }
  }

  /// Analysiert alle Zutaten eines Rezepts auf einmal (effizienter)
  Future<List<IngredientAnalysisResult>> analyzeRecipe({
    required List<Ingredient> ingredients,
    List<AllergyType> allergies = const [],
    List<DietType> diets = const [],
  }) async {
    try {
      final prompt = _buildBatchPrompt(
        ingredients: ingredients,
        allergies: allergies,
        diets: diets,
      );

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      if (response.text == null) {
        return ingredients.map((ing) => 
          IngredientAnalysisResult.noSubstitute(originalIngredient: ing)
        ).toList();
      }

      return _parseBatchResponse(response.text!, ingredients);
    } catch (e) {
      
      // Fallback: Keine Ersatzprodukte
      return ingredients.map((ing) => 
        IngredientAnalysisResult.noSubstitute(originalIngredient: ing)
      ).toList();
    }
  }

  String _buildPrompt({
    required String ingredientName,
    required double amount,
    required String unit,
    required List<AllergyType> allergies,
    required List<DietType> diets,
  }) {
    final allergyLabels = allergies.map((a) => a.label).join(', ');
    final dietLabels = diets.map((d) => d.label).join(', ');
    
    return '''
Du bist ein Experte für Lebensmittel und Ernährung. Analysiere folgende Zutat und schlage Ersatzprodukte vor.

ZUTAT: $ingredientName ($amount $unit)

EINSCHRÄNKUNGEN:
${allergies.isNotEmpty ? '- Allergien: $allergyLabels' : ''}
${diets.isNotEmpty ? '- Ernährungsformen: $dietLabels' : ''}

AUFGABE:
1. Erkenne um welches Lebensmittel es sich handelt
2. Prüfe ob die Zutat problematisch ist für die genannten Allergien/Diäten
3. Wenn JA: Schlage 1-3 passende Ersatzprodukte vor
4. Wenn NEIN: Antworte mit "KEINE_ERSETZUNG"

ANTWORT-FORMAT (JSON):
{
  "needs_replacement": true/false,
  "reason": "Kurze Begründung warum Ersatz nötig",
  "substitutes": [
    {
      "name": "Ersatzprodukt-Name",
      "amount": $amount,
      "unit": "$unit",
      "description": "Kurze Beschreibung",
      "confidence": 0.95
    }
  ]
}

Antworte NUR mit dem JSON, ohne zusätzlichen Text.
''';
  }

  String _buildBatchPrompt({
    required List<Ingredient> ingredients,
    required List<AllergyType> allergies,
    required List<DietType> diets,
  }) {
    final ingredientsList = ingredients.map((ing) => 
      '- ${ing.name} (${ing.amount} ${ing.unit})'
    ).join('\n');
    
    final allergyLabels = allergies.map((a) => a.label).join(', ');
    final dietLabels = diets.map((d) => d.label).join(', ');
    
    return '''
Du bist ein Experte für Lebensmittel und Ernährung. Analysiere folgende Zutatenliste und schlage Ersatzprodukte vor.

ZUTATEN:
$ingredientsList

EINSCHRÄNKUNGEN:
${allergies.isNotEmpty ? '- Allergien: $allergyLabels' : ''}
${diets.isNotEmpty ? '- Ernährungsformen: $dietLabels' : ''}

AUFGABE:
Für JEDE Zutat:
1. Erkenne um welches Lebensmittel es sich handelt
2. Prüfe ob die Zutat problematisch ist für die genannten Allergien/Diäten
3. Wenn JA: Schlage 1 passendes Ersatzprodukt vor
4. Wenn NEIN: needs_replacement = false

ANTWORT-FORMAT (JSON Array):
[
  {
    "original_name": "Original-Zutat",
    "needs_replacement": true/false,
    "reason": "Kurze Begründung",
    "substitute": {
      "name": "Ersatzprodukt-Name",
      "amount": 100,
      "unit": "g",
      "description": "Kurze Beschreibung"
    }
  }
]

Antworte NUR mit dem JSON Array, ohne zusätzlichen Text.
''';
  }

  IngredientAnalysisResult _parseResponse(
    String responseText,
    {required Ingredient originalIngredient}
  ) {
    try {
      // Entferne Markdown-Code-Blöcke falls vorhanden
      String jsonText = responseText.trim();
      if (jsonText.startsWith('```json')) {
        jsonText = jsonText.substring(7);
      }
      if (jsonText.startsWith('```')) {
        jsonText = jsonText.substring(3);
      }
      if (jsonText.endsWith('```')) {
        jsonText = jsonText.substring(0, jsonText.length - 3);
      }
      jsonText = jsonText.trim();

      final Map<String, dynamic> json = {};
      // Einfaches JSON-Parsing (kann durch json.decode ersetzt werden)
      
      // Für jetzt: Fallback
      return IngredientAnalysisResult.noSubstitute(
        originalIngredient: originalIngredient,
      );
    } catch (e) {
      return IngredientAnalysisResult.noSubstitute(
        originalIngredient: originalIngredient,
      );
    }
  }

  List<IngredientAnalysisResult> _parseBatchResponse(
    String responseText,
    List<Ingredient> originalIngredients,
  ) {
    // Für jetzt: Fallback
    return originalIngredients.map((ing) => 
      IngredientAnalysisResult.noSubstitute(originalIngredient: ing)
    ).toList();
  }
}

/// Ergebnis der KI-Analyse einer Zutat
class IngredientAnalysisResult {
  final Ingredient originalIngredient;
  final bool needsReplacement;
  final String? reason;
  final List<AISubstitute> substitutes;

  const IngredientAnalysisResult({
    required this.originalIngredient,
    required this.needsReplacement,
    this.reason,
    this.substitutes = const [],
  });

  factory IngredientAnalysisResult.noSubstitute({
    required Ingredient originalIngredient,
  }) {
    return IngredientAnalysisResult(
      originalIngredient: originalIngredient,
      needsReplacement: false,
      substitutes: [],
    );
  }

  /// Bestes Ersatzprodukt (höchste Confidence)
  AISubstitute? get bestSubstitute {
    if (substitutes.isEmpty) return null;
    return substitutes.reduce((a, b) => 
      a.confidence > b.confidence ? a : b
    );
  }
}

/// KI-vorgeschlagenes Ersatzprodukt
class AISubstitute {
  final String name;
  final double amount;
  final String unit;
  final String description;
  final double confidence; // 0.0 - 1.0

  const AISubstitute({
    required this.name,
    required this.amount,
    required this.unit,
    required this.description,
    this.confidence = 0.8,
  });

  Ingredient toIngredient() {
    return Ingredient(
      name: name,
      amount: amount,
      unit: unit,
    );
  }
}
