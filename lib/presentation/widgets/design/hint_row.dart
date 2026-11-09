import 'dart:async';

import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/swipe_actions.dart';

/// Card padding (D2 hint card: 12 top and bottom, 14 at the sides).
const EdgeInsetsDirectional _kPadding = EdgeInsetsDirectional.fromSTEB(
  14, // D2
  AvoSpacing.m,
  14, // D2
  AvoSpacing.m,
);

/// Gap between the leading widget and the text (D2).
const double _kGap = 10; // D2

/// Soft card shadow (D2 `.card`: 0 1px 2px rgba(0,0,0,.04)).
const double _kShadowAlpha = 0.04; // D2
const double _kShadowBlur = 2; // D2
const Offset _kShadowOffset = Offset(0, 1); // D2

/// Close glyph: two strokes in a 12 pt square.
const double _kCloseGlyph = 12;
const double _kCloseStroke = 1.8;

/// Pressed opacity next to [AvoMotion.pressedScale] (Konzept 00 §12.20).
const double _kPressedOpacity = 0.9;

/// A compact hint card (Konzept 00 §12.12, optics D2-FuerDich "Tipp von Avo"):
/// white surface, radius 20, 15/20 text, optional leading figure or icon, an
/// optional action and an optional close button.
///
/// With [onTap] the whole card is one button (it shrinks while pressed) and
/// [actionLabel] is shown as a tinted link below the text; without [onTap]
/// the label is not shown. [onDismiss] adds a close button with a 44 pt
/// target in the top corner. From AX1 on the leading widget sits above the
/// text. An optional bold [title] stands above [text] (the two-line savings
/// card); [swipeActions] (swipe towards the end edge, "Ausblenden") and
/// [contextMenuItems] (long press, [showAvoMenu] at the finger) are also
/// VoiceOver custom actions. The card fills the width it gets (give it a bounded width, as a
/// column or list does). Content (savings, store suggestion, Pro offer) comes
/// from the caller; show at most two hints per screen.
class HintRow extends StatelessWidget {
  /// Creates a hint.
  const HintRow({
    super.key,
    required this.text,
    this.leading,
    this.actionLabel,
    this.onTap,
    this.onDismiss,
    this.dismissLabel,
    this.title,
    this.swipeActions = const [],
    this.contextMenuItems = const [],
  });

  /// The hint in one or two sentences.
  final String text;

  /// Optional icon tile or small `AvoFigure` before the text.
  final Widget? leading;

  /// Tinted link text below [text] ("Rezepte mit Avocado"); needs [onTap].
  final String? actionLabel;

  /// Makes the whole card a button.
  final VoidCallback? onTap;

  /// Shows a close button that calls this.
  final VoidCallback? onDismiss;

  /// VoiceOver label of the close button; defaults to `common_close`.
  final String? dismissLabel;

  /// Bold first line above [text] ("Du sparst 2,40 €"); [text] then turns
  /// secondary.
  final String? title;

  /// Swipe actions of the card ([SwipeActions]): swiping towards the start
  /// edge shows them at the end edge; the first one runs on a full swipe.
  final List<SwipeAction> swipeActions;

  /// Entries of the menu a long press opens.
  final List<AvoMenuEntry> contextMenuItems;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tap = onTap;
    final dismiss = onDismiss;
    final action = tap != null ? actionLabel : null;
    final lead = leading;
    final heading = title;
    final hasTitle = heading != null && heading.isNotEmpty;

