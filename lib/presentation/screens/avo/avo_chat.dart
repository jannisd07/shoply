import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/data/services/avo_consents.dart';
import 'package:shoply/data/services/avo_conversation.dart';
import 'package:shoply/presentation/providers/avo_screen_context_provider.dart';
import 'package:shoply/presentation/screens/avo/avo_backend.dart';
import 'package:shoply/presentation/screens/avo/avo_chat_state.dart';
import 'package:shoply/presentation/screens/avo/avo_turn.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';

export 'package:shoply/presentation/screens/avo/avo_chat_state.dart';
export 'package:shoply/presentation/screens/avo/avo_turn.dart';

part 'avo_chat_cards.dart';

/// The conversation of the Avo tab: the questions, their answers and the
/// state of every card. Lives as long as the account (a new account gets a
/// new one), so leaving the tab mid-answer lets the answer finish.
///
/// Everything that runs later (answers, undo, retry, choices) uses the
/// [WidgetRef] of the tab root ([attach]), which stays mounted in its tab;
/// never the ref of a round that may scroll away and be disposed.
class AvoChat extends ChangeNotifier with _AvoCardActions {
  AvoChat(this._backend, {DateTime Function()? now, AvoProHintGate? proHints})
    : _now = now ?? DateTime.now,
      _proHints = proHints ?? avoPrefsProHintGate;

  final AvoBackend _backend;
  final DateTime Function() _now;
  final AvoProHintGate _proHints;

  WidgetRef? _ref;

  final List<AvoTurn> _turns = [];
  int _nextId = 0;
  AvoTurn? _active;
  bool _stopRequested = false;
  DateTime? _lastActivity;
  bool _disposed = false;
  bool _slow = false;

  /// "Neues Gespräch" until it is undone or the next question goes out.
  List<AvoTurn>? _cleared;

  /// The service conversation is reset before the next answer starts (never
  /// under an answer that is still finishing).
  bool _resetPending = false;

  AvoScreenContext? _askedContext;

  /// Called once per answer when it is complete (VoiceOver announcement).
  void Function(AvoTurn turn)? onTurnFinished;

  /// Called for every change Avo makes (toast while the tab is not visible).
  @override
  void Function(AvoWidgetPayload change)? onChangeMade;

  /// The tab root hands over its ref (every build).
  void attach(WidgetRef ref) => _ref = ref;

  @override
  WidgetRef? get _cardRef => _ref;

  @override
  AvoBackend get _cardBackend => _backend;

  @override
  bool get _cardsGone => _disposed;

  @override
  List<AvoTurn> get _cardTurns => _turns;

  @override
  DateTime _cardNow() => _now();

  List<AvoTurn> get turns => List.unmodifiable(_turns);
  bool get isEmpty => _turns.isEmpty;
  bool get isWorking => _active != null;
  @override
  AvoTurn? get latest => _turns.isEmpty ? null : _turns.last;

  /// The last answer hit transport trouble (timeout, broken stream) and
  /// nothing has arrived since ("Verbindung schlecht", Kap. 3.3, until Kap.
  /// 20's connection state exists).
  bool get slowConnection => _slow;

  /// The screen context the last question was asked in (the context chip
  /// hides while it is the same).
  AvoScreenContext? get askedContext => _askedContext;

  /// The newest turn that is done (it carries the follow-up chips).
  bool isLatestDone(AvoTurn turn) =>
      identical(turn, latest) && turn.phase == AvoTurnPhase.done;

  // ------------------------------------------------------------- questions

