import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/data/services/avo_consents.dart';
import 'package:shoply/data/services/avo_conversation.dart';
import 'package:shoply/presentation/providers/avo_screen_context_provider.dart';
import 'package:shoply/presentation/screens/avo/avo_backend.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';

/// Where one question of the Avo tab stands (Kap. 3.2, 3.3).
enum AvoTurnPhase {
  /// Sent while another answer was running: "Wird nach dieser Antwort
  /// gesendet".
  queued,

  /// Offline when sent: "Nicht gesendet · Erneut senden". Never resent by
  /// itself.
  notSent,

  /// Avo is answering (status line, then cards and text).
  working,

  /// Answered.
  done,

  /// Stopped with "Stopp" (or the app was left mid-answer): "Angehalten."
  stopped,

  /// The answer failed; [AvoTurn.errorCode] says why.
  failed,
}

/// The status line text while Avo works (table 3.4): a translation key and
/// its parameters.
@immutable
class AvoWorkStep {
  const AvoWorkStep(this.key, [this.params = const {}]);

  static const thinking = AvoWorkStep('avo_status_thinking');

  final String key;
  final Map<String, String> params;

  @override
  bool operator ==(Object other) =>
      other is AvoWorkStep &&
      other.key == key &&
      mapEquals(other.params, params);

  @override
  int get hashCode => Object.hash(
    key,
    Object.hashAll(params.entries.map((e) => Object.hash(e.key, e.value))),
  );
}

/// The status line step for the tool [name] the app is about to run, with
/// the list name from [listName] ("Schreibt auf Wocheneinkauf"). Unknown or
/// unnamed targets fall back to "Denkt nach".
AvoWorkStep avoWorkStepFor(
  String name,
  Map<String, Object?> input, {
  String? Function(String listId)? listName,
}) {
  String? list(String key) {
    final id = input[key];
    if (id is! String || id.isEmpty) return null;
    final n = listName?.call(id)?.trim();
    return n == null || n.isEmpty ? null : n;
  }

  AvoWorkStep withList(String key, String? name) =>
      name == null ? AvoWorkStep.thinking : AvoWorkStep(key, {'list': name});

  switch (name) {
    case 'get_list_contents':
      return withList('avo_status_reading_list', list('list_id'));
    case 'add_item_to_list':
    case 'check_items':
    case 'update_item':
    case 'complete_list':
    case 'add_history_items_to_list':
    case 'add_recipe_to_list':
    case 'plan_to_list':
      return withList('avo_status_writing_list', list('list_id'));
    case 'move_items':
      return withList('avo_status_writing_list', list('to_list_id'));
    case 'search_recipes':
    case 'get_saved_recipes':
    case 'get_recipe_nutrition':
      return const AvoWorkStep('avo_status_recipes');
    case 'log_food':
      return const AvoWorkStep('avo_status_estimate');
    case 'get_plan':
    case 'add_to_plan':
    case 'move_in_plan':
      return const AvoWorkStep('avo_status_plan');
    case 'update_setting':
    case 'set_module':
    case 'setup_nutrition_goal':
      return const AvoWorkStep('avo_status_setting');
    case 'get_shopping_history':
    case 'get_restock_suggestions':
    case 'get_savings_summary':
      return const AvoWorkStep('avo_status_history');
    default:
      return AvoWorkStep.thinking;
  }
}

/// One question and its answer in the Avo tab.
class AvoTurn {
  AvoTurn._(this.id, this.question, this.askedAt);

  final int id;
  final String question;
  final DateTime askedAt;

  AvoTurnPhase phase = AvoTurnPhase.working;

  /// What the status line says while [phase] is [AvoTurnPhase.working].
  AvoWorkStep step = AvoWorkStep.thinking;

  /// The answer text; grows while it is written. Its own notifier so only
  /// the text rebuilds per word.
  final ValueNotifier<String> text = ValueNotifier('');

  /// Result cards, in the order their tools finished.
  final List<AvoWidgetPayload> payloads = [];

  /// Why it failed (see [AvoResponse.errorCode]).
  String? errorCode;

  /// When "Erneut versuchen" turns active again (`rate_limited`).
  DateTime? retryAt;

  /// Avo refused: the text is `avo_err_refused`, without an error symbol.
  bool refused = false;

  /// Daily limit reached on Free: the Pro row may show (once a week).
  bool proHint = false;

  /// Whether the status line still holds the place of the answer.
  bool get showsStatus =>
      phase == AvoTurnPhase.working && payloads.isEmpty && text.value.isEmpty;

  void _restart() {
    phase = AvoTurnPhase.working;
    step = AvoWorkStep.thinking;
    text.value = '';
    payloads.clear();
    errorCode = null;
    retryAt = null;
    refused = false;
    proHint = false;
  }
}

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

