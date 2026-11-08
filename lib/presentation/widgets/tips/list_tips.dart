import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/core/utils/display_name_helper.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/tip_service.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_steps.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/presentation/widgets/tips/tip_slot.dart';

/// The section "Für heute" of a list with its one tip (Konzept 11 §1.1
/// item 6, 17 §6.1: T1–T5, T8). Takes no space without a tip.
class ListTipSection extends ConsumerWidget {
  const ListTipSection({
    super.key,
    required this.items,
    this.shared,
    this.arrival,
  });

  /// The list's visible items; null while they load.
  final List<ShoppingItemModel>? items;

  /// The list is shared (null: not loaded).
  final bool? shared;

  /// `?arrival=` of the route: with it the tip is decided before the items
  /// are there (T1 on a brand-new list).
  final OnboardingArrival? arrival;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(tipServiceProvider);
    // Nothing to decide (and no module read) until the app attached tips.
    if (!service.isAttached) return const SizedBox.shrink();
    final avoOn = ref.watch(moduleEnabledProvider(AppModule.avo));
    final list = items;
    final facts = list == null
        ? TipFacts(ready: arrival != null, shared: shared, avoOn: avoOn)
        : TipFacts.forList(list, shared: shared, avoOn: avoOn);
    return TipSlot(
      place: TipPlace.list,
      facts: facts,
      wrap: (context, row) => InsetSection(
        header: context.tr('tip_section_today'),
        children: [row],
      ),
    );
  }
}

/// What `?arrival=` does on a list (Konzept 17 §3.12), once per app run;
/// call it from the list's `initState`, before the first build:
/// - `new`: tip T1 (the list focuses its add field itself);
/// - `joined`: tip T5, no keyboard;
/// - `existing`: T1–T7 count as shown, and once the status "Angemeldet als
///   Lena. Deine Listen sind da.", no keyboard.
void applyListArrival(
  WidgetRef ref,
  BuildContext context, {
  required String listId,
  required OnboardingArrival? arrival,
}) {
  if (arrival == null) return;
  final tips = ref.read(tipServiceProvider);
  if (!tips.consumeArrival('$listId:${arrival.id}')) return;
  switch (arrival) {
    case OnboardingArrival.created:
      tips.startArrivalTip(TipId.quantity);
    case OnboardingArrival.joined:
      tips.startArrivalTip(TipId.joined);
    case OnboardingArrival.existing:
      tips.markNewPeopleTipsSeen();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        AvoToast.show(context, message: arrivalStatusText(context, ref));
      });
  }
}

/// "Angemeldet als Lena. Deine Listen sind da." (without a usable name:
/// "Du bist angemeldet. Deine Listen sind da.").
String arrivalStatusText(BuildContext context, WidgetRef ref) {
  final raw =
      ref.read(cachedUserProfileProvider)?.displayName ??
      ref.read(currentUserProvider).valueOrNull?.displayName;
  final name = DisplayNameHelper.getDisplayName(raw, fallback: '').trim();
  final first = name.isEmpty ? '' : name.split(RegExp(r'\s+')).first;
  if (first.isEmpty) return context.tr('tip_arrival_existing_anonymous');
  return context.tr('tip_arrival_existing', params: {'name': first});
}
