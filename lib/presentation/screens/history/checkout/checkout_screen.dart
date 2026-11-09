import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/constants/app_brand.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/core/services/shared_preferences_provider.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/trip_checkout.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/store_chain_directory.dart';
import 'package:shoply/data/services/trip_money_format.dart';
import 'package:shoply/data/services/trip_split_math.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/store_choice_provider.dart';
import 'package:shoply/presentation/screens/history/checkout/checkout_data.dart';
import 'package:shoply/presentation/screens/history/history_paths.dart';
import 'package:shoply/presentation/screens/history/widgets/amount_field.dart';
import 'package:shoply/presentation/screens/history/widgets/savings_line.dart';
import 'package:shoply/presentation/screens/history/widgets/store_choice_chips.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/trip_history_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/confirm_dialog.dart';
import 'package:shoply/presentation/widgets/design/full_screen_editor.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/routes/route_paths.dart';

// V1 layout (verlauf-kosten.md V1, D2 X-Einkaufsmodus).
const int _kMaxChipsBeforeHere = 4; // D2: at most four market chips
const int _kMaxNames = 3; // "Brokkoli, Gouda und 4 weitere"
const int _kAmountCheckCents = 100000; // "Stimmt der Betrag?" above 1.000 €

/// What V1 hands back to `openCheckoutFlow` when a trip was saved (or is on
/// its way): everything V3 and the split step need.
@immutable
class CheckoutOutcome {
  const CheckoutOutcome({
    required this.result,
    required this.request,
    required this.itemCount,
    this.savingsCents,
  });

  /// [CheckoutSaved] or [CheckoutPending].
  final CheckoutResult result;
  final CheckoutRequest request;

  /// Checked items that went into the trip.
  final int itemCount;

  /// Rounded savings for the V3 subtitle; null without.
  final int? savingsCents;

  /// The trip id (local while pending).
  String get tripId => switch (result) {
    CheckoutSaved(:final trip) => trip.id,
    CheckoutPending(:final localTripId) => localTripId,
    _ => '',
  };
}

/// V1 "Einkauf abschließen" (`/checkout/:listId`): where was I, and what
/// goes into the history? One tap on "Einkauf speichern" saves; the market
/// is preselected, amount and "Kosten teilen" are optional.
///
/// Closes with a [CheckoutOutcome] when the trip was saved, with nothing
/// when closed. With a typed amount or a changed market, closing asks
/// "Änderungen verwerfen?" and the swipe back is off.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.listId,
    this.splitStepAvailable = false,
    this.tripDetailAvailable = false,
  });

  final String listId;

  /// Whether `/history/:tripId/split` exists (slice W11); without it the
  /// "Kosten teilen" switch is not offered.
  final bool splitStepAvailable;

  /// Whether `/history/:tripId` exists; else "Zum Verlauf" opens `/history`.
  final bool tripDetailAvailable;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

sealed class _Blocked {
  const _Blocked();
}

final class _DoneByOther extends _Blocked {
  const _DoneByOther(this.name, this.tripId);
  final String? name;
  final String? tripId;
}

final class _ListGone extends _Blocked {
  const _ListGone();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String? _chain;
  String? _source; // list, learned, location, user
  bool _preselected = false;
  bool _touchedStore = false;
  final List<String> _picked = [];
  AmountInput _amount = const AmountInput.empty();
  bool? _split;
  bool _saving = false;
  _Blocked? _blocked;
  bool _hintMarked = false;
  bool _saveFailed = false;

  String get _lang => Localizations.localeOf(context).languageCode;

  String? _initialChain;

  /// A typed amount, or a market other than the one V1 opened with.
  bool get _dirty => !_amount.isEmpty || (_touchedStore && _chain != _initialChain);

  void _choose(String? chainId, {String source = 'user'}) {
    setState(() {
      _chain = chainId;
      _source = chainId == null ? null : source;
      _touchedStore = true;
    });
  }

  Future<void> _openPicker() async {
    final choice = await context.push<Object?>(
      storePickTripLocation(listId: widget.listId, selected: _chain),
    );
    if (!mounted || choice == null) return;
    final chainId = _chainOf(choice);
    if (chainId == _noStore) {
      _choose(null);
      return;
    }
    if (chainId == null) return;
    setState(() {
      _picked
        ..remove(chainId)
        ..insert(0, chainId);
    });
    _choose(chainId);
  }