/// The conversation of the Avo tab: the questions, their answers and the
/// state of every card. Lives as long as the account (a new account gets a
/// new one), so leaving the tab mid-answer lets the answer finish.
///
/// Works with the [WidgetRef] of the tab that sent the question: the tools
/// run with the person's providers.
class AvoChat extends ChangeNotifier {
  AvoChat(this._backend, {DateTime Function()? now, AvoProHintGate? proHints})
    : _now = now ?? DateTime.now,
      _proHints = proHints ?? const _PrefsProHintGate();

  final AvoBackend _backend;
  final DateTime Function() _now;
  final AvoProHintGate _proHints;

  final List<AvoTurn> _turns = [];
  int _nextId = 0;
  AvoTurn? _active;
  bool _stopRequested = false;
  DateTime? _lastActivity;
  bool _disposed = false;

  /// "Neues Gespräch" until it is undone or the next question goes out.
  List<AvoTurn>? _cleared;

  AvoScreenContext? _askedContext;

  final Map<AvoWidgetPayload, AvoUndoPhase> _undo = {};
  final Map<String, bool> _checked = {};
  final Map<AvoWidgetPayload, String> _picked = {};
  final Map<AvoWidgetPayload, AvoListChange> _pickResults = {};
  final Map<AvoWidgetPayload, AvoConfirmPhase> _confirm = {};
  final Map<AvoWidgetPayload, bool> _consent = {};
  final Map<AvoWidgetPayload, AvoModulePhase> _modules = {};

  /// Called once per answer when it is complete (for the VoiceOver
  /// announcement).
  void Function(AvoTurn turn)? onTurnFinished;

  List<AvoTurn> get turns => List.unmodifiable(_turns);
  bool get isEmpty => _turns.isEmpty;
  bool get isWorking => _active != null;
  AvoTurn? get latest => _turns.isEmpty ? null : _turns.last;

  /// The screen context the last question was asked in (the context chip
  /// hides while it is the same).
  AvoScreenContext? get askedContext => _askedContext;

  /// The newest turn that is done (it carries the follow-up chips).
  bool isLatestDone(AvoTurn turn) =>
      identical(turn, latest) && turn.phase == AvoTurnPhase.done;

  // ------------------------------------------------------------- questions

  /// Sends [question] (trimmed; empty does nothing). While an answer runs it
  /// waits as "Wird nach dieser Antwort gesendet"; offline it stays as "Nicht
  /// gesendet". [isFree] decides whether the Pro row may follow a daily
  /// limit.
  AvoTurn? send(
    String question,
    WidgetRef ref, {
    bool offline = false,
    bool isFree = true,
  }) {
    final text = question.trim();
    if (text.isEmpty) return null;
    expireIfStale();
    if (_cleared != null) {
      _cleared = null;
      _forgetCards();
      _backend.reset();
    }
    _askedContext = _readContext(ref);
    final turn = AvoTurn._(_nextId++, text, _now());
    _turns.add(turn);
    _lastActivity = _now();
    if (offline) {
      turn.phase = AvoTurnPhase.notSent;
      notifyListeners();
    } else if (_active != null) {
      turn.phase = AvoTurnPhase.queued;
      notifyListeners();
    } else {
      unawaited(_run(turn, ref, isFree: isFree));
    }
    return turn;
  }

  /// "Erneut senden" / "Erneut versuchen" on [turn].
  void retry(
    AvoTurn turn,
    WidgetRef ref, {
    bool offline = false,
    bool isFree = true,
  }) {
    if (!_turns.contains(turn) || identical(turn, _active)) return;
    turn._restart();
    if (offline) {
      turn.phase = AvoTurnPhase.notSent;
      notifyListeners();
    } else if (_active != null) {
      turn.phase = AvoTurnPhase.queued;
      notifyListeners();
    } else {
      unawaited(_run(turn, ref, isFree: isFree));
    }
  }

  /// "Stopp" / "Antwort anhalten": done changes stay with "Widerrufen".
  void stop() {
    if (_active == null) return;
    _stopRequested = true;
    _backend.stop();
  }

