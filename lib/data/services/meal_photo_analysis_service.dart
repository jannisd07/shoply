import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shoply/core/config/env.dart';

/// One-shot AI estimate of a meal photo's nutrition — always a rough guess,
/// shown to the user as an editable pre-fill rather than logged directly,
/// since Gemini vision calorie estimates from a single photo can't be
/// precise (no idea of portion weight, hidden oil/sauce, etc).
class MealPhotoEstimate {
  final String foodName;
  final int calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final String confidence; // 'low' | 'medium' | 'high'

  const MealPhotoEstimate({
    required this.foodName,
    required this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    required this.confidence,
  });
}

class MealPhotoAnalysisService {
  static final MealPhotoAnalysisService instance = MealPhotoAnalysisService();

  late final GenerativeModel _model;

  MealPhotoAnalysisService() {
    _model = GenerativeModel(
      // gemini-2.0-flash is multimodal (unlike the flash-lite model used
      // for text-only categorization elsewhere) — needed for image input.
      model: 'gemini-2.0-flash',
      apiKey: Env.geminiApiKey,
    );
  }

  static const _prompt = '''
You are a nutrition estimation assistant. Look at this photo of a meal and
estimate its nutritional content as eaten (the whole plate/portion shown).
Respond with ONLY a JSON object, no markdown, no explanation:
{"food_name": "short descriptive name", "calories": <int>, "protein_g": <number>, "carbs_g": <number>, "fat_g": <number>, "confidence": "low"|"medium"|"high"}
If you cannot identify food in the image at all, respond with:
{"error": "no_food_detected"}
''';

  /// Returns null if Gemini couldn't identify food, or on any failure —
  /// callers should fall back to manual entry, never fabricate a result.
  Future<MealPhotoEstimate?> analyzePhoto(Uint8List imageBytes) async {
    try {
      final content = [
        Content.multi([
          TextPart(_prompt),
          DataPart('image/jpeg', imageBytes),
        ]),
      ];
      final response = await _model.generateContent(content);
      final text = response.text?.trim();
      if (text == null || text.isEmpty) return null;

      final cleaned = text.replaceAll('```json', '').replaceAll('```', '').trim();
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      if (json.containsKey('error')) return null;

      return MealPhotoEstimate(
        foodName: json['food_name'] as String? ?? 'Meal',
        calories: (json['calories'] as num?)?.round() ?? 0,
        proteinG: (json['protein_g'] as num?)?.toDouble(),
        carbsG: (json['carbs_g'] as num?)?.toDouble(),
        fatG: (json['fat_g'] as num?)?.toDouble(),
        confidence: json['confidence'] as String? ?? 'low',
      );
    } catch (e) {
      debugPrint('⚠️ [MealPhotoAnalysis] Failed: $e');
      return null;
    }
  }
}
