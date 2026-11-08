import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/providers/list_offer_prefs_provider.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/screens/offers/offer_paths.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/hint_row.dart';

const double _kIcon = 18; // D2 like the savings card's tag

/// Whether "Für Angebote in deiner Region: Postleitzahl festlegen" may show
/// on [listId] instead of [surface] (`angebote.md` 3.4): offers available
/// and not hidden on the list, the surface's switch on, the region read and
/// none set, and the hint not closed in the last 7 days.
final offerPostcodeHintProvider =
    Provider.family<bool, ({OfferSurface surface, String listId})>((ref, key) {
      if (!ref.watch(offersRemoteEnabledProvider)) return false;
      if (!ref.watch(offersVisibleForListProvider(key.listId))) return false;
      if (!ref.watch(regionLoadedProvider)) return false;
      if (ref.watch(regionProvider) != null) return false;
      final prefs = ref.watch(offerDisplayPrefsProvider);
      if (prefs == null || !prefs.isOn(key.surface)) return false;
      return prefs.postcodeHintAllowed(ref.watch(offerClockProvider)());
    });

/// Opens the region screen (S11) from a list; true when a region was saved.
Future<bool> openRegionFromList(
  BuildContext context, {
  RegionOrigin from = RegionOrigin.list,
}) async {
  final saved = await context.push<bool>(storeRegionLocation(from: from));
  return saved ?? false;
}

/// The hint card "Für Angebote in deiner Region: Postleitzahl festlegen ·
/// Festlegen" with the `location` glyph (3.4). The card opens the region
/// screen; closing it keeps it away for 7 days (on this account).
class OfferPostcodeHint extends ConsumerWidget {
  const OfferPostcodeHint({super.key, this.from = RegionOrigin.list});

  final RegionOrigin from;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return HintRow(
      leading: AvoIcon(
        AvoIcons.location,
        size: MediaQuery.textScalerOf(context).scale(_kIcon),
        color: colors.secondaryLabel,
      ),
      text: context.tr('offer_hint_set_postcode'),
      actionLabel: context.tr('offer_hint_set_postcode_action'),
      onTap: () => unawaited(openRegionFromList(context, from: from)),
      onDismiss: () => unawaited(
        ref.read(offerDisplayPrefsProvider.notifier).snoozePostcodeHint(),
      ),
    );
  }
}
