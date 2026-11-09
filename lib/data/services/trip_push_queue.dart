import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One push to list members that waits until the undo window of a trip is
/// over (verlauf-kosten.md §3.1, K12-14), so "Widerrufen" never leaves a
/// wrong message behind.
@immutable
class DeferredTripPush {
  const DeferredTripPush({
    required this.tripId,
    required this.userIds,
    required this.title,
    required this.body,
    required this.data,
    required this.notBefore,
  });

  factory DeferredTripPush.fromJson(Map<String, dynamic> json) =>
      DeferredTripPush(
        tripId: json['trip'] as String,
        userIds: [for (final id in json['to'] as List) id as String],
        title: json['title'] as String,
        body: json['body'] as String,
        data: Map<String, dynamic>.from(json['data'] as Map),
        notBefore: DateTime.parse(json['at'] as String),
      );

  final String tripId;
  final List<String> userIds;
  final String title;
  final String body;
  final Map<String, dynamic> data;

  /// Not sent before this moment (end of the undo window).
  final DateTime notBefore;

  Map<String, dynamic> toJson() => {
    'trip': tripId,
    'to': userIds,
    'title': title,
    'body': body,
    'data': data,
    'at': notBefore.toUtc().toIso8601String(),
  };
}

/// Sends a push; the app's is `PushNotificationService.sendToUsers`.
typedef TripPushSender =
    Future<void> Function({
      required List<String> userIds,
      required String title,
      required String body,
      Map<String, dynamic>? data,
    });

/// The simplest honest delay for trip pushes: kept on this device in
/// SharedPreferences and sent when the undo window is over. "Widerrufen"
/// cancels them. If the app is closed inside the window, they go out the
/// next time the history starts ([flushDue]). A server-side delay (and
/// texts in each recipient's language) is an owner task in OPEN-ISSUES.
class TripPushQueue {
  TripPushQueue({
    required TripPushSender send,
    Future<SharedPreferences> Function()? prefs,
    DateTime Function()? now,
  }) : _send = send,
       _prefs = prefs ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now;

  static const String storageKey = 'hist_push_queue_v1';

  final TripPushSender _send;
  final Future<SharedPreferences> Function() _prefs;
  final DateTime Function() _now;
  final Map<String, Timer> _timers = {};

  /// Keeps [push] and sends it at [DeferredTripPush.notBefore].
  Future<void> enqueue(DeferredTripPush push) async {
    final all = await _read();
    all.removeWhere((p) => p.tripId == push.tripId);
    all.add(push);
    await _write(all);
    _schedule(push);
  }

  /// Drops the pushes of [tripId] ("Widerrufen").
  Future<void> cancel(String tripId) async {
    _timers.remove(tripId)?.cancel();
    final all = await _read();
    final before = all.length;
    all.removeWhere((p) => p.tripId == tripId);
    if (all.length != before) await _write(all);
  }

  /// The undo window of [tripId] is over: its pushes go out now.
  Future<void> release(String tripId) async {
    final all = await _read();
    final push = all.where((p) => p.tripId == tripId).firstOrNull;
    if (push == null) return;
    final now = DeferredTripPush(
      tripId: push.tripId,
      userIds: push.userIds,
      title: push.title,
      body: push.body,
      data: push.data,
      notBefore: _now(),
    );
    all
      ..removeWhere((p) => p.tripId == tripId)
      ..add(now);
    await _write(all);
    _schedule(now);
  }

  /// Sends every push that is due and schedules the others (app start).
  Future<void> flushDue() async {
    final all = await _read();
    for (final push in all) {
      _schedule(push);
    }
  }

  void _schedule(DeferredTripPush push) {
    _timers.remove(push.tripId)?.cancel();
    final wait = push.notBefore.difference(_now());
    if (wait <= Duration.zero) {
      unawaited(_sendNow(push.tripId));
      return;
    }
    _timers[push.tripId] = Timer(wait, () => unawaited(_sendNow(push.tripId)));
  }

  Future<void> _sendNow(String tripId) async {
    _timers.remove(tripId);
    final all = await _read();
    final push = all.where((p) => p.tripId == tripId).firstOrNull;
    if (push == null) return; // cancelled meanwhile
    all.removeWhere((p) => p.tripId == tripId);
    await _write(all);
    try {
      await _send(
        userIds: push.userIds,
        title: push.title,
        body: push.body,
        data: push.data,
      );
    } catch (e) {
      debugPrint('⚠️ [HISTORY] Trip push not sent: ${e.runtimeType}');
    }
  }

  /// Stops the timers (tests, sign-out). Kept pushes stay stored.
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }

  Future<List<DeferredTripPush>> _read() async {
    try {
      final raw = (await _prefs()).getString(storageKey);
      if (raw == null) return [];
      return [
        for (final entry in jsonDecode(raw) as List)
          DeferredTripPush.fromJson(Map<String, dynamic>.from(entry as Map)),
      ];
    } catch (e) {
      debugPrint('⚠️ [HISTORY] Push queue unreadable: ${e.runtimeType}');
      return [];
    }
  }

  Future<void> _write(List<DeferredTripPush> all) async {
    final prefs = await _prefs();
    if (all.isEmpty) {
      await prefs.remove(storageKey);
    } else {
      await prefs.setString(
        storageKey,
        jsonEncode([for (final p in all) p.toJson()]),
      );
    }
  }
}
