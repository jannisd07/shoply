/// One-time tips instead of the coach-mark tutorial (Konzept 17 §6.1, K-21).
///
/// Every function is explained once, in place, by one row ("Tipp: …"). This
/// service decides which tip a place shows and remembers what was shown, on
/// this device only (SharedPreferences, no server field;
/// `users.tutorial_completed` stays unused).
///
/// Rules:
/// - At most one tip at a time in the whole app (the *active* tip) and at
///   most one new tip per day.
/// - A shown tip never comes back, except after [TipService.reset]
///   ("Tipps zurücksetzen"). It stays for the rest of the day it first
///   appeared (T5: three days), until it is done or swiped away.
/// - A tip is done by itself as soon as its function is used: through the
///   facts a screen passes ([TipService.observe]) or an event
///   ([TipService.markDone], [TipService.note]).
/// - What a screen shows is decided synchronously from the stored state, so
///   it is fixed at the first frame (see `TipVisit` in
///   `presentation/widgets/tips/tip_slot.dart`).
///
/// For Teil B (stable API):
/// ```dart
/// TipService.instance.markDone(TipId.voice);    // T8: voice mode used
/// TipService.instance.markDone(TipId.mealPlan); // T9: first plan on a list
/// TipService.instance.note(TipEvent.avoTextMessage); // counts for T8
/// ```
/// Both are safe to call at any time, also before the app attached the
/// service (the call is kept and applied on [TipService.attach]).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/models/shopping_item_model.dart';

/// Where a tip row can appear.
enum TipPlace {
  /// Home ("Für dich"), after the savings hint and the meal plan.
  home('home'),

  /// One list, in the section "Für heute".
  list('list'),

  /// The Rezepte tab, directly below the large title.
  recipes('recipes'),

  /// The Wochenplan (Teil B embeds the slot).
  plan('plan');

  const TipPlace(this.id);

  /// Stable storage id.
  final String id;
}

/// The tips T1–T9 of Konzept 17 §6.1. [id] is stored on the device: never
/// rename it.
enum TipId {
  /// T1 "Schreib „2 Milch“ …": list, on arrival after the onboarding; done
  /// by the first item with a quantity.
  quantity('t1', places: {TipPlace.list}),

  /// T2 "Im Markt auf Einkaufen tippen …": 3 open items, never shopped;
  /// done when the shopping mode starts.
  shoppingMode('t2', places: {TipPlace.list, TipPlace.home}),

  /// T3 "Der Kreis hakt ab …": 5 open items, nothing checked off after
  /// 24 h; done by the first check-off.
  checkOff('t3', places: {TipPlace.list}),

  /// T4 "Teil die Liste …": after the first shopping trip, list not
  /// shared; done when a list is shared.
  share('t4', places: {TipPlace.list, TipPlace.home}),

  /// T5 "Was andere abhaken …": after joining a shared list; done after
  /// three days.
  joined('t5', places: {TipPlace.list}, days: 3),

  /// T6 "„Zutaten auf die Liste“ …": first visit of Rezepte; done by the
  /// first "Zutaten auf die Liste".
  recipeToList('t6', places: {TipPlace.recipes}),

  /// T7 "Stell Ernährung und Allergien ein …" with "Einstellen": no diet
  /// set, second visit of Rezepte; done once a diet or allergy is saved.
  diet('t7', places: {TipPlace.recipes}),

  /// T8 "Halte … gedrückt, um mit Avo zu sprechen": Avo module on, Avo used
  /// three times by text; done by Teil B when the voice mode is used.
  voice('t8', places: {TipPlace.list}),

  /// T9 "Leg Rezepte auf die Tage …": first visit of the Wochenplan; done
  /// by Teil B when a plan first goes onto a list.
  mealPlan('t9', places: {TipPlace.plan});

  const TipId(this.id, {required this.places, this.days = 1});

  /// Stable storage id ("t1" … "t9").
  final String id;

  /// Where the tip may appear.
  final Set<TipPlace> places;

  /// Calendar days a shown tip stays (the day it appeared counts as one).
  final int days;

