import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/expense_split.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/services/expense_split_service.dart';
import 'package:shoply/data/services/trip_money_format.dart';
import 'package:shoply/data/services/trip_split_math.dart';
import 'package:shoply/presentation/screens/history/history_actions.dart';
import 'package:shoply/presentation/screens/history/history_format.dart';
import 'package:shoply/presentation/screens/history/widgets/amount_field.dart';
import 'package:shoply/presentation/state/expense_split_provider.dart';
import 'package:shoply/presentation/state/shopping_history_provider.dart';
import 'package:shoply/presentation/state/trip_history_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/full_screen_editor.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/routes/app_branch.dart';

const int _kAmountCheckCents = 100000; // "Stimmt der Betrag?" above 1.000 €

/// "Wocheneinkauf · Lidl · Sa., 7. Nov." under the amount (V6, V7).
String tripContextLine(BuildContext context, ShoppingHistory trip, DateTime now) {
  final lang = Localizations.localeOf(context).languageCode;
  final store = tripStoreName(trip);
  final date = shortDate(trip.completedAt, lang, now);
  return store == null
      ? '${trip.listName} · $date'
      : context.tr(
          'hist_trip_context',
          params: {'list': trip.listName, 'store': store, 'date': date},
        );
}

/// Saves the amount of [trip] (V6): optimistic, with "Betrag gespeichert ·
/// Widerrufen"; on the fallback without L6 an equal split is recomputed
/// here. A later failure brings the old amount back with "Betrag nicht
/// gespeichert · Erneut versuchen" and the error haptic.
/// [ref] is the app's container: V6 has already closed when this runs.
Future<void> saveTripAmount(
  ProviderContainer ref,
  ShoppingHistory trip,
  int? cents, {
  bool showToast = true,
}) async {
  final controller = ref.read(tripHistoryProvider.notifier);
  final before = trip;
  controller.upsert(
    cents == null
        ? trip.copyWith(clearTotalCost: true)
        : trip.copyWith(totalCost: centsToEuros(cents), totalCostSource: 'user'),
  );
  BuildContext? host() => rootNavigatorKey.currentContext;
  try {
    final onServer = await ref
        .read(shoppingHistoryServiceProvider)
        .setTripAmount(trip.id, cents);
    if (!onServer && cents != null) {
      await _recomputeEqual(ref, trip, cents);
    }
    ref.invalidate(tripSplitsProvider(trip.id));
    unawaited(ref.read(openSharesProvider.notifier).refresh());
    final c = host();
    if (!showToast || c == null || !c.mounted) return;
    AvoToast.show(
      c,
      message: c.tr('hist_amount_saved'),
      actionLabel: c.tr('common_undo'),
      onAction: () => unawaited(
        saveTripAmount(ref, trip.copyWith(), before.totalCostCents, showToast: false),
      ),
    );
  } catch (e) {
    debugPrint('❌ [HISTORY] Amount not saved: ${e.runtimeType}');
    controller.upsert(before);
    unawaited(AvoHaptics.error());
    final c = host();
    if (c == null || !c.mounted) return;
    AvoToast.show(
      c,
      message: c.tr('hist_amount_save_failed'),
      actionLabel: c.tr('common_try_again'),
      onAction: () => unawaited(saveTripAmount(ref, before, cents)),
    );
  }
}

/// Fallback of L6: new equal shares in the stored order.
Future<void> _recomputeEqual(ProviderContainer ref, ShoppingHistory trip, int cents) async {
  final service = ref.read(expenseSplitServiceProvider);
  final List<ExpenseSplit> splits = await service.getSplitsForHistory(trip.id);
  if (splits.isEmpty || splits.any((s) => s.splitMode != 'equal')) return;
  await service.saveSplit(
    historyId: trip.id,
    totalCents: cents,
    participants: [
      for (final s in splits)
        SplitShare(userId: s.userId, participantName: s.participantName, amount: 0),
    ],
    shareCents: equalShareCents(cents, splits.length),
    equal: true,
    paidByUserId: trip.paidByUserId,
    paidByName: trip.paidByName,
  );
}

