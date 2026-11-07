import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/common/liquid_glass_container.dart';

/// Messages-style composer for adding items to a shopping list.
///
/// Layout (left to right), mirroring the iOS 26 Messages composer:
///  - a circular "+" glass button,
///  - a capsule glass text field that grows to [maxLines] before scrolling
///    internally,
///  - a send button that scale+fades in inside the capsule's trailing edge
///    while the field is non-empty.
///
/// Material: on iOS both backgrounds are drawn by a *single* native
/// `UIGlassContainerEffect` ([LiquidGlassGroup]) rather than two independent
/// glass views. That is what lets the circle and the capsule bulge toward one
/// another and fuse the way Apple's controls do — separate effect views never
/// merge, no matter how close they sit. Flutter then paints the glyph and the
/// text field on top at matching offsets.
///
/// With Increase Contrast / Reduce Transparency (`MediaQuery.highContrast`)
/// the glass is dropped for opaque surfaces so the field stays readable.
///
/// This widget deliberately does NOT read `MediaQuery.viewInsets`: keyboard
/// tracking is the parent's job, so that only the smallest possible subtree
/// depends on per-frame inset changes.
class AddItemComposer extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmit;
  final VoidCallback onPlusTap;

  /// Key attached to the "+" button so callers can read its global rect as
  /// the origin of the attachment menu's morph animation.
  final GlobalKey plusButtonKey;

  /// Max visible text lines before the field scrolls internally.
  static const int maxLines = 5;

  const AddItemComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.onPlusTap,
    required this.plusButtonKey,
  });

  @override
  State<AddItemComposer> createState() => _AddItemComposerState();
}

// Metrics read off the iOS 26 Messages composer.
const double _kControlSize = 38; // circle diameter == capsule min height
const double _kHitTarget = 44;
const double _kGap = 8; // visual gap between circle and capsule
const double _kTextLeftInset = 16;

class _AddItemComposerState extends State<AddItemComposer> {
  final GlobalKey _contentKey = GlobalKey();

  /// Height of the bar; grows as the field wraps. Seeded with the
  /// single-line height so the very first frame is already correct.
  double _height = _kControlSize;

  bool get _hasText => widget.controller.text.trim().isNotEmpty;
  bool _lastHasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Text scale / locale changes resize the field without touching the
    // controller, so the glass shape has to be re-measured here too —
    // otherwise XXL Dynamic Type leaves the capsule glass too short.
    _scheduleHeightSync();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    // Only rebuild when the empty/non-empty state flips, not per keystroke —
    // the send button's visibility is the only thing derived from the text.
    final has = _hasText;
    if (has != _lastHasText) {
      _lastHasText = has;
      if (mounted) setState(() {});
    }
    _scheduleHeightSync();
  }

  /// The glass shapes are absolute rects, so the native side needs the real
  /// content height. Reading it after layout costs one extra frame, but only
  /// on the frames where the text actually wraps.
  void _scheduleHeightSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _contentKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final h = box.size.height;
      if ((h - _height).abs() > 0.5) setState(() => _height = h);
    });
  }

  void _submit() {
    final value = widget.controller.text.trim();
    if (value.isEmpty) return;
    HapticFeedback.lightImpact();
    // Clear FIRST so listeners (offer search) don't re-trigger on the old
    // text, then hand off — same order the previous add bar used.
    widget.controller.clear();
    widget.onSubmit(value);
    // Messages keeps the keyboard up after sending; so do we.
    widget.focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final reduceTransparency = MediaQuery.highContrastOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final useNativeGlass = Platform.isIOS && !reduceTransparency;

    final content = Row(
      key: _contentKey,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _PlusButton(
          buttonKey: widget.plusButtonKey,
          onTap: widget.onPlusTap,
          drawOwnBackground: !useNativeGlass,
          reduceTransparency: reduceTransparency,
          isDark: isDark,
        ),
        const SizedBox(width: _kGap),
        Expanded(
          child: _Capsule(
            drawOwnBackground: !useNativeGlass,
            reduceTransparency: reduceTransparency,
            isDark: isDark,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: _kTextLeftInset),
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      autofocus: false,
                      minLines: 1,
                      maxLines: AddItemComposer.maxLines,
                      textInputAction: TextInputAction.send,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardAppearance:
                          isDark ? Brightness.dark : Brightness.light,
                      style: TextStyle(
                        fontSize: 17,
                        color: AppColors.textPrimary(context),
                      ),
                      decoration: InputDecoration(
                        hintText: context.tr('add_item'),
                        hintStyle: TextStyle(
                          color: AppColors.textTertiary(context),
                          fontSize: 17,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 9),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                ),
                _SendButton(visible: _hasText, onTap: _submit),
              ],
            ),
          ),
        ),
      ],
    );

    if (!useNativeGlass) return content;

    // One container effect owning both backgrounds, so they merge.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final h = _height;
        const circleInset = (_kHitTarget - _kControlSize) / 2;
        final capsuleLeft = _kHitTarget + _kGap;

        return SizedBox(
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: LiquidGlassGroup(
                  // Slightly under the visual gap, so the shapes reach for
                  // each other without fusing at rest.
                  spacing: 14,
                  shapes: [
                    LiquidGlassShape(
                      rect: Rect.fromLTWH(
                        circleInset,
                        h - _kControlSize,
                        _kControlSize,
                        _kControlSize,
                      ),
                      isCapsule: true,
                    ),
                    LiquidGlassShape(
                      rect: Rect.fromLTWH(
                        capsuleLeft,
                        0,
                        (width - capsuleLeft).clamp(0.0, double.infinity),
                        h,
                      ),
                      isCapsule: true,
                    ),
                  ],
                ),
              ),
              content,
            ],
          ),
        );
      },
    );
  }
}