  /// T1–T7: count as shown for people who used the app before the tips
  /// existed (Konzept 17 §5.4) and for accounts that were already set up.
  bool get forNewPeople => index <= TipId.diet.index;

  static TipId? fromId(String? id) {
    for (final t in values) {
      if (t.id == id) return t;
    }
    return null;
  }
}

/// Events that are counted for the start conditions.
enum TipEvent {
  /// The shopping mode started (also marks T2 done).
  shoppingStarted('shopping'),

  /// A shopping trip was saved ("Einkauf abschließen").
  tripCompleted('trip'),

  /// A message to Avo was typed and sent (Teil B, for T8).
  avoTextMessage('avo_text');

  const TipEvent(this.id);

  /// Stable storage id.
  final String id;
}

/// What a screen knows about itself when it asks for its tip. A null field
/// means "not known here": it neither starts nor finishes a tip.
@immutable
class TipFacts {
  const TipFacts({
    this.ready = true,
    this.openItems,
    this.hasCheckedItem,
    this.hasItemWithQuantity,
    this.oldestOpenItem,
    this.shared,
    this.avoOn,
    this.dietSet,
  });

  /// The facts are complete enough to decide; until then no tip is picked.
  final bool ready;

  /// Open items of this list (Home: the fullest list).
  final int? openItems;

  /// Some item of this list is checked off.
  final bool? hasCheckedItem;

  /// Some item has a quantity or a unit ("2 Milch", "500 g Mehl").
  final bool? hasItemWithQuantity;

  /// When the oldest open item was added.
  final DateTime? oldestOpenItem;

  /// This list is shared (Home: any list is shared).
  final bool? shared;

  /// The Avo module is on.
  final bool? avoOn;

  /// A diet or an allergy is saved (null: not signed in or not loaded yet).
  final bool? dietSet;

  /// The facts of one list from its items.
  factory TipFacts.forList(
    List<ShoppingItemModel> items, {
    bool? shared,
    bool? avoOn,
  }) {
    var open = 0;
    var checked = false;
    var quantity = false;
    DateTime? oldest;
    for (final item in items) {
      if (item.isChecked) {
        checked = true;
      } else {
        open++;
        final at = item.createdAt;
        if (oldest == null || at.isBefore(oldest)) oldest = at;
      }
      final unit = item.unit?.trim() ?? '';
      if (item.quantity != 1 || unit.isNotEmpty) quantity = true;
    }
    return TipFacts(
      openItems: open,
      hasCheckedItem: checked,
      hasItemWithQuantity: quantity,
      oldestOpenItem: oldest,
      shared: shared,
      avoOn: avoOn,
    );
  }
}

/// SharedPreferences key of the whole tip state (one JSON object).
const String kTipStateKey = 'tips_state_v1';

/// Set by the onboarding when it finished (Konzept 17 §1.2: the key stays).
/// Already true on the first start with tips means: an update, not a new
/// person.
const String _kOnboardingCompleteKey = 'onboarding_complete_v1';

/// T3 waits this long after the oldest open item.
const Duration _kCheckOffWait = Duration(hours: 24);

/// Open items for T2 and T3.
const int _kShoppingModeItems = 3;
const int _kCheckOffItems = 5;

/// Text messages to Avo before T8.
const int _kVoiceAfterMessages = 3;

/// Visits of Rezepte before T7 ("zweites Öffnen").
const int _kDietAfterVisits = 2;

/// What is stored about one tip.
class _Record {
  _Record({
    this.shown,
    this.done = false,
    this.hidden = false,
    this.seen = false,
  });

  /// Day it first appeared ("2026-11-08").
  String? shown;

  /// Its function was used.
  bool done;

  /// Swiped away.
  bool hidden;

  /// Counts as shown without having appeared (update, existing account).
  bool seen;

  Map<String, Object> toJson() => {
    if (shown != null) 's': shown!,
    if (done) 'd': true,
    if (hidden) 'h': true,
    if (seen) 'x': true,
  };

