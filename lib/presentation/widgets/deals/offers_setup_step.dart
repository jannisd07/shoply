import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/providers/store_choice_provider.dart';
import 'package:shoply/presentation/screens/offers/offer_text.dart';
import 'package:shoply/presentation/screens/offers/region_screen.dart'
    show openAppSettingsProvider, postcodeErrorKey, postcodePlace;
import 'package:shoply/presentation/screens/offers/store_menu.dart';
import 'package:shoply/presentation/screens/offers/widgets/offers_page.dart';
import 'package:shoply/presentation/screens/offers/widgets/region_rows.dart';
import 'package:shoply/presentation/screens/offers/widgets/store_filter_chip.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

/// The chip of "Aldi" before the region decides between Nord and Süd.
const String _kAldi = 'aldi';

/// The markets of the step in their fixed order (Konzept 17 §3.4).
const List<String> _kOrder = [
  'lidl',
  _kAldi,
  'rewe',
  'edeka',
  'kaufland',
  'netto-marken-discount',
  'penny',
];

/// The offers step of the onboarding (S14, slot `OffersSetupStep({onDone})`
/// in `/onboarding?step=region`, A-O1): Teil A draws the frame, title,
/// sentence, progress, back and "Überspringen"; this is the content and
/// "Weiter".
///
/// "Region": "Standort verwenden" (the explanation is its second line; the
/// tap asks the system) and the postcode with its place or error. "Deine
/// Märkte": chips to pick several from, in a fixed order (with a zip code
/// "Aldi" becomes Aldi Nord or Aldi Süd; with a location the nearest come
/// first, with their distance, once and only while nothing is picked).
/// "Weiter" saves the region and the markets (kept on the device until an
/// account exists, then in it) and calls [onDone].
///
/// Only with the offers module on and the kill switch known off; otherwise
/// it renders nothing and calls [onDone] right after the first frame, so A
/// skips the step without a trace. No figure, no network request without a
/// region; Overpass only after "Standort verwenden".
class OffersSetupStep extends ConsumerStatefulWidget {
  const OffersSetupStep({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<OffersSetupStep> createState() => _OffersSetupStepState();
}

class _OffersSetupStepState extends ConsumerState<OffersSetupStep> {
  final _field = TextEditingController();
  final _focus = FocusNode();
  bool _left = false;
  bool _locating = false;
  bool _done = false;
  bool _skipped = false;
  bool _filled = false;
  LocateResult? _located;

  /// Picked markets; "aldi" stands for the Aldi of the region.
  final Set<String> _picked = {};

  /// The order once the location sorted it (only while nothing was picked).
  List<String>? _sorted;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _field.text.isNotEmpty && !_left) {
        setState(() => _left = true);
      }
    });
  }

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Kill switch known off and the module on ([offersAvailableProvider]).
  bool get _available =>
      ref.read(offersRemoteEnabledProvider) &&
      ref.read(offersAvailableProvider);

  void _skip() {
    if (_skipped) return;
    _skipped = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDone();
    });
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final result = await ref.read(regionControllerProvider.notifier).locate();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _located = result;
      final region = result.region;
      if (result.outcome == LocateOutcome.found && region != null) {
        _field.text = region.zip;
        _left = true;
      }
    });
  }

  /// The zip code the step would save, or null.
  Region? get _region {
    final text = _field.text;
    if (!isKnownZip(text)) return null;
    final located = _located?.region;
    if (located != null && located.zip == text) return located;
    return Region(zip: text, source: RegionSource.manual);
  }

  /// "aldi" as the Aldi of [zip]; both without one.
  List<String> _chains(String id, String? zip) {
    if (id != _kAldi) return [id];
    if (zip == null) return const ['aldi-sued', 'aldi-nord'];
    return [aldiForZip(zip)];
  }

  Future<void> _next() async {
    if (_done) return;
    setState(() => _done = true);
    final region = _region;
    final zip = region?.zip ?? ref.read(regionProvider)?.zip;
    try {
      if (region != null && region.zip != ref.read(regionProvider)?.zip) {
        await ref.read(regionControllerProvider.notifier).saveRegion(region);
      }
      if (_picked.isNotEmpty) {
        final order = _sorted ?? _kOrder;
        await ref.read(offerDisplayPrefsProvider.notifier).setFavorites([
          for (final id in order)
            if (_picked.contains(id)) ..._chains(id, zip),
          for (final id in _picked)
            if (!order.contains(id)) ..._chains(id, zip),
        ]);
      }
    } catch (e) {
      debugPrint('⚠️ [OFFERS] Onboarding choices not saved: $e');
    }
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    if (_skipped || !_available) {
      _skip();
      return const SizedBox.shrink();
    }
    final lang = offerLanguageOf(context);
    final current = ref.watch(regionProvider);
    if (!_filled && ref.watch(regionLoadedProvider)) {
      _filled = true;
      if (current != null && _field.text.isEmpty) _field.text = current.zip;
    }
    final text = _field.text;
    final errorKey = postcodeErrorKey(text, left: _left);
    final error = errorKey == null ? null : context.tr(errorKey);
    final region = _region;
    final place = error != null
        ? null
        : postcodePlace(
            context,
            text,
            region?.city ?? (current?.zip == text ? current?.city : null),
          );

    final outcome = _located?.outcome;
    final coords = _located?.coordinates;
    final nearby = coords == null
        ? const <NearbyStoreOption>[]
        : ref
                  .watch(
                    nearbyStoresAtProvider((
                      latitude: coords.latitude,
                      longitude: coords.longitude,
                    )),
                  )
                  .valueOrNull ??
              const <NearbyStoreOption>[];
    final distances = <String, double>{};
    for (final n in nearby) {
      final key = n.chainId.startsWith('aldi') ? _kAldi : n.chainId;
      distances[key] = distances[key] ?? n.distanceMeters;
    }
    if (_sorted == null && distances.isNotEmpty && _picked.isEmpty) {
      final near = distances.keys.where(_kOrder.contains).toList()
        ..sort((a, b) => distances[a]!.compareTo(distances[b]!));
      _sorted = [...near, ..._kOrder.where((id) => !near.contains(id))];
    }
    final order = _sorted ?? _kOrder;
    final zip = region?.zip ?? current?.zip;

    String nameOf(String id) {
      if (id != _kAldi) return storeNameOf(id);
      return zip == null ? 'Aldi' : storeNameOf(aldiForZip(zip));
    }

    final chips = [
      for (final id in order)
        () {
          final meters = distances[id];
          final distance = meters == null ? null : formatDistance(meters, lang);
          final name = nameOf(id);
          return StoreFilterChip(
            chainId: id == _kAldi
                ? (zip == null ? 'aldi-sued' : aldiForZip(zip))
                : id,
            label: name,
            distance: distance?.shown,
            semanticLabel: distance == null
                ? name
                : context.tr(
                    'offer_setup_chip_a11y',
                    params: {'store': name, 'distance': distance.spoken},
                  ),
            selected: _picked.contains(id),
            multiple: true,
            onTap: () => setState(() {
              if (!_picked.remove(id)) _picked.add(id);
            }),
          );
        }(),
    ];

    final Widget? status = switch (outcome) {
      LocateOutcome.denied => StatusRow(
        kind: StatusKind.permission,
        text: context.tr('offer_setup_location_off'),
        actionLabel: context.tr('settings'),
        onAction: () => unawaited(ref.read(openAppSettingsProvider)()),
      ),
      LocateOutcome.unavailable => StatusRow(
        kind: StatusKind.sectionError,
        text: context.tr('offer_location_unavailable'),
      ),
      LocateOutcome.abroad => StatusRow(
        kind: StatusKind.sectionError,
        text: context.tr('offer_location_abroad'),
      ),
      _ => null,
    };

    final oneColumn =
        context.typography.category.index >= ContentSizeCategory.ax3.index;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepGroup(
          header: context.tr('offer_setup_region'),
          children: [
            UseLocationRow(
              title: context.tr('offer_use_location'),
              subtitle: context.tr('offer_setup_location_sub'),
              locating: _locating,
              locatingLabel: context.tr('offer_locating_a11y'),
              onTap: () => unawaited(_locate()),
            ),
            PostcodeFieldRow(
              controller: _field,
              focusNode: _focus,
              label: context.tr('offer_postcode_label'),
              placeholder: context.tr(
                'offer_postcode_placeholder',
                params: {'example': '10437'},
              ),
              error: error,
              place: place,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        PostcodeNote(place: place, error: error, side: AvoSpacing.l),
        if (status != null)
          Padding(
            padding: const EdgeInsets.only(top: AvoSpacing.s),
            child: status,
          ),
        _StepGroup(
          header: context.tr('offer_setup_stores'),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AvoSpacing.l,
                vertical: AvoSpacing.m,
              ),
              child: oneColumn
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: chips,
                    )
                  : Wrap(spacing: AvoSpacing.s, children: chips),
            ),
          ],
        ),
        OffersFootnote(
          context.tr('offer_setup_stores_note'),
          side: AvoSpacing.l,
        ),
        OffersFootnote(
          context.tr('offer_setup_source_note'),
          top: AvoSpacing.m,
          side: AvoSpacing.l,
        ),
        const SizedBox(height: AvoSpacing.xxl),
        AppButton.primary(
          label: context.tr('offer_setup_next'),
          size: AppButtonSize.large,
          expand: true,
          onPressed: error != null || _done ? null : () => unawaited(_next()),
        ),
      ],
    );
  }
}

/// A white group of D2 inside A's step frame, which already keeps the
/// screen margin: heading, rounded group, hairlines between rows, no outer
/// margin of its own.
class _StepGroup extends StatelessWidget {
  const _StepGroup({required this.header, required this.children});

  final String header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Padding(
            padding: const EdgeInsetsDirectional.only(start: AvoSpacing.l),
            child: SizedBox(
              height: AvoSizes.hairline,
              width: double.infinity,
              child: ColoredBox(color: colors.separator),
            ),
          ),
        );
      }
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionCaps(
          header,
          padding: const EdgeInsets.fromLTRB(
            AvoSpacing.l,
            AvoSpacing.xl,
            AvoSpacing.l,
            6, // D2
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(AvoRadii.group),
          child: ColoredBox(
            color: colors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: rows,
            ),
          ),
        ),
      ],
    );
  }
}
