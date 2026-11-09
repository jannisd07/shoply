import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/pro_badge.dart';

/// Minimum row height (D2 X-Profil `.row` min-height 52).
const double _kRowMinHeight = 52; // D2

/// Vertical padding, so a row with a subtitle reaches D2's 60 pt (X-Profil
/// "Avo Pro" row: 22 + 20 + 2 × 9).
const double _kRowVerticalPadding = 9; // D2

/// Disclosure chevron (D2 X-Profil: 8 × 14, stroke 2, round caps).
const Size _kChevronSize = Size(8, 14); // D2
const double _kChevronStroke = 2; // D2

/// D2 draws the chevron in #C7C7CC. No token has that grey, so it is
/// `secondaryLabel` at 60 % (adapts to dark mode and Increase Contrast).
const double _kChevronAlpha = 0.6;

/// Glyph before a value, next to 17 pt text.
const double _kValueLeadingSize = 15; // D2

/// Gap between the title and the [ProBadge].
const double _kBadgeGap = AvoSpacing.s;

/// Space between a wrapped title and the value below it.
const double _kRunSpacing = AvoSpacing.xxs;

String _joinLabel(List<String?> parts) =>
    parts.whereType<String>().where((p) => p.isNotEmpty).join(', ');

/// Shared frame of all settings rows: minimum height, padding, and the iOS
/// highlight that appears the moment a finger touches the row.
///
/// Rows highlight instead of scaling (Konzept 00 §12.20 scales buttons):
/// a full-width row that shrinks would detach from the group's hairlines.
class _RowShell extends StatefulWidget {
  const _RowShell({
    required this.child,
    this.onTap,
    this.highlightOnPress = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool highlightOnPress;

  @override
  State<_RowShell> createState() => _RowShellState();
}

class _RowShellState extends State<_RowShell>
    with SingleTickerProviderStateMixin {
  /// 0 = resting, 1 = fully highlighted. Created eagerly: dispose must never
  /// be the first access (a lazy controller would look up TickerMode there).
  late final AnimationController _highlight;

  @override
  void initState() {
    super.initState();
    _highlight = AnimationController.unbounded(vsync: this);
  }

  void _press() {
    _highlight
      ..stop()
      ..value = 1;
  }

  void _release() {
    _highlight.animateWith(
      SpringSimulation(
        AvoMotion.quick,
        _highlight.value,
        0,
        _highlight.velocity,
      ),
    );
  }

  @override
  void dispose() {
    _highlight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kRowMinHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AvoSpacing.l,
          vertical: _kRowVerticalPadding,
        ),
        child: widget.child,
      ),
    );
    final onTap = widget.onTap;
    if (onTap == null) return row;
    final highlight = widget.highlightOnPress;
    final fill = context.colors.fillStrong;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTapDown: highlight ? (_) => _press() : null,
      onTapUp: highlight ? (_) => _release() : null,
      onTapCancel: highlight ? _release : null,
      onTap: onTap,
      child: highlight
          ? AnimatedBuilder(
              animation: _highlight,
              builder: (context, child) {
                final t = _highlight.value.clamp(0.0, 1.0);
                return ColoredBox(
                  color: fill.withValues(alpha: fill.a * t),
                  child: child,
                );
              },
              child: row,
            )
          : row,
    );
  }
}

/// Title, optional [ProBadge] and subtitle, stacked.
class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.title,
    required this.titleColor,
    this.subtitle,
    this.pro = false,
  });

  final String title;
  final Color titleColor;
  final String? subtitle;
  final bool pro;

  @override
  Widget build(BuildContext context) {
    final titleText = Text(
      title,
      style: context.text(AvoTextStyle.body, color: titleColor),
    );
    final sub = subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pro)
          Wrap(
            spacing: _kBadgeGap,
            runSpacing: _kRunSpacing,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [titleText, const ProBadge()],
          )
        else
          titleText,
        if (sub != null)
          Text(
            sub,
            style: context.text(
              AvoTextStyle.subhead,
              color: context.colors.secondaryLabel,
            ),
          ),
      ],
    );
  }
}