  static _Record fromJson(Object? raw) {
    if (raw is! Map) return _Record();
    return _Record(
      shown: raw['s'] as String?,
      done: raw['d'] == true,
      hidden: raw['h'] == true,
      seen: raw['x'] == true,
    );
  }
}

/// Decides and remembers the one-time tips. See the library comment.
class TipService extends ChangeNotifier {
  /// A service with its own state; the app uses [instance].
  TipService({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  /// The app-wide service. `app.dart` attaches it to the preferences at
  /// start; until then it shows nothing (so screens in tests stay free of
  /// tips unless a test attaches its own service).
  static final TipService instance = TipService();

  final DateTime Function() _clock;
  SharedPreferences? _prefs;

  final Map<TipId, _Record> _tips = {};
  final Map<String, int> _counts = {};
  TipId? _active;
  String? _startedOn;

  /// Calls made before [attach], applied there.
  final List<void Function()> _pending = [];

  bool _notifyScheduled = false;

  /// Whether the service has its stored state.
  bool get isAttached => _prefs != null;

  /// The tip that is currently shown somewhere, if any (for tests and
  /// debugging; screens use [pick] and [isShowing]).
  TipId? get active {
    _expireActive(_today());
    return _active;
  }

  /// How often [event] happened on this device.
  int count(TipEvent event) => _counts[event.id] ?? 0;

  /// Visits of [place] so far (counted by the slots).
  int visits(TipPlace place) => _counts['visit.${place.id}'] ?? 0;

  /// Whether [id] will never appear again (done, swiped away, shown on an
  /// earlier day, or counted as shown).
  bool isFinished(TipId id) {
    final r = _tips[id];
    if (r == null) return false;
    if (r.done || r.hidden || r.seen) return true;
    return r.shown != null && active != id;
  }

  // ------------------------------------------------------------ storage

  /// Reads the stored state synchronously. On the first start with tips,
  /// T1–T7 count as shown if the onboarding was already finished before
  /// (an update, Konzept 17 §5.4). Safe to call again with the same
  /// preferences.
  void attach(SharedPreferences prefs) {
    if (identical(prefs, _prefs)) return;
    _prefs = prefs;
    _tips.clear();
    _counts.clear();
    _active = null;
    _startedOn = null;
    final raw = prefs.getString(kTipStateKey);
    if (raw == null) {
      if (prefs.getBool(_kOnboardingCompleteKey) ?? false) _seeNewPeopleTips();
    } else {
      _decode(raw);
    }
    final pending = List.of(_pending);
    _pending.clear();
    for (final call in pending) {
      call();
    }
    _save();
  }

  void _decode(String raw) {
    try {
      final map = (jsonDecode(raw) as Map).cast<String, Object?>();
      final tips = map['tips'];
      if (tips is Map) {
        for (final entry in tips.entries) {
          final id = TipId.fromId(entry.key as String?);
          if (id != null) _tips[id] = _Record.fromJson(entry.value);
        }
      }
      final counts = map['n'];
      if (counts is Map) {
        for (final entry in counts.entries) {
          final value = entry.value;
          if (entry.key is String && value is int) {
            _counts[entry.key as String] = value;
          }
        }
      }
      _active = TipId.fromId(map['active'] as String?);
      _startedOn = map['start'] as String?;
    } catch (e) {
      debugPrint('⚠️ [TIPS] Stored state unreadable, starting fresh: $e');
      _tips.clear();
      _counts.clear();
      _active = null;
      _startedOn = null;
    }
  }

  String _encode() => jsonEncode({
    'v': 1,
    'tips': {
      for (final entry in _tips.entries) entry.key.id: entry.value.toJson(),
    },
    'n': _counts,
    if (_active != null) 'active': _active!.id,
    if (_startedOn != null) 'start': _startedOn!,
  });

  void _save() {
    final prefs = _prefs;
    if (prefs == null) return;
    unawaited(
      prefs.setString(kTipStateKey, _encode()).catchError((Object e) {
        debugPrint('⚠️ [TIPS] Could not save: $e');
        return false;
      }),
    );
  }

  /// Listeners hear about changes after the current frame's work, so a
  /// change made while a screen builds never rebuilds another one mid-build.
  void _changed() {
    _save();
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

  /// Runs [call] now, or on [attach] when the state is not read yet.
  void _whenAttached(void Function() call) {
    if (isAttached) {
      call();
    } else {
      _pending.add(call);
    }
  }

  // ------------------------------------------------------------- days

  String _today() => _dayOf(_clock());

  static String _dayOf(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)}';
  }

  static int? _daysBetween(String from, String to) {
    final a = DateTime.tryParse(from);
    final b = DateTime.tryParse(to);
    if (a == null || b == null) return null;
    // Calendar dates as UTC midnights: no daylight-saving drift.
    final da = DateTime.utc(a.year, a.month, a.day);
    final db = DateTime.utc(b.year, b.month, b.day);
    return db.difference(da).inDays;
  }

  /// Ends the active tip once it is done, swiped away or its days are over.
  void _expireActive(String today) {
    final id = _active;
    if (id == null) return;
    final r = _tips[id];
    final shown = r?.shown;
    final over =
        shown == null || (_daysBetween(shown, today) ?? id.days) >= id.days;
    if (r == null || r.done || r.hidden || r.seen || over) {
      _active = null;
      _save();
    }
  }

  _Record _record(TipId id) => _tips.putIfAbsent(id, _Record.new);

  void _seeNewPeopleTips() {
    for (final id in TipId.values) {
      if (id.forNewPeople) _record(id).seen = true;
    }
    if (_active?.forNewPeople ?? false) _active = null;
  }

  // ---------------------------------------------------------- picking

  /// The tip [place] shows now, or null. Starts a new tip when none is
  /// active, none started today and one of the place's tips may start.
  /// Changes no listener; call it once per visit (`TipVisit` does).
  /// [only] limits the tips this place can render.
  TipId? pick(TipPlace place, TipFacts facts, {Set<TipId>? only}) {
    if (!isAttached || !facts.ready) return null;
    final today = _today();
    _expireActive(today);
    final current = _active;
    if (current != null) {
      final renders = only == null || only.contains(current);
      return renders && _showsAt(current, place, facts) ? current : null;
    }
    if (_startedOn == today) return null;
    for (final id in _candidates(place)) {
      if (only != null && !only.contains(id)) continue;
      if (isFinished(id)) continue;
      if (!_canStart(id, place, facts)) continue;
      _start(id, today);
      return id;
    }
    return null;
  }

  /// Whether [id] is still to be shown at [place] (it may have been done or
  /// swiped away since it was picked).
  bool isShowing(TipId id, TipPlace place, TipFacts facts) {
    if (!isAttached) return false;
    _expireActive(_today());
    return _active == id && _showsAt(id, place, facts);
  }

  void _start(TipId id, String today) {
    final r = _record(id);
    r.shown ??= today;
    _active = id;
    _startedOn = today;
    _save();
  }

  static List<TipId> _candidates(TipPlace place) => switch (place) {
    // T1 and T5 start only through [startArrivalTip].
    TipPlace.list => const [
      TipId.shoppingMode,
      TipId.checkOff,
      TipId.share,
      TipId.voice,
    ],
    TipPlace.home => const [TipId.shoppingMode, TipId.share],
    TipPlace.recipes => const [TipId.recipeToList, TipId.diet],
    TipPlace.plan => const [TipId.mealPlan],
  };

  bool get _shopped =>
      count(TipEvent.shoppingStarted) > 0 || count(TipEvent.tripCompleted) > 0;

  bool _canStart(TipId id, TipPlace place, TipFacts f) {
    final open = f.openItems ?? 0;
    switch (id) {
      case TipId.quantity:
      case TipId.joined:
        return false;
      case TipId.shoppingMode:
        return open >= _kShoppingModeItems && !_shopped;
      case TipId.checkOff:
        final oldest = f.oldestOpenItem;
        return open >= _kCheckOffItems &&
            f.hasCheckedItem == false &&
            oldest != null &&
            _clock().difference(oldest) >= _kCheckOffWait;
      case TipId.share:
        return _shopped && f.shared == false;
      case TipId.recipeToList:
        return place == TipPlace.recipes;
      case TipId.diet:
        return f.dietSet == false &&
            visits(TipPlace.recipes) >= _kDietAfterVisits;
      case TipId.voice:
        return f.avoOn == true &&
            count(TipEvent.avoTextMessage) >= _kVoiceAfterMessages;
      case TipId.mealPlan:
        return place == TipPlace.plan;
    }
  }

  /// Whether an active tip still makes sense at [place] with [f].
  bool _showsAt(TipId id, TipPlace place, TipFacts f) {
    if (!id.places.contains(place)) return false;
    return switch (id) {
      TipId.shoppingMode ||
      TipId.checkOff => place != TipPlace.list || (f.openItems ?? 1) > 0,
      TipId.share => f.shared != true,
      TipId.joined => f.shared != false,
      TipId.diet => f.dietSet != true,
      TipId.voice => f.avoOn != false,
      TipId.quantity || TipId.recipeToList || TipId.mealPlan => true,
    };
  }

  // ----------------------------------------------------------- events

  /// Marks tips done that [facts] show as used (an item with a quantity, a
  /// checked item, a shared list, a saved diet). Call it on every build of
  /// a place; it only writes when something changes.
  void observe(TipPlace place, TipFacts facts) {
    if (!isAttached) return;
    var changed = false;
    void done(TipId id) {
      final r = _record(id);
      if (r.done) return;
      r.done = true;
      changed = true;
    }

    if (facts.hasItemWithQuantity == true) done(TipId.quantity);
    if (facts.hasCheckedItem == true) done(TipId.checkOff);
    if (facts.shared == true) done(TipId.share);
    if (facts.dietSet == true) done(TipId.diet);
    if (changed) _changed();
  }

  /// [id]'s function was used: it never appears again and disappears where
  /// it is shown. For Teil B: T8 ([TipId.voice]) and T9 ([TipId.mealPlan]).
  void markDone(TipId id) => _whenAttached(() {
    final r = _record(id);
    if (r.done) return;
    r.done = true;
    _changed();
  });

  /// Swiped away ("Ausblenden"): never again.
  void dismiss(TipId id) => _whenAttached(() {
    final r = _record(id);
    if (r.hidden) return;
    r.hidden = true;
    _changed();
  });

  /// Counts [event]. The shopping mode also finishes T2.
  void note(TipEvent event) => _whenAttached(() {
    _counts[event.id] = count(event) + 1;
    if (event == TipEvent.shoppingStarted) {
      _record(TipId.shoppingMode).done = true;
    }
    _changed();
  });

  /// Counts a visit of [place] (T6 "erstes Öffnen", T7 "zweites Öffnen").
  /// Changes no listener.
  void visit(TipPlace place) {
    if (!isAttached) return;
    final key = 'visit.${place.id}';
    _counts[key] = (_counts[key] ?? 0) + 1;
    _save();
  }

  /// Arrival after the onboarding (Konzept 17 §3.12): starts T1 ([TipId.
  /// quantity]) or T5 ([TipId.joined]) right away, unless it is finished.
  /// Changes no listener (called while the list is being set up).
  void startArrivalTip(TipId id) {
    if (!isAttached) return;
    if (id != TipId.quantity && id != TipId.joined) return;
    final today = _today();
    _expireActive(today);
    if (isFinished(id)) return;
    _start(id, today);
  }

  final Set<String> _arrivals = {};

  /// True the first time [key] (list and arrival) is passed in this app run,
  /// so an arrival acts once even if its screen is built again.
  bool consumeArrival(String key) => _arrivals.add(key);

  /// An account that was already set up signed in (arrival `existing`):
  /// like after an update, T1–T7 count as shown. Changes no listener.
  void markNewPeopleTipsSeen() {
    if (!isAttached) return;
    _seeNewPeopleTips();
    _save();
  }

  /// "Tipps zurücksetzen": every tip may appear again, from today on. The
  /// event counters stay, and tips whose function is already in use finish
  /// again on the next visit.
  void reset() {
    _tips.clear();
    _active = null;
    _startedOn = null;
    _changed();
  }
}
