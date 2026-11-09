import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/providers/list_offer_prefs_provider.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/screens/offers/offer_paths.dart';
import 'package:shoply/presentation/screens/offers/region_screen.dart'
    show regionText;
import 'package:shoply/presentation/screens/offers/store_menu.dart';
import 'package:shoply/presentation/screens/offers/widgets/offers_page.dart';
import 'package:shoply/presentation/screens/offers/widgets/offers_source_footnote.dart';
import 'package:shoply/presentation/screens/offers/widgets/spring_collapse.dart';
import 'package:shoply/presentation/screens/offers/widgets/store_mark.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/hint_row.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/row_highlight.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

// D2 X-Angebote: market chips in "Meine Märkte".
const double _kChipHeight = 32; // D2
const double _kChipMark = 20; // D2
const EdgeInsetsDirectional _kChipPadding = EdgeInsetsDirectional.fromSTEB(
  6,
  0,
  12,
  0,
); // D2 padding 0 12 0 6
const EdgeInsets _kChipArea = EdgeInsets.symmetric(
  horizontal: AvoSpacing.l,
  vertical: AvoSpacing.m,
); // D2 12 16
const double _kRowIcon = 22; // D2 glyph at the start of a row
const double _kWarning = 15; // D2 warning glyph before "Nicht festgelegt"
const double _kChevron = 14; // D2 disclosure chevron

/// Row ids of "Preise & Angebote" (`/settings/offers?row=…`, the settings
/// search).
abstract final class OffersSettingsRows {
  static const module = 'offers.module';
  static const detect = 'offers.detect';
  static const region = 'offers.region';

  /// One of the "Anzeigen" switches (`offers.itemOffers`, …).
  static String surface(OfferSurface s) => 'offers.${s.name}';
}

/// The lists whose offers the person hid, with their names, in the order
/// of the lists ("Ausgeblendet für"); override in tests.
final offerHiddenListsShownProvider =
    Provider.autoDispose<List<({String id, String name})>>((ref) {
      final hidden = ref.watch(hiddenOfferListsProvider) ?? const <String>{};
      if (hidden.isEmpty) return const [];
      final lists = ref.watch(listsNotifierProvider).valueOrNull ?? const [];
      return [
        for (final l in lists)
          if (hidden.contains(l.id)) (id: l.id, name: l.name.trim()),
      ];
    });

/// "Preise & Angebote" (S12, `/settings/offers` in the Profil tab; "Märkte"
/// while the offers kill switch is on): what the app shows about offers and
/// markets, and where it knows it from.
///
/// The module switch (the same as in the Profil tab) with the source
/// footnote, "Anzeigen" with the five single switches, "Meine Märkte" (the
/// favourite markets as chips, one button to "Lieblingsmärkte", and "Markt
/// automatisch erkennen"), the region (with a warning while there is none)
/// and the lists whose offers are hidden, each with "Einblenden".
///
/// Module off: "Anzeigen" and "Ausgeblendet für" fold away; the markets and
/// the region stay (core). Kill switch: only the markets, detection and the
/// location stay, without the word "Angebot". Every switch acts at once.
/// Never Pro, no figure.
class OffersSettingsScreen extends ConsumerWidget {
  const OffersSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remote = ref.watch(offersRemoteEnabledProvider);
    final module = ref.watch(moduleEnabledProvider(AppModule.offers));
    final prefs = ref.watch(offerDisplayPrefsProvider);
    final notifier = ref.read(offerDisplayPrefsProvider.notifier);
    final favorites = ref.watch(favoriteStoresProvider);
    final region = ref.watch(regionProvider);
    final regionLoaded = ref.watch(regionLoadedProvider);
    final hiddenLists = ref.watch(offerHiddenListsShownProvider);

    Widget surface(String key, OfferSurface s, {String? subtitle}) =>
        HighlightableRow(
          id: OffersSettingsRows.surface(s),
          child: ToggleRow(
            title: context.tr(key),
            subtitle: subtitle,
            value: prefs?.isOn(s) ?? true,
            enabled: prefs != null,
            onChanged: (on) => unawaited(notifier.setSurface(s, on)),
          ),
        );

