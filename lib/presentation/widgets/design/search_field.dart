import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';

// D2 / iOS search field: neutral fill, radius 10, at least 36 visible inside
// a 44 hit height; magnifier 8 from the leading edge.
const double _fieldRadius = 10; // D2
const double _visibleMinHeight = 36; // D2
const double _iconInset = AvoSpacing.s; // D2

/// Gap between the magnifier and the text.
const double _textInset = AvoSpacing.xs + AvoSpacing.xxs;

/// Konzept 00 §12.20: pressed controls also drop to 90 % opacity.
const double _pressedOpacity = 0.9;

/// The D2 search field (Konzept 00 §12.25): a filled rounded field with a
/// magnifier and placeholder; a clear button appears once there is text and
/// "Abbrechen" slides in beside it while it has focus.
///
/// Cancel clears the text (reporting `''` to [onChanged]) and drops focus.
/// The field has no fixed height: it is at least 36 pt visible inside a
/// 44 pt hit area and grows with Dynamic Type.
class AvoSearchField extends StatefulWidget {
  /// Creates a search field.
  const AvoSearchField({
    super.key,
    this.controller,
    this.hint,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
    this.cancelLabel,
  });

  /// Text controller; one is created when null.
  final TextEditingController? controller;

  /// Placeholder and VoiceOver label; defaults to "Suchen".
  final String? hint;

  /// Called on every edit, and with `''` when clear or cancel empties it.
  final ValueChanged<String>? onChanged;

  /// Called when the keyboard's search key is pressed.
  final ValueChanged<String>? onSubmitted;

  /// Focus node; one is created when null.
  final FocusNode? focusNode;

  /// Focus the field when it first appears.
  final bool autofocus;

  /// Label of the cancel button; defaults to "Abbrechen".
  final String? cancelLabel;

  @override
  State<AvoSearchField> createState() => _AvoSearchFieldState();
}

class _AvoSearchFieldState extends State<AvoSearchField>
    with SingleTickerProviderStateMixin {
  TextEditingController? _ownController;
  FocusNode? _ownFocus;
  late final AnimationController _cancel = AnimationController(vsync: this);
  bool _hasText = false;
  bool _focused = false;

  /// Read in build: focus can change while the element is being unmounted,
  /// when looking up MediaQuery is no longer allowed.
  bool _reduceMotion = false;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onText);
    _focus.addListener(_onFocus);
    _hasText = _controller.text.isNotEmpty;
    _focused = _focus.hasFocus;
    _cancel.value = _focused ? 1 : 0;
  }

  @override
  void didUpdateWidget(AvoSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_onText);
      if (widget.controller != null) {
        _ownController?.dispose();
        _ownController = null;
      }
      _controller.addListener(_onText);
      _onText();
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      if (widget.focusNode != null) {
        _ownFocus?.dispose();
        _ownFocus = null;
      }
      _focus.addListener(_onFocus);
      _onFocus();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onText);
    _focus.removeListener(_onFocus);
    _ownController?.dispose();
    _ownFocus?.dispose();
    _cancel.dispose();
    super.dispose();
  }

  void _onText() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  void _onFocus() {
    if (!mounted) return;
    final focused = _focus.hasFocus;
    if (focused == _focused) return;
    setState(() => _focused = focused);
    final target = focused ? 1.0 : 0.0;
    if (_reduceMotion) {
      _cancel.value = target;
      return;
    }
    _cancel.animateWith(
      SpringSimulation(
        AvoMotion.quick,
        _cancel.value,
        target,
        _cancel.velocity,
        snapToEnd: true,
      ),
    );
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  void _cancelSearch() {
    if (_controller.text.isNotEmpty) {
      _controller.clear();
      widget.onChanged?.call('');
    }
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = context.reduceMotion;
    final colors = context.colors;
    final hint = widget.hint ?? context.tr('search');
    final bodySize = context.typography.sizeOf(AvoTextStyle.body);
    final line = context.typography.lineHeightOf(AvoTextStyle.body);
    final inset = (AvoSizes.hitTarget - _visibleMinHeight) / 2;
    final textPad = math.max(0.0, (AvoSizes.hitTarget - line) / 2);

    final field = Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: inset),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: colors.fill,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_fieldRadius),
                ),
              ),
            ),
          ),
        ),
        Row(
          children: [
            const SizedBox(width: _iconInset),
            ExcludeSemantics(
              child: Icon(
                CupertinoIcons.search,
                size: bodySize,
                color: colors.placeholder,
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  // Drawn here rather than by CupertinoTextField, which
                  // would merge it into the label ("Suchen, Suchen") and
                  // drop the label once there is text.
                  if (!_hasText)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ExcludeSemantics(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: _textInset,
                            ),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                hint,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text(
                                  AvoTextStyle.body,
                                  color: colors.placeholder,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Semantics(
                    label: hint,
                    child: CupertinoTextField(
                      controller: _controller,
                      focusNode: _focus,
                      autofocus: widget.autofocus,
                      style: context.text(AvoTextStyle.body),
                      cursorColor: colors.tint,
                      decoration: null,
                      padding: EdgeInsets.symmetric(
                        horizontal: _textInset,
                        vertical: textPad,
                      ),
                      textInputAction: TextInputAction.search,
                      onChanged: widget.onChanged,
                      onSubmitted: widget.onSubmitted,
                    ),
                  ),
                ],
              ),
            ),
            if (_hasText)
              TextFieldTapRegion(
                child: _ClearButton(
                  label: context.tr('clear'),
                  size: bodySize,
                  onTap: _clear,
                ),
              )
            else
              const SizedBox(width: AvoSpacing.s),
          ],
        ),
      ],
    );

    return Row(
      children: [
        Expanded(child: field),
        AnimatedBuilder(
          animation: _cancel,
          builder: (context, child) {
            if (_cancel.value == 0 && !_focused) return const SizedBox.shrink();
            return ClipRect(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: _cancel.value.clamp(0.0, 1.0),
                heightFactor: 1,
                child: Opacity(
                  opacity: _cancel.value.clamp(0.0, 1.0),
                  child: child,
                ),
              ),
            );
          },
          child: TextFieldTapRegion(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: AvoSpacing.s),
              child: _CancelButton(
                label: widget.cancelLabel ?? context.tr('cancel'),
                onTap: _cancelSearch,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ClearButton extends StatelessWidget {
  const _ClearButton({
    required this.label,
    required this.size,
    required this.onTap,
  });

  final String label;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onTap,
      child: _Pressable(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AvoSizes.hitTarget,
            minHeight: AvoSizes.hitTarget,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Icon(
              CupertinoIcons.clear_circled_solid,
              size: size,
              color: context.colors.placeholder,
            ),
          ),
        ),
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: _Pressable(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AvoSizes.hitTarget,
              minWidth: AvoSizes.hitTarget,
            ),
            child: Align(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: context.text(
                  AvoTextStyle.body,
                  color: context.colors.tint,
                ),
              ),
            ),
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
