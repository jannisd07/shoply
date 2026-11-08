/// The market menu of a list (S1, `angebote.md`): pick a market, "Anderer
/// Markt …" (opens S2), "Kein fester Markt", and for a suggested market
/// "Ja, Lidl" / "Nicht fragen". Every choice shows at once and is undone
/// from the toast; a failed save rolls back and says so.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/store_chain_directory.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/providers/store_choice_provider.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';
import 'package:shoply/presentation/screens/offers/offer_paths.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

/// Display name of a directory chain ("REWE"), else the id.
String storeNameOf(String chainId) =>
    StoreChainDirectory.byId(chainId)?.displayName ?? chainId;

/// Whether the directory chain [chainId] matches a market search: its
/// name, id or an alias contains [query] (umlauts folded), or [query] is a
/// typo of it ("lidel" finds Lidl). An empty query matches everything.
bool storeMatchesQuery(String chainId, String query) {
  final q = query.trim();
  if (q.isEmpty) return true;
  final chain = StoreChainDirectory.byId(chainId);
  if (chain == null) return false;
  final needle = _fold(q);
  final names = [chain.displayName, chain.id, ...chain.aliases];
  if (names.any((n) => _fold(n).contains(needle))) return true;
  return matchChain(q) == chainId;
}

String _fold(String text) => text
    .toLowerCase()
    .replaceAll('ä', 'ae')
    .replaceAll('ö', 'oe')
    .replaceAll('ü', 'ue')
    .replaceAll('ß', 'ss')
    .replaceAll(RegExp('[^a-z0-9]'), '');

/// Opens "Markt wählen" and returns what was picked (null when closed).
Future<StoreChoice?> openStorePicker(
  BuildContext context, {
  String? listId,
  StorePickerOrigin from = StorePickerOrigin.chip,
}) =>
    context.push<StoreChoice>(storePickerLocation(listId: listId, from: from));

/// The context toasts are shown from: the root navigator, which outlives
/// the screen or menu that asked (the toast host sits around it).
BuildContext _toastContext(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).context;

/// Saves [choice] as the market of [listId] and shows "Markt: REWE ·
/// Widerrufen" (or "Kein fester Markt"). The change shows at once; when the
/// save fails the market springs back, the toast turns into "Markt nicht
/// gespeichert · Erneut versuchen" and the error haptic fires.
///
/// Reads through the app's [ProviderContainer], so it may run on after the
/// screen that asked has closed (S2 pops at once).
Future<void> applyStoreChoice(
  BuildContext context,
  String listId,
  StoreChoice choice,
) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final repo = container.read(listStoreRepositoryProvider);
  final previous = container.read(storeForListProvider(listId))?.id;
  final toastContext = _toastContext(context);
  final next = switch (choice) {
    ChainStoreChoice(:final chainId) => chainId,
    _ => null,
  };
  if (choice is CustomStoreChoice || next == previous) return;

  Future<void> write(String? chainId) => chainId == null
      ? repo.clearExplicit(listId)
      : repo.setExplicit(listId, chainId);

  AvoToast.show(
    toastContext,
    message: next == null
        ? toastContext.tr('offer_toast_store_none')
        : toastContext.tr(
            'offer_toast_store_set',
            params: {'store': storeNameOf(next)},
          ),
    actionLabel: toastContext.tr('common_undo'),
    onAction: () => unawaited(_quietly(write(previous))),
  );
  try {
    await write(next);
  } catch (e) {
    debugPrint('❌ [STORE] Market of the list not saved: $e');
    unawaited(AvoHaptics.error());
    if (!toastContext.mounted) return;
    AvoToast.show(
      toastContext,
      message: toastContext.tr('offer_toast_store_failed'),
      actionLabel: toastContext.tr('common_try_again'),
      onAction: () {
        if (!toastContext.mounted) return;
        unawaited(applyStoreChoice(toastContext, listId, choice));
      },
    );
  }
}

Future<void> _quietly(Future<void> write) async {
  try {
    await write;
  } catch (e) {
    debugPrint('❌ [STORE] Undo of the market not saved: $e');
  }
}

/// The rows of the market menu for [listId] (S1).
List<AvoMenuEntry> storeMenuEntries(
  BuildContext context,
  WidgetRef ref,
  String listId,
) {
  final guess = ref.read(storeGuessForListProvider(listId)).valueOrNull;
  final dontAsk = ref.read(offerDisplayPrefsProvider)?.dontAskStore[listId];
  final suggested =
      guess != null &&
          !guess.confirmed &&
          ref.read(storeDetectionOnProvider) &&
          dontAsk != guess.chainId &&
          StoreChainDirectory.byId(guess.chainId) != null
      ? guess.chainId
      : null;

  void pick(StoreChoice choice) =>
      unawaited(applyStoreChoice(context, listId, choice));

  final other = AvoMenuItem(
    label: context.tr('offer_store_other'),
    icon: AvoIcons.storefront,
    onSelected: () => unawaited(openStorePicker(context, listId: listId)),
  );

  if (suggested != null) {
    final name = storeNameOf(suggested);
    final prefs = ref.read(offerDisplayPrefsProvider.notifier);
    return [
      AvoMenuItem(
        label: context.tr('offer_store_confirm_yes', params: {'store': name}),
        checked: true,
        onSelected: () => pick(ChainStoreChoice(suggested)),
      ),
      other,
      AvoMenuItem(
        label: context.tr('offer_store_dont_ask'),
        onSelected: () => unawaited(prefs.dontAskStore(listId, suggested)),
      ),
    ];
  }

  final current = ref.read(storeForListProvider(listId))?.id;
  final history =
      ref.read(listStoreHistoryProvider(listId)).valueOrNull ?? const [];
  final favorites = ref.read(favoriteStoresProvider);
  // Favourites in their order, then this list's other markets (at most
  // three); without either the common chains (S1).
  final ordered = favorites.isEmpty && history.isEmpty
      ? popularChainIds(ref.read(regionProvider)?.zip)
      : [...favorites, ...history.where((id) => !favorites.contains(id))];
  final chains = <String>{
    if (current != null && !favorites.contains(current)) current,
    for (final id in ordered)
      if (StoreChainDirectory.byId(id) != null) id,
  }.toList();
  return [
    for (final id in chains)
      AvoMenuItem(
        label: storeNameOf(id),
        checked: id == current,
        onSelected: () => pick(ChainStoreChoice(id)),
      ),
    const AvoMenuDivider(),
    other,
    AvoMenuItem(
      label: context.tr('offer_store_none'),
      enabled: current != null,
      onSelected: () => pick(const NoStoreChoice()),
    ),
  ];
}

/// Opens the market menu of [listId] out of the widget of [context].
Future<void> showStoreMenu(BuildContext context, WidgetRef ref, String listId) {
  final guess = ref.read(storeGuessForListProvider(listId)).valueOrNull;
  final title =
      guess != null && !guess.confirmed && ref.read(storeDetectionOnProvider)
      ? context.tr(
          'offer_store_confirm_title',
          params: {'store': storeNameOf(guess.chainId)},
        )
      : context.tr('offer_pick_title');
  return showAvoMenu(
    context,
    items: storeMenuEntries(context, ref, listId),
    semanticLabel: title,
  );
}
