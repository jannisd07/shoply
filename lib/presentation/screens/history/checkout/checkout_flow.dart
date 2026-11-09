import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/trip_checkout.dart';
import 'package:shoply/data/services/store_chain_directory.dart';
import 'package:shoply/data/services/trip_money_format.dart';
import 'package:shoply/presentation/screens/history/checkout/checkout_screen.dart';
import 'package:shoply/presentation/screens/history/history_paths.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/trip_history_provider.dart';
import 'package:shoply/presentation/widgets/design/success_moment.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/routes/app_branch.dart';

/// Runs the checkout of [listId] on [context]. True when the trip was saved,
/// false when it was cancelled or had nothing checked. [ref] reads the
/// providers of [context]'s scope.
typedef CheckoutRunner =
    Future<bool> Function(BuildContext context, WidgetRef ref, String listId);

/// The checkout behind [openCheckoutFlow]: the full-screen chain V1 → V3 →
/// (V7). Override in tests that only need the result.
final checkoutRunnerProvider = Provider<CheckoutRunner>(
  (ref) => runCheckoutChain,
);

/// "Einkauf abschließen" for [listId] (contract `b_slots.dart`): pushes
/// `/checkout/:listId` (V1). The future ends only when the whole chain is
/// over (V1, the success moment V3, an optional split V7) and is true when
/// a trip was saved or is queued (offline, slow network: it waits with the
/// sync mark in the history); then the host ends the shopping mode. The undo toast
/// "Einkauf gespeichert · Widerrufen" follows right after.
Future<bool> openCheckoutFlow(BuildContext context, String listId) {
  final container = ProviderScope.containerOf(context, listen: false);
  final runner = container.read(checkoutRunnerProvider);
  final ref = context is WidgetRef
      ? context as WidgetRef
      : _ContainerRef(container, context);
  return runner(context, ref, listId);
}

/// The default [CheckoutRunner].
Future<bool> runCheckoutChain(
  BuildContext context,
  WidgetRef ref,
  String listId,
) async {
  final router = GoRouter.of(context);
  final controller = ref.read(tripHistoryProvider.notifier);
  final items = ref.read(itemsNotifierProvider(listId).notifier);
  final outcome = await router.push<Object?>(
    checkoutLocation(listId),
  );
  if (outcome is! CheckoutOutcome) return false;
  if (!context.mounted) return true;

  // V3: only after V1 has closed, over the list (or shopping mode).
  await showSuccessMoment(
    context,
    title: context.tr('hist_saved_title'),
    subtitle: checkoutSuccessSubtitle(context, outcome),
  );

  final tripId = outcome.tripId;
  final saved = outcome.result is CheckoutSaved;
  if (outcome.request.splitPlanned && saved && context.mounted) {
    await router.push<Object?>(
      historySplitLocation(
        tripId,
        amountCents: outcome.request.totalCostCents,
        fromCheckout: true,
      ),
    );
  }
  if (context.mounted) {
    showCheckoutUndoToast(
      context,
      controller: controller,
      tripId: tripId,
      reloadItems: items.loadItems,
    );
  }
  return true;
}

/// The V3 subtitle: "9 Artikel bei Lidl · ca. 3,20 € durch Angebote
/// gespart, laut Händler", "9 Artikel bei Lidl" or "9 Artikel".
String checkoutSuccessSubtitle(BuildContext context, CheckoutOutcome outcome) {
  final n = outcome.itemCount;
  final chainId = outcome.request.chainId;
  final store = chainId == null
      ? null
      : StoreChainDirectory.byId(chainId)?.displayName;
  final base = store == null
      ? (n == 1
            ? context.tr('hist_saved_sub_one')
            : context.tr('hist_saved_sub', params: {'n': '$n'}))
      : (n == 1
            ? context.tr('hist_saved_sub_store_one', params: {'store': store})
            : context.tr(
                'hist_saved_sub_store',
                params: {'n': '$n', 'store': store},
              ));
  final savings = outcome.savingsCents;
  if (savings == null || store == null) return base;
  return context.tr(
    'hist_saved_sub_savings',
    params: {
      'base': base,
      'amount': formatEuroCents(
        savings,
        Localizations.localeOf(context).languageCode,
      ),
    },
  );
}