    final textBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasTitle)
          Text(
            heading,
            style: context.text(AvoTextStyle.subhead, weight: FontWeight.w700),
          ),
        Text(
          text,
          style: context.text(
            AvoTextStyle.subhead,
            color: hasTitle ? colors.secondaryLabel : null,
          ),
        ),
        if (action != null)
          Padding(
            padding: const EdgeInsets.only(top: AvoSpacing.xs),
            child: Text(
              action,
              style: context.text(
                AvoTextStyle.subhead,
                color: colors.tint,
                weight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );

    final Widget content;
    if (lead == null) {
      content = textBlock;
    } else if (context.isAccessibilityText) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          lead,
          const SizedBox(height: AvoSpacing.s),
          textBlock,
        ],
      );
    } else {
      content = Row(
        children: [
          lead,
          const SizedBox(width: _kGap),
          Expanded(child: textBlock),
        ],
      );
    }

    final padding = dismiss == null
        ? _kPadding
        : _kPadding.copyWith(end: AvoSizes.hitTarget);

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
        constraints: const BoxConstraints(
          minHeight: AvoSizes.hitTarget,
          minWidth: double.infinity,
        ),
        child: Padding(padding: padding, child: content),
      ),
    );

    if (contextMenuItems.isNotEmpty) {
      final pressable = card;
      card = Builder(
        builder: (menuContext) => GestureDetector(
          excludeFromSemantics: true,
          onLongPressStart: (details) => unawaited(
            showAvoMenu(
              menuContext,
              items: contextMenuItems,
              anchorRect: Rect.fromCenter(
                center: details.globalPosition,
                width: 1,
                height: 1,
              ),
            ),
          ),
          child: pressable,
        ),
      );
    }

    final customActions = <CustomSemanticsAction, VoidCallback>{
      for (final entry in contextMenuItems)
        if (entry is AvoMenuItem && entry.enabled)
          CustomSemanticsAction(label: entry.label): entry.onSelected,
      ...SwipeActions.semanticActionsOf(swipeActions),
    };

    card = Semantics(
      container: true,
      button: tap != null,
      label: [?(hasTitle ? heading : null), text, ?action].join(', '),
      onTap: tap,
      customSemanticsActions: customActions.isEmpty ? null : customActions,
      child: ExcludeSemantics(
        child: tap == null ? card : _PressScale(onTap: tap, child: card),
      ),
    );

    final Widget result;
    if (dismiss == null) {
      result = card;
    } else {
      result = Stack(
        children: [
          card,
          PositionedDirectional(
            top: 0,
            end: 0,
            child: Semantics(
              container: true,
              button: true,
              label: dismissLabel ?? context.tr('common_close'),
              onTap: dismiss,
              child: ExcludeSemantics(
                child: _PressScale(
                  onTap: dismiss,
                  child: SizedBox.square(
                    dimension: AvoSizes.hitTarget,
                    child: Center(
                      child: CustomPaint(
                        size: const Size.square(_kCloseGlyph),
                        painter: _ClosePainter(colors.secondaryLabel),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return SwipeActions(
      trailingActions: swipeActions,
      exposeSemantics: false,
      borderRadius: BorderRadius.circular(AvoRadii.card),
      child: result,
    );
  }
}

class _ClosePainter extends CustomPainter {
  const _ClosePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kCloseStroke
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset.zero, Offset(size.width, size.height), paint)
      ..drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(_ClosePainter old) => old.color != color;
}

/// Shrinks its child to [AvoMotion.pressedScale] and 90 % opacity the moment
/// it is touched, on an interruptible spring. Reduce Motion: no scaling, only
/// the dimming.
class _PressScale extends StatefulWidget {
  const _PressScale({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale>
    with SingleTickerProviderStateMixin {
  /// 0 = resting, 1 = fully pressed. Created eagerly: dispose must never be
  /// the first access (a lazy controller would look up TickerMode there).
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController.unbounded(vsync: this);
  }

  /// Read in build: [_to] also runs from onTapCancel while the tree is being
  /// torn down, when the context may no longer be used.
  bool _reduceMotion = false;

  void _to(double target) {
    if (!mounted) return;
    if (_reduceMotion) {
      _press
        ..stop()
        ..value = target;
      return;
    }
    _press.animateWith(
      SpringSimulation(AvoMotion.quick, _press.value, target, _press.velocity),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = _reduceMotion = context.reduceMotion;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTapDown: (_) => _to(1),
      onTapUp: (_) => _to(0),
      onTapCancel: () => _to(0),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _press,
        builder: (context, child) {
          final t = _press.value.clamp(0.0, 1.0);
          final scale = reduce ? 1.0 : 1 - (1 - AvoMotion.pressedScale) * t;
          return Opacity(
            opacity: 1 - (1 - _kPressedOpacity) * t,
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: widget.child,
      ),
    );
  }
}