/// Lays out the title block and a value: side by side while both fit (the
/// value wraps below when they do not), always stacked from AX1 on.
class _TitleAndValue extends StatelessWidget {
  const _TitleAndValue({
    required this.titleBlock,
    this.value,
    this.valueLeading,
  });

  final Widget titleBlock;
  final String? value;
  final Widget? valueLeading;

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v == null) return titleBlock;
    final valueLabel = Text(
      v,
      style: context.text(
        AvoTextStyle.body,
        color: context.colors.secondaryLabel,
      ),
    );
    final lead = valueLeading;
    final Widget valueText = lead == null
        ? valueLabel
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconStyleScope(size: _kValueLeadingSize, child: lead),
              const SizedBox(width: AvoSpacing.xs),
              Flexible(child: valueLabel),
            ],
          );
    if (context.isAccessibilityText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [titleBlock, valueText],
      );
    }
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AvoSpacing.m,
      runSpacing: _kRunSpacing,
      children: [titleBlock, valueText],
    );
  }
}

/// The disclosure chevron of navigation rows, drawn like D2's SVG.
class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    final color = context.colors.secondaryLabel.withValues(
      alpha: _kChevronAlpha,
    );
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    return Transform.flip(
      flipX: rtl,
      child: CustomPaint(size: _kChevronSize, painter: _ChevronPainter(color)),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // D2 path "M1.5 1.5 6.5 7l-5 5.5" in an 8 × 14 box.
    final sx = size.width / _kChevronSize.width;
    final sy = size.height / _kChevronSize.height;
    final path = Path()
      ..moveTo(1.5 * sx, 1.5 * sy)
      ..lineTo(6.5 * sx, 7 * sy)
      ..lineTo(1.5 * sx, 12.5 * sy);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _kChevronStroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => old.color != color;
}

/// Keeps a trailing element (chevron) on the first text line from AX1 on.
class _FirstLineAligned extends StatelessWidget {
  const _FirstLineAligned({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: context.typography.lineHeightOf(AvoTextStyle.body),
    child: Center(widthFactor: 1, child: child),
  );
}

/// A settings row that opens a screen: title, optional subtitle and value,
/// chevron at the end (Konzept 00 §12.22, optics D2 X-Profil).
///
/// The whole row is one VoiceOver button ("Wochenplan, Pro feature, Lidl").
/// Without [onTap] the row is shown disabled. From AX1 on the value moves
/// below the title.
class NavRow extends StatelessWidget {
  /// Creates a navigation row.
  const NavRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.valueLeading,
    this.leading,
    this.onTap,
    this.pro = false,
    this.destructive = false,
  });

  /// Row title, 17/22.
  final String title;

  /// Second line, 15/20 `secondaryLabel`.
  final String? subtitle;

  /// Current value at the end ("Automatisch"), 17/22 `secondaryLabel`.
  final String? value;

  /// A glyph before [value], for example a warning triangle
  /// (`exclamationmarkTriangleFill` in `warning`, 15 pt) before "In iOS aus".
  /// Decorative for VoiceOver: put what it means into [value]. Ignored
  /// without a [value].
  final Widget? valueLeading;

  /// Optional icon tile before the title (D2: 30 pt, radius 8).
  final Widget? leading;

  /// Opens the target. Null shows the row disabled.
  final VoidCallback? onTap;

  /// Puts a [ProBadge] after the title.
  final bool pro;

  /// Title in the destructive colour ("Konto löschen").
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onTap != null;
    final titleColor = !enabled
        ? colors.secondaryLabel
        : destructive
        ? colors.destructive
        : colors.label;
    final ax = context.isAccessibilityText;
    final lead = leading;
    final body = _TitleAndValue(
      titleBlock: _TitleBlock(
        title: title,
        titleColor: titleColor,
        subtitle: subtitle,
        pro: pro,
      ),
      value: value,
      valueLeading: valueLeading,
    );
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: _joinLabel([
        title,
        if (pro) context.tr('common_pro_feature'),
        subtitle,
      ]),
      value: value,
      onTap: onTap,
      child: ExcludeSemantics(
        child: _RowShell(
          onTap: onTap,
          child: Row(
            crossAxisAlignment: ax
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              if (lead != null) ...[lead, const SizedBox(width: AvoSpacing.m)],
              Expanded(child: body),
              const SizedBox(width: AvoSpacing.m),
              if (ax)
                const _FirstLineAligned(child: _Chevron())
              else
                const _Chevron(),
            ],
          ),
        ),
      ),
    );
  }
}

