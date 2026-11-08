import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which data Avo may give to Claude (Kap. 16): "Ernährung und Allergien"
/// (health) and "Kalorien, Gewicht und Ziele" (body). Both start off and
/// live on this device only.
abstract final class AvoConsents {
  static const _healthKey = 'avo_consent_health';
  static const _bodyKey = 'avo_consent_body';

  static Future<({bool health, bool body})> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (
        health: prefs.getBool(_healthKey) ?? false,
        body: prefs.getBool(_bodyKey) ?? false,
      );
    } catch (e) {
      debugPrint('⚠️ [AVO] Consents not loaded: $e');
      return (health: false, body: false);
    }
  }

  static Future<void> set({bool? health, bool? body}) async {
    final prefs = await SharedPreferences.getInstance();
    if (health != null) await prefs.setBool(_healthKey, health);
    if (body != null) await prefs.setBool(_bodyKey, body);
  }
}

/// The consent a card in the chat asks for.
enum AvoConsentKind { health, body }
