import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';

/// Messages-style composer for adding items to a shopping list.
///
/// Layout (left to right), mirroring the Apple Messages composer:
///  - a circular "+" glass button (34pt visual inside a >=44pt hit target),
///  - a capsule glass text field that grows to [maxLines] before scrolling
///    internally,
///  - a send button that scale+fades in inside the capsule's trailing edge
///    while the field is non-empty.
///
/// Material notes: the glass is a real `BackdropFilter` sampling whatever
/// scrolls behind the bar (the same recipe the app's other liquid-glass
/// widgets use) — not a static translucent color. With Increase Contrast /
/// Reduce Transparency enabled (`MediaQuery.highContrast`) it falls back to
/// an opaque surface so the field never becomes unreadable.
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
  /// the origin of the attachment sheet's morph animation.
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

class _AddItemComposerState extends State<AddItemComposer> {
  bool get _hasText => widget.controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  bool _lastHasText = false;
  void _onTextChanged() {
    // Only rebuild when the empty/non-empty state flips, not per keystroke —
    // the send button's visibility is the only thing this widget derives
    // from the text.
    final has = _hasText;
    if (has != _lastHasText) {
      _lastHasText = has;
      if (mounted) setState(() {});
    }
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

    // Real glass unless the user asked for contrast — then opaque surface.
    final capsuleTint = reduceTransparency
        ? AppColors.surface(context)
        : (isDark
              ? Colors.black.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.55));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _PlusButton(
          buttonKey: widget.plusButtonKey,
          onTap: widget.onPlusTap,
          reduceTransparency: reduceTransparency,
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _GlassCapsule(
            tint: capsuleTint,
            blur: !reduceTransparency,
            isDark: isDark,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, top: 2, bottom: 2),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.bottomCenter,
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
                          fontSize: 15,
                          color: AppColors.textPrimary(context),
                        ),
                        decoration: InputDecoration(
                          hintText: context.tr('add_item'),
                          hintStyle: TextStyle(
                            color: AppColors.textTertiary(context),
                            fontSize: 15,
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
                ),
                // Send button, inside the capsule's trailing edge.
                _SendButton(visible: _hasText, onTap: _submit),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The circular "+" glass button — 34pt visual inside a 44x44 hit target.
class _PlusButton extends StatelessWidget {
  final GlobalKey buttonKey;
  final VoidCallback onTap;
  final bool reduceTransparency;
  final bool isDark;

  const _PlusButton({
    required this.buttonKey,
    required this.onTap,
    required this.reduceTransparency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final tint = reduceTransparency
        ? AppColors.surface(context)
        : (isDark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.black.withValues(alpha: 0.06));

    return Semantics(
      button: true,
      label: context.tr('attachment_sheet_title'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        // 44x44 hit target regardless of the 34pt visual circle.
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: ClipOval(
              key: buttonKey,
              child: BackdropFilter(
                filter: reduceTransparency
                    ? ImageFilter.blur(sigmaX: 0, sigmaY: 0)
                    : ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: tint,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.16)
                          : Colors.white.withValues(alpha: 0.65),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    CupertinoIcons.plus,
                    size: 19,
                    color: AppColors.textPrimary(context),
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
              // Full-height 44pt-wide target hugging the trailing edge.
              child: SizedBox(
                width: 44,
                height: 40,
                child: Center(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.arrow_up,
                      size: 17,
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

/// Capsule-shaped glass container with the specular top-edge highlight.
class _GlassCapsule extends StatelessWidget {
  final Widget child;
  final Color tint;
  final bool blur;
  final bool isDark;

  const _GlassCapsule({
    required this.child,
    required this.tint,
    required this.blur,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Min height 40 (grows with multi-line text / large Dynamic Type — no
    // fixed height, so XXL text sizes never clip).
    final capsule = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(22),
        ),
        child: child,
      ),
    );

    return Container(
      // The specular edge: a hairline gradient border, brighter on top —
      // the same trick UIGlassEffect's rim light produces.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: 0.28),
                  Colors.white.withValues(alpha: 0.08),
                ]
              : [
                  Colors.white.withValues(alpha: 0.9),
                  Colors.white.withValues(alpha: 0.35),
                ],
        ),
      ),
      padding: const EdgeInsets.all(0.8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: blur
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: capsule,
              )
            : capsule,
      ),
    );
  }
}
