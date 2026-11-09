import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';

import 'package:shoply/core/design/design.dart';

/// What a [StatusRow] reports; picks the symbol (and the colour for
/// [failed]).
enum StatusKind {
  /// No connection ("Offline. Deine Änderungen werden gespeichert, …").
  offline,

  /// Changes are queued ("Offline. 3 Änderungen warten.").
  pending,

  /// Queued changes are being sent ("3 Änderungen werden gesendet.").
  sending,

  /// Something could not be saved; text and symbol in the destructive
  /// colour ("1 Änderung konnte nicht gespeichert werden.").
  failed,

  /// One section could not be loaded ("Das lässt sich gerade nicht laden.").
  sectionError,

  /// A permission is missing ("Standort ist aus. In Einstellungen erlauben").
  permission,
}

/// Symbol size at the default text size; it grows with Dynamic Type.
const double _kSymbolSize = 16;

/// Subhead size at the default category (Large), the reference for scaling
/// the symbol.
const double _kSubheadAtLarge = 15;

/// Gap between symbol and text, and before the action.
const double _kSymbolGap = AvoSpacing.s;

/// Largest share of the row (after the symbol) the action may take beside
/// the text; a wider action moves below it.
const double _kMaxInlineActionShare = 0.5;

/// Pressed opacity next to [AvoMotion.pressedScale] (Konzept 00 §12.20).
const double _kPressedOpacity = 0.9;

IconData _symbolFor(StatusKind kind) => switch (kind) {
  StatusKind.offline => CupertinoIcons.wifi_slash,
  StatusKind.pending => CupertinoIcons.clock,
  StatusKind.sending => CupertinoIcons.arrow_2_circlepath,
  StatusKind.failed => CupertinoIcons.exclamationmark_circle,
  StatusKind.sectionError => CupertinoIcons.exclamationmark_triangle,
  StatusKind.permission => CupertinoIcons.hand_raised,
};

/// A one-line status without a surface: symbol, sentence, optional action
/// (Konzept 00 §12.27, §13; A2 digest 4.3).
///
/// Place it under the screen title or at the start of a section, never above
/// the title, and show only one per screen. It spans the full width and
/// brings its own 16 pt side margins. The whole row is one VoiceOver element
/// (the action is its double-tap) and a live region: it is announced politely
/// when it appears or its text changes (on iOS through an explicit
/// announcement, where live regions do not speak by themselves). From AX1 on,
/// and whenever it would take more than half of the row, the action moves
/// below the text, where it may wrap. Haptics for a failure belong to the
/// failing action, not to this row.
class StatusRow extends StatefulWidget {
  /// Creates a status row.
  const StatusRow({
    super.key,
    required this.kind,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  /// What is reported; picks symbol and colour.
  final StatusKind kind;

  /// The sentence in everyday language, never a raw error.
  final String text;

  /// Tinted action after the text ("Erneut versuchen"); needs [onAction].
  final String? actionLabel;

  /// Runs the action.
  final VoidCallback? onAction;

  @override
  State<StatusRow> createState() => _StatusRowState();
}

class _StatusRowState extends State<StatusRow> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _announce());
  }

  @override
  void didUpdateWidget(StatusRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _announce());
    }
  }

  /// iOS live regions only post a layout change; speak the text explicitly.
  /// Android speaks live regions itself, so nothing is sent there.
  void _announce() {
    if (!mounted || defaultTargetPlatform != TargetPlatform.iOS) return;
    final view = View.maybeOf(context);
    if (view == null) return;
    SemanticsService.sendAnnouncement(
      view,
      widget.text,
      Directionality.maybeOf(context) ?? TextDirection.ltr,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final failed = widget.kind == StatusKind.failed;
    final textColor = failed ? colors.destructive : colors.label;
    final symbolColor = failed ? colors.destructive : colors.secondaryLabel;
    final lineHeight = typography.lineHeightOf(AvoTextStyle.subhead);
    final symbolSize =
        _kSymbolSize *
        typography.sizeOf(AvoTextStyle.subhead) /
        _kSubheadAtLarge;
    final label = widget.actionLabel;
    final onAction = widget.onAction;
    final hasAction = label != null && onAction != null;

    final symbol = SizedBox(
      height: lineHeight,
      child: Center(
        widthFactor: 1,
        child: Icon(
          _symbolFor(widget.kind),
          size: symbolSize,
          color: symbolColor,
        ),
      ),
    );
    final message = Padding(
      padding: const EdgeInsets.symmetric(vertical: AvoSpacing.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          symbol,
          const SizedBox(width: _kSymbolGap),
          Expanded(
            child: Text(
              widget.text,
              style: context.text(AvoTextStyle.subhead, color: textColor),
            ),
          ),
        ],
      ),
    );

    final Widget content;
    if (!hasAction) {
      content = message;
    } else {
      final action = _StatusAction(label: label, onTap: onAction);
      final stacked = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          message,
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: symbolSize + _kSymbolGap,
            ),
            child: action,
          ),
        ],
      );
      if (context.isAccessibilityText) {
        content = stacked;
      } else {
        content = LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final actionWidth = _actionWidth(context, label);
            // The action sits after the text only while it leaves the
            // sentence most of the row; otherwise it moves below the text
            // (320 pt at ×1.35 with "Erneut versuchen").
            if (width.isFinite &&
                actionWidth + _kSymbolGap >
                    (width - symbolSize - _kSymbolGap) *
                        _kMaxInlineActionShare) {
              return stacked;
            }
            return Row(
              children: [
                Expanded(child: message),
                const SizedBox(width: _kSymbolGap),
                action,
              ],
            );
          },
        );
      }
    }

    return Semantics(
      container: true,
      liveRegion: true,
      button: hasAction,
      label: widget.text,
      hint: hasAction ? label : null,
      onTap: hasAction ? onAction : null,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
            child: content,
          ),
        ),
      ),
    );
  }
}

TextStyle _actionStyle(BuildContext context) => context.text(
  AvoTextStyle.subhead,
  color: context.colors.tint,
  weight: FontWeight.w600,
);

/// Width of the action label on one line, at the current text size.
double _actionWidth(BuildContext context, String label) {
  var style = _actionStyle(context);
  if (MediaQuery.boldTextOf(context)) {
    style = style.merge(const TextStyle(fontWeight: FontWeight.bold));
  }
  final painter = TextPainter(
    text: TextSpan(text: label, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = math.max(painter.width.ceilToDouble(), AvoSizes.hitTarget);
  painter.dispose();
  return width;
}

/// Tinted text action with a 44 pt target that dims and shrinks on touch.
class _StatusAction extends StatefulWidget {
  const _StatusAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_StatusAction> createState() => _StatusActionState();
}

class _StatusActionState extends State<_StatusAction>
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AvoSizes.hitTarget,
          minWidth: AvoSizes.hitTarget,
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
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
            child: Text(widget.label, style: _actionStyle(context)),
          ),
        ),
      ),
    );
  }
}
