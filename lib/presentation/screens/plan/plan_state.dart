import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/services/shared_preferences_provider.dart';
import 'package:shoply/data/models/meal_plan.dart';
import 'package:shoply/data/services/meal_plan_aggregator.dart';
import 'package:shoply/presentation/providers/avo_screen_context_provider.dart';
import 'package:shoply/presentation/providers/meal_plan_provider.dart';

// Wochenplan (B7) screens: what the plan overview shows right now (which
// week, edit mode, the undo toast in place of the capsule, a failed send)
// and the per-entry status the rows and the capsule read
// (`wochenplan.md` 4.1.4, 4.1.5, 4.1.13).

/// Weeks the plan reaches from the current one (±52, 3.4).
const int kPlanWeekReach = 52;

/// How long the undo toast takes the capsule's place (3.6).
const Duration kPlanToastTime = Duration(seconds: 4);
const Duration kPlanToastTimeVoiceOver = Duration(seconds: 10);

/// Ingredients that could not go on the list after a send (4.1.9).
class PlanSendFailure {
  const PlanSendFailure({required this.weekStart, required this.names, required this.count});

  final DateTime weekStart;
  final List<String> names;
  final int count;
}

@immutable
class PlanViewState {
  const PlanViewState({
    required this.weekStart,
    this.editing = false,
    this.focusDay,
    this.focusSerial = 0,
    this.toastUntil,
    this.failure,
  });

  /// Monday of the week shown.
  final DateTime weekStart;

  /// "Bearbeiten": minus circles and grips instead of steppers (4.1.7).
  final bool editing;

  /// A day to scroll to (`?day=`, after "Rezept wählen"); [focusSerial]
  /// changes with every request.
  final DateTime? focusDay;
  final int focusSerial;

  /// The undo toast stands where the capsule is until then.
  final DateTime? toastUntil;

  /// The last send that left ingredients out.
  final PlanSendFailure? failure;

  PlanViewState copyWith({
    DateTime? weekStart,
    bool? editing,
    DateTime? focusDay,
    int? focusSerial,
    DateTime? toastUntil,
    PlanSendFailure? failure,
    bool clearToast = false,
    bool clearFailure = false,
  }) =>
      PlanViewState(
        weekStart: weekStart ?? this.weekStart,
        editing: editing ?? this.editing,
        focusDay: focusDay ?? this.focusDay,
        focusSerial: focusSerial ?? this.focusSerial,
        toastUntil: clearToast ? null : toastUntil ?? this.toastUntil,
        failure: clearFailure ? null : failure ?? this.failure,
      );
}

class PlanViewNotifier extends StateNotifier<PlanViewState> {
  PlanViewNotifier(this._now) : super(PlanViewState(weekStart: planWeekStart(_now())));

  final DateTime Function() _now;
  Timer? _toastTimer;

  DateTime get currentWeek => planWeekStart(_now());

  bool canShow(DateTime weekStart) {
    final weeks = planWeekStart(weekStart).difference(currentWeek).inDays / 7;
    return weeks.abs() <= kPlanWeekReach + 0.5;
  }

  /// Shows [weekStart]'s week (clamped to ±52 weeks); edit mode ends.
  void showWeek(DateTime weekStart) {
    final start = planWeekStart(weekStart);
    if (!canShow(start)) return;
    state = state.copyWith(weekStart: start, editing: false);
  }

  void step(int weeks) => showWeek(planAddDays(state.weekStart, 7 * weeks));

  /// Opens the week of [day] and scrolls to it.
  void focus(DateTime day) {
    final d = planDay(day);
    state = state.copyWith(weekStart: planWeekStart(d), focusDay: d, focusSerial: state.focusSerial + 1);
  }

  /// Back to this week and today (the segment tapped again, 4.1.1).
  void reselect() => focus(_now());

  void setEditing(bool editing) => state = state.copyWith(editing: editing);

  /// The undo toast took the capsule's place for [time].
  void toastShown(Duration time) {
    _toastTimer?.cancel();
    state = state.copyWith(toastUntil: _now().add(time));
    _toastTimer = Timer(time, () {
      if (mounted) state = state.copyWith(clearToast: true);
    });
  }

  void setFailure(PlanSendFailure? failure) =>
      state = failure == null ? state.copyWith(clearFailure: true) : state.copyWith(failure: failure);

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }
}

/// The plan overview's state; lives as long as the app (the shown week
/// survives a tab switch).
final planViewProvider = StateNotifierProvider<PlanViewNotifier, PlanViewState>(
  (ref) => PlanViewNotifier(ref.watch(mealPlanClockProvider)),
);

/// "Vergangene Tage" unfolded, remembered per device (4.1.3 item 6).
final planPastDaysOpenProvider = StateNotifierProvider<PlanPastDaysNotifier, bool>(
  (ref) => PlanPastDaysNotifier(ref.watch(sharedPreferencesProvider).valueOrNull),
);

class PlanPastDaysNotifier extends StateNotifier<bool> {
  PlanPastDaysNotifier(this._prefs) : super(_prefs?.getBool(_key) ?? false);

  static const _key = 'plan_past_days_open_v1';
  final SharedPreferences? _prefs;

  void toggle() {
    state = !state;
    unawaited(_save(state));
  }

  Future<void> _save(bool open) async {
    try {
      await (_prefs ?? await SharedPreferences.getInstance()).setBool(_key, open);
    } catch (e) {
      debugPrint('⚠️ [MEAL_PLAN] Past days state not saved: $e');
    }
  }
}

