import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/core/services/shared_preferences_provider.dart';
import 'package:shoply/data/models/expense_split.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/services/offer_savings.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/screens/history/history_format.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/state/trip_history_provider.dart';

// What the history screens and the Home sections read (verlauf-kosten.md
// V4–V12), all synchronous from W10's local-first providers.

/// Whether savings may show in the history (§3.14): offers available, the
/// switch "Ersparnis im Verlauf und nach dem Einkauf" on, a real region.
/// [listId] is the trip's list ('' for the whole history).
final historySavingsVisibleProvider = Provider.family<bool, String>(
  (ref, listId) =>
      ref.watch(
        offerSurfaceVisibleProvider((
          surface: OfferSurface.historySavings,
          listId: listId,
        )),
      ) &&
      ref.watch(regionProvider) != null,
);

/// Rounded savings of one trip ("ca. 3,20 € gespart"), only of the trip's
/// market (L4); null when hidden, without a market or below 0,50 €.
final tripSavingsCentsProvider = Provider.family<int?, String>((ref, tripId) {
  final trip = ref.watch(historyTripProvider(tripId));
  if (trip == null || trip.storeChainId == null) return null;
  if (!ref.watch(historySavingsVisibleProvider(trip.listId ?? ''))) {
    return null;
  }
  return roundedSavingsCents((totalSavingsOf([trip]) * 100).round());
});

/// Rounded savings of many trips, summed unrounded first (§3.3); null when
/// hidden or below 0,50 €. Trips without a market do not count.
int? savingsOfTrips(bool visible, Iterable<ShoppingHistory> trips) {
  if (!visible) return null;
  final withStore = [
    for (final t in trips)
      if (t.storeChainId != null) t,
  ];
  return roundedSavingsCents((totalSavingsOf(withStore) * 100).round());
}

// ------------------------------------------------------------------ shares

/// Open (and lately settled) shares of [tripId] from [openSharesProvider];
/// empty while Kosten teilen is off.
final tripOpenSharesProvider = Provider.family<List<OpenShare>, String>((
  ref,
  tripId,
) {
  if (!ref.watch(moduleEnabledProvider(AppModule.costSplit))) return const [];
  final shares = ref.watch(openSharesProvider.select((s) => s.shares));
  return [
    for (final s in shares)
      if (s.historyId == tripId) s,
  ];
});

/// The debt line of a [TripRow]: who owes whom on [tripId], unpaid only.
@immutable
class TripDebt {
  const TripDebt({required this.owedToMe, required this.cents, this.name, this.people = 1});

  /// Others owe the person (else the person owes [name]).
  final bool owedToMe;
  final int cents;

  /// The one other person, or null for several ([people]).
  final String? name;
  final int people;
}

/// [TripDebt] of [tripId], or null when nothing is open.
final tripDebtProvider = Provider.family<TripDebt?, String>((ref, tripId) {
  final me = ref.watch(authUserIdProvider);
  if (me == null) return null;
  final shares = ref.watch(tripOpenSharesProvider(tripId));
  final owed = [
    for (final s in shares)
      if (!s.isPaid && s.isOwedTo(me)) s,
  ];
  if (owed.isNotEmpty) {
    final cents = owed.fold<int>(0, (a, s) => a + s.amountCents);
    return TripDebt(
      owedToMe: true,
      cents: cents,
      name: owed.length == 1 ? owed.first.participantName : null,
      people: owed.length,
    );
  }
  final owe = [
    for (final s in shares)
      if (!s.isPaid && s.isOwedBy(me)) s,
  ];
  if (owe.isEmpty) return null;
  return TripDebt(
    owedToMe: false,
    cents: owe.fold<int>(0, (a, s) => a + s.amountCents),
    name: owe.first.paidByName,
  );
});

// ------------------------------------------------------------------ Home

/// The synchronous Home snapshot (§3.1): this month, the six months and
/// the newest three trips, from the local history in the first frame.
@immutable
class HomeHistorySnapshot {
  const HomeHistorySnapshot({
    required this.now,
    required this.thisMonth,
    required this.months,
    required this.recent,
    required this.monthSavingsCents,
    required this.multipleLists,
  });

  final DateTime now;
  final MonthSummary thisMonth;

  /// The six months of "Ausgaben im Vergleich", oldest first.
  final List<MonthSummary> months;

  /// The newest three trips.
  final List<ShoppingHistory> recent;

  /// Rounded savings of this month, or null (hidden, below 0,50 €).
  final int? monthSavingsCents;

  /// The recent trips come from more than one list (V11 adds the list).
  final bool multipleLists;
}

final homeHistorySnapshotProvider = Provider<HomeHistorySnapshot>((ref) {
  final now = ref.watch(historyClockProvider)();
  final trips = ref.watch(tripHistoryProvider.select((s) => s.trips));
  final month = DateTime(now.year, now.month);
  final recent = trips.take(3).toList();
  return HomeHistorySnapshot(
    now: now,
    thisMonth: summarizeMonth(trips, month),
    months: sixMonths(trips, now),
    recent: recent,
    monthSavingsCents: savingsOfTrips(
      ref.watch(historySavingsVisibleProvider('')),
      tripsInMonth(trips, year: now.year, month: now.month),
    ),
    multipleLists: recent.map((t) => t.listId ?? t.listName).toSet().length > 1,
  );
});

// ------------------------------------------------------------------ V12

/// Which one hint "Kosten teilen" Home shows (V12).
sealed class HomeSplitHintData {
  const HomeSplitHintData();
}

