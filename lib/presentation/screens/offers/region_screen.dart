import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/screens/offers/widgets/offers_page.dart';
import 'package:shoply/presentation/screens/offers/widgets/region_rows.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/confirm_dialog.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

/// Opens the iOS settings of the app (location denied); override in tests.
final openAppSettingsProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    try {
      await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('⚠️ [LOCATION] Settings not opened: $e');
    }
  },
);

/// The error key of a typed zip code: none while empty, "5 Ziffern" once
/// the field was left with fewer, "kennen wir nicht" for zone 00 and 99999.
String? postcodeErrorKey(String text, {required bool left}) {
  if (text.isEmpty) return null;
  if (text.length < 5) return left ? 'offer_postcode_digits' : null;
  return isKnownZip(text) ? null : 'offer_postcode_unknown';
}

/// The line under the field: "79098 · Freiburg im Breisgau" when the town
/// is known (from the location), else "PLZ 79098" (there is no zip table
/// yet, Lücke L10); null without five digits.
String? postcodePlace(BuildContext context, String zip, String? city) {
  if (!isKnownZip(zip)) return null;
  if (city != null && city.isNotEmpty) {
    return context.tr(
      'offer_postcode_place',
      params: {'postcode': zip, 'city': city},
    );
  }
  return context.tr('offer_postcode_place_fallback', params: {'postcode': zip});
}

/// "79098 Freiburg" or "79098".
String regionText(Region region) {
  final city = region.city;
  return city == null || city.isEmpty ? region.zip : '${region.zip} $city';
}

/// "Region" (S11, `/settings/offers/region` in the Profil tab and
/// `/stores/region` full screen; "Standort" while the offers kill switch is
/// on). For which region should offers apply?
///
/// A sentence, "Standort verwenden" (asks the system once, finds the zip
/// code within 3 s and fills the field; saved only with "Fertig"), the
/// postcode field with the place or the error below it, and "Region
/// entfernen" while one is set (no question: an undo toast, the screen
/// stays). "Fertig" is on for a valid, changed region, saves it, shows
/// "Region: 79098 Freiburg · Widerrufen" and returns `true`. Leaving with an
/// unsaved valid change asks "Änderungen verwerfen?" (S16). The region is
/// kept with the module off too; it is core for market suggestions.
class RegionScreen extends ConsumerStatefulWidget {
  const RegionScreen({super.key, this.fullScreen = false});

  /// `/stores/region`: xmark "Schließen", no tab bar.
  final bool fullScreen;

  @override
  ConsumerState<RegionScreen> createState() => _RegionScreenState();
}

class _RegionScreenState extends ConsumerState<RegionScreen> {
  final _field = TextEditingController();
  final _focus = FocusNode();

  /// The region the screen opened with (filled once the region was read).
  Region? _initial;
  bool _filled = false;

  /// The field was left once: from then on "Bitte 5 Ziffern eingeben."
  bool _left = false;

  bool _locating = false;
  LocateOutcome? _outcome;
  Region? _located;
  String? _lastError;

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

  /// What "Fertig" would save; null while the field is not a known zip.
  Region? get _draft {
    final text = _field.text;
    if (!isKnownZip(text)) return null;
    final located = _located;
    if (located != null && located.zip == text) return located;
    final initial = _initial;
    return Region(
      zip: text,
      city: initial != null && initial.zip == text ? initial.city : null,
      source: RegionSource.manual,
    );
  }