/// Amounts changed in "Menge ändern" per week, by line key; they count
/// until the ingredients are added (S4).
final planAmountOverridesProvider =
    StateProvider.family<Map<String, PlanQuantity>, DateTime>((ref, weekStart) => const {});

/// The original names replaced for the diet, with the replacement the
/// line showed ("Original statt Hafermilch"), per week.
final planOriginalShownProvider =
    StateProvider.family<Map<String, String>, DateTime>((ref, weekStart) => const {});

// ---------------------------------------------------------------- status

enum PlanEntryStatusKind {
  /// Everything is on the target list, sent or a pantry staple.
  allOnList,

  /// "2 Zutaten fehlen".
  missing,

  /// Sent, then more servings: "3 Zutaten fehlen für 2 weitere Portionen".
  missingMore,

  /// Sent, then fewer servings: "alles auf der Liste · 2 Portionen weniger".
  fewer,

  /// The recipe was deleted.
  unavailable,

  /// The recipe has no ingredients.
  noIngredients,

  /// A day before today: no status.
  past,
}

@immutable
class PlanEntryStatus {
  const PlanEntryStatus(this.kind, {this.missing = 0, this.servingsDelta = 0});

  final PlanEntryStatusKind kind;
  final int missing;

  /// Servings more (positive) or fewer (negative) than sent.
  final int servingsDelta;

  bool get warns => kind == PlanEntryStatusKind.missing || kind == PlanEntryStatusKind.missingMore;

  @override
  bool operator ==(Object other) =>
      other is PlanEntryStatus && other.kind == kind && other.missing == missing && other.servingsDelta == servingsDelta;

  @override
  int get hashCode => Object.hash(kind, missing, servingsDelta);
}

@immutable
class PlanWeekSummary {
  const PlanWeekSummary({required this.capsuleCount, required this.listId, required this.status, required this.past});

  /// Merged lines still to buy in the default range (the capsule, K2).
  final int capsuleCount;
  final String? listId;
  final Map<String, PlanEntryStatus> status;

  /// The whole week lies before today.
  final bool past;
}

/// The status of every entry of a week and the capsule's number, for the
/// week's target list and the default range ("Ab heute").
final planWeekSummaryProvider = Provider.family<PlanWeekSummary, DateTime>((ref, weekStart) {
  final start = planWeekStart(weekStart);
  final week = ref.watch(weekPlanProvider(start));
  final today = planDay(ref.watch(mealPlanClockProvider)());
  final past = !planAddDays(start, 7).isAfter(today);
  final listId = ref.watch(planTargetListIdProvider(start));
  final aggregation = past || week.entryCount == 0
      ? PlanAggregation.empty
      : ref.watch(planAggregationProvider((weekStart: start, range: PlanRange.fromToday, listId: listId)));
  final skipped = {for (final s in aggregation.withoutIngredients) s.entryId: s.reason};

  final status = <String, PlanEntryStatus>{};
  for (final e in week.entries) {
    if (e.planDate.isBefore(today)) {
      status[e.id] = const PlanEntryStatus(PlanEntryStatusKind.past);
    } else if (e.recipeId == null) {
      status[e.id] = const PlanEntryStatus(PlanEntryStatusKind.unavailable);
    } else if (skipped[e.id] == PlanSkipReason.noIngredients || (e.openServings == 0 && e.snapshot.ingredients.isEmpty)) {
      status[e.id] = const PlanEntryStatus(PlanEntryStatusKind.noIngredients);
    } else {
      final delta = e.servingsChangeSinceSent;
      final missing = aggregation.missingByEntry[e.id] ?? 0;
      if (e.isSent && delta > 0 && missing > 0) {
        status[e.id] = PlanEntryStatus(PlanEntryStatusKind.missingMore, missing: missing, servingsDelta: delta);
      } else if (missing > 0) {
        status[e.id] = PlanEntryStatus(PlanEntryStatusKind.missing, missing: missing);
      } else if (e.isSent && delta < 0) {
        status[e.id] = PlanEntryStatus(PlanEntryStatusKind.fewer, servingsDelta: delta);
      } else {
        status[e.id] = const PlanEntryStatus(PlanEntryStatusKind.allOnList);
      }
    }
  }
  return PlanWeekSummary(
    capsuleCount: past ? 0 : aggregation.selectedCount,
    listId: listId,
    status: status,
    past: past,
  );
});

/// The first load has nothing to show yet: no device state and no answer
/// from the server for the week.
final planWeekUnknownProvider = Provider.family<bool, DateTime>((ref, weekStart) {
  final snapshot = ref.watch(mealPlanSnapshotProvider);
  return !snapshot.loaded || !snapshot.knows(weekStart);
});

// ---------------------------------------------------------------- Avo

/// Tells Avo which plan screen is open (`avoScreenContextProvider`, 1.3)
/// while [child] is shown; leaving clears it unless another screen set its
/// own meanwhile.
class PlanAvoContext extends ConsumerStatefulWidget {
  const PlanAvoContext({super.key, required this.screen, required this.child});

  /// `plan` or `plan_to_list`.
  final String screen;
  final Widget child;

  @override
  ConsumerState<PlanAvoContext> createState() => _PlanAvoContextState();
}

class _PlanAvoContextState extends ConsumerState<PlanAvoContext> {
  late final StateController<AvoScreenContext?> _avo = ref.read(avoScreenContextProvider.notifier);
  late final AvoScreenContext _mine = AvoScreenContext(screen: widget.screen);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _avo.state = _mine;
    });
  }

  @override
  void dispose() {
    final avo = _avo;
    final mine = _mine;
    Future.microtask(() {
      try {
        if (avo.state == mine) avo.state = null;
      } catch (_) {
        // The provider container is gone (app closing).
      }
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