/// Exactly one open share: "Lena schuldet dir 21,40 € · Wocheneinkauf".
final class OneBalanceHint extends HomeSplitHintData {
  const OneBalanceHint(this.share, {required this.owedToMe});
  final OpenShare share;
  final bool owedToMe;
}

/// Several open shares: "3 offene Beträge · …".
final class ManyBalancesHint extends HomeSplitHintData {
  const ManyBalancesHint(this.summary);
  final OpenBalancesSummary summary;
}

/// A trip of the last 7 days on a shared list, not split yet, with the
/// list's other members (never empty; "" for a member without a name).
final class ShareTripHint extends HomeSplitHintData {
  const ShareTripHint(this.trip, this.others);
  final ShoppingHistory trip;
  final List<String> others;
}

/// Per-account dismissals of the Home hints (rule 15): "Einkauf teilen"
/// per trip, the balances for three days.
class SplitHintDismissals {
  SplitHintDismissals(this._prefs, this.userId);

  final SharedPreferences _prefs;
  final String userId;

  static const Duration balancesPause = Duration(days: 3);

  String get _tripsKey => 'hist_hint_share_dismissed_v1_$userId';
  String get _balancesKey => 'hist_hint_balances_until_v1_$userId';

  bool tripDismissed(String tripId) =>
      (_prefs.getStringList(_tripsKey) ?? const []).contains(tripId);

  bool balancesPaused(DateTime now) {
    final until = _prefs.getInt(_balancesKey);
    return until != null && now.millisecondsSinceEpoch < until;
  }

  Future<void> dismissTrip(String tripId) {
    final ids = [...?_prefs.getStringList(_tripsKey), tripId];
    // Keep the newest 50; older trips are past the 7-day window anyway.
    return _prefs.setStringList(
      _tripsKey,
      ids.length > 50 ? ids.sublist(ids.length - 50) : ids,
    );
  }

  Future<void> pauseBalances(DateTime now) => _prefs.setInt(
    _balancesKey,
    now.add(balancesPause).millisecondsSinceEpoch,
  );
}

final splitHintDismissalsProvider = Provider<SplitHintDismissals?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  final uid = ref.watch(authUserIdProvider);
  if (prefs == null || uid == null) return null;
  return SplitHintDismissals(prefs, uid);
});

/// Bumped after a dismissal, so the hint re-evaluates.
final splitHintRevisionProvider = StateProvider<int>((ref) => 0);

/// The hint to show (offen before teilen, §V12), or null.
final homeSplitHintProvider = Provider<HomeSplitHintData?>((ref) {
  if (!ref.watch(moduleEnabledProvider(AppModule.costSplit))) return null;
  final me = ref.watch(authUserIdProvider);
  final dismissals = ref.watch(splitHintDismissalsProvider);
  if (me == null || dismissals == null) return null;
  ref.watch(splitHintRevisionProvider);
  final now = ref.watch(historyClockProvider)();

  final summary = ref.watch(openBalancesSummaryProvider);
  if (summary != null && !dismissals.balancesPaused(now)) {
    if (summary.openCount == 1) {
      final shares = ref.watch(openSharesProvider.select((s) => s.shares));
      final share = shares
          .where((s) => !s.isPaid && (s.isOwedTo(me) || s.isOwedBy(me)))
          .firstOrNull;
      if (share != null) {
        return OneBalanceHint(share, owedToMe: share.isOwedTo(me));
      }
    } else {
      return ManyBalancesHint(summary);
    }
  }

  final trips = ref.watch(tripHistoryProvider.select((s) => s.trips));
  final shares = ref.watch(openSharesProvider.select((s) => s.shares));
  final split = {for (final s in shares) s.historyId};
  final lists = ref.watch(listsNotifierProvider).valueOrNull ?? const [];
  final shared = {
    for (final l in lists)
      if (l.isShared) l.id,
  };
  final from = now.subtract(const Duration(days: 7));
  for (final t in trips) {
    if (t.completedAt.isBefore(from)) break;
    if (isLocalTripId(t.id) || t.listId == null) continue;
    if (!shared.contains(t.listId) || split.contains(t.id)) continue;
    if (dismissals.tripDismissed(t.id)) continue;
    // Decide here, so HasContent and the widget always agree (§3.1): no
    // hint until the members are known, none without another member.
    final members = ref.watch(splitMembersProvider(t.listId!));
    if (members == null) return null;
    final others = [
      for (final m in members)
        if (m.userId != me) m.name,
    ];
    if (others.isEmpty) continue;
    return ShareTripHint(t, others);
  }
  return null;
});

/// Remembers a dismissed hint in the account and hides it.
Future<void> dismissSplitHint(WidgetRef ref, HomeSplitHintData hint) async {
  final dismissals = ref.read(splitHintDismissalsProvider);
  if (dismissals == null) return;
  switch (hint) {
    case ShareTripHint(:final trip):
      await dismissals.dismissTrip(trip.id);
    case OneBalanceHint() || ManyBalancesHint():
      await dismissals.pauseBalances(ref.read(historyClockProvider)());
  }
  ref.read(splitHintRevisionProvider.notifier).state++;
}

/// Trips of [listId] only, or all for null; for V4's filter.
List<ShoppingHistory> tripsOfList(List<ShoppingHistory> trips, String? listId) =>
    listId == null
    ? trips
    : [
        for (final t in trips)
          if (t.listId == listId) t,
      ];

/// Writes in the background without failing the caller (local first).
void runInBackground(Future<void> Function() job, String what) {
  unawaited(
    job().catchError((Object e) {
      debugPrint('⚠️ [HISTORY] $what failed: ${e.runtimeType}');
    }),
  );
}
