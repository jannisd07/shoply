import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/services/shared_preferences_provider.dart';

/// The local pacing of contextual Pro hints (Konzept 18 §9.3, 00 §16.5).
///
/// - The first offer only after an aha moment (the first finished trip,
///   [noteAha]), never on the visit in which it happened.
/// - At most one Pro hint a day overall; the same hint at most once a week.
///   A hint shown today stays for the rest of the day (closing the paywall
///   keeps the row).
/// - "Nicht mehr zeigen" ([hide]) is final for that hint; resetting tips
///   does not bring it back.
///
/// Account-bound: everything lives under [key], which a sign-out removes
/// (`account_local_data.dart`).
class ProHintCounter {
  /// A counter in [prefs]; [clock] for tests.
  ProHintCounter(this._prefs, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// The SharedPreferences key.
  static const key = 'pro_hints_v1';

  /// The Home row "14 Tage Avo Pro gratis testen" (§11.11).
  static const trialOffer = 'trial_offer';

  /// Days before the same hint may come back.
  static const int weekDays = 7;

  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  Map<String, dynamic> _read() {
    final raw = _prefs.getString(key);
    if (raw == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (e) {
      debugPrint('⚠️ [PRO_HINT] State unreadable: ${e.runtimeType}');
      return {};
    }
  }

  void _write(Map<String, dynamic> state) =>
      unawaited(_prefs.setString(key, jsonEncode(state)));

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parse(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;

  /// When the first aha moment happened; null before.
  DateTime? get ahaAt => _parse(_read()['aha']);

  /// Records an aha moment (a finished trip). Only the first one counts.
  void noteAha() {
    final state = _read();
    if (state['aha'] != null) return;
    state['aha'] = _clock().toIso8601String();
    _write(state);
  }

  /// Whether [hint] was hidden for good.
  bool isHidden(String hint) =>
      (_read()['hidden'] as List?)?.contains(hint) ?? false;

  /// Whether [hint] may appear on a visit that began at [visitStart].
  bool canShow(String hint, {required DateTime visitStart}) {
    final state = _read();
    final aha = _parse(state['aha']);
    if (aha == null || !aha.isBefore(visitStart)) return false;
    if ((state['hidden'] as List?)?.contains(hint) ?? false) return false;
    final today = _day(_clock());
    final lastDay = state['lastDay'] as String?;
    if (lastDay == today) return state['lastHint'] == hint;
    final shown = _parse((state['shown'] as Map?)?[hint]);
    if (shown == null) return true;
    final now = _clock();
    // Calendar days in UTC, so a daylight-saving week still has 7 days.
    final days = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime.utc(shown.year, shown.month, shown.day)).inDays;
    return days >= weekDays;
  }

  /// Notes that [hint] is on screen today.
  void markShown(String hint) {
    final state = _read();
    final today = _day(_clock());
    if (state['lastDay'] == today && state['lastHint'] == hint) return;
    state['lastDay'] = today;
    state['lastHint'] = hint;
    state['shown'] = {
      ...?(state['shown'] as Map?)?.cast<String, dynamic>(),
      hint: today,
    };
    _write(state);
  }

  /// "Nicht mehr zeigen": [hint] never comes back.
  void hide(String hint) {
    final state = _read();
    final hidden = [...?(state['hidden'] as List?)?.cast<String>()];
    if (!hidden.contains(hint)) hidden.add(hint);
    state['hidden'] = hidden;
    _write(state);
  }
}

/// The counter once the preferences are loaded (null before).
final proHintCounterProvider = Provider<ProHintCounter?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  return prefs == null ? null : ProHintCounter(prefs);
});

/// One visit of a screen that may show a Pro hint (like `TipVisit`): the
/// decision is made once, at the first frame whose inputs are ready, and a
/// new visit starts when the screen becomes visible again (00 §12.12: hints
/// never appear while someone reads).
class ProHintVisit {
  /// A visit for [hint].
  ProHintVisit(this.hint, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// The hint id ([ProHintCounter.trialOffer]).
  final String hint;
  final DateTime Function() _clock;

  bool? _tickerOn;
  DateTime? _start;
  bool? _show;
  int _visits = 0;

  /// Call in build. [ready] says whether everything the decision needs is
  /// known (Pro status above all); [allowed] whether the screen has room.
  /// The first visit of the screen (the app start) never shows a hint
  /// (§9.3). A decided hint goes away when the screen runs out of room later
  /// (rows that loaded after the decision, K-38).
  bool resolve(
    BuildContext context,
    ProHintCounter? counter, {
    required bool ready,
    required bool allowed,
  }) {
    final on = TickerMode.valuesOf(context).enabled;
    if (_tickerOn != true && on) {
      _start = _clock();
      _show = null;
      _visits++;
    }
    _tickerOn = on;
    if (_show == null && on && ready && counter != null) {
      final show =
          _visits > 1 &&
          allowed &&
          counter.canShow(hint, visitStart: _start ?? _clock());
      _show = show;
      if (show) counter.markShown(hint);
    }
    return (_show ?? false) && allowed;
  }

  /// Takes the hint away for the rest of this visit.
  void dismiss() => _show = false;
}
