import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

/// The device-wide SharedPreferences key the hidden lists used before they
/// were kept per account. Read once and moved to the first account that
/// signs in on this device ([hiddenOfferListsKeyFor]), then removed.
const String hiddenOfferListsPrefsKey = 'offers_hidden_lists_v1';

/// SharedPreferences key of the lists whose offers [userId] hid.
String hiddenOfferListsKeyFor(String userId) =>
    '$hiddenOfferListsPrefsKey:$userId';

/// The signed-in account the offer choices on this device belong to; null
/// signed out or while the session cannot be read. Choices are stored per
/// account and every provider that keeps them starts again when this
/// changes (sign-out, another account). Override in tests.
final offerAccountIdProvider = Provider<String?>((ref) {
  try {
    return ref.watch(authUserIdProvider);
  } catch (e) {
    // Without a session (Supabase not ready) there is no account.
    return null;
  }
});

/// Ids of the lists on which the person hid the offers ("Angebote auf dieser
/// Liste ausblenden"). Kept on this device per account; null until the saved
/// choices are loaded. Starts again for another account.
final hiddenOfferListsProvider =
    StateNotifierProvider<HiddenOfferListsNotifier, Set<String>?>(
      (ref) => HiddenOfferListsNotifier(ref.watch(offerAccountIdProvider)),
    );

/// Whether the person hid the offers on [listId] (contract 3.3). False until
/// the saved choices are loaded.
final offersHiddenForListProvider = Provider.family<bool, String>(
  (ref, listId) => ref.watch(
    hiddenOfferListsProvider.select((ids) => ids?.contains(listId) ?? false),
  ),
);

/// The gate of every offer slot on a list: offers are available (module and
/// kill switch) and known not to be hidden on [listId]. Closed until the
/// saved choices are loaded, so a hidden list never asks the offers source.
final offersVisibleForListProvider = Provider.family<bool, String>(
  (ref, listId) =>
      ref.watch(offersAvailableProvider) &&
      ref.watch(
        hiddenOfferListsProvider.select(
          (ids) => ids != null && !ids.contains(listId),
        ),
      ),
);

/// Hides or shows the offers on [listId] and saves the choice on the device
/// (contract `b_slots.dart`, list menu "Angebote für diese Liste
/// ausblenden"). Services without a [WidgetRef] call
/// `ref.read(hiddenOfferListsProvider.notifier).setHidden(listId, hidden)`.
Future<void> setOffersHiddenForList(
  WidgetRef ref,
  String listId,
  bool hidden,
) => ref.read(hiddenOfferListsProvider.notifier).setHidden(listId, hidden);

class HiddenOfferListsNotifier extends StateNotifier<Set<String>?> {
  /// The hidden lists of [userId]; signed out (null) nothing is stored.
  HiddenOfferListsNotifier(this.userId) : super(null) {
    _loaded = _load();
  }

  final String? userId;
  late final Future<void> _loaded;

  Future<void> _load() async {
    final id = userId;
    if (id == null) {
      if (mounted) state = const <String>{};
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = hiddenOfferListsKeyFor(id);
      var stored = prefs.getStringList(key);
      final legacy = prefs.getStringList(hiddenOfferListsPrefsKey);
      if (legacy != null) {
        // Once: the device-wide choice from before goes to this account.
        if (stored == null) {
          stored = legacy;
          await prefs.setStringList(key, legacy);
        }
        await prefs.remove(hiddenOfferListsPrefsKey);
      }
      if (mounted) state = {...?stored};
    } catch (e) {
      // Hiding is a convenience, not a legal gate: without the saved
      // choices the offers show.
      debugPrint('⚠️ [OFFERS] Hidden offer lists not loaded: $e');
      if (mounted) state = const <String>{};
    }
  }

  /// Shows the change at once (after the saved choices are loaded) and then
  /// saves it. A failed save keeps the change for this session; signed out
  /// it stays in memory only.
  Future<void> setHidden(String listId, bool hidden) async {
    await _loaded;
    final current = state ?? const <String>{};
    if (!mounted || current.contains(listId) == hidden) return;
    final next = {...current};
    if (hidden) {
      next.add(listId);
    } else {
      next.remove(listId);
    }
    state = next;
    final id = userId;
    if (id == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(hiddenOfferListsKeyFor(id), next.toList());
    } catch (e) {
      debugPrint('⚠️ [OFFERS] Hidden offer lists not saved: $e');
    }
  }
}