  /// Sends [question] (trimmed; empty does nothing). While an answer runs it
  /// waits as "Wird nach dieser Antwort gesendet"; offline it stays as "Nicht
  /// gesendet". [proHintAllowed] (Free and a known Pro limit) lets the Pro
  /// row follow a daily limit, using up that week's one showing.
  @override
  AvoTurn? send(
    String question, {
    bool offline = false,
    bool proHintAllowed = false,
    String? sentText,
    List<AvoWidgetPayload> carried = const [],
  }) {
    final text = question.trim();
    if (text.isEmpty || _ref == null) return null;
    expireIfStale();
    if (_cleared != null) {
      _cleared = null;
      _resetPending = true;
    }
    _askedContext = _readContext();
    final turn = AvoTurn(
      _nextId++,
      text,
      _now(),
      sentText: sentText,
      carried: carried,
      proHintAllowed: proHintAllowed,
    );
    _turns.add(turn);
    _lastActivity = _now();
    _start(turn, offline: offline);
    return turn;
  }

  void _start(AvoTurn turn, {required bool offline}) {
    if (offline) {
      turn.phase = AvoTurnPhase.notSent;
      notifyListeners();
    } else if (_active != null) {
      turn.phase = AvoTurnPhase.queued;
      notifyListeners();
    } else {
      unawaited(_run(turn));
    }
  }

  /// "Erneut senden" / "Erneut versuchen" on [turn]. Without done changes of
  /// its own the round starts over in place (keeping a note it already
  /// carries). With done changes (any write: list changes, settings, recipes
  /// to a list, logs, modules) they keep their cards and "Widerrufen", and
  /// the question goes out as a new round with [doneNote], which must cover
  /// [AvoTurn.doneChanges] (this round's and every earlier one's), so
  /// nothing is done twice.
  void retry(
    AvoTurn turn, {
    bool offline = false,
    bool proHintAllowed = false,
    String? doneNote,
  }) {
    if (!_turns.contains(turn) || identical(turn, _active)) return;
    if (turn.payloads.any((p) => p.isDoneChange)) {
      turn.retried = true;
      final note = doneNote?.trim();
      send(
        turn.question,
        offline: offline,
        proHintAllowed: proHintAllowed,
        carried: turn.doneChanges,
        sentText: note == null || note.isEmpty
            ? null
            : '${turn.question}\n\n$note',
      );
      return;
    }
    turn.restart();
    _start(turn, offline: offline);
  }

  /// "Stopp" / "Antwort anhalten": done changes stay with "Widerrufen".
  void stop() {
    if (_active == null) return;
    _stopRequested = true;
    _backend.stop();
  }

  Future<void> _run(AvoTurn turn) async {
    final ref = _ref;
    if (ref == null) return;
    if (_resetPending) {
      _resetPending = false;
      _forgetCards();
      _backend.reset();
    }
    _active = turn;
    _stopRequested = false;
    turn.phase = AvoTurnPhase.working;
    notifyListeners();

    // Anything arriving from Avo means the connection carries again.
    void firstEvent() {
      if (!_slow) return;
      _slow = false;
      notifyListeners();
    }

    AvoResponse? response;
    try {
      response = await _backend.ask(
        turn.sentText ?? turn.question,
        ref,
        onText: (delta) {
          if (!identical(_active, turn) || _disposed) return;
          firstEvent();
          final wasEmpty = turn.text.value.isEmpty;
          turn.text.value += delta;
          if (wasEmpty) notifyListeners();
        },
        onTool: (name, input) {
          if (!identical(_active, turn) || _disposed) return;
          firstEvent();
          // Text before a tool is narration the answer replaces.
          turn.text.value = '';
          turn.step = avoWorkStepFor(name, input, listName: _listName);
          notifyListeners();
        },
        onPayload: (payload) {
          if (_disposed || turn.payloads.contains(payload)) return;
          turn.payloads.add(payload);
          notifyListeners();
          if (payload.kind == AvoPayloadKind.listChange &&
              _turns.contains(turn)) {
            onChangeMade?.call(payload);
          }
        },
      );
    } catch (e) {
      debugPrint('❌ [AVO_TAB] Answer failed: $e');
    }
    if (_disposed) return;
    // "Verbindung schlecht" only for transport trouble (no event in time, a
    // broken stream), never for a slow but working answer.
    final code = response?.errorCode;
    if (code == 'timeout' || code == 'network_error') {
      _slow = true;
    } else if (response != null && code == null) {
      _slow = false;
    }
    await _finish(turn, response, proHintAllowed: turn.proHintAllowed);
    _active = null;
    _lastActivity = _now();
    if (_disposed) return;
    notifyListeners();
    if (_turns.contains(turn)) onTurnFinished?.call(turn);

    final next = _turns
        .where((t) => t.phase == AvoTurnPhase.queued)
        .firstOrNull;
    if (next != null) unawaited(_run(next));
  }

