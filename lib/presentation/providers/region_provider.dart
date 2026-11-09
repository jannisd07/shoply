import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/data/services/user_location_service.dart';
import 'package:shoply/presentation/providers/list_offer_prefs_provider.dart';

export 'package:shoply/data/services/user_location_service.dart'
    show
        LocateOutcome,
        LocateResult,
        Region,
        RegionSource,
        isKnownZip,
        isValidZip;

/// Where the region comes from; override in tests.
final regionLookupProvider =
    Provider<RegionLookup>((ref) => UserLocationService.instance);

/// The region and whether it was read yet.
@immutable
class RegionState {
  const RegionState({required this.loaded, this.region});

  final bool loaded;
  final Region? region;
}

/// Loads the region once without asking for location permission, follows
/// every change saved anywhere (offers, profile, Avo) and saves the
/// person's own choice. Starts again for another account (sign-out, a
/// different sign-in), so no account keeps the previous one's region in
/// memory.
final regionControllerProvider =
    StateNotifierProvider<RegionController, RegionState>((ref) {
  ref.watch(offerAccountIdProvider);
  return RegionController(ref.watch(regionLookupProvider));
});

/// The person's real region for offers (Kap. 12, rule 4), or null: no
/// location and no typed zip code, or not read yet. Null means no offer
/// request anywhere and no savings figure. There is no stand-in zip code.
final regionProvider = Provider<Region?>(
  (ref) => ref.watch(regionControllerProvider.select((s) => s.region)),
);

/// Whether [regionProvider] was read already, so a screen can tell "no
/// region" ("Postleitzahl festlegen") from "still reading".
final regionLoadedProvider = Provider<bool>(
  (ref) => ref.watch(regionControllerProvider.select((s) => s.loaded)),
);

class RegionController extends StateNotifier<RegionState> {
  RegionController(this._lookup) : super(const RegionState(loaded: false)) {
    _subscription = _lookup.changes.listen((_) => unawaited(_load()));
    unawaited(_load());
  }

  final RegionLookup _lookup;
  late final StreamSubscription<void> _subscription;

  Future<void> _load({bool allowPermissionPrompt = false}) async {
    try {
      final region = await _lookup.getRegion(
        allowPermissionPrompt: allowPermissionPrompt,
        forceRefresh: allowPermissionPrompt,
      );
      if (mounted) state = RegionState(loaded: true, region: region);
    } catch (e) {
      debugPrint('⚠️ [OFFERS] Region not read: $e');
      if (mounted) state = RegionState(loaded: true, region: state.region);
    }
  }

  /// Saves a typed zip code. False, and nothing saved, unless it has
  /// exactly five digits.
  Future<bool> setManualZip(String zip) async {
    final trimmed = zip.trim();
    if (!isValidZip(trimmed)) return false;
    await _lookup.setManualZipCode(trimmed);
    return true;
  }

  /// "Standort verwenden" (S11, S14): the one place that may show the
  /// system location prompt (after the screen explained why). Finds the zip
  /// code without saving it; [saveRegion] keeps it.
  Future<LocateResult> locate() => _lookup.locate();

  /// Keeps [region]: a typed one as the typed zip code, a located one as
  /// the location. Shows at once.
  Future<void> saveRegion(Region region) async {
    if (region.source == RegionSource.manual) {
      await setManualZip(region.zip);
    } else {
      await _lookup.saveLocatedRegion(region);
    }
    if (mounted) state = RegionState(loaded: true, region: region);
  }

  /// "Region entfernen": no region until the person sets one again. Shows
  /// at once.
  Future<void> remove() async {
    if (mounted) state = const RegionState(loaded: true);
    await _lookup.removeRegion();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
