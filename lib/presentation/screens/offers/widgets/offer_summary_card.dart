import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

// D2 X-Einkaufsmodus savings card (`angebote.md` 2.1), the look of A's
// HintRow with a bold first line (request A-C3).
const EdgeInsetsDirectional _kPadding = EdgeInsetsDirectional.fromSTEB(
  14,
  12,
  14,
  12,
); // D2
const double _kIcon = 18; // D2 tag
const double _kGap = 10; // D2
const double _kChevron = 14;
const double _kClose = 12; // D2 close glyph in a 44-pt target
const double _kShadowAlpha = 0.04; // D2 `.card`
const double _kShadowBlur = 2; // D2
const Offset _kShadowOffset = Offset(0, 1); // D2
const double _kSwipeThreshold = 0.35;

/// The two-line savings card (S7, `OfferSummaryText`): "4 von 11 Artikeln
/// diese Woche bei Lidl im Angebot" in 15/20 semibold, below it "ca. 3,20 €
/// gespart · in deiner Region · Preise laut Händler".
///
/// In the list [onHideWeek] adds a close button, a swipe to the left and,
/// with [onMenu], a long press menu ("Diese Woche ausblenden", [onNever]);
/// [onTap] makes the whole card a button with a chevron (it opens the offers
/// of the list once that screen exists). Without any of them (shopping mode)
/// the card is still: no chevron, no close, no gestures.
///
/// VoiceOver reads one element with [semanticLabel] (the mandatory sentence
/// in one piece), the hide actions are custom actions. From AX1 on the
/// symbol sits above the text.
class OfferSummaryCard extends StatelessWidget {
  const OfferSummaryCard({
    super.key,
    required this.head,
    required this.detail,
    required this.semanticLabel,
    this.onTap,
    this.onHideWeek,
    this.onNever,
    this.onMenu,
  });

  final String head;
  final String detail;
  final String semanticLabel;

  /// Opens the offers of the list; null is the still variant.
  final VoidCallback? onTap;

  /// "Diese Woche ausblenden" (close button, swipe, menu, VoiceOver).
  final VoidCallback? onHideWeek;

  /// "Nicht mehr zeigen" (menu, VoiceOver).
  final VoidCallback? onNever;

  /// Opens the context menu from the card (long press).
  final void Function(BuildContext context)? onMenu;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tap = onTap;
    final hide = onHideWeek;
    final ax = context.isAccessibilityText;

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          head,
          style: context.text(AvoTextStyle.subhead, weight: FontWeight.w600),
        ),
        Text(
          detail,
          style: context.text(
            AvoTextStyle.subhead,
            color: colors.secondaryLabel,
          ),
        ),
      ],
    );
    final icon = AvoIcon(
      AvoIcons.tag,
      size: MediaQuery.textScalerOf(context).scale(_kIcon),
      color: colors.secondaryLabel,
    );
    final chevron = tap == null
        ? null
        : AvoIcon(
            AvoIcons.chevronRight,
            size: MediaQuery.textScalerOf(context).scale(_kChevron),
            color: colors.secondaryLabel,
          );

    Widget content;
    if (ax) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: AvoSpacing.s),
          text,
        ],
      );
    } else {
      content = Row(
        children: [
          icon,
          const SizedBox(width: _kGap),
          Expanded(child: text),
          if (chevron != null) ...[const SizedBox(width: _kGap), chevron],
        ],
      );
    }

    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AvoRadii.card),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: _kShadowAlpha),
            offset: _kShadowOffset,
            blurRadius: _kShadowBlur,
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
        child: Padding(
          padding: hide == null
              ? _kPadding
              : _kPadding.copyWith(end: AvoSizes.hitTarget),
          child: content,
        ),
      ),
    );

    final menu = onMenu;
    if (tap != null) card = PressableScale(onPressed: tap, child: card);
    if (menu != null) {
      final pressable = card;
      card = Builder(
        builder: (context) =>
            GestureDetector(onLongPress: () => menu(context), child: pressable),
      );
    }

    if (hide != null) {
      card = Stack(
        children: [
          card,
          PositionedDirectional(
            top: 0,
            end: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: hide,
              child: SizedBox.square(
                dimension: AvoSizes.hitTarget,
                child: Center(
                  child: AvoIcon(
                    AvoIcons.xmark,
                    size: _kClose,
                    color: colors.secondaryLabel,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final actions = <CustomSemanticsAction, VoidCallback>{
      if (hide != null)
        CustomSemanticsAction(label: context.tr('offer_summary_hide_week')):
            hide,
      if (hide != null && onNever != null)
        CustomSemanticsAction(label: context.tr('offer_summary_never')):
            onNever!,
    };
    card = Semantics(
      container: true,
      button: tap != null,
      label: semanticLabel,
      hint: tap == null ? null : context.tr('offer_summary_hint_a11y'),
      onTap: tap,
      customSemanticsActions: actions.isEmpty ? null : actions,
      excludeSemantics: true,
      child: card,
    );

    if (hide == null) return card;
    return Dismissible(
      key: const ValueKey('offer-summary-swipe'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: _kSwipeThreshold},
      onUpdate: (details) {
        if (details.reached && !details.previousReached) {
          unawaited(AvoHaptics.light());
        }
      },
      onDismissed: (_) => hide(),
      background: ClipRRect(
        borderRadius: BorderRadius.circular(AvoRadii.card),
        child: ColoredBox(
          color: colors.fill,
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: AvoSpacing.xl),
              child: ExcludeSemantics(
                child: Text(
                  context.tr('offer_summary_hide_week'),
                  style: context.text(AvoTextStyle.subhead),
                ),
              ),
            ),
          ),
        ),
      ),
      child: card,
    );
  }
}
