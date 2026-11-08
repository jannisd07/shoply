import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/store_chain_directory.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/store_choice_provider.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';
import 'package:shoply/presentation/screens/offers/store_menu.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_icons.dart';
import 'package:shoply/presentation/screens/offers/widgets/store_mark.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

// D2 X-Einkaufsmodus market chip (`angebote.md` 2.1).
const double _kChipHeight = 30; // D2
const EdgeInsetsDirectional _kPadding = EdgeInsetsDirectional.fromSTEB(
  8,
  0,
  12,
  0,
); // D2 padding 0 12 0 8
const EdgeInsetsDirectional _kPaddingNoMark = EdgeInsetsDirectional.fromSTEB(
  10,
  0,
  12,
  0,
); // D2 storefront glyph sits 2 pt further in than the tile
const double _kGap = 6; // D2
const double _kChevron = 12; // D2
const double _kStorefront = 16; // D2 storefront (angebote.md S1)
const double _kShadowAlpha = 0.06; // D2 0 1 2 rgba(0,0,0,.06)
const double _kShadowBlur = 2; // D2
const Offset _kShadowOffset = Offset(0, 1); // D2
const double _kDash = 3; // D2 dashed suggestion outline
const double _kDashGap = 2.5; // D2
const double _kBorder = 1; // D2 suggestion and Increase Contrast outline

/// What the chip shows.
enum _ChipState { store, suggestion, none }

/// The market of a list (S1, Kap. 12 E-13) in the list header, shopping mode
/// and list info (contract `b_slots.dart`). Core, not part of the offers
/// module: it stays the same with the module off, the kill switch on and
/// offline (the chain directory is on the device).
///
/// A white capsule with the market's letter tile, its name and a chevron
/// ("Lidl"), "Lidl?" with a dashed outline for a suggestion, "Markt wählen"
/// without a market. A tap opens the market menu out of the chip; the
/// choice shows at once, with an undo toast. The visible capsule is 30 pt,
/// the touch target 44 pt. VoiceOver: "Markt: Lidl, ändern".
class StoreChip extends ConsumerWidget {
  const StoreChip({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final guess = ref.watch(storeGuessForListProvider(listId)).valueOrNull;
    // Keeps the trip history ready for the menu.
    ref.listen(listStoreHistoryProvider(listId), (_, __) {});

    final known =
        guess != null && StoreChainDirectory.byId(guess.chainId) != null;
    final state = !known
        ? _ChipState.none
        : guess.confirmed
        ? _ChipState.store
        // "Nicht fragen" is only read for a suggestion.
        : ref.watch(
                offerDisplayPrefsProvider.select(
                  (p) => p?.dontAskStore[listId],
                ),
              ) ==
              guess.chainId
        ? _ChipState.none
        : _ChipState.suggestion;
    final name = known ? storeNameOf(guess.chainId) : null;

    final Widget lead;
    final String text;
    final Color textColor;
    final String label;
    switch (state) {
      case _ChipState.store:
        lead = StoreMark.chain(guess!.chainId);
        text = name!;
        textColor = colors.label;
        label = context.tr('offer_store_chip_a11y', params: {'store': name});
      case _ChipState.suggestion:
        lead = StoreMark.chain(guess!.chainId);
        text = '$name?';
        textColor = colors.label;
        label = context.tr(
          'offer_store_chip_suggested_a11y',
          params: {'store': name!},
        );
      case _ChipState.none:
        lead = AvoIcon(
          OfferIcons.storefront,
          size: MediaQuery.textScalerOf(context).scale(_kStorefront),
          color: colors.secondaryLabel,
        );
        text = context.tr('offer_store_choose');
        textColor = colors.secondaryLabel;
        label = text;
    }

    final content = Row(
      key: ValueKey('store-chip-$state-$text'),
      mainAxisSize: MainAxisSize.min,
      children: [
        lead,
        const SizedBox(width: _kGap),
        Flexible(
          child: Text(
            text,
            style: context.text(
              AvoTextStyle.subhead,
              color: textColor,
              weight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: _kGap),
        AvoIcon(
          AvoIcons.chevronDown,
          size: MediaQuery.textScalerOf(context).scale(_kChevron),
          color: colors.secondaryLabel,
        ),
      ],
    );

    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    Widget capsule = DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.surface,
        shape: StadiumBorder(
          side: highContrast && state != _ChipState.suggestion
              ? BorderSide(color: colors.separator, width: _kBorder)
              : BorderSide.none,
        ),
        shadows: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: _kShadowAlpha),
            offset: _kShadowOffset,
            blurRadius: _kShadowBlur,
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _kChipHeight),
        child: Padding(
          padding: state == _ChipState.none ? _kPaddingNoMark : _kPadding,
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: AnimatedSwitcher(
              duration: AvoMotion.fadeReduced,
              child: content,
            ),
          ),
        ),
      ),
    );
    if (state == _ChipState.suggestion) {
      capsule = CustomPaint(
        foregroundPainter: _DashedCapsulePainter(colors.uncheckedRing),
        child: capsule,
      );
    }

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: () => unawaited(showStoreMenu(context, ref, listId)),
      child: PressableScale(
        onPressed: () => unawaited(showStoreMenu(context, ref, listId)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AvoSizes.hitTarget,
            minWidth: AvoSizes.hitTarget,
          ),
          child: Center(widthFactor: 1, heightFactor: 1, child: capsule),
        ),
      ),
    );
  }
}

/// The 1-pt dashed outline of a suggested market (D2 "Lidl?").
class _DashedCapsulePainter extends CustomPainter {
  const _DashedCapsulePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_kBorder / 2);
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kBorder;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + _kDash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += _kDash + _kDashGap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedCapsulePainter oldDelegate) =>
      oldDelegate.color != color;
}