/// The circular "+" button — [_kControlSize] visual inside a [_kHitTarget]
/// touch area. On iOS the glass behind it comes from the shared group, so
/// this only draws the glyph.
class _PlusButton extends StatelessWidget {
  final GlobalKey buttonKey;
  final VoidCallback onTap;
  final bool drawOwnBackground;
  final bool reduceTransparency;
  final bool isDark;

  const _PlusButton({
    required this.buttonKey,
    required this.onTap,
    required this.drawOwnBackground,
    required this.reduceTransparency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final glyph = Icon(
      CupertinoIcons.plus,
      size: 20,
      color: AppColors.textPrimary(context),
    );

    Widget circle = SizedBox(
      key: buttonKey,
      width: _kControlSize,
      height: _kControlSize,
      child: Center(child: glyph),
    );

    if (drawOwnBackground) {
      final tint = reduceTransparency
          ? AppColors.surface(context)
          : (isDark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.black.withValues(alpha: 0.06));
      circle = SizedBox(
        key: buttonKey,
        width: _kControlSize,
        height: _kControlSize,
        child: ClipOval(
          child: BackdropFilter(
            filter: reduceTransparency
                ? ImageFilter.blur(sigmaX: 0, sigmaY: 0)
                : ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              child: Center(child: glyph),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: context.tr('attachment_sheet_title'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: SizedBox(
          width: _kHitTarget,
          height: _kHitTarget,
          child: Center(child: circle),
        ),
      ),
    );
  }
}

/// The text capsule. On iOS the glass comes from the shared group; this only
/// enforces the minimum height (and draws a fallback surface elsewhere).
class _Capsule extends StatelessWidget {
  final Widget child;
  final bool drawOwnBackground;
  final bool reduceTransparency;
  final bool isDark;

  const _Capsule({
    required this.child,
    required this.drawOwnBackground,
    required this.reduceTransparency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // No fixed height, so XXL Dynamic Type grows the capsule instead of
    // clipping the text.
    final sized = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kControlSize),
      child: child,
    );

    if (!drawOwnBackground) return sized;

    final tint = reduceTransparency
        ? AppColors.surface(context)
        : (isDark
            ? Colors.black.withValues(alpha: 0.35)
            : Colors.white.withValues(alpha: 0.55));
    final radius = BorderRadius.circular(_kControlSize / 2);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: reduceTransparency
            ? ImageFilter.blur(sigmaX: 0, sigmaY: 0)
            : ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(color: tint, borderRadius: radius),
          child: sized,
        ),
      ),
    );
  }
}

/// The send button that appears inside the capsule while text is present —
/// scale+fade, matching the Messages composer's arrow button.
class _SendButton extends StatelessWidget {
  final bool visible;
  final VoidCallback onTap;

  const _SendButton({required this.visible, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentColor(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 180);

    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: duration,
      curve: Curves.easeOut,
      child: AnimatedScale(
        scale: visible ? 1 : 0.4,
        duration: duration,
        curve: Curves.easeOutBack,
        child: IgnorePointer(
          ignoring: !visible,
          child: Semantics(
            button: true,
            label: context.tr('add_item'),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: SizedBox(
                width: _kControlSize,
                height: _kControlSize,
                child: Center(
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.arrow_up,
                      size: 18,
                      color: Colors.white,
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
