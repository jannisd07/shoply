import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/services/app_flags_service.dart';
import 'package:shoply/data/services/claude_service.dart';
import 'package:shoply/data/services/meal_photo_analysis_service.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';

// AI estimates and meal photos (S5, S8, S10): the photo and text estimates,
// the daily limits as this device saw them, the private photo bucket.

// ── AI estimates ────────────────────────────────────────────────────────

/// The photo estimate of S5; override in tests.
final mealPhotoAnalyzerProvider = Provider<Future<MealPhotoEstimate> Function(Uint8List photo)>(
  (ref) => (photo) => MealPhotoAnalysisService.instance.analyzePhoto(photo),
);

/// A text estimate (task `nutrition_estimate`): per serving for a recipe,
/// as eaten for a food.
@immutable
class CalorieNutritionEstimate {
  const CalorieNutritionEstimate({
    required this.kcal,
    this.proteinG,
    this.carbsG,
    this.fatG,
    required this.confidence,
  });

  final int kcal;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final EstimateConfidence confidence;
}

typedef CalorieNutritionEstimator = Future<CalorieNutritionEstimate> Function(String text, {int? servings});

/// The server task leaves room inside a 10 s client deadline.
const Duration _kNutritionTimeout = Duration(seconds: 10);

/// "Kalorien schätzen lassen" (S8, S10). Throws [ClaudeException].
final calorieNutritionEstimatorProvider = Provider<CalorieNutritionEstimator>((ref) {
  return (String text, {int? servings}) async {
    final result = await ClaudeService.instance.run(
      'nutrition_estimate',
      {'text': text, if (servings != null && servings > 0) 'servings': servings},
      timeout: _kNutritionTimeout,
    );
    final kcal = result['kcal'];
    if (kcal is! num || !kcal.isFinite || kcal < 0) throw const ClaudeException('provider_error');
    double? grams(Object? v) => v is num && v.isFinite && v >= 0 ? v.toDouble() : null;
    return CalorieNutritionEstimate(
      kcal: kcal.round(),
      proteinG: grams(result['protein_g']),
      carbsG: grams(result['carbs_g']),
      fatG: grams(result['fat_g']),
      confidence: EstimateConfidenceX.fromDb(result['confidence'] as String?) ?? EstimateConfidence.low,
    );
  };
});

/// A daily AI limit as this device saw it: reached when the server answered
/// `quota_exceeded` today (kept per account and day).
CaloriePhotoLimit _dailyLimit(Ref ref, String name) {
  final userId = ref.watch(authUserIdProvider);
  final prefs = ref.watch(calorieSharedPreferencesProvider).valueOrNull;
  final today = ref.watch(calorieTodayKeyProvider);
  final key = userId == null ? null : 'cal_${name}_limit_v1_$userId';
  return CaloriePhotoLimit(
    reached: key != null && prefs?.getString(key) == today,
    save: key == null || prefs == null ? null : () => prefs.setString(key, today),
  );
}

/// Today's photo estimates are used up. S3 then shows the limit instead of
/// the camera.
final caloriePhotoLimitReachedProvider = StateNotifierProvider.autoDispose<CaloriePhotoLimit, bool>(
  (ref) => _dailyLimit(ref, 'photo'),
);

/// Today's text estimates ("Kalorien schätzen lassen", S8 and S10) are used
/// up: the button gives way to the limit sentence until tomorrow.
final calorieTextEstimateLimitReachedProvider = StateNotifierProvider.autoDispose<CaloriePhotoLimit, bool>(
  (ref) => _dailyLimit(ref, 'text_estimate'),
);

/// Photo estimates a day with Avo Pro (`app_flags.ai_limits`, 15 until the
/// flags say otherwise).
final caloriePhotosPerDayProProvider = Provider<int>((ref) {
  final limits = ref.watch(appFlagsProvider.select((f) => f.values[AppFlagKeys.aiLimits]));
  final pro = limits is Map ? limits['pro'] : null;
  final n = pro is Map ? pro['meal_photo'] : null;
  return n is num && n > 0 ? n.round() : 15;
});

class CaloriePhotoLimit extends StateNotifier<bool> {
  CaloriePhotoLimit({required bool reached, this.save}) : super(reached);

  final Future<bool> Function()? save;

  void markReached() {
    state = true;
    unawaited(save?.call());
  }
}

// ── Photos in the private bucket ────────────────────────────────────────

/// A signed URL for a meal photo path (cached by path in the service).
final mealPhotoUrlProvider = FutureProvider.autoDispose.family<String?, String>(
  (ref, path) => ref.watch(mealPhotoStorageProvider).signedUrl(path),
);
