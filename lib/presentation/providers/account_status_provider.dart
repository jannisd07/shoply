import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/core/services/shared_preferences_provider.dart';
import 'package:shoply/data/models/expense_split.dart';
import 'package:shoply/data/services/calorie_write_queue.dart';
import 'package:shoply/data/services/subscription_service.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/presentation/providers/subscription_provider.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/expense_split_provider.dart';

// What Teil A's account pages ask of Teil B's data (A8, `a8-stand.md` "Von
// Teil B"): changes that would be lost on sign-out, open amounts of Kosten
// teilen, and the subscription facts the Pro row and "Konto löschen" show.
// Exported through `b_slots.dart`.

// ------------------------------------------------------------ unsent changes

/// Entries that wait on this device until they reach the server: the
/// calorie write queue of [userId] (plus the queue of builds before it was
/// kept per account) and the meal plan outbox of [userId]. Failed writes
/// count too; they are lost on sign-out as well.
int countPendingChanges(SharedPreferences prefs, {String? userId}) {
  var count = _jsonListLength(prefs.getString(legacyCalorieWriteQueueKey));
  if (userId != null) {
    count += _jsonListLength(prefs.getString(calorieWriteQueueKey(userId)));
    count += _jsonListLength(prefs.getString(mealPlanOutboxKey(userId)));
  }
  return count;
}

/// SharedPreferences key of [userId]'s unsent meal plan changes (the
/// outbox of `MealPlanRepository`).
@visibleForTesting
String mealPlanOutboxKey(String userId) => 'meal_plan_outbox_v1_$userId';

int _jsonListLength(String? raw) {
  if (raw == null || raw.isEmpty) return 0;
  try {
    final decoded = jsonDecode(raw);
    return decoded is List ? decoded.length : 0;
  } catch (_) {
    return 0;
  }
}

/// How many changes of Kalorien and Wochenplan would be lost on sign-out
/// (Konzept 18 §7.2). A function, so "Abmelden" reads the count at the
/// moment of the tap; 0 while SharedPreferences is not loaded. Replaces the
/// direct reads of `cal_write_queue_v1` and `meal_plan_outbox_v1_<uid>`.
final pendingChangesCountProvider = Provider<int Function()>((ref) {
  return () {
    final prefs = ref.read(sharedPreferencesProvider).valueOrNull;
    if (prefs == null) return 0;
    return countPendingChanges(prefs, userId: ref.read(authUserIdProvider));
  };
});

// ------------------------------------------------------------ open amounts

/// Unpaid shares of Kosten teilen that involve [userId]: what others still
/// owe on trips [userId] paid ([owedToMe], the payer's own share left out)
/// and what [userId] still owes ([iOwe]).
@visibleForTesting
int countOpenSplitShares({
  required String userId,
  required List<TripSplitSummary> owedToMe,
  required List<TripSplitSummary> iOwe,
}) {
  var count = 0;
  for (final trip in owedToMe) {
    count += trip.splits.where((s) => !s.isPaid && s.userId != userId).length;
  }
  for (final trip in iOwe) {
    count += trip.splits.where((s) => !s.isPaid).length;
  }
  return count;
}

/// Open amounts of Kosten teilen ("Konto löschen": "2 offene Beträge");
/// null while the module is off, signed out or when they cannot be read.
final openSplitBalancesCountProvider = FutureProvider.autoDispose<int?>((
  ref,
) async {
  final userId = ref.watch(authUserIdProvider);
  if (userId == null) return null;
  if (!ref.watch(moduleEnabledProvider(AppModule.costSplit))) return null;
  try {
    final owedToMe = await ref.watch(tripsAwaitingPaymentToMeProvider.future);
    final iOwe = await ref.watch(tripsIOweProvider.future);
    return countOpenSplitShares(userId: userId, owedToMe: owedToMe, iOwe: iOwe);
  } catch (e) {
    debugPrint('⚠️ [SPLIT] Open amounts not read: ${e.runtimeType}');
    return null;
  }
});

// ------------------------------------------------------------ subscription

/// What the account knows about Avo Pro (`users.subscription_status`,
/// `subscription_expires_at`, `trial_ends_at`).
///
/// Apple's own facts (whether it renews, a billing grace period, Family
/// Sharing) only reach the account with the receipt check
/// `verify-subscription` (Konzept 18 E18-10); until then they are null,
/// meaning "not known", never a guess.
@immutable
class ProSubscriptionDetails {
  const ProSubscriptionDetails({
    required this.status,
    this.expiresAt,
    this.trialEndsAt,
    this.now,
  });