  Future<void> _run(AvoTurn turn, WidgetRef ref, {required bool isFree}) async {
    _active = turn;
    _stopRequested = false;
    turn.phase = AvoTurnPhase.working;
    notifyListeners();

    AvoResponse? response;
    try {
      response = await _backend.ask(
        turn.question,
        ref,
        onText: (delta) {
          if (!identical(_active, turn) || _disposed) return;
          final wasEmpty = turn.text.value.isEmpty;
          turn.text.value += delta;
          if (wasEmpty) notifyListeners();
        },
        onTool: (name, input) {
          if (!identical(_active, turn) || _disposed) return;
          // Text before a tool is narration the answer replaces.
          turn.text.value = '';
          turn.step = avoWorkStepFor(
            name,
            input,
            listName: (id) => _listName(ref, id),
          );
          notifyListeners();
        },
        onPayload: (payload) {
          if (_disposed || turn.payloads.contains(payload)) return;
          turn.payloads.add(payload);
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('❌ [AVO_TAB] Answer failed: $e');
    }
    if (_disposed) return;
    await _finish(turn, response, isFree: isFree);
    _active = null;
    _lastActivity = _now();
    if (_disposed) return;
    notifyListeners();
    onTurnFinished?.call(turn);

    final next = _turns
        .where((t) => t.phase == AvoTurnPhase.queued)
        .firstOrNull;
    if (next != null) unawaited(_run(next, ref, isFree: isFree));
  }

  Future<void> _finish(
    AvoTurn turn,
    AvoResponse? response, {
    required bool isFree,
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
        turn.proHint = isFree && await _proHints.take();
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

  /// "Neues Gespräch": empties the tab at once; [undoNewConversation] brings
  /// it back until the next question goes out.
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

  /// A conversation ends after a day without activity (Kap. 16).
  void expireIfStale() {
    final last = _lastActivity;
    if (last == null || _active != null) return;
    if (_now().difference(last) <= AvoConversation.lifetime) return;
    _turns.clear();
    _cleared = null;
    _lastActivity = null;
    _forgetCards();
    _backend.reset();
    notifyListeners();
  }

  void _forgetCards() {
    _undo.clear();
    _checked.clear();
    _picked.clear();
    _pickResults.clear();
    _confirm.clear();
    _consent.clear();
    _modules.clear();
  }

  // ---------------------------------------------------------------- cards

  AvoUndoPhase undoPhaseOf(AvoWidgetPayload p) => _undo[p] ?? AvoUndoPhase.idle;

  /// "Widerrufen" on a change card.
  Future<void> undo(AvoWidgetPayload p) async {
    final undo = p.listChange?.undo ?? _pickResults[p]?.undo;
    if (undo == null || undoPhaseOf(p) != AvoUndoPhase.idle) return;
    _undo[p] = AvoUndoPhase.working;
    notifyListeners();
    final result = await undo();
    if (_disposed) return;
    _undo[p] = switch (result) {
      AvoUndoResult.undone => AvoUndoPhase.undone,
      AvoUndoResult.changedSince => AvoUndoPhase.changedSince,
      AvoUndoResult.failed => AvoUndoPhase.idle,
    };
    if (result == AvoUndoResult.failed) unawaited(AvoHaptics.error());
    notifyListeners();
  }

  /// The checked state of [item] after taps in a card.
  bool isChecked(ShoppingItemModel item) => _checked[item.id] ?? item.isChecked;

  /// The check circle of an item row in a card: checks the real item.
  Future<void> setChecked(
    ShoppingItemModel item,
    bool checked,
    WidgetRef ref,
  ) async {
    if (item.id.isEmpty) return;
    final before = isChecked(item);
    _checked[item.id] = checked;
    notifyListeners();
    try {
      await ref
          .read(itemRepositoryProvider)
          .toggleItemChecked(item.id, checked);
      // Refresh an open list without creating a notifier for closed ones.
      if (ref.exists(itemsNotifierProvider(item.listId))) {
        unawaited(
          ref.read(itemsNotifierProvider(item.listId).notifier).loadItems(),
        );
      }
    } catch (e) {
      debugPrint('❌ [AVO_TAB] Check failed: $e');
      if (_disposed) return;
      _checked[item.id] = before;
      unawaited(AvoHaptics.error());
      notifyListeners();
    }
  }

  /// The list chosen on an "Auf welche Liste?" card, or null.
  String? pickedListOf(AvoWidgetPayload p) => _picked[p];

  /// The change the choice made, once it is saved.
  AvoListChange? pickResultOf(AvoWidgetPayload p) => _pickResults[p];

  /// A tap on a list of an "Auf welche Liste?" card.
  Future<void> pick(AvoWidgetPayload p, String listId, WidgetRef ref) async {
    final data = p.pickListData;
    if (data == null || _picked.containsKey(p)) return;
    _picked[p] = listId;
    notifyListeners();
    try {
      final change = await _backend.addItem(
        ref,
        listId: listId,
        name: data.itemName,
        quantity: data.quantity,
        unit: data.unit,
      );
      if (_disposed) return;
      _pickResults[p] = change;
    } catch (e) {
      debugPrint('❌ [AVO_TAB] Add from choice failed: $e');
      if (_disposed) return;
      _picked.remove(p);
      unawaited(AvoHaptics.error());
    }
    notifyListeners();
  }

  /// A newer question was asked after [p] without an answer to it.
  bool isChoiceStale(AvoWidgetPayload p) {
    if (_picked.containsKey(p)) return false;
    final owner = _turns.where((t) => t.payloads.contains(p)).firstOrNull;
    return owner != null && !identical(owner, latest);
  }

  AvoConfirmPhase confirmPhaseOf(AvoWidgetPayload p) {
    final phase = _confirm[p];
    if (phase != null) return phase;
    final pending = p.pendingDelete;
    if (pending != null && !_now().isBefore(pending.expiresAt)) {
      return AvoConfirmPhase.expired;
    }
    return AvoConfirmPhase.asking;
  }

  /// The destructive button of a confirm card: only this tap deletes.
  Future<void> confirmDelete(AvoWidgetPayload p, WidgetRef ref) async {
    final pending = p.pendingDelete;
    final phase = confirmPhaseOf(p);
    if (pending == null ||
        (phase != AvoConfirmPhase.asking && phase != AvoConfirmPhase.failed)) {
      return;
    }
    _confirm[p] = AvoConfirmPhase.working;
    notifyListeners();
    final outcome = await _backend.confirmDelete(pending.token, ref);
    if (_disposed) return;
    _confirm[p] = switch (outcome) {
      AvoDeleteOutcome.deleted => AvoConfirmPhase.deleted,
      AvoDeleteOutcome.expired => AvoConfirmPhase.expired,
      AvoDeleteOutcome.failed => AvoConfirmPhase.failed,
    };
    if (outcome == AvoDeleteOutcome.failed) unawaited(AvoHaptics.error());
    notifyListeners();
  }

  void cancelDelete(AvoWidgetPayload p) {
    if (confirmPhaseOf(p) != AvoConfirmPhase.asking) return;
    _confirm[p] = AvoConfirmPhase.cancelled;
    notifyListeners();
  }

  /// Re-reads expiry (the card's timer after 10 minutes).
  void refreshConfirm() => notifyListeners();

  /// null: not answered; true: shared; false: "Nicht jetzt".
  bool? consentOf(AvoWidgetPayload p) => _consent[p];

  Future<void> answerConsent(AvoWidgetPayload p, {required bool share}) async {
    final kind = p.consentKind;
    if (kind == null || _consent.containsKey(p)) return;
    if (share) {
      try {
        if (kind == AvoConsentKind.body) {
          await AvoConsents.set(body: true);
        } else {
          await AvoConsents.set(health: true);
        }
      } catch (e) {
        debugPrint('❌ [AVO_TAB] Consent not saved: $e');
        unawaited(AvoHaptics.error());
        return;
      }
    }
    if (_disposed) return;
    _consent[p] = share;
    notifyListeners();
  }

  AvoModulePhase modulePhaseOf(AvoWidgetPayload p) =>
      _modules[p] ?? AvoModulePhase.off;

  /// "Einschalten" on a module-off row: switches the module on and asks the
  /// question again.
  Future<void> turnOnModule(
    AvoWidgetPayload p,
    WidgetRef ref, {
    bool offline = false,
    bool isFree = true,
  }) async {
    final module = p.module;
    if (module == null || modulePhaseOf(p) != AvoModulePhase.off) return;
    _modules[p] = AvoModulePhase.working;
    notifyListeners();
    try {
      await ref.read(appModulesProvider.notifier).setEnabled(module, true);
    } catch (e) {
      debugPrint('❌ [AVO_TAB] Module not switched on: $e');
      if (_disposed) return;
      _modules[p] = AvoModulePhase.off;
      unawaited(AvoHaptics.error());
      notifyListeners();
      return;
    }
    if (_disposed) return;
    _modules[p] = AvoModulePhase.on;
    notifyListeners();
    final owner = _turns.where((t) => t.payloads.contains(p)).firstOrNull;
    if (owner != null) {
      send(owner.question, ref, offline: offline, isFree: isFree);
    }
  }

  /// "Widerrufen" after "Einschalten".
  Future<void> undoModule(AvoWidgetPayload p, WidgetRef ref) async {
    final module = p.module;
    if (module == null || modulePhaseOf(p) != AvoModulePhase.on) return;
    try {
      await ref.read(appModulesProvider.notifier).setEnabled(module, false);
    } catch (e) {
      debugPrint('❌ [AVO_TAB] Module not switched off: $e');
      unawaited(AvoHaptics.error());
      return;
    }
    if (_disposed) return;
    _modules[p] = AvoModulePhase.undone;
    notifyListeners();
  }

  // ---------------------------------------------------------------- helpers

  static AvoScreenContext? _readContext(WidgetRef ref) {
    try {
      return ref.read(avoScreenContextProvider);
    } catch (_) {
      return null;
    }
  }

  static String? _listName(WidgetRef ref, String listId) =>
      ref.read(avoListsProvider).where((l) => l.id == listId).firstOrNull?.name;

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
