part of 'avo_chat.dart';

/// The state and the actions of every card in the conversation: undo, a
/// retried failed part, check circles, choices, confirm cards, consent and
/// module rows. Kept in the conversation, so scrolling never resets a card.
mixin _AvoCardActions on ChangeNotifier {
  WidgetRef? get _cardRef;
  AvoBackend get _cardBackend;
  bool get _cardsGone;
  List<AvoTurn> get _cardTurns;
  DateTime _cardNow();
  AvoTurn? get latest;
  void Function(AvoWidgetPayload change)? get onChangeMade;
  AvoTurn? send(
    String question, {
    bool offline = false,
    bool proHintAllowed = false,
    String? sentText,
  });

  final Map<AvoWidgetPayload, AvoUndoPhase> _undo = {};
  final Map<String, bool> _checked = {};
  final Map<AvoWidgetPayload, String> _picked = {};
  final Map<AvoWidgetPayload, AvoListChange> _pickResults = {};
  final Map<AvoWidgetPayload, AvoListChange> _replaced = {};
  final Set<AvoWidgetPayload> _partialWorking = {};
  final Map<AvoWidgetPayload, AvoConfirmPhase> _confirm = {};
  final Map<AvoWidgetPayload, bool> _consent = {};
  final Map<AvoWidgetPayload, AvoModulePhase> _modules = {};

  void _forgetCards() {
    _undo.clear();
    _checked.clear();
    _picked.clear();
    _pickResults.clear();
    _replaced.clear();
    _partialWorking.clear();
    _confirm.clear();
    _consent.clear();
    _modules.clear();
  }

  /// The change a card shows: after "Erneut versuchen" on its failed part
  /// the newer one.
  AvoListChange? changeOf(AvoWidgetPayload p) =>
      _replaced[p] ?? p.listChange ?? _pickResults[p];

  AvoUndoPhase undoPhaseOf(AvoWidgetPayload p) => _undo[p] ?? AvoUndoPhase.idle;

  /// "Widerrufen" on a change card.
  Future<void> undo(AvoWidgetPayload p) async {
    final undo = changeOf(p)?.undo;
    if (undo == null || undoPhaseOf(p) != AvoUndoPhase.idle) return;
    _undo[p] = AvoUndoPhase.working;
    notifyListeners();
    AvoUndoResult result;
    try {
      result = await undo();
    } catch (e) {
      debugPrint('❌ [AVO_TAB] Undo failed: $e');
      result = AvoUndoResult.failed;
    }
    if (_cardsGone) return;
    _undo[p] = switch (result) {
      AvoUndoResult.undone => AvoUndoPhase.undone,
      AvoUndoResult.changedSince => AvoUndoPhase.changedSince,
      AvoUndoResult.failed => AvoUndoPhase.idle,
    };
    if (result == AvoUndoResult.failed) unawaited(AvoHaptics.error());
    notifyListeners();
  }

  /// "Erneut versuchen" on a card's "2 Artikel nicht verschoben" row.
  bool isPartialWorking(AvoWidgetPayload p) => _partialWorking.contains(p);

  Future<void> retryPartial(AvoWidgetPayload p) async {
    final retry = changeOf(p)?.retryFailed;
    if (retry == null || _partialWorking.contains(p)) return;
    _partialWorking.add(p);
    notifyListeners();
    try {
      final next = await retry();
      if (next != null) _replaced[p] = next;
    } catch (e) {
      debugPrint('❌ [AVO_TAB] Retry of the failed part failed: $e');
      unawaited(AvoHaptics.error());
    }
    if (_cardsGone) return;
    _partialWorking.remove(p);
    notifyListeners();
  }

  /// The checked state of [item] after taps in a card.
  bool isChecked(ShoppingItemModel item) => _checked[item.id] ?? item.isChecked;

  /// The check circle of an item row in a card: checks the real item.
  Future<void> setChecked(ShoppingItemModel item, bool checked) async {
    final ref = _cardRef;
    if (item.id.isEmpty || ref == null) return;
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
      if (_cardsGone) return;
      _checked[item.id] = before;
      unawaited(AvoHaptics.error());
      notifyListeners();
    }
  }

  /// The list chosen on an "Auf welche Liste?" card, or null.
  String? pickedListOf(AvoWidgetPayload p) => _picked[p];

  /// The change the choice made, once it is saved.
  AvoListChange? pickResultOf(AvoWidgetPayload p) =>
      _replaced[p] ?? _pickResults[p];

  /// A tap on a list of an "Auf welche Liste?" card.
  Future<void> pick(AvoWidgetPayload p, String listId) async {
    final data = p.pickListData;
    final ref = _cardRef;
    if (data == null || ref == null || _picked.containsKey(p)) return;
    _picked[p] = listId;
    notifyListeners();
    try {
      final change = await _cardBackend.addItem(
        ref,
        listId: listId,
        name: data.itemName,
        quantity: data.quantity,
        unit: data.unit,
      );
      if (_cardsGone) return;
      _pickResults[p] = change;
      onChangeMade?.call(p);
    } catch (e) {
      debugPrint('❌ [AVO_TAB] Add from choice failed: $e');
      if (_cardsGone) return;
      _picked.remove(p);
      unawaited(AvoHaptics.error());
    }
    notifyListeners();
  }

  /// A newer question was asked after [p] without an answer to it.
  bool isChoiceStale(AvoWidgetPayload p) {
    if (_picked.containsKey(p)) return false;
    final owner = _cardTurns.where((t) => t.payloads.contains(p)).firstOrNull;
    return owner != null && !identical(owner, latest);
  }

  AvoConfirmPhase confirmPhaseOf(AvoWidgetPayload p) {
    final phase = _confirm[p];
    if (phase != null) return phase;
    final pending = p.pendingDelete;
    if (pending != null && !_cardNow().isBefore(pending.expiresAt)) {
      return AvoConfirmPhase.expired;
    }
    return AvoConfirmPhase.asking;
  }

  /// The destructive button of a confirm card: only this tap deletes.
  Future<void> confirmDelete(AvoWidgetPayload p) async {
    final pending = p.pendingDelete;
    final ref = _cardRef;
    final phase = confirmPhaseOf(p);
    if (pending == null ||
        ref == null ||
        (phase != AvoConfirmPhase.asking && phase != AvoConfirmPhase.failed)) {
      return;
    }
    _confirm[p] = AvoConfirmPhase.working;
    notifyListeners();
    final outcome = await _cardBackend.confirmDelete(pending.token, ref);
    if (_cardsGone) return;
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

  final Set<Object> _shown = {};

  /// True the first time a card is built, false when it is only scrolled
  /// back into view (focus and scrolling happen once, Kap. 6.4).
  bool firstShowOf(Object card) => _shown.add(card);

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
    if (_cardsGone) return;
    _consent[p] = share;
    notifyListeners();
  }

  AvoModulePhase modulePhaseOf(AvoWidgetPayload p) =>
      _modules[p] ?? AvoModulePhase.off;

  /// "Einschalten" on a module-off row: switches the module on and asks the
  /// question again.
  Future<void> turnOnModule(
    AvoWidgetPayload p, {
    bool offline = false,
    bool proHintAllowed = false,
  }) async {
    final module = p.module;
    final ref = _cardRef;
    if (module == null ||
        ref == null ||
        modulePhaseOf(p) != AvoModulePhase.off) {
      return;
    }
    _modules[p] = AvoModulePhase.working;
    notifyListeners();
    try {
      await ref.read(appModulesProvider.notifier).setEnabled(module, true);
    } catch (e) {
      debugPrint('❌ [AVO_TAB] Module not switched on: $e');
      if (_cardsGone) return;
      _modules[p] = AvoModulePhase.off;
      unawaited(AvoHaptics.error());
      notifyListeners();
      return;
    }
    if (_cardsGone) return;
    _modules[p] = AvoModulePhase.on;
    notifyListeners();
    final owner = _cardTurns.where((t) => t.payloads.contains(p)).firstOrNull;
    if (owner != null) {
      send(owner.question, offline: offline, proHintAllowed: proHintAllowed);
    }
  }

  /// "Widerrufen" after "Einschalten".
  Future<void> undoModule(AvoWidgetPayload p) async {
    final module = p.module;
    final ref = _cardRef;
    if (module == null ||
        ref == null ||
        modulePhaseOf(p) != AvoModulePhase.on) {
      return;
    }
    try {
      await ref.read(appModulesProvider.notifier).setEnabled(module, false);
    } catch (e) {
      debugPrint('❌ [AVO_TAB] Module not switched off: $e');
      unawaited(AvoHaptics.error());
      return;
    }
    if (_cardsGone) return;
    _modules[p] = AvoModulePhase.undone;
    notifyListeners();
  }
}
