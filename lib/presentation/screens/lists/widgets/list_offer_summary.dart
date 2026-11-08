import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/offer_savings.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';
import 'package:shoply/presentation/screens/lists/widgets/shopping_mode_header.dart'
    show ShoppingModeHeader;
import 'package:shoply/presentation/screens/offers/offer_text.dart';
import 'package:shoply/presentation/screens/offers/store_menu.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_icons.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_summary_card.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/hint_row.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

const double _kHintIcon = 18; // D2 like the savings card's tag

/// "4 von 11 Artikeln diese Woche bei Lidl im Angebot" (S7, contract
/// `b_slots.dart`): the savings card at the end of the list and under the
/// shopping-mode header, in the mandatory wording of `offer_savings.dart`.
///
/// - In the list the card offers "Diese Woche ausblenden" (close button,
///   swipe left, long press, VoiceOver) and "Nicht mehr zeigen"; a list
///   without a market shows "Für welchen Markt ist …? · Markt wählen"
///   instead, until it is closed (then a week of quiet).
/// - In shopping mode (inside [ShoppingModeHeader]) the card is still: no
///   close button, no gestures, no hint.
///
/// Whether the card shows is decided when the list opens (`angebote.md`
/// 3.2): offers found later appear the next time, so nothing jumps while
/// reading; choosing a market on the screen is the one exception. Renders
/// nothing, and asks nothing, while offers are off, hidden on the list,
/// without a real region or with "Ersparnis in der Liste" off.
class ListOfferSummary extends ConsumerStatefulWidget {
  const ListOfferSummary({super.key, required this.listId});

  final String listId;

  @override
  ConsumerState<ListOfferSummary> createState() => _ListOfferSummaryState();
}

class _ListOfferSummaryState extends ConsumerState<ListOfferSummary> {
  /// Snapshots fetched before this moment were on the device when the list
  /// opened.
  DateTime _openedAt = DateTime.now();

  /// Decided once per opening: the card shows (or not) for good.
  bool? _shows;

  /// The market the decision was made for.
  String? _decidedFor;

  /// Last savings figure shown: the sentence keeps it until the next
  /// opening when it drops below 0,50 € while reading.
  int? _shownSavings;

  @override
  void didUpdateWidget(covariant ListOfferSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listId != widget.listId) {
      _openedAt = DateTime.now();
      _shows = null;
      _decidedFor = null;
      _shownSavings = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final listId = widget.listId;
    final shopping =
        context.findAncestorWidgetOfExactType<ShoppingModeHeader>() != null;
    final visible = ref.watch(
      offerSurfaceVisibleProvider((
        surface: OfferSurface.listSavings,
        listId: listId,
      )),
    );
    if (!visible) return const SizedBox.shrink();
    final prefs = ref.watch(offerDisplayPrefsProvider);
    final now = ref.watch(offerClockProvider)();
    if (prefs?.summaryHiddenWeek[listId] == weekKey(now)) {
      return const SizedBox.shrink();
    }

    final store = ref.watch(storeForListProvider(listId));
    if (store == null) {
      if (shopping) return const SizedBox.shrink();
      return _noStoreHint(context, prefs, now);
    }

    if (_decidedFor != null && _decidedFor != store.id) {
      // The person picked another market here: its offers may appear.
      _openedAt = DateTime(9999);
      _shows = null;
      _shownSavings = null;
    }
    final snapshot = ref.watch(listOfferSnapshotProvider(listId));
    final summary = ref.watch(listOfferSummaryProvider(listId));
    if (_shows == null) {
      if (snapshot.isLoading && !snapshot.hasValue) {
        return const SizedBox.shrink();
      }
      final fetchedAt = snapshot.valueOrNull?.fetchedAt;
      _shows =
          summary != null && fetchedAt != null && fetchedAt.isBefore(_openedAt);
      _decidedFor = store.id;
    }
    if (_shows != true || summary == null) return const SizedBox.shrink();

    final savings = summary.savingsCents ?? _shownSavings;
    _shownSavings = savings;
    final lang = offerLanguageOf(context);
    final text = offerSummaryText(
      OfferSummary(
        chainId: summary.chainId,
        storeName: summary.storeName,
        matched: summary.matched,
        total: summary.total,
        savingsCents: savings,
      ),
      lang,
    );
    final label = context.tr(
      'offer_summary_card_a11y',
      params: {'sentence': text.sentence},
    );
    if (shopping) {
      return OfferSummaryCard(
        head: text.head,
        detail: text.detail,
        semanticLabel: label,
      );
    }
    return OfferSummaryCard(
      head: text.head,
      detail: text.detail,
      semanticLabel: label,
      onHideWeek: () => _hideWeek(context),
      onNever: () => _never(context),
      onMenu: _openMenu,
    );
  }

  Widget _noStoreHint(
    BuildContext context,
    OfferDisplayPrefs? prefs,
    DateTime now,
  ) {
    final until = prefs?.noStoreHintUntil[widget.listId];
    if (prefs == null || (until != null && now.isBefore(until))) {
      return const SizedBox.shrink();
    }
    final lists = ref.watch(listsNotifierProvider).valueOrNull;
    final name = lists
        ?.where((l) => l.id == widget.listId)
        .firstOrNull
        ?.name
        .trim();
    if (name == null || name.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    return Builder(
      builder: (context) => HintRow(
        leading: AvoIcon(
          OfferIcons.storefront,
          size: MediaQuery.textScalerOf(context).scale(_kHintIcon),
          color: colors.secondaryLabel,
        ),
        text: context.tr('offer_hint_no_store', params: {'list': name}),
        actionLabel: context.tr('offer_hint_no_store_action'),
        onTap: () => unawaited(showStoreMenu(context, ref, widget.listId)),
        onDismiss: () => unawaited(
          ref
              .read(offerDisplayPrefsProvider.notifier)
              .snoozeNoStoreHint(widget.listId),
        ),
      ),
    );
  }

  void _hideWeek(BuildContext context) {
    final prefs = ref.read(offerDisplayPrefsProvider.notifier);
    unawaited(prefs.setSummaryHiddenThisWeek(widget.listId, true));
    AvoToast.show(
      context,
      message: context.tr('offer_toast_summary_week'),
      actionLabel: context.tr('common_undo'),
      onAction: () =>
          unawaited(prefs.setSummaryHiddenThisWeek(widget.listId, false)),
    );
  }

  void _never(BuildContext context) {
    final prefs = ref.read(offerDisplayPrefsProvider.notifier);
    unawaited(prefs.setSurface(OfferSurface.listSavings, false));
    AvoToast.show(
      context,
      message: context.tr('offer_toast_summary_off'),
      actionLabel: context.tr('common_undo'),
      onAction: () =>
          unawaited(prefs.setSurface(OfferSurface.listSavings, true)),
    );
  }

  void _openMenu(BuildContext anchor) {
    unawaited(
      showAvoMenu(
        anchor,
        items: [
          AvoMenuItem(
            label: anchor.tr('offer_summary_hide_week'),
            onSelected: () => _hideWeek(context),
          ),
          AvoMenuItem(
            label: anchor.tr('offer_summary_never'),
            onSelected: () => _never(context),
          ),
        ],
      ),
    );
  }
}
