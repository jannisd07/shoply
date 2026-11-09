part of 'avo_chat.dart';

/// Portions an estimate card can count up to (Kap. 7.2, stepper).
const int avoMaxPortions = 10;

/// The state and the actions of every card in the conversation: undo, a
/// retried failed part, check circles, choices, confirm cards, consent and
/// module rows. Kept in the conversation, so scrolling never resets a card.
mixin _AvoCardActions on ChangeNotifier {
  WidgetRef? get _cardRef;
  AvoBackend get _cardBackend;
  bool get _cardsGone;
  List<AvoTurn> get _cardTurns;
  DateTime _cardNow();
  void _cardNotify();
  AvoTurn? get latest;
  void _start(AvoTurn turn, {required bool offline});
  void Function(AvoWidgetPayload change)? get onChangeMade;
  AvoTurn? send(
    String question, {
    bool offline = false,
    bool proHintAllowed = false,
    String? sentText,
  });

  /// Keyed by a payload, or by `(payload, row)` for a row of a card.
  final Map<Object, AvoUndoPhase> _undo = {};
  final Map<String, bool> _checked = {};
  final Map<AvoWidgetPayload, String> _picked = {};
  final Map<AvoWidgetPayload, AvoListChange> _pickResults = {};
  final Map<AvoWidgetPayload, AvoListChange> _replaced = {};
  final Set<AvoWidgetPayload> _partialWorking = {};
  final Map<AvoWidgetPayload, AvoConfirmPhase> _confirm = {};
  final Map<AvoWidgetPayload, bool> _consent = {};
  final Map<AvoWidgetPayload, AvoModulePhase> _modules = {};

  /// Writes made by a tap on a card (estimate, goal, allergy, planned day,
  /// photo note, trip), by the card's payload.
  final Map<AvoWidgetPayload, AvoRecord> _tapRecords = {};

  /// Rows of a card that put one item on a list ("Vielleicht auch").
  final Map<(AvoWidgetPayload, int), AvoListChange> _rowChanges = {};

  /// Card actions that are running.
  final Set<Object> _working = {};
  final Map<AvoWidgetPayload, MealType> _meals = {};
  final Map<AvoWidgetPayload, int> _portions = {};
  final Map<AvoWidgetPayload, Set<int>> _deselected = {};
  final Map<AvoWidgetPayload, String> _importLists = {};
  final Map<AvoWidgetPayload, AvoPhotoIntent> _photoChoices = {};

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
    _tapRecords.clear();
    _rowChanges.clear();
    _working.clear();
    _meals.clear();
    _portions.clear();
    _deselected.clear();
    _importLists.clear();
    _photoChoices.clear();
    _stale.clear();
    _openRows.clear();
  }

  /// The change a card shows: after "Erneut versuchen" on its failed part
  /// the newer one.
  AvoListChange? changeOf(AvoWidgetPayload p) =>
      _replaced[p] ?? p.listChange ?? _pickResults[p];

  AvoUndoPhase undoPhaseOf(Object key) => _undo[key] ?? AvoUndoPhase.idle;

  /// The record a card shows: the tool's, or the one a tap on it made.
  AvoRecord? recordOf(AvoWidgetPayload p) => p.record ?? _tapRecords[p];

  /// "Widerrufen" on a change card or a record.
  Future<void> undo(AvoWidgetPayload p) =>
      undoKey(p, changeOf(p)?.undo ?? recordOf(p)?.undo);

  /// "Widerrufen" for [key] (a payload or a card row) with [run].
  Future<void> undoKey(Object key, AvoUndo? run) async {
    if (run == null || undoPhaseOf(key) != AvoUndoPhase.idle) return;
    _undo[key] = AvoUndoPhase.working;
    notifyListeners();
    AvoUndoResult result;
    try {
      result = await run();
    } catch (e) {
      debugPrint('❌ [AVO_TAB] Undo failed: $e');
      result = AvoUndoResult.failed;
    }
    if (_cardsGone) return;
    _undo[key] = switch (result) {
      AvoUndoResult.undone => AvoUndoPhase.undone,
      AvoUndoResult.changedSince => AvoUndoPhase.changedSince,
      AvoUndoResult.failed => AvoUndoPhase.idle,
    };
    if (result == AvoUndoResult.failed) unawaited(AvoHaptics.error());
    notifyListeners();
  }

  bool isCardWorking(Object key) => _working.contains(key);

  /// Runs a card's write once at a time for [key]; a failure gives the
  /// error haptic and leaves the card as it was.
  Future<T?> _cardWrite<T>(
    Object key,
    Future<T> Function(WidgetRef ref) run,
  ) async {
    final ref = _cardRef;
    if (ref == null || _working.contains(key)) return null;
    _working.add(key);
    notifyListeners();
    try {
      return await run(ref);
    } catch (e) {
      debugPrint('❌ [AVO_TAB] Card action failed: $e');
      unawaited(AvoHaptics.error());
      return null;
    } finally {
      if (!_cardsGone) {
        _working.remove(key);
        notifyListeners();
      }
    }
  }

  // ------------------------------------------------------------- estimate

  MealType mealOf(AvoWidgetPayload p) =>
      _meals[p] ??
      (p.card is AvoEstimateCard
          ? (p.card! as AvoEstimateCard).meal
          : MealType.snack);

  void setMeal(AvoWidgetPayload p, MealType meal) {
    if (_tapRecords.containsKey(p)) return;
    _meals[p] = meal;
    notifyListeners();
  }

  /// Portions of an estimate (1 = what Avo saw), 1 to [avoMaxPortions].
  int portionOf(AvoWidgetPayload p) => _portions[p] ?? 1;

  void setPortion(AvoWidgetPayload p, int portions) {
    if (_tapRecords.containsKey(p)) return;
    _portions[p] = portions.clamp(1, avoMaxPortions);
    notifyListeners();
  }

  /// "Eintragen": only now the diary entry is written (Kap. 7.2).
  Future<void> logEstimate(AvoWidgetPayload p) async {
    final estimate = p.card;
    if (estimate is! AvoEstimateCard || _tapRecords.containsKey(p)) return;
    final record = await _cardWrite(
      p,
      (ref) => _cardBackend.logEstimate(
        ref,
        estimate,
        meal: mealOf(p),
        factor: portionOf(p).toDouble(),
      ),
    );
    if (record != null && !_cardsGone) {
      _tapRecords[p] = record;
      notifyListeners();
    }
  }

  /// The newest estimate of the conversation that is not logged: only it
  /// gets the filled "Eintragen" (Kap. 7.2).
  bool isNewestOpenEstimate(AvoWidgetPayload p) {
    for (final t in _cardTurns.reversed) {
      for (final q in t.payloads.reversed) {
        if (q.card is AvoEstimateCard && !_tapRecords.containsKey(q)) {
          return identical(q, p);
        }
      }
    }
    return false;
  }

  // ----------------------------------------------------------------- goal

  /// "Übernehmen" on a goal preview.
  Future<void> applyGoal(AvoWidgetPayload p) async {
    final preview = p.card;
    if (preview is! AvoGoalPreviewCard || _tapRecords.containsKey(p)) return;
    final record = await _cardWrite(
      p,
      (ref) => _cardBackend.applyGoal(ref, preview),
    );
    if (record != null && !_cardsGone) {
      _tapRecords[p] = record;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- split

  /// The split preview is out of date (trip or split changed since).
  bool isSplitStale(AvoWidgetPayload p) => _stale.contains(p);
  final Set<AvoWidgetPayload> _stale = {};

  /// "Teilen" on a split preview: the only way a split is saved.
  Future<void> splitTrip(AvoWidgetPayload p) async {
    final card = p.card;
    if (card is! AvoSplitPreviewCard ||
        _tapRecords.containsKey(p) ||
        _stale.contains(p)) {
      return;
    }
    var stale = false;
    final record = await _cardWrite(p, (ref) async {
      final r = await _cardBackend.splitTrip(ref, card);
      if (r == null) stale = true;
      return r;
    });
    if (_cardsGone) return;
    if (record != null) _tapRecords[p] = record;
    if (stale) _stale.add(p);
    notifyListeners();
  }

  // ------------------------------------------------------------ trip rows

  /// Unfolded trip rows of a trips card (kept here, so scrolling never
  /// folds them).
  bool isTripOpen(AvoWidgetPayload p, int row) => _openRows.contains((p, row));
  final Set<(AvoWidgetPayload, int)> _openRows = {};

  void toggleTrip(AvoWidgetPayload p, int row) {
    if (!_openRows.remove((p, row))) _openRows.add((p, row));
    notifyListeners();
  }

  // -------------------------------------------------------------- allergy

  /// "Entfernen" on a removal card: the only way an allergy or a diet goes.
  Future<void> removeEntry(AvoWidgetPayload p) async {
    final card = p.card;
    final phase = confirmPhaseOf(p);
    if (card is! AvoRemovalCard ||
        (phase != AvoConfirmPhase.asking && phase != AvoConfirmPhase.failed)) {
      return;
    }
    _confirm[p] = AvoConfirmPhase.working;
    notifyListeners();
    final record = await _cardWrite((
      p,
      'removal',
    ), (ref) => _cardBackend.removeEntry(ref, card));
    if (_cardsGone) return;
    if (record == null) {
      _confirm[p] = AvoConfirmPhase.failed;
    } else {
      _confirm[p] = AvoConfirmPhase.deleted;
      _tapRecords[p] = record;
    }
    notifyListeners();
  }

  // ----------------------------------------------------------------- plan

  /// "Dazulegen" or "Ersetzen" on a day that has a recipe.
  Future<void> choosePlan(AvoWidgetPayload p, {required bool replace}) async {
    final card = p.card;
    if (card is! AvoPlanTakenCard || _picked.containsKey(p)) return;
    _picked[p] = replace ? 'replace' : 'add';
    notifyListeners();
    final record = await _cardWrite(
      p,
      (ref) => _cardBackend.planRecipe(ref, card, replace: replace),
    );
    if (_cardsGone) return;
    if (record == null) {
      _picked.remove(p);
    } else {
      _tapRecords[p] = record;
    }
    notifyListeners();
  }

  // ------------------------------------------------------- items to a list

  /// A row of "Vielleicht auch": puts it on the card's list.
  AvoListChange? rowChangeOf(AvoWidgetPayload p, int row) =>
      _rowChanges[(p, row)];

  Future<void> addRestock(AvoWidgetPayload p, int row) async {
    final card = p.card;
    if (card is! AvoRestockCard ||
        card.listId == null ||
        row >= card.lines.length ||
        _rowChanges.containsKey((p, row))) {
      return;
    }
    final line = card.lines[row];
    final change = await _cardWrite(
      (p, row),
      (ref) => _cardBackend.addItem(
        ref,
        listId: card.listId!,
        name: line.name,
        quantity: line.quantity ?? 1,
      ),
    );
    if (change != null && !_cardsGone) {
      _rowChanges[(p, row)] = change;
      notifyListeners();
    }
  }

  /// "Alle wieder auf {Liste}" on a trips card: the newest trip's items.
  Future<void> addTripAgain(AvoWidgetPayload p) async {
    final card = p.card;
    if (card is! AvoTripsCard ||
        card.listId == null ||
        card.trips.isEmpty ||
        _tapRecords.containsKey(p)) {
      return;
    }
    final trip = card.trips.first;
    final record = await _cardWrite(
      p,
      (ref) => _cardBackend.addItems(
        ref,
        tool: 'add_history_items_to_list',
        source: AvoItemsSource.history,
        listId: card.listId!,
        items: [
          for (final i in trip.items)
            NewItem(
              name: i.name,
              quantity: i.quantity,
              unit: i.unit,
              category: i.category,
            ),
        ],
      ),
    );
    if (record != null && !_cardsGone) {
      _tapRecords[p] = record;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------ photo note

  /// The rows of a photo note that are not chosen (all are at first).
  Set<int> deselectedOf(AvoWidgetPayload p) => _deselected[p] ?? const {};

  void toggleImportRow(AvoWidgetPayload p, int row) {
    if (_tapRecords.containsKey(p)) return;
    final set = {...deselectedOf(p)};
    if (!set.remove(row)) set.add(row);
    _deselected[p] = set;
    notifyListeners();
  }

  /// The list the note goes to: the context's, else the person's choice.
  String? importListOf(AvoWidgetPayload p) =>
      _importLists[p] ??
      (p.card is AvoListImportCard
          ? (p.card! as AvoListImportCard).listId
          : null);

  void pickImportList(AvoWidgetPayload p, String listId) {
    if (_tapRecords.containsKey(p)) return;
    _importLists[p] = listId;
    notifyListeners();
  }

  /// "{n} hinzufügen" on a photo note.
  Future<void> addImport(AvoWidgetPayload p) async {
    final card = p.card;
    final listId = importListOf(p);
    if (card is! AvoListImportCard ||
        listId == null ||
        _tapRecords.containsKey(p)) {
      return;
    }
    final off = deselectedOf(p);
    final items = [
      for (var i = 0; i < card.items.length; i++)
        if (!off.contains(i))
          NewItem(
            name: card.items[i].name,
            quantity: card.items[i].quantity ?? 1,
            unit: card.items[i].unit,
            category: card.items[i].categoryId,
          ),
    ];
    if (items.isEmpty) return;
    final record = await _cardWrite(
      p,
      (ref) => _cardBackend.addItems(
        ref,
        tool: 'list_import',
        source: AvoItemsSource.photo,
        listId: listId,
        items: items,
      ),
    );
    if (record != null && !_cardsGone) {
      _tapRecords[p] = record;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------ photo kind

  AvoPhotoIntent? photoChoiceOf(AvoWidgetPayload p) => _photoChoices[p];

  /// A tap on "Als Essen eintragen" / "Artikel auf eine Liste": the round
  /// reads its photo that way.
  void choosePhoto(
    AvoWidgetPayload p,
    AvoPhotoIntent intent, {
    bool offline = false,
  }) {
    if (_photoChoices.containsKey(p)) return;
    final owner = _cardTurns.where((t) => t.payloads.contains(p)).firstOrNull;
    if (owner == null || !owner.isPhoto) return;
    _photoChoices[p] = intent;
    owner.photoIntent = intent;
    _start(owner, offline: offline);
    _cardNotify();
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