/// A settings row with a switch; the whole row toggles (Konzept 00 §12.22).
///
/// The switch is a [CupertinoSwitch] with the accent track. It does not take
/// touches itself, so it never fires its own haptic (switches are not in the
/// haptics table of Konzept 00 §11); the trade-off is that its thumb cannot
/// be dragged. VoiceOver reads one element with the switch state. From AX1 on
/// the switch moves below the title.
class ToggleRow extends StatelessWidget {
  /// Creates a switch row.
  const ToggleRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.leading,
    this.enabled = true,
  });

  /// Row title, 17/22.
  final String title;

  /// Second line, 15/20 `secondaryLabel`.
  final String? subtitle;

  /// Whether the switch is on.
  final bool value;

  /// Called with the new value when the row is tapped.
  final ValueChanged<bool> onChanged;

  /// Optional icon tile before the title.
  final Widget? leading;

  /// False dims the row and ignores taps.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ax = context.isAccessibilityText;
    final lead = leading;
    final toggle = enabled ? () => onChanged(!value) : null;
    final switchWidget = IgnorePointer(
      child: CupertinoSwitch(
        value: value,
        onChanged: enabled ? (_) {} : null,
        activeTrackColor: colors.tintFill,
        inactiveTrackColor: colors.fillStrong,
      ),
    );
    final titleBlock = _TitleBlock(
      title: title,
      titleColor: enabled ? colors.label : colors.secondaryLabel,
      subtitle: subtitle,
    );
    return Semantics(
      container: true,
      toggled: value,
      enabled: enabled,
      label: _joinLabel([title, subtitle]),
      onTap: toggle,
      child: ExcludeSemantics(
        child: _RowShell(
          onTap: toggle,
          highlightOnPress: false,
          child: Row(
            crossAxisAlignment: ax
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              if (lead != null) ...[lead, const SizedBox(width: AvoSpacing.m)],
              if (ax)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      titleBlock,
                      const SizedBox(height: AvoSpacing.s),
                      switchWidget,
                    ],
                  ),
                )
              else ...[
                Expanded(child: titleBlock),
                const SizedBox(width: AvoSpacing.m),
                switchWidget,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A read-only row: title and value ("Version", "4.2.0"). From AX1 on the
/// value moves below the title.
class ValueRow extends StatelessWidget {
  /// Creates a value row.
  const ValueRow({super.key, required this.title, required this.value});

  /// Row title, 17/22.
  final String title;

  /// The value, 17/22 `secondaryLabel`.
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: title,
      value: value,
      child: ExcludeSemantics(
        child: _RowShell(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            heightFactor: 1,
            child: _TitleAndValue(
              titleBlock: _TitleBlock(
                title: title,
                titleColor: context.colors.label,
              ),
              value: value,
            ),
          ),
        ),
      ),
    );
  }
}

/// A centred destructive action row ("Abmelden", "Konto löschen"); put it in
/// its own `InsetSection` at the end of a screen. Confirm with
/// `showAvoConfirm` before acting.
class DestructiveRow extends StatelessWidget {
  /// Creates a destructive row.
  const DestructiveRow({super.key, required this.title, required this.onTap});

  /// The action, 17/22 in the destructive colour.
  final String title;

  /// Runs the action (usually after a confirmation).
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: title,
      onTap: onTap,
      child: ExcludeSemantics(
        child: _RowShell(
          onTap: onTap,
          child: Center(
            heightFactor: 1,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: context.text(
                AvoTextStyle.body,
                color: context.colors.destructive,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