/// V6 "Betrag" (`/history/:tripId/amount`): type, change or remove the
/// amount of a trip. Only the person who shopped comes here.
class TripAmountScreen extends ConsumerStatefulWidget {
  const TripAmountScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripAmountScreen> createState() => _TripAmountScreenState();
}

class _TripAmountScreenState extends ConsumerState<TripAmountScreen> {
  bool _gone = false;
  AmountInput? _input;
  final FocusNode _focus = FocusNode(debugLabel: 'TripAmount');
  bool _bounced = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _bounce(ShoppingHistory trip) {
    if (_bounced) return;
    _bounced = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final name = (trip.completedByName ?? '').trim();
      Navigator.of(context).maybePop();
      final c = rootNavigatorKey.currentContext;
      if (c == null) return;
      AvoToast.show(
        c,
        message: c.tr(
          'hist_amount_not_yours',
          params: {'name': name.isEmpty ? c.tr('hist_member_unknown') : name},
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(historyTripProvider(widget.tripId));
    final title = context.tr('hist_amount_title');
    if (trip == null) {
      // Not in the local history: read it once; gone → the history (§1.2).
      final lookup = ref.watch(tripLookupProvider(widget.tripId));
      if (!_gone && !lookup.isLoading && lookup.valueOrNull == null) {
        _gone = true;
        leaveGoneTrip(context);
      }
      return FullScreenEditor(
        title: title,
        child: const SkeletonSection(rows: 1, withImage: false),
      );
    }
    if (!isOwnTrip(ref, trip)) {
      _bounce(trip);
      return FullScreenEditor(title: title, child: const SizedBox.shrink());
    }
    final lang = Localizations.localeOf(context).languageCode;
    final now = ref.watch(historyClockProvider)();
    final initial = trip.totalCostCents;
    final input = _input;
    final cents = input == null ? initial : input.cents;
    final invalid = input?.isInvalid ?? false;
    final changed = input != null && !invalid && cents != initial;
    final splits = ref.watch(tripSplitsProvider(trip.id)).valueOrNull ?? const [];
    final custom = splits.isNotEmpty && splits.any((s) => s.splitMode != 'equal');
    final colors = context.colors;

    return FullScreenEditor(
      title: title,
      dirty: changed,
      doneLabel: context.tr('hist_amount_save'),
      doneEnabled: changed,
      onDone: () {
        final container = ProviderScope.containerOf(context, listen: false);
        Navigator.of(context).pop();
        unawaited(saveTripAmount(container, trip, cents));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          InsetSection(
            footer: tripContextLine(context, trip, now),
            children: [
              HistoryAmountField(
                title: context.tr('hist_amount_label'),
                placeholder: context.tr('hist_checkout_amount_placeholder'),
                languageCode: lang,
                initialCents: initial,
                focusNode: _focus,
                semanticHint: invalid ? context.tr('hist_amount_invalid') : null,
                onChanged: (v) => setState(() => _input = v),
              ),
            ],
          ),
          if (invalid)
            AmountNote(text: context.tr('hist_amount_invalid'), error: true)
          else if (cents != null && cents > _kAmountCheckCents)
            AmountNote(
              text: context.tr(
                'hist_amount_check',
                params: {'amount': formatEuroCents(cents, lang)},
              ),
            ),
          if (splits.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AvoSpacing.xxxl,
                AvoSpacing.l,
                AvoSpacing.xxxl,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: AvoIcon(
                      AvoIcons.exclamationmarkCircle,
                      size: 15, // D2
                      color: colors.secondaryLabel,
                    ),
                  ),
                  const SizedBox(width: AvoSpacing.xs + AvoSpacing.xxs),
                  Expanded(
                    child: Text(
                      context.tr(
                        custom
                            ? 'hist_amount_split_custom_note'
                            : 'hist_amount_split_note',
                      ),
                      style: context.text(AvoTextStyle.subhead),
                    ),
                  ),
                ],
              ),
            ),
          if (input != null && input.isEmpty && initial != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AvoSpacing.xxxl,
                AvoSpacing.m,
                AvoSpacing.xxxl,
                0,
              ),
              child: Text(
                context.tr('hist_amount_clear_note'),
                style: context.text(
                  AvoTextStyle.subhead,
                  color: colors.secondaryLabel,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
