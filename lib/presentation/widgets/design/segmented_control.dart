import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';

// D2 "Segmented Control" (D2-Komponenten): track 44 high, radius 22, inner
// padding 3, thumb 38 high with a soft shadow. Compact (D2-Artikel unit
// picker): track 34 inside a 44 hit height, padding 2, segments at least 52
// wide.
const double _pad = 3; // D2
const double _padCompact = 2; // D2
const double _compactHeight = 34; // D2
const double _minSegmentCompact = 52; // D2
const double _thumbRing = 0.5; // D2 shadow `0 0 0 .5px`
const double _thumbRingAlpha = 0.04; // D2
const double _thumbShadowAlpha = 0.12; // D2
const double _thumbShadowY = 2; // D2
const double _thumbShadowBlur = 6; // D2

/// Space between a label and its segment edge.
const double _labelPad = AvoSpacing.s;

/// Konzept 00 §12.20: pressed controls also drop to 90 % opacity.
const double _pressedOpacity = 0.9;

/// Width of the centred fallback picker (an iOS alert is 270).
const double _dialogMaxWidth = 320;

/// One option of an [AppSegmentedControl].
class SegmentItem<T> {
  /// Creates an option.
  const SegmentItem({required this.value, required this.label});

  /// The value reported when this option is chosen.
  final T value;

  /// The visible (and VoiceOver) label.
  final String label;
}

/// A D2 segmented control for 2–4 options (Konzept 00 §12.18).
///
/// The white thumb springs to a tapped segment. A finger that starts on the
/// thumb drags it 1:1 (rubber band at the ends); passing a segment plays the
/// selection haptic, releasing snaps to the nearest one. Taps play no
/// haptic. When a label does not fit (measured at the current width and
/// text size) the control turns into a pull-down button that opens a
/// centred choice dialog. VoiceOver reads each segment as a button with a
/// selected state in a mutually exclusive group.
class AppSegmentedControl<T> extends StatefulWidget {
  /// Creates a segmented control.
  const AppSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.semanticLabel,
    this.compact = false,
  }) : assert(segments.length >= 2 && segments.length <= 4);

  /// The options, 2 to 4.
  final List<SegmentItem<T>> segments;

  /// The value of the selected option.
  final T selected;

  /// Called with the value of a newly chosen option.
  final ValueChanged<T> onChanged;

  /// What is being chosen ("Sortieren nach"); VoiceOver group label and
  /// title of the fallback dialog.
  final String? semanticLabel;

  /// D2-Artikel size: 34 pt visible inside the 44 pt hit height, segments
  /// sized to their labels when the width is unbounded.
  final bool compact;

  @override
  State<AppSegmentedControl<T>> createState() => _AppSegmentedControlState<T>();
}