  Future<void> _finish(
    AvoTurn turn,
    AvoResponse? response, {
    required bool proHintAllowed,
  }) async {
    for (final p in response?.payloads ?? const <AvoWidgetPayload>[]) {
      if (!turn.payloads.contains(p)) turn.payloads.add(p);
    }
    if (_stopRequested) {
      turn.phase = AvoTurnPhase.stopped;
      return;
    }
    final code = response == null ? 'generic' : response.errorCode;
    if (code == null) {
      turn.phase = AvoTurnPhase.done;
      turn.text.value = response!.message;
      return;
    }
    turn.text.value = '';
    switch (code) {
      case 'refused':
        turn.phase = AvoTurnPhase.done;
        turn.refused = true;
      case 'network_error' when turn.payloads.isEmpty:
        turn.phase = AvoTurnPhase.notSent;
      case 'quota_exceeded':
        turn.phase = AvoTurnPhase.failed;
        turn.errorCode = code;
        turn.proHint = proHintAllowed && await _proHints.take();
      default:
        turn.phase = AvoTurnPhase.failed;
        turn.errorCode = code;
        final wait = response?.retryAfterS;
        if (wait != null && wait > 0) {
          turn.retryAt = _now().add(Duration(seconds: wait));
        }
        unawaited(AvoHaptics.error());
    }
  }

  // ---------------------------------------------------------- conversation

  /// "Neues Gespräch": empties the tab at once and stops a running answer;
  /// [undoNewConversation] brings it back until the next question goes out.
  void newConversation() {
    if (_turns.isEmpty) return;
    stop();
    _cleared = List.of(_turns);
    _turns.clear();
    _askedContext = null;
    notifyListeners();
  }

  /// "Widerrufen" on the "Neues Gespräch begonnen" toast.
  void undoNewConversation() {
    final cleared = _cleared;
    if (cleared == null || _turns.isNotEmpty) return;
    _turns.addAll(cleared);
    _cleared = null;
    notifyListeners();
  }

  /// A conversation ends after a day without activity (Kap. 16). Checked on
  /// every question and whenever the tab shows again.
  void expireIfStale() {
    final last = _lastActivity;
    if (last == null || _active != null) return;
    if (_now().difference(last) <= AvoConversation.lifetime) return;
    _turns.clear();
    _cleared = null;
    _lastActivity = null;
    _resetPending = false;
    _forgetCards();
    _backend.reset();
    notifyListeners();
  }

  // ---------------------------------------------------------------- helpers

  AvoScreenContext? _readContext() {
    try {
      return _ref?.read(avoScreenContextProvider);
    } catch (_) {
      return null;
    }
  }

  String? _listName(String listId) => _ref
      ?.read(avoListsProvider)
      .where((l) => l.id == listId)
      .firstOrNull
      ?.name;

  @override
  void dispose() {
    _disposed = true;
    if (_active != null) _backend.stop();
    for (final t in [..._turns, ...?_cleared]) {
      t.text.dispose();
    }
    super.dispose();
  }
}

/// The person's lists as the Avo tab shows them (cards, choices, context).
/// Overridden in tests.
final avoListsProvider = Provider<List<ShoppingListModel>>(
  (ref) => ref.watch(listsNotifierProvider).valueOrNull ?? const [],
);

/// The Avo tab's conversation. Rebuilt for every account, so sign-out and
/// account switches drop the conversation, the context and every undo.
final avoChatProvider = ChangeNotifierProvider<AvoChat>((ref) {
  ref.watch(authUserIdProvider);
  return AvoChat(ref.watch(avoBackendProvider));
});