    final children = <Widget>[
      if (remote) ...[
        if (regionLoaded && region == null && module)
          Padding(
            padding: const EdgeInsets.only(bottom: AvoSpacing.m),
            // A location glyph, not StatusRow's raised hand, which reads
            // like "stop" (S6 P3): the same hint as in the lists, no close.
            child: HintRow(
              leading: AvoIcon(
                AvoIcons.location,
                size: MediaQuery.textScalerOf(context).scale(AvoIcon.defaultSize),
                color: context.colors.secondaryLabel,
              ),
              text: context.tr('offer_hint_set_postcode'),
              actionLabel: context.tr('offer_hint_set_postcode_action'),
              onTap: () => unawaited(context.push(offersSettingsRegionPath)),
            ),
          ),
        const SizedBox(height: AvoSpacing.s),
        InsetSection(
          children: [
            HighlightableRow(
              id: OffersSettingsRows.module,
              child: ToggleRow(
                title: context.tr('common_module_offers'),
                subtitle: context.tr('offer_settings_master_sub'),
                value: module,
                onChanged: (on) => unawaited(
                  ref
                      .read(appModulesProvider.notifier)
                      .setEnabled(AppModule.offers, on),
                ),
              ),
            ),
          ],
        ),
        const OffersSourceFootnote(),
        SpringCollapse(
          visible: module,
          child: InsetSection(
            header: context.tr('offer_settings_show'),
            children: [
              surface('offer_settings_on_items', OfferSurface.itemOffers),
              surface(
                'offer_settings_while_typing',
                OfferSurface.typingSuggestions,
              ),
              surface(
                'offer_settings_in_list',
                OfferSurface.listSavings,
                subtitle: context.tr('offer_settings_in_list_sub'),
              ),
              surface('offer_settings_home_tips', OfferSurface.homeTips),
              surface('offer_settings_history', OfferSurface.historySavings),
            ],
          ),
        ),
      ],
      InsetSection(
        header: context.tr('offer_settings_my_stores'),
        footer: context.tr('offer_settings_detect_note'),
        children: [
          _MarketChips(
            favorites: favorites,
            onTap: () => unawaited(context.push(offersSettingsMarketsPath)),
          ),
          HighlightableRow(
            id: OffersSettingsRows.detect,
            child: ToggleRow(
              title: context.tr('offer_settings_detect'),
              value: prefs?.detectStore ?? true,
              enabled: prefs != null,
              onChanged: (on) => unawaited(notifier.setDetectStore(on)),
            ),
          ),
        ],
      ),
      const SizedBox(height: AvoSpacing.section),
      InsetSection(
        children: [
          HighlightableRow(
            id: OffersSettingsRows.region,
            child: _RegionRow(
              title: context.tr(
                remote
                    ? 'offer_settings_region'
                    : 'offer_settings_location_stores',
              ),
              subtitle: remote
                  ? null
                  : context.tr('offer_settings_location_stores_sub'),
              value: region == null ? null : regionText(region),
              known: !regionLoaded || region != null,
              onTap: () => unawaited(context.push(offersSettingsRegionPath)),
            ),
          ),
        ],
      ),
      if (remote)
        SpringCollapse(
          visible: module && hiddenLists.isNotEmpty,
          child: InsetSection(
            header: context.tr('offer_settings_hidden_for'),
            children: [
              for (final l in hiddenLists)
                _HiddenListRow(
                  name: l.name,
                  onShow: () => _show(context, ref, l.id, l.name),
                ),
            ],
          ),
        ),
    ];

    return OffersPage(
      title: context.tr(
        remote ? 'common_module_offers' : 'offer_settings_title_stores',
      ),
      children: children,
    );
  }

  void _show(BuildContext context, WidgetRef ref, String listId, String name) {
    final notifier = ref.read(hiddenOfferListsProvider.notifier);
    unawaited(notifier.setHidden(listId, false));
    AvoToast.show(
      context,
      message: context.tr('offer_toast_list_shown', params: {'list': name}),
      actionLabel: context.tr('common_undo'),
      onAction: () => unawaited(notifier.setHidden(listId, true)),
    );
  }
}

/// The favourite markets as chips and "+ Markt", one button to
/// "Lieblingsmärkte" (D2 X-Angebote: StoreMark 20, name, 32 high, `fill`,
/// wrapping, 8 apart; from AX3 one chip per line).
class _MarketChips extends StatelessWidget {
  const _MarketChips({required this.favorites, required this.onTap});

  final List<String> favorites;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final names = [for (final id in favorites) storeNameOf(id)];
    final oneColumn =
        context.typography.category.index >= ContentSizeCategory.ax3.index;

