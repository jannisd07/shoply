import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

// D2 "Filter-Chips" (D2-Komponenten): visible 34 high inside a 44 hit
// height, padding 0 14, capsule, 15 pt medium; gap 8.
const double _chipHeight = 34; // D2
const double _chipPadH = 14; // D2
const double _chipGap = AvoSpacing.s; // D2
const double _leadingSlot = 20; // D2: StoreMark 20 next to 15 pt text
const double _leadingGap = AvoSpacing.xs + AvoSpacing.xxs; // 6
/// The leading slot grows with the text up to about AX2.
const double _leadingMaxGrowth = 2; // D2: grows to about AX2

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
    this.leading,
    this.trailing,
    this.secondaryLabel,
    this.radioIndex,
    this.radioCount,
  });

  /// The visible (and VoiceOver) label. No emojis.
  final String label;

  /// Whether the filter is on.
  final bool selected;

  /// Called with the new selected state; null disables the chip.
  final ValueChanged<bool>? onSelected;

  /// A glyph before the label: a store mark, an 8 pt dot. It is centred in a
  /// 20 pt slot, scaled down to fit it, and the slot grows with the text up
  /// to about AX2. Decorative for VoiceOver.
  final Widget? leading;

  /// A small glyph after the label, for example `chevron.right` at 11 pt on
  /// "Anderer Markt …" (a chip that opens a screen). Unless it sets its own
  /// colour it is drawn in `secondaryLabel` (the light text colour on a
  /// selected chip) through [IconStyleScope], and sits
  /// 6 pt after the label. Decorative for VoiceOver: say in [label] what it
  /// means.
  final Widget? trailing;

  /// Quiet text after the label, drawn as "· 400 m" in the secondary colour
  /// (pass `400 m`, not the dot). VoiceOver reads it after the label. On a
  /// selected chip it takes the chip's light text colour to stay readable.
  final String? secondaryLabel;

  /// Zero-based position of this chip in a single-choice group. With
  /// [radioCount] it makes VoiceOver announce a radio button: "selected,
  /// 1 of 4". [SingleChoiceChipRow] sets both.
  final int? radioIndex;

  /// Size of the single-choice group, see [radioIndex].
  final int? radioCount;

  bool get _radio => radioIndex != null && radioCount != null;

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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                _LeadingSlot(child: leading!),
                const SizedBox(width: _leadingGap),
              ],
              Flexible(
                child: Text.rich(
                  TextSpan(
                    text: label,
                    children: [
                      if (secondaryLabel != null)
                        TextSpan(
                          text: ' · $secondaryLabel',
                          style: context.text(
                            AvoTextStyle.subhead,
                            color: selected
                                ? colors.onChipSelected
                                : colors.secondaryLabel,
                          ),
                        ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: context.text(
                    AvoTextStyle.subhead,
                    weight: FontWeight.w500,
                    color: selected ? colors.onChipSelected : colors.label,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: _leadingGap),
                ExcludeSemantics(
                  child: IconStyleScope(
                    color: selected
                        ? colors.onChipSelected
                        : colors.secondaryLabel,
                    child: trailing!,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!enabled) chip = Opacity(opacity: _disabledOpacity, child: chip);

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: _radio ? true : null,
      enabled: enabled,
      label: secondaryLabel == null ? label : '$label, $secondaryLabel',
      value: _radio
          ? context.tr(
              'common_chip_position',
              params: {'index': '${radioIndex! + 1}', 'count': '$radioCount'},
            )
          : null,
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
    this.wrap = false,
  });

  /// The chips, usually [AppFilterChip]s (a "Zurücksetzen" chip last).
  final List<Widget> chips;

  /// Space around the chips; the scroll view scrolls under it.
  final EdgeInsetsGeometry padding;

  /// True breaks the chips into several lines at every text size instead of
  /// scrolling (a store list, all filters at a glance). False wraps only from
  /// xxxLarge on.
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final wraps =
        wrap ||
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

/// One option of a [SingleChoiceChipRow].
@immutable
class ChipChoice<T> {
  /// Creates an option.
  const ChipChoice({
    required this.value,
    required this.label,
    this.secondaryLabel,
    this.leading,
  });

  /// What [SingleChoiceChipRow.onChanged] reports.
  final T value;

  /// Visible and VoiceOver label.
  final String label;

  /// See [AppFilterChip.secondaryLabel].
  final String? secondaryLabel;

  /// See [AppFilterChip.leading].
  final Widget? leading;
}

/// A [ChipRow] where at most one chip is on (store, period, sort).
///
/// VoiceOver reads every chip as a radio button: "Lidl, selected, 1 of 4".
/// Tapping the chosen chip again clears the choice when [allowDeselect] is
/// true (then [onChanged] gets null), otherwise it does nothing. [onChanged]
/// null disables all chips.
class SingleChoiceChipRow<T> extends StatelessWidget {
  /// Creates a single-choice chip row.
  const SingleChoiceChipRow({
    super.key,
    required this.choices,
    required this.value,
    required this.onChanged,
    this.allowDeselect = false,
    this.wrap = false,
    this.padding = const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
  });

  /// The options in display order.
  final List<ChipChoice<T>> choices;

  /// The chosen value, or null for none.
  final T? value;

  /// Called with the new choice; null when it was cleared.
  final ValueChanged<T?>? onChanged;

  /// Whether tapping the chosen chip clears the choice.
  final bool allowDeselect;

  /// See [ChipRow.wrap].
  final bool wrap;

  /// See [ChipRow.padding].
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ChipRow(
      padding: padding,
      wrap: wrap,
      chips: [
        for (var i = 0; i < choices.length; i++)
          AppFilterChip(
            label: choices[i].label,
            secondaryLabel: choices[i].secondaryLabel,
            leading: choices[i].leading,
            selected: choices[i].value == value,
            radioIndex: i,
            radioCount: choices.length,
            onSelected: onChanged == null
                ? null
                : (on) {
                    if (on) {
                      onChanged!(choices[i].value);
                    } else if (allowDeselect) {
                      onChanged!(null);
                    }
                  },
          ),
      ],
    );
  }
}

class _LeadingSlot extends StatelessWidget {
  const _LeadingSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final growth =
        (context.typography.sizeOf(AvoTextStyle.subhead) /
                AvoTypography.forFactor(1).sizeOf(AvoTextStyle.subhead))
            .clamp(1.0, _leadingMaxGrowth);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: _leadingSlot * growth,
        child: FittedBox(
          child: SizedBox.square(
            dimension: _leadingSlot,
            child: Center(child: child),
          ),
        ),
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
