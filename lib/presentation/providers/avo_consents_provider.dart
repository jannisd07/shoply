import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/data/services/avo_consents.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

/// What Avo may give to Claude ("Was Avo einbeziehen darf", Kap. 16 §10.1):
/// [health] "Ernährung und Allergien", [body] "Kalorien, Gewicht und Ziele".
/// Both start off; [loaded] once the device values were read.
@immutable
class AvoConsentState {
  const AvoConsentState({
    this.health = false,
    this.body = false,
    this.loaded = false,
  });

  final bool health;
  final bool body;
  final bool loaded;
}

/// The consents on this device ([AvoConsents]). Taking one back ends the
/// conversation at the next question (`AvoConversation.applyConsents`), so
/// earlier answers cannot carry what is now withheld.
class AvoConsentsNotifier extends StateNotifier<AvoConsentState> {
  AvoConsentsNotifier() : super(const AvoConsentState()) {
    unawaited(_load());
  }

  bool _changed = false;

  Future<void> _load() async {
    final stored = await AvoConsents.load();
    if (!mounted || _changed) return;
    state = AvoConsentState(
      health: stored.health,
      body: stored.body,
      loaded: true,
    );
  }

  /// Saves at once; the switch shows the new value before the write ends.
  Future<void> set({bool? health, bool? body}) async {
    _changed = true;
    state = AvoConsentState(
      health: health ?? state.health,
      body: body ?? state.body,
      loaded: true,
    );
    try {
      await AvoConsents.set(health: health, body: body);
    } catch (e) {
      debugPrint('⚠️ [AVO] Consent not saved: ${e.runtimeType}');
    }
  }
}

/// The signed-in person's consents for Avo; read again for another account.
final avoConsentsProvider =
    StateNotifierProvider<AvoConsentsNotifier, AvoConsentState>((ref) {
      ref.watch(authUserIdProvider);
      return AvoConsentsNotifier();
    });
