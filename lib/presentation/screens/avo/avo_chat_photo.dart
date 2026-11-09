part of 'avo_chat.dart';

/// Photos for Avo (Kap. 7): what a photo is, reading it through `meal_photo`
/// or `list_import`, and the card it becomes. A photo never enters the
/// `avo_chat` history; it stays in this conversation on the device.
mixin _AvoPhotoTurns on ChangeNotifier {
  WidgetRef? get _photoRef;
  AvoBackend get _photoBackend;
  bool get _photoGone;
  AvoScreenContext? _readContext();
  DateTime _photoNow();

  /// The week's one showing of the Pro row after a daily limit.
  AvoProHintGate get _photoProHints;

  CancelToken? _photoCancel;

  /// Completes on "Stopp": the round ends at once, whatever the read does.
  Completer<void>? _photoStop;

  /// The context says what a photo is: on the calories screen a meal (with
  /// the module on), on a list or in shopping mode a shopping note.
  AvoPhotoIntent? _photoIntentFromContext() {
    final screen = _readContext()?.screen;
    if (screen == 'calories' && _caloriesOn) return AvoPhotoIntent.meal;
    if (screen == 'list' || screen == 'shopping') return AvoPhotoIntent.list;
    return null;
  }

  bool get _caloriesOn {
    try {
      return _photoRef?.read(moduleEnabledProvider(AppModule.calories)) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// "Stopp" on a photo round: a note being read is cancelled; a meal
  /// estimate that arrives later is dropped.
  void _stopPhoto() {
    _photoCancel?.cancel();
    _photoCancel = null;
    final stop = _photoStop;
    _photoStop = null;
    if (stop != null && !stop.isCompleted) stop.complete();
  }

  /// Reads [turn]'s photo and adds its card. Without an intent the round
  /// asks "Was soll ich mit dem Foto machen?" and is done.
  Future<void> _runPhoto(
    AvoTurn turn, {
    required bool Function() stopped,
  }) async {
    final photo = turn.photo!;
    final intent = turn.photoIntent;
    if (intent == null) {
      turn.payloads.add(
        AvoWidgetPayload.card(AvoPhotoChoiceCard(caloriesOn: _caloriesOn)),
      );
      turn.phase = AvoTurnPhase.done;
      return;
    }
    turn.step = AvoWorkStep(
      intent == AvoPhotoIntent.meal
          ? 'avo_status_estimate'
          : 'avo_status_photo',
    );
    notifyListeners();

    final stop = _photoStop = Completer<void>();
    final read = intent == AvoPhotoIntent.meal
        ? _readMeal(turn, photo)
        : _readNote(photo);
    // "Stopp" ends the round now; a late estimate is dropped.
    final result = await Future.any<AvoWidgetPayload?>([
      read,
      stop.future.then((_) => null),
    ]);
    if (identical(_photoStop, stop)) _photoStop = null;
    if (_photoGone) return;
    if (result == null || stopped()) {
      turn.phase = AvoTurnPhase.stopped;
      return;
    }
    turn.payloads.add(result);
    turn.phase = AvoTurnPhase.done;
    if (result.card case AvoPhotoErrorCard(code: 'quota_exceeded')) {
      // The daily photo limit (A9-3): Free sees the Pro row, as after the
      // question limit, at most once a week.
      turn.proHint = turn.proHintAllowed && await _photoProHints.take();
      if (_photoGone) return;
    } else if (result.card is AvoPhotoErrorCard) {
      unawaited(AvoHaptics.error());
    } else if (result.card case AvoEstimateCard(
      :final allergens,
    ) when allergens.isNotEmpty) {
      // Once, for the allergen (Kap. 7.4, 12.4).
      unawaited(AvoHaptics.warning());
    }
  }

  Future<AvoWidgetPayload> _readMeal(AvoTurn turn, Uint8List photo) async {
    try {
      final e = await _photoBackend.readMealPhoto(
        photo,
        note: turn.question.isEmpty ? null : turn.question,
      );
      final grams = e.components.fold<int>(0, (sum, c) => sum + c.grams);
      return AvoWidgetPayload.card(
        AvoEstimateCard(
          name: e.foodName,
          kcal: e.calories,
          proteinG: e.proteinG,
          carbsG: e.carbsG,
          fatG: e.fatG,
          confidence: e.confidence,
          meal: avoMealAt(_photoNow()),
          grams: grams > 0 ? grams : null,
          photo: photo,
          allergens: _allergensIn(e),
        ),
      );
    } on MealPhotoException catch (e) {
      return AvoWidgetPayload.card(AvoPhotoErrorCard(code: e.code, meal: true));
    } catch (e) {
      debugPrint('❌ [AVO_TAB] Meal photo failed: $e');
      return AvoWidgetPayload.card(
        const AvoPhotoErrorCard(code: 'provider_error', meal: true),
      );
    }
  }

  Future<AvoWidgetPayload> _readNote(Uint8List photo) async {
    final cancel = CancelToken();
    _photoCancel = cancel;
    try {
      final r = await _photoBackend.readListPhoto(photo, cancel);
      final listId = _readContext()?.listId;
      return AvoWidgetPayload.card(
        AvoListImportCard(
          items: r.items,
          unreadable: r.unparsedLines,
          listId: listId,
        ),
      );
    } on ListImportException catch (e) {
      return AvoWidgetPayload.card(
        AvoPhotoErrorCard(
          code: e.serverCode == 'quota_exceeded' ? 'quota_exceeded' : e.code,
          meal: false,
        ),
      );
    } catch (e) {
      debugPrint('❌ [AVO_TAB] Note photo failed: $e');
      return AvoWidgetPayload.card(
        const AvoPhotoErrorCard(code: 'provider_error', meal: false),
      );
    } finally {
      if (identical(_photoCancel, cancel)) _photoCancel = null;
    }
  }

  /// The person's allergies the meal probably holds: by name in the dish
  /// and its parts, and by the allergen types Avo saw. Matched on the
  /// device; a hint, never a promise of the opposite.
  List<String> _allergensIn(MealPhotoEstimate e) {
    final List<String> allergies;
    try {
      allergies =
          _photoRef?.read(currentUserProvider).valueOrNull?.allergies ??
          const [];
    } catch (_) {
      return const [];
    }
    if (allergies.isEmpty) return const [];
    final matcher = AllergenMatcher(allergies);
    final found = <String>{
      for (final m in matcher.matchesAll([
        e.foodName,
        for (final c in e.components) c.name,
      ]))
        m.allergy,
    };
    for (final allergy in allergies) {
      final type = AllergenMatcher.resolve(allergy);
      if (type != null && e.allergens.contains(type)) found.add(allergy);
    }
    return [
      for (final a in allergies)
        if (found.contains(a)) a,
    ];
  }
}
