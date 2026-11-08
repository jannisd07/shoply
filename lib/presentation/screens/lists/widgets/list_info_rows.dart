import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

/// Konzept 00 §12.20: unavailable controls at 40 %.
const double _kDisabledOpacity = 0.4;

/// A tinted action row in an inset group ("Personen einladen", "Kategorie
/// hinzufügen"): symbol and text in [AvoColors.tint], at least 44 pt high,
/// highlights while pressed. One VoiceOver button; [subtitle] explains why
/// it is off ("Braucht eine Verbindung").
class ListInfoActionRow extends StatefulWidget {
  const ListInfoActionRow({
    super.key,
    required this.label,
    required this.icon,
    this.subtitle,
    this.onTap,
  });

  final String label;
  final AvoIconData icon;
  final String? subtitle;

  /// Null shows the row dimmed.
  final VoidCallback? onTap;

  @override
  State<ListInfoActionRow> createState() => _ListInfoActionRowState();
}

class _ListInfoActionRowState extends State<ListInfoActionRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _highlight = AnimationController.unbounded(
    vsync: this,
  );

  @override
  void dispose() {
    _highlight.dispose();
    super.dispose();
  }

  void _release() {
    if (!mounted) return;
    _highlight.animateWith(
      SpringSimulation(AvoMotion.quick, _highlight.value, 0, 0, snapToEnd: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final onTap = widget.onTap;
    final subtitle = widget.subtitle;
    Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AvoSpacing.l,
          vertical: AvoSpacing.m - 1,
        ),
        child: Row(
          children: [
            AvoIcon(widget.icon, size: 22, color: colors.tint),
            const SizedBox(width: AvoSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: context.text(AvoTextStyle.body, color: colors.tint),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: context.text(
                        AvoTextStyle.subhead,
                        color: colors.secondaryLabel,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) {
      row = Opacity(opacity: _kDisabledOpacity, child: row);
    } else {
      row = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _highlight
          ..stop()
          ..value = 1,
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        onTap: onTap,
        child: AnimatedBuilder(
          animation: _highlight,
          child: row,
          builder: (context, child) {
            final t = _highlight.value.clamp(0.0, 1.0);
            if (t == 0) return child!;
            final fill = colors.fillStrong;
            return ColoredBox(
              color: fill.withValues(alpha: fill.a * t),
              child: child,
            );
          },
        ),
      );
    }
    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      label: [widget.label, ?subtitle].join(', '),
      onTap: onTap,
      excludeSemantics: true,
      child: row,
    );
  }
}
