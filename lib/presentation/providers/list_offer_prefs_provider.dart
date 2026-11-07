import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/presentation/providers/app_flags_provider.dart';

/// SharedPreferences key with the ids of the lists whose offers are hidden.
const String hiddenOfferListsPrefsKey = 'offers_hidden_lists_v1';

/// Ids of the lists on which the person hid the offers ("Angebote auf dieser
/// Liste ausblenden"). Kept on this device only; null until the saved
/// choices are loaded.
final hiddenOfferListsProvider =
    StateNotifierProvider<HiddenOfferListsNotifier, Set<String>?>(
      (ref) => HiddenOfferListsNotifier(),
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
) =>
    ref.read(hiddenOfferListsProvider.notifier).setHidden(listId, hidden);

class HiddenOfferListsNotifier extends StateNotifier<Set<String>?> {
  HiddenOfferListsNotifier() : super(null) {
    _loaded = _load();
  }

  late final Future<void> _loaded;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(hiddenOfferListsPrefsKey);
      if (mounted) state = {...?stored};
    } catch (e) {
      // Hiding is a convenience, not a legal gate: without the saved
      // choices the offers show.
      debugPrint('⚠️ [OFFERS] Hidden offer lists not loaded: $e');
      if (mounted) state = const <String>{};
    }
  }

  /// Shows the change at once (after the saved choices are loaded) and then
  /// saves it. A failed save keeps the change for this session.
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
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(hiddenOfferListsPrefsKey, next.toList());
    } catch (e) {
      debugPrint('⚠️ [OFFERS] Hidden offer lists not saved: $e');
    }
  }
}