/// "Einkauf gespeichert · Widerrufen" (V3, 4 s, 10 s with VoiceOver).
/// "Widerrufen" takes the trip back with a split from this chain and its
/// pushes; when the toast is gone the pushes are released.
void showCheckoutUndoToast(
  BuildContext context, {
  required TripHistoryController controller,
  required String tripId,
  required Future<void> Function() reloadItems,
}) {
  var undone = false;
  final undoneText = context.tr('hist_saved_undone');
  final failedText = context.tr('hist_undo_failed');
  final voiceOver = MediaQuery.accessibleNavigationOf(context);
  // Without VoiceOver the toast is gone after its fixed 4 s, so the pushes
  // may go then. With VoiceOver it pauses while focused (A's AvoToast has no
  // dismissal callback yet, A-V24): only the hold ends the wait there.
  // "Widerrufen" itself stays valid on the server for 15 minutes.
  AvoToast.show(
    context,
    message: context.tr('hist_saved_toast'),
    actionLabel: context.tr('common_undo'),
    onAction: () {
      undone = true;
      unawaited(() async {
        final result = await controller.undo(tripId);
        if (result == UndoTripResult.undone) {
          await reloadItems();
          if (context.mounted) AvoToast.show(context, message: undoneText);
        } else {
          unawaited(AvoHaptics.error());
          if (context.mounted) AvoToast.show(context, message: failedText);
          controller.release(tripId);
        }
      }());
    },
  );
  if (!voiceOver) {
    Timer(checkoutToastGone, () {
      if (!undone) controller.release(tripId);
    });
  }
}

/// A [WidgetRef] over the provider container of a plain [BuildContext], so
/// [openCheckoutFlow] keeps its `(context, listId)` contract for hosts whose
/// context is no consumer. Watching is reading here: the runner never
/// rebuilds anything.
class _ContainerRef implements WidgetRef {
  _ContainerRef(this._container, this.context);

  final ProviderContainer _container;

  @override
  final BuildContext context;

  @override
  T read<T>(ProviderListenable<T> provider) => _container.read(provider);

  @override
  T watch<T>(ProviderListenable<T> provider) => _container.read(provider);

  @override
  bool exists(ProviderBase<Object?> provider) => _container.exists(provider);

  @override
  void invalidate(ProviderOrFamily provider) =>
      _container.invalidate(provider);

  @override
  R refresh<R>(Refreshable<R> provider) =>
      _container.refresh(provider);

  @override
  void listen<T>(
    ProviderListenable<T> provider,
    void Function(T? previous, T next) listener, {
    void Function(Object error, StackTrace stackTrace)? onError,
  }) => throw UnsupportedError('listen inside the checkout runner');

  @override
  ProviderSubscription<T> listenManual<T>(
    ProviderListenable<T> provider,
    void Function(T? previous, T next) listener, {
    void Function(Object error, StackTrace stackTrace)? onError,
    bool fireImmediately = false,
  }) => _container.listen(
    provider,
    listener,
    onError: onError,
    fireImmediately: fireImmediately,
  );
}

/// A trip that V1 no longer waited for was refused later (offline, slow,
/// retried): say so over whatever is open, with the error haptic, so it
/// never disappears without a word (spec §3.1).
void showLateCheckoutRejection(CheckoutResult rejection) {
  final c = rootNavigatorKey.currentContext;
  if (c == null || !c.mounted) return;
  final message = switch (rejection) {
    CheckoutAlreadyCompleted(:final byName) => c.tr(
      'hist_late_done_by_other',
      params: {
        'name': (byName == null || byName.trim().isEmpty)
            ? c.tr('hist_member_unknown')
            : byName,
      },
    ),
    CheckoutListGone() => c.tr('hist_late_list_gone'),
    CheckoutNothingChecked() => c.tr('hist_late_nothing_checked'),
    CheckoutSaved() || CheckoutPending() => null,
  };
  if (message == null) return;
  unawaited(AvoHaptics.error());
  AvoToast.show(c, message: message);
}