    Widget chip({required Widget lead, required String text, Color? ink}) =>
        DecoratedBox(
          decoration: ShapeDecoration(
            color: colors.fill,
            shape: const StadiumBorder(),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _kChipHeight),
            child: Padding(
              padding: _kChipPadding,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  lead,
                  const SizedBox(width: AvoSpacing.xs),
                  Flexible(
                    child: Text(
                      text,
                      style: context.text(
                        AvoTextStyle.subhead,
                        weight: FontWeight.w500,
                        color: ink ?? colors.label,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

    final chips = <Widget>[
      for (final id in favorites)
        chip(
          lead: StoreMark.chain(id, size: _kChipMark),
          text: storeNameOf(id),
        ),
      chip(
        lead: const SizedBox.shrink(),
        text: context.tr('offer_settings_add_store'),
        ink: colors.tint,
      ),
    ];
    return Semantics(
      container: true,
      button: true,
      label: favorites.isEmpty
          ? '${context.tr('offer_settings_no_favorites')}. '
                '${context.tr('offer_settings_add_store')}'
          : context.tr(
              'offer_settings_stores_a11y',
              params: {'stores': names.join(', ')},
            ),
      onTap: onTap,
      excludeSemantics: true,
      child: PressableScale(
        onPressed: onTap,
        child: ColoredBox(
          color: colors.surface,
          child: Padding(
            padding: _kChipArea,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (favorites.isEmpty) ...[
                  Text(
                    context.tr('offer_settings_no_favorites'),
                    style: context.text(
                      AvoTextStyle.subhead,
                      color: colors.secondaryLabel,
                    ),
                  ),
                  const SizedBox(height: AvoSpacing.s),
                ],
                if (oneColumn)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final c in chips)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AvoSpacing.s),
                          child: c,
                        ),
                    ],
                  )
                else
                  Wrap(
                    spacing: AvoSpacing.s,
                    runSpacing: AvoSpacing.s,
                    children: chips,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Region · 79098 Freiburg" with the `location` glyph and a chevron; without
/// a region "Nicht festgelegt" with the warning triangle in `warning`
/// before it (symbol and text, never colour alone). Like A's `NavRow`; the
/// value stacks below the title from AX1 on.
class _RegionRow extends StatelessWidget {
  const _RegionRow({
    required this.title,
    required this.value,
    required this.known,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String? value;

  /// False: the region was read and there is none (the warning shows).
  final bool known;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ax = context.isAccessibilityText;
    final shown = value;
    final unset = !known && shown == null;
    final valueWidget = unset
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AvoIcon(
                AvoIcons.exclamationmarkTriangleFill,
                size: MediaQuery.textScalerOf(context).scale(_kWarning),
                color: colors.warning,
              ),
              const SizedBox(width: AvoSpacing.xs),
              Flexible(
                child: Text(
                  context.tr('offer_settings_region_unset'),
                  style: context.text(
                    AvoTextStyle.body,
                    color: colors.secondaryLabel,
                  ),
                ),
              ),
            ],
          )
        : shown == null
        ? const SizedBox.shrink()
        : Text(
            shown,
            style: context.text(
              AvoTextStyle.body,
              color: colors.secondaryLabel,
            ),
          );
    final sub = subtitle;
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: context.text(AvoTextStyle.body)),
        if (sub != null)
          Text(
            sub,
            style: context.text(
              AvoTextStyle.subhead,
              color: colors.secondaryLabel,
            ),
          ),
      ],
    );
    return Semantics(
      container: true,
      button: true,
      label: [title, ?sub].join(', '),
      value: unset ? context.tr('offer_settings_region_unset_a11y') : shown,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52), // D2
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AvoSpacing.l,
              vertical: AvoSpacing.s,
            ),
            child: Row(
              crossAxisAlignment: ax
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                AvoIcon(AvoIcons.location, size: _kRowIcon, color: colors.tint),
                const SizedBox(width: AvoSpacing.m),
                Expanded(
                  child: ax
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [titleBlock, valueWidget],
                        )
                      : Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: AvoSpacing.m,
                          children: [titleBlock, valueWidget],
                        ),
                ),
                const SizedBox(width: AvoSpacing.m),
                AvoIcon(
                  AvoIcons.chevronRight,
                  size: _kChevron,
                  color: colors.secondaryLabel,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A list with hidden offers and "Einblenden" (44 pt) at the end.
class _HiddenListRow extends StatelessWidget {
  const _HiddenListRow({required this.name, required this.onShow});

  final String name;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final ax = context.isAccessibilityText;
    final title = Text(name, style: context.text(AvoTextStyle.body));
    final action = Semantics(
      container: true,
      label: '${context.tr('offer_show_again')}, $name',
      button: true,
      onTap: onShow,
      excludeSemantics: true,
      child: AppButton.plain(
        label: context.tr('offer_show_again'),
        onPressed: onShow,
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52), // D2
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AvoSpacing.l,
          AvoSpacing.xs,
          AvoSpacing.s,
          AvoSpacing.xs,
        ),
        child: ax
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [title, action],
              )
            : Row(
                children: [
                  Expanded(child: title),
                  action,
                ],
              ),
      ),
    );
  }
}