  bool get _dirty {
    final draft = _draft;
    return draft != null && draft.zip != ref.read(regionProvider)?.zip;
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _outcome = null;
    });
    final result = await ref.read(regionControllerProvider.notifier).locate();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _outcome = result.outcome;
      final region = result.region;
      if (result.outcome == LocateOutcome.found && region != null) {
        _located = region;
        _field.text = region.zip;
        _left = true;
      }
    });
    if (result.outcome == LocateOutcome.found && result.region != null) {
      _announce(
        context
            .tr(
              'offer_use_location_current',
              params: {
                'postcode': result.region!.zip,
                'city': result.region!.city ?? '',
              },
            )
            .trim(),
      );
    }
  }

  void _announce(String message) {
    final view = View.maybeOf(context);
    if (view == null) return;
    unawaited(
      SemanticsService.sendAnnouncement(
        view,
        message,
        Directionality.of(context),
      ),
    );
  }

  BuildContext get _toastContext =>
      Navigator.of(context, rootNavigator: true).context;

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    final controller = ref.read(regionControllerProvider.notifier);
    final previous = ref.read(regionProvider);
    final toastContext = _toastContext;
    AvoToast.show(
      toastContext,
      message: toastContext
          .tr(
            'offer_toast_region_set',
            params: {'postcode': draft.zip, 'city': draft.city ?? ''},
          )
          .trim(),
      actionLabel: toastContext.tr('common_undo'),
      onAction: () => unawaited(
        previous == null
            ? controller.remove()
            : controller.saveRegion(previous),
      ),
    );
    _announce(
      context
          .tr(
            'offer_toast_region_set',
            params: {'postcode': draft.zip, 'city': draft.city ?? ''},
          )
          .trim(),
    );
    unawaited(_quietly(controller.saveRegion(draft)));
    _initial = draft;
    if (context.canPop()) context.pop(true);
  }

  Future<void> _quietly(Future<void> write) async {
    try {
      await write;
    } catch (e) {
      debugPrint('❌ [OFFERS] Region not saved: $e');
      unawaited(AvoHaptics.error());
    }
  }

  void _remove() {
    final controller = ref.read(regionControllerProvider.notifier);
    final previous = ref.read(regionProvider);
    if (previous == null) return;
    setState(() {
      _field.clear();
      _located = null;
      _outcome = null;
      _left = false;
      _initial = null;
    });
    unawaited(_quietly(controller.remove()));
    AvoToast.show(
      _toastContext,
      message: context.tr('offer_toast_region_removed'),
      actionLabel: context.tr('common_undo'),
      onAction: () => unawaited(controller.saveRegion(previous)),
    );
  }

  Future<void> _leave() async {
    if (!_dirty) {
      if (context.canPop()) context.pop(false);
      return;
    }
    final discard = await showAvoConfirm(
      context,
      title: context.tr('common_discard_changes_title'),
      confirmLabel: context.tr('common_discard'),
      cancelLabel: context.tr('common_keep_editing'),
    );
    if (discard && mounted && context.canPop()) context.pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final stores = !ref.watch(offersRemoteEnabledProvider);
    final loaded = ref.watch(regionLoadedProvider);
    final current = ref.watch(regionProvider);
    if (loaded && !_filled) {
      _filled = true;
      _initial = current;
      if (current != null && _field.text.isEmpty) _field.text = current.zip;
    }

    final text = _field.text;
    final errorKey = postcodeErrorKey(text, left: _left);
    final error = errorKey == null ? null : context.tr(errorKey);
    if (error != null && error != _lastError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _announce(error);
      });
    }
    _lastError = error;
    final draft = _draft;
    final place = error != null
        ? null
        : postcodePlace(context, text, draft?.city);
    final dirty = draft != null && draft.zip != current?.zip;

    final known = _located ?? current;
    final locationSub = known != null && known.source == RegionSource.gps
        ? context
              .tr(
                'offer_use_location_current',
                params: {'postcode': known.zip, 'city': known.city ?? ''},
              )
              .trim()
        : context.tr('offer_use_location_sub');

    final Widget locationRow = _outcome == LocateOutcome.denied
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: AvoSpacing.s),
            child: StatusRow(
              kind: StatusKind.permission,
              text: context.tr('offer_location_off'),
              actionLabel: context.tr('settings'),
              onAction: () => unawaited(ref.read(openAppSettingsProvider)()),
            ),
          )
        : UseLocationRow(
            title: context.tr('offer_use_location'),
            subtitle: locationSub,
            locating: _locating,
            locatingLabel: context.tr('offer_locating_a11y'),
            onTap: () => unawaited(_locate()),
          );

    final children = <Widget>[
      OffersLead(
        context.tr(stores ? 'offer_region_intro_stores' : 'offer_region_intro'),
        style: AvoTextStyle.body,
        top: 0,
      ),
      const SizedBox(height: AvoSpacing.section),
      InsetSection(children: [locationRow]),
      if (_outcome == LocateOutcome.unavailable)
        Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.s),
          child: StatusRow(
            kind: StatusKind.sectionError,
            text: context.tr('offer_location_unavailable'),
          ),
        ),
      if (_outcome == LocateOutcome.abroad)
        OffersFootnote(
          context.tr(
            stores ? 'offer_location_abroad_stores' : 'offer_location_abroad',
          ),
        ),
      const SizedBox(height: AvoSpacing.section),
      InsetSection(
        children: [
          PostcodeFieldRow(
            controller: _field,
            focusNode: _focus,
            label: context.tr('offer_postcode_label'),
            placeholder: context.tr(
              'offer_postcode_placeholder',
              params: {'example': '79098'},
            ),
            error: error,
            place: place,
            onChanged: (_) => setState(() {}),
            onSubmitted: dirty ? () => unawaited(_save()) : null,
          ),
        ],
      ),
      PostcodeNote(place: place, error: error),
      if (current != null) ...[
        const SizedBox(height: AvoSpacing.section),
        InsetSection(
          children: [
            DestructiveRow(
              title: context.tr('offer_region_remove'),
              onTap: _remove,
            ),
          ],
        ),
      ],
    ];

    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: ColoredBox(
        color: colors.background,
        child: OffersPage(
          title: context.tr(
            stores ? 'offer_region_title_stores' : 'offer_region_title',
          ),
          largeTitle: false,
          close: widget.fullScreen,
          bottom: widget.fullScreen
              ? OffersPageBottom.safeArea
              : OffersPageBottom.tabBar,
          onBack: () => unawaited(_leave()),
          trailing: [
            AppButton.primary(
              label: context.tr('done'),
              floating: true,
              onPressed: dirty ? () => unawaited(_save()) : null,
            ),
          ],
          children: children,
        ),
      ),
    );
  }
}