  static const String _noStore = '';

  /// The chain id of a `StoreChoice` popped by the picker; [_noStore] for
  /// "Ohne Markt", null for a market of the person's own (a trip stores
  /// chains only so far).
  String? _chainOf(Object choice) => switch (choice) {
    ChainStoreChoice(:final chainId) => chainId,
    NoStoreChoice() => _noStore,
    _ => null,
  };

  Future<void> _useLocation() async {
    final port = ref.read(checkoutLocationPortProvider);
    final access = ref.read(checkoutLocationHintProvider).valueOrNull;
    if (access == CheckoutLocationAccess.denied) {
      await port.openSettings();
      return;
    }
    final go = await showAvoConfirm(
      context,
      title: context.tr('hist_location_title'),
      message: context.tr(
        'hist_location_body',
        params: {'app': AppBrand.name},
      ),
      confirmLabel: context.tr('hist_location_continue'),
      cancelLabel: context.tr('common_not_now'),
      destructive: false,
    );
    if (!go || !mounted) return;
    if (await port.request()) ref.invalidate(checkoutStoreHereProvider);
    if (mounted) ref.invalidate(checkoutLocationHintProvider);
  }

  Future<void> _save(List<ShoppingItemModel> checked, String listName) async {
    if (_saving || _amount.isInvalid) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    final members = ref.read(splitMembersProvider(widget.listId)) ?? const [];
    final me = ref.read(authUserIdProvider);
    final mine = members.where((m) => m.userId == me).firstOrNull;
    final split = _splitShown(members) && (_split ?? _splitDefault());
    final request = CheckoutRequest(
      listId: widget.listId,
      listName: listName,
      checkedItems: checked,
      chainId: _chain,
      storeSource: switch (_source) {
        'list' => TripStoreSource.list,
        'learned' => TripStoreSource.learned,
        'location' => TripStoreSource.location,
        null => null,
        _ => TripStoreSource.user,
      },
      totalCostCents: _amount.cents,
      splitPlanned: split,
      notifyUserIds: [
        for (final m in members)
          if (m.userId != me) m.userId,
      ],
      actorName: mine?.name,
    );
    final savings = ref.read(
      checkoutSavingsCentsProvider((listId: widget.listId, chainId: _chain)),
    );
    final controller = ref.read(tripHistoryProvider.notifier);
    final pending = controller.checkout(request);
    final localId = controller.localIdOf(request) ?? '';

    // Saving never waits for the network: offline it closes at once, online
    // it waits briefly only to catch a synchronous "no" (list gone, a member
    // was faster), which keeps V1 open with the matching state.
    CheckoutResult result;
    if (ref.read(isOfflineProvider)) {
      result = CheckoutPending(localTripId: localId);
    } else {
      result = await pending.timeout(
        checkoutRejectWait,
        onTimeout: () => CheckoutPending(localTripId: localId),
      );
    }
    if (!mounted) return;

    switch (result) {
      case CheckoutAlreadyCompleted(:final byName, :final tripId):
        setState(() {
          _saving = false;
          _blocked = _DoneByOther(byName, tripId);
        });
        return;
      case CheckoutListGone():
        setState(() {
          _saving = false;
          _blocked = const _ListGone();
        });
        return;
      case CheckoutPending(failed: true, :final localTripId):
        // Online and refused at once (server error): nothing is saved and
        // the items stay checked. V1 stays open, saying so, and the next
        // tap tries again (no second entry in the history).
        unawaited(controller.undo(localTripId));
        unawaited(AvoHaptics.error());
        setState(() {
          _saving = false;
          _saveFailed = true;
        });
        return;
      case CheckoutNothingChecked():
        setState(() => _saving = false);
        unawaited(
          ref.read(itemsNotifierProvider(widget.listId).notifier).loadItems(),
        );
        return;
      case CheckoutSaved() || CheckoutPending():
        // V1 stops waiting: a later "no" comes as a toast (I4).
        if (result is CheckoutPending) controller.handOver(result.localTripId);
        final prefs = ref.read(sharedPreferencesProvider).valueOrNull;
        if (_splitShown(members)) {
          unawaited(prefs?.setBool(checkoutSplitLastKey(widget.listId), split));
        }
        // The removed items leave the list now; realtime would follow.
        unawaited(
          ref.read(itemsNotifierProvider(widget.listId).notifier).loadItems(),
        );
        Navigator.of(context).pop(
          CheckoutOutcome(
            result: result,
            request: request,
            itemCount: checked.length,
            savingsCents: savings,
          ),
        );
    }
  }

