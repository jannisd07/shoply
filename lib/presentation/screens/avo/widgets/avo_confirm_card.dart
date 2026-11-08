import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/avo/avo_chat.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

// D2 confirm card (Kap. 6.1): one section, padding 16; trash 20 in the
// secondary colour (neutral, not red); two buttons of equal width, 44 high,
// radius 22; stacked from AX1 and on narrow screens, destructive on top.
const double _pad = AvoSpacing.l; // D2
const double _trash = 20; // D2
const double _buttonRadius = 22; // D2
const double _buttonGap = AvoSpacing.s;
const double _stackBelowWidth = 300; // 320 pt screens (Kap. 6.1)
const double _disabledOpacity = 0.4; // Konzept 00 §12.20

/// "„Party“ löschen?" for a deletion Avo proposed (Kap. 6). Only a tap on
/// the destructive button deletes, with the card's one-time token; spoken
/// or typed "ja" has no way to it. No figure in the card.
///
/// [phase] is kept by the conversation, so scrolling away never resets a
/// card. [expiresAt] dims the buttons once the 10 minutes are over.
class AvoConfirmCard extends StatefulWidget {
  const AvoConfirmCard({
    super.key,
    required this.title,
    required this.phase,
    required this.confirmLabel,
    required this.doneText,
    required this.onConfirm,
    required this.onCancel,
    this.body,
    this.confirmHint,
    this.cancelLabel,
    this.offline = false,
    this.expiresAt,
    this.onExpired,
  });

  final String title;
  final String? body;
  final String confirmLabel;
  final String? cancelLabel;

  /// VoiceOver hint of the destructive button ("Löscht die Liste
  /// endgültig.").
  final String? confirmHint;

  /// The result line once deleted ("Liste „Party“ gelöscht").
  final String doneText;
  final AvoConfirmPhase phase;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  /// Offline the destructive button is dimmed: deleting never waits in the
  /// offline queue.
  final bool offline;
  final DateTime? expiresAt;
  final VoidCallback? onExpired;

  @override
  State<AvoConfirmCard> createState() => _AvoConfirmCardState();
}

class _AvoConfirmCardState extends State<AvoConfirmCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant AvoConfirmCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final at = widget.expiresAt;
    if (at == null) return;
    final left = at.difference(DateTime.now());
    if (left.isNegative) return;
    _timer = Timer(left, () => widget.onExpired?.call());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final phase = widget.phase;

    if (phase == AvoConfirmPhase.deleted ||
        phase == AvoConfirmPhase.cancelled) {
      final text = phase == AvoConfirmPhase.deleted
          ? widget.doneText
          : context.tr('avo_not_deleted');
      return Semantics(
        container: true,
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.all(_pad),
          child: Row(
            children: [
              ExcludeSemantics(
                child: AvoIcon(
                  AvoIcons.trash,
                  size: _trash,
                  color: colors.secondaryLabel,
                ),
              ),
              const SizedBox(width: AvoSpacing.m),
              Expanded(
                child: Text(
                  text,
                  style: context.text(
                    AvoTextStyle.body,
                    color: phase == AvoConfirmPhase.cancelled
                        ? colors.secondaryLabel
                        : colors.label,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final expired = phase == AvoConfirmPhase.expired;
    final failed = phase == AvoConfirmPhase.failed;
    final working = phase == AvoConfirmPhase.working;
    final note = expired
        ? context.tr('avo_confirm_expired')
        : failed
        ? context.tr('avo_err_title')
        : widget.offline
        ? context.tr('avo_confirm_offline')
        : null;
    final canConfirm = !expired && !working && !widget.offline;

    // The light text red as a fill keeps white text at 5.4:1 in dark mode
    // too (the dark text red is too light for white text). Requested from
    // Teil A as a `destructiveFill` token.
    final destructiveFill = MediaQuery.highContrastOf(context)
        ? AvoColors.lightHighContrast.destructive
        : AvoColors.light.destructive;
    final destructive = _CardButton(
      label: failed ? context.tr('avo_retry') : widget.confirmLabel,
      hint: widget.confirmHint,
      fill: destructiveFill,
      foreground: colors.onTint,
      working: working,
      onPressed: canConfirm ? widget.onConfirm : null,
    );
    final cancel = _CardButton(
      label: widget.cancelLabel ?? context.tr('avo_cancel'),
      fill: colors.fill,
      foreground: colors.label,
      onPressed: expired || working ? null : widget.onCancel,
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: context.tr('avo_confirm_group'),
      child: Padding(
        padding: const EdgeInsets.all(_pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: AvoSpacing.xxs),
                  child: ExcludeSemantics(
                    child: AvoIcon(
                      AvoIcons.trash,
                      size: _trash,
                      color: colors.secondaryLabel,
                    ),
                  ),
                ),
                const SizedBox(width: AvoSpacing.m),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      widget.title,
                      style: context.text(AvoTextStyle.headline),
                    ),
                  ),
                ),
              ],
            ),
            if (widget.body != null) ...[
              const SizedBox(height: AvoSpacing.xs),
              Text(
                widget.body!,
                style: context.text(
                  AvoTextStyle.subhead,
                  color: colors.secondaryLabel,
                ),
              ),
            ],
            if (note != null) ...[
              const SizedBox(height: AvoSpacing.xs),
              Semantics(
                liveRegion: true,
                child: Text(
                  note,
                  style: context.text(
                    AvoTextStyle.subhead,
                    color: failed ? colors.destructive : colors.secondaryLabel,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AvoSpacing.m),
            LayoutBuilder(
              builder: (context, constraints) {
                final stack =
                    context.isAccessibilityText ||
                    constraints.maxWidth < _stackBelowWidth;
                if (stack) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      destructive,
                      const SizedBox(height: _buttonGap),
                      cancel,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cancel),
                    const SizedBox(width: _buttonGap),
                    Expanded(child: destructive),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A filled 44 pt button of the confirm card ("Abbrechen" on `fill`,
/// "Löschen" on the destructive text red, white text 5.4:1). Requested from
/// Teil A as `AppButton` variants.
class _CardButton extends StatelessWidget {
  const _CardButton({
    required this.label,
    required this.fill,
    required this.foreground,
    required this.onPressed,
    this.hint,
    this.working = false,
  });

  final String label;
  final String? hint;
  final Color fill;
  final Color foreground;
  final VoidCallback? onPressed;
  final bool working;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    Widget face = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(_buttonRadius),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AvoSpacing.l,
            vertical: AvoSpacing.s,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: working
                ? CupertinoActivityIndicator(color: foreground)
                : Text(
                    label,
                    textAlign: TextAlign.center,
                    style: context.text(
                      AvoTextStyle.body,
                      color: foreground,
                      weight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
    if (!enabled && !working) {
      face = Opacity(opacity: _disabledOpacity, child: face);
    }
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      hint: hint,
      onTap: onPressed,
      excludeSemantics: true,
      child: PressableScale(onPressed: onPressed, child: face),
    );
  }
}