class _AppSegmentedControlState<T> extends State<AppSegmentedControl<T>>
    with TickerProviderStateMixin {
  late final AnimationController _thumb;
  late final AnimationController _press;

  int? _pressedIndex;
  bool _draggingThumb = false;
  double _dragStart = 0;
  double _dragDx = 0;
  int _dragIndex = 0;

  // Geometry of the last layout, for gestures.
  double _segmentWidth = 1;
  double _inset = _pad;

  int get _selectedIndex {
    final i = widget.segments.indexWhere((s) => s.value == widget.selected);
    return i < 0 ? 0 : i;
  }

  int get _count => widget.segments.length;

  @override
  void initState() {
    super.initState();
    _thumb = AnimationController.unbounded(
      vsync: this,
      value: _selectedIndex.toDouble(),
    );
    _press = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(AppSegmentedControl<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reduceMotion = context.reduceMotion;
    if (!_draggingThumb && _thumb.value != _selectedIndex) {
      _moveThumb(_selectedIndex.toDouble());
    }
  }

  @override
  void dispose() {
    _thumb.dispose();
    _press.dispose();
    super.dispose();
  }

  /// Read in build: gesture callbacks can fire while the element is being
  /// unmounted, when looking up MediaQuery is no longer allowed.
  bool _reduceMotion = false;

  void _moveThumb(double target, {double? velocity}) {
    if (!mounted) return;
    if (_reduceMotion) {
      _thumb.value = target;
      return;
    }
    _thumb.animateWith(
      SpringSimulation(
        AvoMotion.quick,
        _thumb.value,
        target,
        velocity ?? _thumb.velocity,
        snapToEnd: true,
      ),
    );
  }

  void _setPressed(bool down) {
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

  int _indexAt(double dx) =>
      ((dx - _inset) / _segmentWidth).floor().clamp(0, _count - 1);

  void _select(int index) {
    if (index != _selectedIndex) widget.onChanged(widget.segments[index].value);
  }

  void _onTapDown(TapDownDetails d) {
    setState(() => _pressedIndex = _indexAt(d.localPosition.dx));
    _setPressed(true);
  }

  void _onTapUp(TapUpDetails d) {
    _setPressed(false);
    setState(() => _pressedIndex = null);
    _select(_indexAt(d.localPosition.dx));
  }

  void _onTapCancel() {
    _setPressed(false);
  }

  void _onDragStart(DragStartDetails d) {
    final index = _indexAt(d.localPosition.dx);
    _draggingThumb = index == _thumb.value.round();
    _dragIndex = index;
    setState(() => _pressedIndex = index);
    _setPressed(true);
    if (_draggingThumb) {
      _thumb.stop();
      _dragStart = _thumb.value;
      _dragDx = 0;
    }
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_draggingThumb) {
      final index = _indexAt(d.localPosition.dx);
      if (index != _pressedIndex) setState(() => _pressedIndex = index);
      return;
    }
    _dragDx += d.delta.dx;
    final raw = _dragStart + _dragDx / _segmentWidth;
    final last = (_count - 1).toDouble();
    double pos = raw;
    if (raw < 0) {
      pos =
          -AvoMotion.rubberBand(-raw * _segmentWidth, _segmentWidth) /
          _segmentWidth;
    } else if (raw > last) {
      pos =
          last +
          AvoMotion.rubberBand((raw - last) * _segmentWidth, _segmentWidth) /
              _segmentWidth;
    }
    _thumb.value = pos;
    final nearest = pos.round().clamp(0, _count - 1);
    if (nearest != _dragIndex) {
      // The thumb snaps over a new segment.
      unawaited(AvoHaptics.selection());
      setState(() {
        _dragIndex = nearest;
        _pressedIndex = nearest;
      });
    }
  }

  void _onDragEnd(DragEndDetails d) {
    _setPressed(false);
    final pressed = _pressedIndex;
    setState(() => _pressedIndex = null);
    if (!_draggingThumb) {
      if (pressed != null) _select(pressed);
      return;
    }
    _draggingThumb = false;
    final target = _thumb.value.round().clamp(0, _count - 1);
    _moveThumb(
      target.toDouble(),
      velocity: d.velocity.pixelsPerSecond.dx / _segmentWidth,
    );
    _select(target);
  }

  void _onDragCancel() {
    _setPressed(false);
    _pressedIndex = null;
    if (_draggingThumb) {
      _draggingThumb = false;
      _moveThumb(_selectedIndex.toDouble());
    }
  }

  TextStyle _labelStyle(BuildContext context, bool active) => context.text(
    AvoTextStyle.subhead,
    weight: active ? FontWeight.w600 : FontWeight.w500,
  );

  /// Width each segment gets, or null when a label does not fit.
  double? _segmentWidthFor(BuildContext context, BoxConstraints constraints) {
    var style = _labelStyle(context, true);
    if (MediaQuery.boldTextOf(context)) {
      style = style.merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    var widest = 0.0;
    for (final segment in widget.segments) {
      final painter = TextPainter(
        text: TextSpan(text: segment.label, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    final needed = widest.ceilToDouble() + 2 * _labelPad;
    final pad = widget.compact ? _padCompact : _pad;
    if (!constraints.hasBoundedWidth) {
      return math.max(
        needed,
        widget.compact ? _minSegmentCompact : AvoSizes.hitTarget,
      );
    }
    final available = (constraints.maxWidth - 2 * pad) / _count;
    if (available < needed || available < AvoSizes.hitTarget) return null;
    return available;
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = context.reduceMotion;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = _segmentWidthFor(context, constraints);
        if (width == null) {
          return _PullDownButton<T>(
            segments: widget.segments,
            selectedIndex: _selectedIndex,
            semanticLabel: widget.semanticLabel,
            onChanged: widget.onChanged,
          );
        }
        return _buildTrack(context, width, constraints);
      },
    );
  }

  Widget _buildTrack(
    BuildContext context,
    double segmentWidth,
    BoxConstraints constraints,
  ) {
    final colors = context.colors;
    final compact = widget.compact;
    final pad = compact ? _padCompact : _pad;
    final inset = compact ? (AvoSizes.hitTarget - _compactHeight) / 2 : 0.0;
    final thumbMin = (compact ? _compactHeight : AvoSizes.hitTarget) - 2 * pad;
    final labelPad = math.max(
      0.0,
      (thumbMin - context.typography.lineHeightOf(AvoTextStyle.subhead)) / 2,
    );
    _segmentWidth = segmentWidth;
    _inset = pad;
    final active = _draggingThumb ? _dragIndex : _selectedIndex;
    final selected = _selectedIndex;
    final total = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : segmentWidth * _count + 2 * pad;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        onHorizontalDragCancel: _onDragCancel,
        child: SizedBox(
          width: total,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: inset),
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: colors.fill,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: Listenable.merge([_thumb, _press]),
                builder: (context, child) {
                  final onThumb =
                      _pressedIndex != null &&
                      _pressedIndex == _thumb.value.round();
                  final p = onThumb && !context.reduceMotion
                      ? _press.value
                      : 0.0;
                  return Positioned(
                    left: pad + _thumb.value * segmentWidth,
                    width: segmentWidth,
                    top: inset + pad,
                    bottom: inset + pad,
                    child: p == 0
                        ? child!
                        : Transform.scale(
                            scale: 1 - (1 - AvoMotion.pressedScale) * p,
                            child: child,
                          ),
                  );
                },
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: colors.surfaceRaised,
                    shape: const StadiumBorder(),
                    shadows: [
                      BoxShadow(
                        color: colors.shadow.withValues(alpha: _thumbRingAlpha),
                        spreadRadius: _thumbRing,
                      ),
                      BoxShadow(
                        color: colors.shadow.withValues(
                          alpha: _thumbShadowAlpha,
                        ),
                        offset: const Offset(0, _thumbShadowY),
                        blurRadius: _thumbShadowBlur,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < _count; i++)
                      Semantics(
                        container: true,
                        button: true,
                        selected: i == selected,
                        inMutuallyExclusiveGroup: true,
                        label: widget.segments[i].label,
                        onTap: () => _select(i),
                        child: SizedBox(
                          width: segmentWidth,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: inset + pad + labelPad,
                            ),
                            child: _SegmentLabel(
                              label: widget.segments[i].label,
                              style: _labelStyle(context, i == active),
                              pressed: _pressedIndex == i && i != active
                                  ? _press
                                  : null,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel({
    required this.label,
    required this.style,
    required this.pressed,
  });

  final String label;
  final TextStyle style;

  /// Press progress when this (unselected) segment is under the finger.
  final Animation<double>? pressed;

  @override
  Widget build(BuildContext context) {
    final text = ExcludeSemantics(
      child: Text(
        label,
        style: style,
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.center,
      ),
    );
    final pressed = this.pressed;
    final centred = Center(heightFactor: 1, child: text);
    if (pressed == null) return centred;
    return AnimatedBuilder(
      animation: pressed,
      child: centred,
      builder: (context, child) {
        final p = pressed.value;
        if (p == 0) return child!;
        final scaled = context.reduceMotion
            ? child!
            : Transform.scale(
                scale: 1 - (1 - AvoMotion.pressedScale) * p,
                child: child,
              );
        return Opacity(opacity: 1 - (1 - _pressedOpacity) * p, child: scaled);
      },
    );
  }
}

/// Fallback when the labels do not fit: a capsule with the current value
/// and an up/down chevron that opens a centred choice dialog (no action
/// sheet, owner rule).
class _PullDownButton<T> extends StatelessWidget {
  const _PullDownButton({
    required this.segments,
    required this.selectedIndex,
    required this.semanticLabel,
    required this.onChanged,
  });

  final List<SegmentItem<T>> segments;
  final int selectedIndex;
  final String? semanticLabel;
  final ValueChanged<T> onChanged;

  Future<void> _open(BuildContext context) async {
    final index = await showCupertinoDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ChoiceDialog(
        title: semanticLabel,
        labels: [for (final s in segments) s.label],
        selectedIndex: selectedIndex,
      ),
    );
    if (index != null && index != selectedIndex) {
      onChanged(segments[index].value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final current = segments[selectedIndex].label;
    final line = context.typography.lineHeightOf(AvoTextStyle.subhead);
    final vertical = math.max(0.0, (AvoSizes.hitTarget - line) / 2);
    return Semantics(
      container: true,
      button: true,
      label: semanticLabel ?? current,
      value: semanticLabel == null ? null : current,
      onTap: () => _open(context),
      child: _Pressable(
        onTap: () => _open(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AvoSizes.hitTarget,
            minWidth: AvoSizes.hitTarget,
          ),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: colors.fill,
              shape: const StadiumBorder(),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AvoSpacing.l,
                vertical: vertical,
              ),
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        current,
                        style: context.text(
                          AvoTextStyle.subhead,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AvoSpacing.xs),
                    Icon(
                      CupertinoIcons.chevron_up_chevron_down,
                      size: line * 0.75,
                      color: colors.secondaryLabel,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Centred list of choices (title, options with a check mark, cancel).
class _ChoiceDialog extends StatelessWidget {
  const _ChoiceDialog({
    required this.title,
    required this.labels,
    required this.selectedIndex,
  });

  final String? title;
  final List<String> labels;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = this.title;
    final radius = BorderRadius.circular(AvoRadii.card);
    Widget hairline() => SizedBox(
      height: AvoSizes.hairline,
      child: ColoredBox(color: colors.separator),
    );
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AvoSpacing.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _dialogMaxWidth),
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: title,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: colors.surfaceRaised,
                  shape: RoundedRectangleBorder(borderRadius: radius),
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (title != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AvoSpacing.l,
                              AvoSpacing.l,
                              AvoSpacing.l,
                              AvoSpacing.s,
                            ),
                            child: ExcludeSemantics(
                              child: Text(
                                title,
                                textAlign: TextAlign.center,
                                style: context.text(
                                  AvoTextStyle.footnote,
                                  weight: FontWeight.w600,
                                  color: colors.secondaryLabel,
                                ),
                              ),
                            ),
                          ),
                        for (var i = 0; i < labels.length; i++) ...[
                          if (i > 0 || title != null) hairline(),
                          _DialogRow(
                            label: labels[i],
                            selected: i == selectedIndex,
                            option: true,
                            onTap: () => Navigator.of(context).pop(i),
                          ),
                        ],
                        hairline(),
                        _DialogRow(
                          label: context.tr('cancel'),
                          selected: false,
                          option: false,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogRow extends StatefulWidget {
  const _DialogRow({
    required this.label,
    required this.selected,
    required this.option,
    required this.onTap,
  });

  final String label;
  final bool selected;

  /// An option (selectable) rather than the cancel row.
  final bool option;
  final VoidCallback onTap;

  @override
  State<_DialogRow> createState() => _DialogRowState();
}

class _DialogRowState extends State<_DialogRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final line = context.typography.lineHeightOf(AvoTextStyle.body);
    final vertical = math.max(0.0, (AvoSizes.hitTarget - line) / 2);
    Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AvoSpacing.l,
          vertical: vertical,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: context.text(
                  AvoTextStyle.body,
                  weight: widget.option ? null : FontWeight.w600,
                  color: widget.option ? colors.label : colors.tint,
                ),
              ),
            ),
            if (widget.selected) ...[
              const SizedBox(width: AvoSpacing.s),
              Icon(
                CupertinoIcons.checkmark,
                size: context.typography.sizeOf(AvoTextStyle.body),
                color: colors.tint,
              ),
            ],
          ],
        ),
      ),
    );
    if (_pressed) row = ColoredBox(color: colors.fill, child: row);
    return Semantics(
      container: true,
      button: true,
      selected: widget.option ? widget.selected : null,
      inMutuallyExclusiveGroup: widget.option ? true : null,
      label: widget.label,
      onTap: widget.onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: row,
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
  final VoidCallback onTap;

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
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = context.reduceMotion;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
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