  bool _splitDefault() =>
      ref
          .read(sharedPreferencesProvider)
          .valueOrNull
          ?.getBool(checkoutSplitLastKey(widget.listId)) ??
      false;

  bool _splitShown(List<SplitMember> members) =>
      widget.splitStepAvailable &&
      ref.read(moduleEnabledProvider(AppModule.costSplit)) &&
      members.length >= 2;

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final listId = widget.listId;
    final itemsState = ref.watch(itemsNotifierProvider(listId));
    final items = itemsState.valueOrNull;
    final listName = ref.watch(checkoutListNameProvider(listId)).valueOrNull ?? '';
    final preselection = ref.watch(checkoutPreselectionProvider(listId));
    final here = ref.watch(checkoutStoreHereProvider).valueOrNull;
    final favorites = ref.watch(favoriteStoresProvider);
    final history =
        ref.watch(listStoreHistoryProvider(listId)).valueOrNull ??
        const <String>[];
    final members = ref.watch(splitMembersProvider(listId)) ?? const [];
    final splitModule = ref.watch(moduleEnabledProvider(AppModule.costSplit));
    final hint = ref.watch(checkoutLocationHintProvider).valueOrNull;
    final offline = ref.watch(isOfflineProvider);
    final savings = ref.watch(
      checkoutSavingsCentsProvider((listId: listId, chainId: _chain)),
    );

    // Preselection: decided once, from local data, never changed later by
    // itself. The location only adds the "(hier)" chip, and picks it only
    // while nothing is chosen and the person has not tapped anything.
    if (!_preselected &&
        preselection != null &&
        !_touchedStore &&
        _source != 'location') {
      _preselected = true;
      _chain = preselection.chainId;
      _initialChain = _chain;
      _source = preselection.source;
    }
    if (!_touchedStore &&
        _chain == null &&
        preselection == null &&
        here != null &&
        StoreChainDirectory.byId(here) != null) {
      _chain = here;
      _initialChain = here;
      _source = 'location';
    }

    final title = context.tr('hist_checkout_title');
    if (items == null) {
      return FullScreenEditor(
        title: title,
        child: SkeletonSection(
          rows: 2,
          withImage: false,

        ),
      );
    }

    final checked = [
      for (final item in items)
        if (item.isChecked) item,
    ];
    final open = [
      for (final item in items)
        if (!item.isChecked) item,
    ];

    final blocked = _blocked;
    if (blocked != null) return _blockedScreen(title, blocked);
    if (checked.isEmpty) {
      return _messageScreen(
        title,
        heading: context.tr('hist_checkout_empty_title'),
        body: context.tr('hist_checkout_empty_body'),
        primaryLabel: context.tr('hist_back_to_list'),
        onPrimary: _close,
      );
    }

    // Chips: chosen first, favourites, this list's markets (four at most),
    // then "(hier)", then "Anderer Markt …".
    final ids = <String>[
      ?_chain,
      ..._picked,
      ?preselection?.chainId,
      ...favorites,
      ...history,
    ];
    final entries = <StoreChoiceEntry>[];
    for (final id in ids) {
      if (StoreChainDirectory.byId(id) == null) continue;
      if (entries.any((e) => e.chainId == id)) continue;
      if (entries.length >= _kMaxChipsBeforeHere && id != _chain) continue;
      entries.add(StoreChoiceEntry(id, here: id == here));
    }
    if (here != null &&
        StoreChainDirectory.byId(here) != null &&
        !entries.any((e) => e.chainId == here)) {
      entries.add(StoreChoiceEntry(here, here: true));
    }

    final sourceNote = _chain == null
        ? null
        : switch (_source) {
            'list' => context.tr('hist_checkout_source_list'),
            'learned' => context.tr('hist_checkout_source_learned'),
            'location' => context.tr('hist_checkout_source_location'),
            _ => null,
          };

