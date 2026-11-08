import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
