// A8 requests to Teil B: unsent changes, open amounts, subscription facts and
// the presence gate, as Teil A imports them from b_slots.dart.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/services/shared_preferences_provider.dart';
import 'package:shoply/data/models/expense_split.dart';
import 'package:shoply/data/services/subscription_service.dart';
import 'package:shoply/presentation/providers/account_status_provider.dart';
import 'package:shoply/presentation/providers/subscription_provider.dart';
import 'package:shoply/presentation/screens/profile/settings/data/list_preferences.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart' as slots;

ExpenseSplit _split(String id, {String? userId, bool paid = false}) =>
    ExpenseSplit(
      id: id,
      historyId: 'h',
      userId: userId,
      participantName: id,
      amount: 5,
      isPaid: paid,
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    );

TripSplitSummary _trip(List<ExpenseSplit> splits) => TripSplitSummary(
  historyId: 'h',
  listName: 'Wocheneinkauf',
  completedAt: DateTime(2026, 11, 1),
  totalCost: 20,
  paidByUserId: 'me',
  splits: splits,
);

void main() {
  test('b_slots exports the A8 interfaces under their names', () {
    final ProviderListenable<int Function()> pending =
        slots.pendingChangesCountProvider;
    final ProviderListenable<AsyncValue<int?>> balances =
        slots.openSplitBalancesCountProvider;
    final ProviderListenable<DateTime?> renews =
        slots.subscriptionRenewsOnProvider;
    final ProviderListenable<bool?> family =
        slots.subscriptionFamilySharedProvider;
    final ProviderListenable<AsyncValue<slots.ProSubscriptionDetails?>>
    details = slots.proSubscriptionDetailsProvider;
    final ProviderListenable<bool> presence = slots.sharePresenceProvider;
    expect([pending, balances, renews, family, details, presence], hasLength(6));
  });

  group('countPendingChanges', () {
    test('counts the per-account calorie queue, the old queue and the plan '
        'outbox of that account only', () async {
      SharedPreferences.setMockInitialValues({
        'cal_write_queue_v1': '[{"id":"a"}]',
        'cal_write_queue_v1_u1': '[{"id":"b"},{"id":"c"}]',
        'cal_write_queue_v1_u2': '[{"id":"x"}]',
        'meal_plan_outbox_v1_u1': '[{"kind":"entry_upsert"}]',
        'meal_plan_outbox_v1_u2': '[{"kind":"x"},{"kind":"y"}]',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(countPendingChanges(prefs, userId: 'u1'), 4);
      expect(countPendingChanges(prefs), 1);
    });

    test('unreadable or missing queues count as empty', () async {
      SharedPreferences.setMockInitialValues({
        'cal_write_queue_v1_u1': '{',
        'meal_plan_outbox_v1_u1': '{"not":"a list"}',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(countPendingChanges(prefs, userId: 'u1'), 0);
    });

    test('the provider reads at the moment it is called', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) async => prefs),
          authUserIdProvider.overrideWithValue('u1'),
        ],
      );
      addTearDown(container.dispose);
      await container.read(sharedPreferencesProvider.future);
      final count = container.read(pendingChangesCountProvider);
      expect(count(), 0);
      await prefs.setString('cal_write_queue_v1_u1', '[{"id":"a"}]');
      expect(count(), 1);
    });
  });

  test('countOpenSplitShares leaves out paid shares and the payer', () {
    final count = countOpenSplitShares(
      userId: 'me',
      owedToMe: [
        _trip([
          _split('mine', userId: 'me', paid: true),
          _split('lena', userId: 'lena'),
          _split('tom', userId: 'tom', paid: true),
          _split('guest'),
        ]),
      ],
      iOwe: [
        _trip([_split('mine2', userId: 'me')]),
      ],
    );
    expect(count, 3);
  });

  group('ProSubscriptionDetails', () {
    final now = DateTime(2026, 11, 9, 12);

    test('a running trial, its end and no renewal guess', () {
      final d = ProSubscriptionDetails.fromRow({
        'subscription_status': 'trial',
        'trial_ends_at': '2026-11-21T10:00:00Z',
      }, now: now);
      expect(d.isTrial, isTrue);
      expect(d.trialEligible, isFalse);
      expect(d.willRenew, isNull);
      expect(d.familyShared, isNull);
      expect(d.inGracePeriod, isNull);
    });

    test('a trial that ran out is no trial and used up', () {
      final d = ProSubscriptionDetails.fromRow({
        'subscription_status': 'trial',
        'trial_ends_at': '2026-11-01T10:00:00Z',
      }, now: now);
      expect(d.isTrial, isFalse);
      expect(d.trialEligible, isFalse);
    });

    test('a new account may start the trial', () {
      final d = ProSubscriptionDetails.fromRow(const {}, now: now);
      expect(d.status, 'inactive');
      expect(d.trialEligible, isTrue);
    });

    test('a cancelled subscription does not renew', () {
      final d = ProSubscriptionDetails.fromRow({
        'subscription_status': 'cancelled',
        'subscription_expires_at': '2027-11-07T00:00:00Z',
      }, now: now);
      expect(d.willRenew, isFalse);
      expect(d.expiresAt, DateTime.utc(2027, 11, 7).toLocal());
    });
  });

  test('renews-on and family sharing stay unknown for an active account', () async {
    final container = ProviderContainer(
      overrides: [
        authUserIdProvider.overrideWithValue('u1'),
        subscriptionStatusProvider.overrideWith(
          (ref) => Stream.value(SubscriptionStatus.subscribed),
        ),
        subscriptionRowLoaderProvider.overrideWithValue(
          (userId) async => {
            'subscription_status': 'active',
            'subscription_expires_at': '2027-11-07T00:00:00Z',
          },
        ),
      ],
    );
    addTearDown(container.dispose);
    final details = await container.read(proSubscriptionDetailsProvider.future);
    expect(details?.status, 'active');
    expect(container.read(subscriptionRenewsOnProvider), isNull);
    expect(container.read(subscriptionFamilySharedProvider), isNull);
  });

  test('signed out there are no subscription facts', () async {
    final container = ProviderContainer(
      overrides: [authUserIdProvider.overrideWithValue(null)],
    );
    addTearDown(container.dispose);
    expect(await container.read(proSubscriptionDetailsProvider.future), isNull);
  });

  test('presence follows "Anderen zeigen, dass ich einkaufe"', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [authUserIdProvider.overrideWithValue('u1')],
    );
    addTearDown(container.dispose);
    expect(container.read(slots.sharePresenceProvider), isTrue);
    await container
        .read(listPreferencesProvider.notifier)
        .update(const ListPreferences(sharePresence: false));
    expect(container.read(slots.sharePresenceProvider), isFalse);
  });
}