    final showHint =
        preselection == null &&
        _chain == null &&
        !offline &&
        (hint == CheckoutLocationAccess.notAsked ||
            hint == CheckoutLocationAccess.denied);
    if (showHint && !_hintMarked) {
      _hintMarked = true;
      final prefs = ref.read(sharedPreferencesProvider).valueOrNull;
      if (prefs != null) unawaited(markCheckoutLocationHintShown(prefs));
    }

    final splitShown =
        widget.splitStepAvailable && splitModule && members.length >= 2;
    final split = _split ?? (splitShown && _splitDefault());
    final me = ref.watch(authUserIdProvider);
    final others = [
      for (final m in members)
        if (m.userId != me) m.name.isEmpty ? context.tr('hist_member_unknown') : m.name,
    ];

    final amountCents = _amount.cents;
    final children = <Widget>[
      if (_saveFailed)
        Padding(
          padding: const EdgeInsets.only(bottom: AvoSpacing.m),
          child: StatusRow(
            kind: StatusKind.failed,
            text: context.tr('common_not_saved'),
          ),
        ),
      _Summary(listName: listName, checked: checked, open: open),
      InsetSection(
        header: context.tr('hist_checkout_where'),
        showSeparators: false,
        footer: showHint ? null : sourceNote,
        children: [
          StoreChoiceChips(
            entries: entries,
            selected: _chain,
            selectedHint: sourceNote,
            onChanged: _choose,
            onOther: () => unawaited(_openPicker()),
          ),
        ],
      ),
      if (showHint)
        _LocationHint(
          denied: hint == CheckoutLocationAccess.denied,
          onPressed: () => unawaited(_useLocation()),
        ),
      InsetSection(
        header: context.tr('hist_checkout_amount'),
        footer: _amount.isInvalid
            ? null
            : context.tr(
                splitShown
                    ? 'hist_checkout_amount_note_split'
                    : 'hist_checkout_amount_note',
              ),
        children: [
          HistoryAmountField(
            title: context.tr('hist_checkout_amount'),
            placeholder: context.tr('hist_checkout_amount_placeholder'),
            languageCode: _lang,
            // VoiceOver hears the error on the field itself (WCAG 3.3.1).
            semanticHint: _amount.isInvalid
                ? context.tr('hist_amount_invalid')
                : context.tr(
                    splitShown
                        ? 'hist_checkout_amount_note_split'
                        : 'hist_checkout_amount_note',
                  ),
            onChanged: (input) => setState(() => _amount = input),
          ),
        ],
      ),
      if (_amount.isInvalid)
        AmountNote(text: context.tr('hist_amount_invalid'), error: true)
      else if (amountCents != null && amountCents > _kAmountCheckCents)
        AmountNote(
          text: context.tr(
            'hist_amount_check',
            params: {'amount': formatEuroCents(amountCents, _lang)},
          ),
        ),
      if (splitShown)
        Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.section),
          child: InsetSection(
            children: [
              ToggleRow(
                leading: AvoIcon(
                  AvoIcons.eurosignCircle,
                  color: context.colors.secondaryLabel,
                ),
                title: context.tr('hist_checkout_split'),
                subtitle: _splitSubtitle(context, others),
                value: split,
                onChanged: (on) => setState(() => _split = on),
              ),
            ],
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(top: AvoSpacing.section),
        child: SavingsLine(cents: savings),
      ),
      const SizedBox(height: AvoSpacing.l),
    ];

    return FullScreenEditor(
      title: title,
      dirty: _dirty,
      bottom: AppButton.primary(
        label: context.tr('hist_checkout_save'),
        icon: AvoIcon(AvoIcons.check, color: context.colors.onTint),
        size: AppButtonSize.large,
        expand: true,
        onPressed: _amount.isInvalid || _saving
            ? null
            : () => unawaited(_save(checked, listName)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  String _splitSubtitle(BuildContext context, List<String> others) {
    if (others.length == 1) {
      return context.tr('hist_checkout_split_one', params: {'a': others[0]});
    }
    if (others.length == 2) {
      return context.tr(
        'hist_checkout_split_two',
        params: {'a': others[0], 'b': others[1]},
      );
    }
    return context.tr(
      'hist_checkout_split_many',
      params: {
        'a': others[0],
        'b': others[1],
        'n': '${others.length - 2}',
      },
    );
  }

  Widget _blockedScreen(String title, _Blocked blocked) {
    switch (blocked) {
      case _DoneByOther(:final name, :final tripId):
        return _messageScreen(
          title,
          heading: context.tr(
            'hist_checkout_done_by_other',
            params: {
              'name': (name == null || name.trim().isEmpty)
                  ? context.tr('hist_member_unknown')
                  : name,
            },
          ),
          primaryLabel: context.tr('hist_to_history'),
          onPrimary: () {
            final router = GoRouter.of(context);
            Navigator.of(context).pop();
            unawaited(
              router.push<void>(
                widget.tripDetailAvailable && tripId != null
                    ? historyTripLocation(tripId)
                    : RoutePaths.history,
              ),
            );
          },
          secondaryLabel: context.tr('hist_back_to_list'),
          onSecondary: _close,
        );
      case _ListGone():
        return _messageScreen(
          title,
          heading: context.tr('hist_checkout_list_gone'),
          primaryLabel: context.tr('hist_to_lists'),
          onPrimary: () {
            final router = GoRouter.of(context);
            Navigator.of(context).pop();
            router.go(RoutePaths.lists);
          },
        );
    }
  }

  Widget _messageScreen(
    String title, {
    required String heading,
    String? body,
    required String primaryLabel,
    required VoidCallback onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    return FullScreenEditor(
      title: title,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton.primary(
            label: primaryLabel,
            size: AppButtonSize.large,
            expand: true,
            onPressed: onPrimary,
          ),
          if (secondaryLabel != null && onSecondary != null)
            AppButton.plain(label: secondaryLabel, onPressed: onSecondary),
        ],
      ),
      child: InsetSection(
        children: [
          Padding(
            padding: const EdgeInsets.all(AvoSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    heading,
                    style: context.text(AvoTextStyle.headline),
                  ),
                ),
                if (body != null) ...[
                  const SizedBox(height: AvoSpacing.xs),
                  Text(
                    body,
                    style: context.text(
                      AvoTextStyle.subhead,
                      color: context.colors.label,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "9 Artikel im Wagen" and "2 bleiben auf Wocheneinkauf: Brokkoli, Gouda".
class _Summary extends StatelessWidget {
  const _Summary({
    required this.listName,
    required this.checked,
    required this.open,
  });

  final String listName;
  final List<ShoppingItemModel> checked;
  final List<ShoppingItemModel> open;

  @override
  Widget build(BuildContext context) {
    final n = checked.length;
    final inCart = n == 1
        ? context.tr('hist_checkout_in_cart_one')
        : context.tr('hist_checkout_in_cart', params: {'n': '$n'});
    String? left;
    if (open.isNotEmpty) {
      final shown = [for (final i in open.take(_kMaxNames)) i.name].join(', ');
      final names = open.length > _kMaxNames
          ? context.tr(
              'hist_names_more',
              params: {'names': shown, 'n': '${open.length - _kMaxNames}'},
            )
          : shown;
      left = open.length == 1
          ? context.tr(
              'hist_checkout_left_one',
              params: {'list': listName, 'names': names},
            )
          : context.tr(
              'hist_checkout_left',
              params: {
                'n': '${open.length}',
                'list': listName,
                'names': names,
              },
            );
    }
    return Semantics(
      container: true,
      label: left == null ? '$inCart.' : '$inCart. $left.',
      excludeSemantics: true,
      child: InsetSection(
        children: [
          Padding(
            padding: const EdgeInsets.all(AvoSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(inCart, style: context.text(AvoTextStyle.headline)),
                if (left != null) ...[
                  const SizedBox(height: AvoSpacing.xxs),
                  Text(left, style: context.text(AvoTextStyle.subhead)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The one-time location hint under "Wo warst du?" (never asks on open).
class _LocationHint extends StatelessWidget {
  const _LocationHint({required this.denied, required this.onPressed});

  final bool denied;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AvoSpacing.xxxl,
        AvoSpacing.s,
        AvoSpacing.xxxl,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr(
              'hist_checkout_location_hint',
              params: {'app': AppBrand.name},
            ),
            style: context.text(
              AvoTextStyle.footnote,
              color: context.colors.secondaryLabel,
            ),
          ),
          AppButton.plain(
            label: context.tr(
              denied
                  ? 'hist_checkout_location_settings'
                  : 'hist_checkout_location_use',
            ),
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}
