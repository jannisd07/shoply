import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:shoply/core/design/design.dart';

// D2 "Filter-Chips" (D2-Komponenten): visible 34 high inside a 44 hit
// height, padding 0 14, capsule, 15 pt medium; gap 8.
const double _chipHeight = 34; // D2
const double _chipPadH = 14; // D2
const double _chipGap = AvoSpacing.s; // D2

/// iOS dims unavailable controls to about half.
const double _disabledOpacity = 0.45;

/// Konzept 00 §12.20: pressed controls also drop to 90 % opacity.
const double _pressedOpacity = 0.9;

/// A D2 filter chip (Konzept 00 §12.19): selected chips are dark with light
/// text, others sit on the neutral fill.
///
/// The visible capsule is 34 pt high inside a 44 pt hit area and grows with
/// Dynamic Type. Pressing scales it down; there is no haptic. VoiceOver
/// reads a button with a selected state.
class AppFilterChip extends StatelessWidget {
  /// Creates a filter chip.
  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    this.onSelected,
  });

  /// The visible (and VoiceOver) label. No emojis.
  final String label;

  /// Whether the filter is on.
  final bool selected;

  /// Called with the new selected state; null disables the chip.
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onSelected != null;
    final line = context.typography.lineHeightOf(AvoTextStyle.subhead);
    final vertical = ((_chipHeight - line) / 2).clamp(0.0, _chipHeight);
    void toggle() => onSelected?.call(!selected);

    Widget chip = DecoratedBox(
      decoration: ShapeDecoration(
        color: selected ? colors.chipSelected : colors.fill,
        shape: const StadiumBorder(),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: _chipHeight,
          minWidth: _chipHeight,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: _chipPadH,
            vertical: vertical,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: context.text(
              AvoTextStyle.subhead,
              weight: FontWeight.w500,
              color: selected ? colors.onChipSelected : colors.label,
            ),
          ),
        ),
      ),
    );
    if (!enabled) chip = Opacity(opacity: _disabledOpacity, child: chip);

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      onTap: enabled ? toggle : null,
      child: ExcludeSemantics(
        child: _Pressable(
          onTap: enabled ? toggle : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AvoSizes.hitTarget,
              minWidth: AvoSizes.hitTarget,
            ),
            child: Align(widthFactor: 1, heightFactor: 1, child: chip),
          ),
        ),
      ),
    );
  }
}

/// A row of filter chips (Konzept 00 §12.19): one horizontally scrolling
/// line with 8 pt gaps up to text size xxLarge, a wrapping block from
/// xxxLarge on, so large text never hides chips off-screen.
class ChipRow extends StatelessWidget {
  /// Creates a chip row.
  const ChipRow({
    super.key,
    required this.chips,
    this.padding = const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
  });

  /// The chips, usually [AppFilterChip]s (a "Zurücksetzen" chip last).
  final List<Widget> chips;

  /// Space around the chips; the scroll view scrolls under it.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final wraps =
        context.typography.category.index >= ContentSizeCategory.xxxLarge.index;
    if (wraps) {
      return Padding(
        padding: padding,
        child: Wrap(spacing: _chipGap, children: chips),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: _chipGap),
            chips[i],
          ],
        ],
      ),
    );
  }
}

/// Scales its child to [AvoMotion.pressedScale] and 90 % opacity while a
/// finger is down, on the quick spring (instant opacity only under Reduce
/// Motion).
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(vsync: this);
  }

  /// Read in build: gesture callbacks can fire while the element is being
  /// unmounted, when looking up MediaQuery is no longer allowed.
  bool _reduceMotion = false;

  void _set(bool down) {
    if (!mounted) return;
    final target = down ? 1.0 : 0.0;
    if (_reduceMotion) {
      _press.value = target;
      return;
    }
    _press.animateWith(
      SpringSimulation(
        AvoMotion.quick,
        _press.value,
        target,
        _press.velocity,
        snapToEnd: true,
      ),
    );
  }

  @override
  void didUpdateWidget(_Pressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onTap == null && _press.value != 0) _set(false);
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = context.reduceMotion;
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _press,
        child: widget.child,
        builder: (context, child) {
          final p = _press.value;
          if (p == 0) return child!;
          final scaled = context.reduceMotion
              ? child!
              : Transform.scale(
                  scale: 1 - (1 - AvoMotion.pressedScale) * p,
                  child: child,
                );
          return Opacity(opacity: 1 - (1 - _pressedOpacity) * p, child: scaled);
        },
      ),
    );
  }
}