  /// From a `users` row; [now] decides whether a trial still runs.
  factory ProSubscriptionDetails.fromRow(
    Map<String, dynamic> row, {
    DateTime? now,
  }) => ProSubscriptionDetails(
    status: (row['subscription_status'] as String?) ?? 'inactive',
    expiresAt: _date(row['subscription_expires_at']),
    trialEndsAt: _date(row['trial_ends_at']),
    now: now,
  );

  /// `inactive`, `trial`, `active`, `cancelled` or `expired`.
  final String status;

  /// End of the paid period the account knows of.
  final DateTime? expiresAt;

  /// End of the trial, also after it ran out (the trial was used).
  final DateTime? trialEndsAt;

  /// The clock [isTrial] compares with; null is the current time.
  final DateTime? now;

  DateTime get _now => now ?? DateTime.now();

  /// A trial runs right now.
  bool get isTrial {
    final end = trialEndsAt;
    return status == 'trial' && end != null && end.isAfter(_now);
  }

  /// The account may still start the trial: it never had one and is not
  /// subscribed (the rule of `activate_trial`).
  bool get trialEligible => status == 'inactive' && trialEndsAt == null;

  /// Whether the subscription renews: false once it was cancelled, null
  /// otherwise (StoreKit's auto-renew state is not in the account yet).
  bool? get willRenew => status == 'cancelled' ? false : null;

  /// In Apple's billing grace period; not known before E18-10.
  bool? get inGracePeriod => null;

  /// Pro through Family Sharing; not known before E18-10.
  bool? get familyShared => null;

  static DateTime? _date(Object? raw) =>
      raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

  @override
  bool operator ==(Object other) =>
      other is ProSubscriptionDetails &&
      other.status == status &&
      other.expiresAt == expiresAt &&
      other.trialEndsAt == trialEndsAt;

  @override
  int get hashCode => Object.hash(status, expiresAt, trialEndsAt);
}

/// Reads the subscription columns of [userId]'s `users` row; null when
/// there is none. Override in tests.
final subscriptionRowLoaderProvider =
    Provider<Future<Map<String, dynamic>?> Function(String userId)>(
      (ref) => (userId) => SupabaseService.instance.client
          .from('users')
          .select('subscription_status, subscription_expires_at, trial_ends_at')
          .eq('id', userId)
          .maybeSingle(),
    );

/// The signed-in account's subscription facts, read again whenever the
/// purchase state changes; null signed out or when the row cannot be read.
final proSubscriptionDetailsProvider =
    FutureProvider<ProSubscriptionDetails?>((ref) async {
      final userId = ref.watch(authUserIdProvider);
      if (userId == null) return null;
      // A purchase, restore or expiry changes the row: read it again. The
      // first status (loading to known) is the start, not a change.
      ref.listen<SubscriptionStatus?>(
        subscriptionStatusProvider.select((s) => s.valueOrNull),
        (previous, next) {
          if (previous != null && previous != next) ref.invalidateSelf();
        },
      );
      try {
        final row = await ref.watch(subscriptionRowLoaderProvider)(userId);
        return row == null ? null : ProSubscriptionDetails.fromRow(row);
      } catch (e) {
        debugPrint('⚠️ [SUBSCRIPTION] Details not read: ${e.runtimeType}');
        return null;
      }
    });

/// The day Avo Pro renews ("Aktiv · verlängert sich am 7. Nov. 2027"), or
/// null when it does not renew or it is not known whether it does. Today
/// always null: the auto-renew state comes with E18-10.
final subscriptionRenewsOnProvider = Provider<DateTime?>((ref) {
  final details = ref.watch(proSubscriptionDetailsProvider).valueOrNull;
  if (details == null || details.willRenew != true) return null;
  return details.expiresAt;
});

/// Avo Pro comes through Family Sharing ("Aktiv über Familienfreigabe"):
/// true, false, or null while unknown (today always, until E18-10).
final subscriptionFamilySharedProvider = Provider<bool?>(
  (ref) => ref.watch(proSubscriptionDetailsProvider).valueOrNull?.familyShared,
);
