import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/services/app_flags_service.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';

/// State of "Widerrufen" on one change card.
enum AvoUndoPhase { idle, working, undone, changedSince }

/// State of a delete confirm card (Kap. 6.3).
enum AvoConfirmPhase { asking, working, deleted, cancelled, expired, failed }

/// State of a module-off row (Kap. 2.8).
enum AvoModulePhase { off, working, on, undone }

/// Remembers when the Pro row for the daily limit was last shown: at most
/// once a week (owner question F1).
abstract interface class AvoProHintGate {
  /// True (and remembered) when the row may show now.
  Future<bool> take();
}

class _PrefsProHintGate implements AvoProHintGate {
  const _PrefsProHintGate();

  static const _key = 'avo_pro_hint_shown_at';
  static const _every = Duration(days: 7);

  @override
  Future<bool> take() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_key);
      final now = DateTime.now();
      if (last != null &&
          now.difference(DateTime.fromMillisecondsSinceEpoch(last)) < _every) {
        return false;
      }
      await prefs.setInt(_key, now.millisecondsSinceEpoch);
      return true;
    } catch (e) {
      debugPrint('⚠️ [AVO_TAB] Pro hint state not read: $e');
      return false;
    }
  }
}

/// The gate the app uses (SharedPreferences, this device).
const AvoProHintGate avoPrefsProHintGate = _PrefsProHintGate();

/// Avo Pro's daily limit of an `ai` task from `app_flags.ai_limits`
/// (`pro.<task>`); null while unknown.
final avoProTaskLimitProvider = Provider.family<int?, String>((ref, task) {
  final limits = ref.watch(
    appFlagsProvider.select((f) => f.values[AppFlagKeys.aiLimits]),
  );
  if (limits is! Map) return null;
  final pro = limits['pro'];
  if (pro is! Map) return null;
  final value = pro[task];
  return value is num ? value.toInt() : null;
});

/// The `ai` task whose Pro limit the Pro row after a photo names.
String avoPhotoTask({required bool meal}) => meal ? 'meal_photo' : 'list_import';
