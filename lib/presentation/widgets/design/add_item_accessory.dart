import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/physics.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/glass_surface.dart';

// D2 "Bottom-Accessory" (D2-Komponenten): glass capsule at least 52 high,
// radius 26, padding 0 14 0 10, gap 10; tinted circle 32 with a 16 pt plus
// (stroke 2.8); field 17/22; mic 44 with a -6 margin (22 pt glyph); price
// 13/18 semibold.
const double _leadingInset = 10; // D2
const double _trailingInset = 14; // D2
const double _gap = 10; // D2
const double _plusCircle = 32; // D2
const double _plusGlyph = 16; // D2
const double _plusStroke = 2.8; // D2
const double _micGlyph = 22; // D2
const double _micOverlap = 6; // D2 margin 0 -6px

// D2 X-Avo composer: padding 0 6 0 14, gap 8; camera button 32 × 44 with a
// 22 pt glyph; `.glass-tint` circle 40 with a 20 pt waveform (stroke 2.2).
const double _avoLeadingInset = 14; // D2
const double _avoTrailingInset = 6; // D2
const double _avoGap = 8; // D2
const double _cameraWidth = 32; // D2
const double _cameraGlyph = 22; // D2
const double _voiceCircle = 40; // D2
const double _voiceGlyph = 20; // D2

/// Text inset above and below one line: (52 - 22) / 2 at the default size.
const double _textVertical = 15; // D2

/// From two lines on the capsule becomes a rectangle with half the minimum
/// height as radius, so the corners stay concentric (Konzept 11 §2.4, L-04).
const double _multiLineRadius = AvoSizes.accessoryHeight / 2; // D2 26

/// Free-standing glyphs (mic, camera) grow with Dynamic Type up to xxxL
/// (body 23 pt) and then stay (Konzept 11 §2.1, E-04). Glyphs inside the
/// tinted circles keep their D2 size, like the circles.
const double _iconGrowthLimit = 23 / 17;

/// Below this the info text ("≈ 23,80 €") leaves the row and sits under the
/// field (Konzept 00 §12.4: the field stays at least 160 pt wide).
const double _minFieldWidth = 160;

/// From AX3 the field shows at most two lines before it scrolls (Konzept 11
/// §2.1).
const int _axMaxLines = 2;

/// Gap between the accessory and the keyboard, and between the suggestion
/// panel and the accessory (Konzept 11 §2.2).
const double _dockGap = AvoSpacing.s;

// D2 `.glass-tint` on the small circles: 0 6px 18px rgba(31,122,58,.30).
const Offset _tintShadowOffset = Offset(0, 6); // D2
const double _tintShadowBlur = 18; // D2
const double _tintShadowAlpha = 0.30; // D2

const double _disabledOpacity = 0.4; // Konzept 00 §12.20

// D2 X-Avo glyphs that are not in [AvoIcons] yet.
const AvoIconData _cameraIcon = AvoIconData([
  AvoIconPath('M4 8h3l2-3h6l2 3h3v11H4z'),
  AvoIconCircle(12, 13, 3.5),
]); // D2 stroke 1.8
const AvoIconData _waveformIcon = AvoIconData([
  AvoIconPath('M5 10v4M9 7v10M13 5v14M17 8v8M21 11v2'),
], strokeWidth: 2.2); // D2
// "Senden" has no D2 glyph: an arrow up in the waveform's weight.
const AvoIconData _sendIcon = AvoIconData([
  AvoIconPath('M12 19V5.5M6 11.5l6-6 6 6'),
], strokeWidth: 2.4);

/// The add-item field that floats above the tab bar (D2 "Bottom-Accessory",
/// Konzept 00 §12.4, 11 §2): a glass capsule with a tinted plus circle, a
/// 17/22 text field, an optional mic button and an optional short info text
/// such as "≈ 23,80 €".
///
/// - Never a fixed height: at least 52 pt, growing with Dynamic Type, bold
///   text and wrapped lines; the glass follows the content in the same
///   layout pass (fixes A3, rule L-04). One line is a capsule; from two lines
///   it becomes a rectangle with a 26 pt radius.
/// - Multi-line up to [maxLines] (two from AX3), then the field scrolls.
/// - Return and the plus circle (once there is text) call [onSubmitted] with
///   the trimmed text and keep the keyboard up. The accessory never clears
///   itself: the caller decides (usually `controller.clear()` after adding).
/// - Tapping anywhere on the capsule focuses the field. No haptics.
/// - [above] holds the suggestion panel, 8 pt above the capsule.
///
/// Place it with [AccessoryDock], which keeps it above the tab bar or the
/// keyboard. It lives on the floating layer only.
class AddItemAccessory extends StatelessWidget {
  /// Creates the add-item accessory.
  const AddItemAccessory({
    super.key,
    required this.placeholder,
    this.controller,
    this.focusNode,
    this.onSubmitted,
    this.onChanged,
    this.onDictate,
    this.leading,
    this.trailing,
    this.trailingText,
    this.above,
    this.maxLines = 3,
    this.autofocus = false,
    this.textInputAction = TextInputAction.done,
    this.semanticHint,
    this.submitLabel,
  }) : assert(maxLines >= 1),
       assert(
         trailing == null || trailingText == null,
         'Pass either trailing or trailingText.',
       );

  /// Placeholder and VoiceOver label, for example "Artikel hinzufügen".
  final String placeholder;

  /// Text controller; one is created when null.
  final TextEditingController? controller;

  /// Focus node; one is created when null.
  final FocusNode? focusNode;

  /// Called with the trimmed text on Return or the plus circle. Not called
  /// for empty text. The field is not cleared.
  final ValueChanged<String>? onSubmitted;

  /// Called on every edit.
  final ValueChanged<String>? onChanged;

  /// Shows the 44 pt mic button ("Per Sprache hinzufügen") when set.
  final VoidCallback? onDictate;

  /// Replaces the tinted plus circle, for example a small activity indicator
  /// while a note is being read (Konzept 11 §3.2). Gets a 44 pt high slot,
  /// centred on the first line; it brings its own semantics.
  final Widget? leading;

  /// A short control at the end of the row (about 44 pt wide). For text use
  /// [trailingText].
  final Widget? trailing;

  /// A short info text at the end, 13/18 semibold with tabular figures, for
  /// example "≈ 23,80 €". Moves under the field when it would leave the field
  /// less than 160 pt.
  final String? trailingText;

  /// The suggestion panel above the capsule (Konzept 11 §2.2, filled by the
  /// screen, for example with `OfferSuggestionsBar`). 8 pt gap.
  final Widget? above;

  /// Lines shown before the field scrolls; at most two from AX3.
  final int maxLines;

  /// Focus the field when it first appears.
  final bool autofocus;

  /// The keyboard's return key. Return submits; it never inserts a newline.
  final TextInputAction textInputAction;

  /// VoiceOver hint, for example "Zum Beispiel 2 Milch".
  final String? semanticHint;

  /// VoiceOver label of the plus circle while there is text; defaults to
  /// "Hinzufügen".
  final String? submitLabel;

  @override
  Widget build(BuildContext context) {
    final info = trailingText;
    if (info == null) return _build(context, infoBelow: false);
    // The decision needs the capsule width, known in this layout pass.
    return LayoutBuilder(
      builder: (context, constraints) => _build(
        context,
        infoBelow: _infoBelow(context, constraints.maxWidth, info),
      ),
    );
  }

  bool _infoBelow(BuildContext context, double width, String info) {
    if (!width.isFinite) return false;
    final leadingBox = AvoSizes.hitTarget;
    var fixed =
        (_leadingInset - (leadingBox - _plusCircle) / 2) +
        leadingBox +
        (_gap - (leadingBox - _plusCircle) / 2) +
        _trailingInset;
    if (onDictate != null) {
      fixed += _gap - _micOverlap + AvoSizes.hitTarget + _gap - _micOverlap;
    } else {
      fixed += _gap;
    }
    final infoWidth = _measure(context, info, _infoStyle(context));
    return width - fixed - infoWidth < _minFieldWidth;
  }

  Widget _build(BuildContext context, {required bool infoBelow}) {
    final scale = _iconScale(context);
    final hasMic = onDictate != null;
    final custom = leading;
    final leadingBox = AvoSizes.hitTarget;
    final overlap = (leadingBox - _plusCircle) / 2;
    final info = trailingText;
    final infoInline = info != null && !infoBelow;

    final micSize = _micGlyph * scale;
    final end = <Widget>[
      if (hasMic) ...[
        const SizedBox(width: _gap - _micOverlap),
        _GlyphButton(
          icon: AvoIcons.mic,
          size: micSize,
          label: context.tr('common_dictate'),
          onPressed: onDictate,
        ),
      ],
      if (trailing != null) ...[
        SizedBox(width: hasMic ? _gap - _micOverlap : _gap),
        trailing!,
      ],
      if (infoInline) ...[
        SizedBox(width: hasMic ? _gap - _micOverlap : _gap),
        Text(info, maxLines: 1, softWrap: false, style: _infoStyle(context)),
      ],
    ];
    final endsWithMic = hasMic && trailing == null && !infoInline;

    return _GlassInput(
      placeholder: placeholder,
      controller: controller,
      focusNode: focusNode,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      maxLines: maxLines,
      autofocus: autofocus,
      textInputAction: textInputAction,
      semanticHint: semanticHint,
      startInset: _leadingInset - overlap,
      endInset: endsWithMic ? _trailingInset - _micOverlap : _trailingInset,
      above: above,
      below: infoBelow && info != null
          ? Padding(
              padding: const EdgeInsetsDirectional.only(
                end: _trailingInset,
                bottom: _leadingInset,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  info,
                  textAlign: TextAlign.end,
                  style: _infoStyle(context),
                ),
              ),
            )
          : null,
      leadingBuilder: (context, input) => [
        if (custom != null)
          // Same 44 pt slot as the plus circle, so the D2 insets hold.
          ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AvoSizes.hitTarget,
              minHeight: AvoSizes.hitTarget,
            ),
            child: Center(widthFactor: 1, heightFactor: 1, child: custom),
          )
        else
          _PlusCircle(
            submits: input.canSubmit,
            label: submitLabel ?? context.tr('add'),
            onSubmit: input.submit,
          ),
        SizedBox(width: _gap - overlap),
      ],
      trailingBuilder: (context, input) => end,
    );
  }

  static TextStyle _infoStyle(BuildContext context) => context.text(
    AvoTextStyle.footnote,
    weight: FontWeight.w600,
    tabular: true,
  );
}

/// The Avo composer (D2 X-Avo, Konzept 16 §3 and §4): a glass capsule with a
/// camera button, a 17/22 text field and a tinted round button that starts
/// voice mode and turns into "Senden" as soon as there is text.
///
/// Same rules as [AddItemAccessory]: no fixed height, multi-line up to
/// [maxLines] (two from AX3), Return sends ([onSubmitted] with the trimmed
/// text), the field is not cleared by itself, no haptics. The switch between
/// waveform and arrow is a quick spring (Reduce Motion: a short fade).
class AvoComposerField extends StatelessWidget {
  /// Creates the Avo composer.
  const AvoComposerField({
    super.key,
    required this.placeholder,
    required this.sendLabel,
    required this.voiceLabel,
    this.shortPlaceholder,
    this.controller,
    this.focusNode,
    this.onSubmitted,
    this.onChanged,
    this.onCamera,
    this.cameraLabel,
    this.onVoice,
    this.above,
    this.maxLines = 3,
    this.autofocus = false,
    this.textInputAction = TextInputAction.send,
  }) : assert(maxLines >= 1),
       assert(
         onCamera == null || cameraLabel != null,
         'A camera button needs a cameraLabel.',
       );

  /// Placeholder and VoiceOver label, for example "Frag Avo oder suche".
  final String placeholder;

  /// Shorter placeholder used from AX1 (Konzept 16 §3: "Frag Avo").
  final String? shortPlaceholder;

  /// VoiceOver label of the round button while there is text ("Senden").
  final String sendLabel;

  /// VoiceOver label of the round button while the field is empty
  /// ("Sprachmodus starten").
  final String voiceLabel;

  /// Text controller; one is created when null.
  final TextEditingController? controller;

  /// Focus node; one is created when null.
  final FocusNode? focusNode;

  /// Called with the trimmed text on Return or "Senden". Not called for
  /// empty text. The field is not cleared.
  final ValueChanged<String>? onSubmitted;

  /// Called on every edit.
  final ValueChanged<String>? onChanged;

  /// Shows the camera button at the start when set (module Avo on).
  final VoidCallback? onCamera;

  /// VoiceOver label of the camera button ("Foto aufnehmen").
  final String? cameraLabel;

  /// Starts voice mode. Null dims the round button while the field is
  /// empty.
  final VoidCallback? onVoice;

  /// A panel above the capsule (suggestions), 8 pt gap.
  final Widget? above;

  /// Lines shown before the field scrolls; at most two from AX3.
  final int maxLines;

  /// Focus the field when it first appears.
  final bool autofocus;

  /// The keyboard's return key; "Senden" by default.
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    final scale = _iconScale(context);
    final hasCamera = onCamera != null;
    final cameraOverlap = (AvoSizes.hitTarget - _cameraWidth) / 2;
    final voiceOverlap = (AvoSizes.hitTarget - _voiceCircle) / 2;
    final short = shortPlaceholder;
    final text = short != null && context.isAccessibilityText
        ? short
        : placeholder;

    return _GlassInput(
      placeholder: text,
      semanticLabel: placeholder,
      controller: controller,
      focusNode: focusNode,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      maxLines: maxLines,
      autofocus: autofocus,
      textInputAction: textInputAction,
      startInset: hasCamera
          ? _avoLeadingInset - cameraOverlap
          : _avoLeadingInset,
      endInset: _avoTrailingInset - voiceOverlap,
      above: above,
      leadingBuilder: (context, input) => [
        if (hasCamera) ...[
          _GlyphButton(
            icon: _cameraIcon,
            size: _cameraGlyph * scale,
            label: cameraLabel!,
            onPressed: onCamera,
          ),
          const SizedBox(
            width: _avoGap - (AvoSizes.hitTarget - _cameraWidth) / 2,
          ),
        ],
      ],
      trailingBuilder: (context, input) => [
        SizedBox(width: _avoGap - voiceOverlap),
        _VoiceSendButton(
          hasText: input.canSubmit,
          sendLabel: sendLabel,
          voiceLabel: voiceLabel,
          onSend: input.submit,
          onVoice: onVoice,
        ),
      ],
    );
  }
}

/// Places a floating accessory ([AddItemAccessory], [AvoComposerField]) in
/// a [Stack]: 16 pt from the sides and [ShellInsets.aboveTabBar] above the
/// bottom edge, or 8 pt above the keyboard while it is open.
///
/// Must be a direct child of the screen's [Stack]. Only this widget reads
/// the keyboard inset, so typing does not rebuild the screen. The screen must
/// not shrink for the keyboard itself (no `Scaffold` with
/// `resizeToAvoidBottomInset`), or the inset is counted twice. Hide the tab
/// bar while the keyboard is open (Konzept 11 §2.1).
class AccessoryDock extends StatelessWidget {
  /// Positions [child] above the tab bar or the keyboard.
  const AccessoryDock({
    super.key,
    required this.child,
    this.aboveTabBar = true,
  });

  /// The accessory.
  final Widget child;

  /// True (default) on tab roots: rests above the tab bar. False where there
  /// is no tab bar (Avo sheet): rests 8 pt above the bottom safe area.
  final bool aboveTabBar;

  /// Distance of the accessory's bottom edge from the bottom of the screen.
  static double bottomOffset(BuildContext context, {bool aboveTabBar = true}) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    if (keyboard > 0) return keyboard + _dockGap;
    if (aboveTabBar) return ShellInsets.aboveTabBar(context);
    return MediaQuery.viewPaddingOf(context).bottom + _dockGap;
  }

  @override
  Widget build(BuildContext context) => Positioned(
    left: AvoSpacing.screen,
    right: AvoSpacing.screen,
    bottom: bottomOffset(context, aboveTabBar: aboveTabBar),
    child: child,
  );
}

// ------------------------------------------------------------------- shared

double _iconScale(BuildContext context) {
  final base = AvoTypography.forFactor(1).sizeOf(AvoTextStyle.body);
  final size = context.typography.sizeOf(AvoTextStyle.body);
  return (size / base).clamp(1.0, _iconGrowthLimit);
}

double _measure(BuildContext context, String text, TextStyle style) {
  // Same resolution as Text: Bold Text and the text scaler.
  final effective = MediaQuery.boldTextOf(context)
      ? style.merge(const TextStyle(fontWeight: FontWeight.bold))
      : style;
  final painter = TextPainter(
    text: TextSpan(text: text, style: effective),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

typedef _SlotBuilder =
    List<Widget> Function(BuildContext context, _GlassInputState input);

/// The glass capsule with the text field both public fields share.
class _GlassInput extends StatefulWidget {
  const _GlassInput({
    required this.placeholder,
    this.semanticLabel,
    this.semanticHint,
    this.controller,
    this.focusNode,
    this.onSubmitted,
    this.onChanged,
    required this.maxLines,
    required this.autofocus,
    required this.textInputAction,
    required this.startInset,
    required this.endInset,
    required this.leadingBuilder,
    required this.trailingBuilder,
    this.above,
    this.below,
  });

  final String placeholder;
  final String? semanticLabel;
  final String? semanticHint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final bool autofocus;
  final TextInputAction textInputAction;
  final double startInset;
  final double endInset;
  final _SlotBuilder leadingBuilder;
  final _SlotBuilder trailingBuilder;
  final Widget? above;
  final Widget? below;

  @override
  State<_GlassInput> createState() => _GlassInputState();
}

class _GlassInputState extends State<_GlassInput> {
  TextEditingController? _ownController;
  FocusNode? _ownFocus;
  bool _empty = true;
  bool _canSubmit = false;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  /// There is text other than spaces.
  bool get canSubmit => _canSubmit;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onText);
    _read();
  }

  @override
  void didUpdateWidget(covariant _GlassInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_onText);
      if (widget.controller != null) {
        _ownController?.dispose();
        _ownController = null;
      }
      _controller.addListener(_onText);
      _read();
    }
    if (oldWidget.focusNode != widget.focusNode && widget.focusNode != null) {
      _ownFocus?.dispose();
      _ownFocus = null;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onText);
    _ownController?.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  void _read() {
    final text = _controller.text;
    _empty = text.isEmpty;
    _canSubmit = text.trim().isNotEmpty;
  }

  void _onText() {
    final text = _controller.text;
    final empty = text.isEmpty;
    final canSubmit = text.trim().isNotEmpty;
    // Rebuild only when the placeholder or the buttons change, not per key.
    if (empty != _empty || canSubmit != _canSubmit) {
      setState(() {
        _empty = empty;
        _canSubmit = canSubmit;
      });
    }
  }

  /// Hands the trimmed text to the caller; keeps text and focus.
  void submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmitted?.call(text);
  }

  void _focusField() {
    if (!_focus.hasFocus) _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final line = typography.lineHeightOf(AvoTextStyle.body);
    final vertical = math.max(
      _textVertical,
      (AvoSizes.accessoryHeight - line) / 2,
    );
    final oneLine = line + 2 * vertical;
    final maxLines = typography.category.index >= ContentSizeCategory.ax3.index
        ? math.min(widget.maxLines, _axMaxLines)
        : widget.maxLines;

    Widget slot(Widget child) => SizedBox(
      height: oneLine,
      child: Center(widthFactor: 1, child: child),
    );

    final field = Stack(
      children: [
        Semantics(
          label: widget.semanticLabel ?? widget.placeholder,
          hint: widget.semanticHint,
          child: CupertinoTextField(
            controller: _controller,
            focusNode: _focus,
            autofocus: widget.autofocus,
            style: context.text(AvoTextStyle.body),
            cursorColor: colors.tint,
            decoration: null,
            padding: EdgeInsets.symmetric(vertical: vertical),
            minLines: 1,
            maxLines: maxLines,
            textInputAction: widget.textInputAction,
            textCapitalization: TextCapitalization.sentences,
            keyboardAppearance: Theme.of(context).brightness,
            onChanged: widget.onChanged,
            // Return submits but keeps the keyboard up (Konzept 11 §2.2).
            onEditingComplete: _controller.clearComposing,
            onSubmitted: (_) => submit(),
          ),
        ),
        // Drawn here rather than by CupertinoTextField, which would merge it
        // into the label and drop the label once there is text. Wraps (up to
        // the field's lines) instead of being cut.
        if (_empty)
          IgnorePointer(
            child: ExcludeSemantics(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: vertical),
                child: Text(
                  widget.placeholder,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: context.text(
                    AvoTextStyle.body,
                    color: colors.placeholder,
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(width: widget.startInset),
        for (final w in widget.leadingBuilder(context, this)) slot(w),
        Expanded(child: field),
        for (final w in widget.trailingBuilder(context, this)) slot(w),
        SizedBox(width: widget.endInset),
      ],
    );
    final below = widget.below;
    if (below != null) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [content, below],
      );
    }

    final capsule = TextFieldTapRegion(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: _focusField,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            // The content decides the height; the glass reads it in the same
            // layout pass. Never a fixed height here (A3).
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final multiLine = constraints.maxHeight > oneLine + 0.5;
                  return GlassSurface(
                    // A new shape needs a new native view: its corner
                    // configuration is fixed at creation.
                    key: ValueKey<bool>(multiLine),
                    shape: multiLine ? GlassShape.rounded : GlassShape.capsule,
                    radius: _multiLineRadius,
                    child: const SizedBox.expand(),
                  );
                },
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AvoSizes.accessoryHeight,
              ),
              child: content,
            ),
          ],
        ),
      ),
    );

    final above = widget.above;
    if (above == null) return capsule;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        above,
        const SizedBox(height: _dockGap),
        capsule,
      ],
    );
  }
}

/// D2 `.glass-tint` drawn as a plain circle: the capsule behind it is already
/// glass, and native glass inside native glass is not allowed.
class _TintCircle extends StatelessWidget {
  const _TintCircle({required this.diameter, required this.child});

  final double diameter;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox.square(
      dimension: diameter,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: context.reduceTransparency
              ? colors.tintFill
              : colors.glassTintFill,
          shape: CircleBorder(
            side: BorderSide(
              color: colors.glassTintBorder,
              width: AvoSizes.hairline,
            ),
          ),
          shadows: [
            BoxShadow(
              color: colors.tintFill.withValues(alpha: _tintShadowAlpha),
              offset: _tintShadowOffset,
              blurRadius: _tintShadowBlur,
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// The tinted plus circle. Decorative while the field is empty (a tap
/// focuses the field through the capsule); a "Hinzufügen" button once there
/// is text.
class _PlusCircle extends StatelessWidget {
  const _PlusCircle({
    required this.submits,
    required this.label,
    required this.onSubmit,
  });

  final bool submits;
  final String label;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final face = SizedBox.square(
      dimension: AvoSizes.hitTarget,
      child: Center(
        child: _TintCircle(
          diameter: _plusCircle,
          child: AvoIcon(
            AvoIcons.plus,
            size: _plusGlyph,
            strokeWidth: _plusStroke,
            color: context.colors.onTint,
          ),
        ),
      ),
    );
    if (!submits) return ExcludeSemantics(child: face);
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onSubmit,
      excludeSemantics: true,
      child: PressableScale(onPressed: onSubmit, child: face),
    );
  }
}

/// A free-standing glyph with a 44 pt hit area (mic, camera).
class _GlyphButton extends StatelessWidget {
  const _GlyphButton({
    required this.icon,
    required this.size,
    required this.label,
    required this.onPressed,
  });

  final AvoIconData icon;
  final double size;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: PressableScale(
        onPressed: onPressed,
        child: SizedBox.square(
          dimension: math.max(AvoSizes.hitTarget, size),
          child: Center(child: AvoIcon(icon, size: size)),
        ),
      ),
    );
  }
}

/// The tinted round button of the Avo composer: waveform while the field is
/// empty, arrow ("Senden") once there is text.
class _VoiceSendButton extends StatefulWidget {
  const _VoiceSendButton({
    required this.hasText,
    required this.sendLabel,
    required this.voiceLabel,
    required this.onSend,
    required this.onVoice,
  });

  final bool hasText;
  final String sendLabel;
  final String voiceLabel;
  final VoidCallback onSend;
  final VoidCallback? onVoice;

  @override
  State<_VoiceSendButton> createState() => _VoiceSendButtonState();
}

class _VoiceSendButtonState extends State<_VoiceSendButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _send = AnimationController(
    vsync: this,
    value: widget.hasText ? 1 : 0,
  );

  /// Read in build: the text can change while the element is unmounting.
  bool _reduceMotion = false;

  @override
  void didUpdateWidget(covariant _VoiceSendButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hasText == widget.hasText) return;
    final target = widget.hasText ? 1.0 : 0.0;
    if (_reduceMotion) {
      _send.animateTo(
        target,
        duration: AvoMotion.fadeReduced,
        curve: Curves.easeInOut,
      );
    } else {
      _send.animateWith(
        SpringSimulation(
          AvoMotion.quick,
          _send.value,
          target,
          _send.velocity,
          snapToEnd: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _send.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = context.reduceMotion;
    final onTint = context.colors.onTint;
    final hasText = widget.hasText;
    final onTap = hasText ? widget.onSend : widget.onVoice;
    final enabled = onTap != null;

    Widget face = SizedBox.square(
      dimension: AvoSizes.hitTarget,
      child: Center(
        child: _TintCircle(
          diameter: _voiceCircle,
          child: AnimatedBuilder(
            animation: _send,
            builder: (context, _) {
              final t = _send.value.clamp(0.0, 1.0);
              // The incoming glyph grows from 0.6 (Konzept 00 §10.2 morph).
              double grow(double v) => _reduceMotion ? 1 : 0.6 + 0.4 * v;
              return Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: 1 - t,
                    child: Transform.scale(
                      scale: grow(1 - t),
                      child: AvoIcon(
                        _waveformIcon,
                        size: _voiceGlyph,
                        color: onTint,
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: t,
                    child: Transform.scale(
                      scale: grow(t),
                      child: AvoIcon(
                        _sendIcon,
                        size: _voiceGlyph,
                        color: onTint,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    if (!enabled) face = Opacity(opacity: _disabledOpacity, child: face);

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: hasText ? widget.sendLabel : widget.voiceLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: PressableScale(onPressed: onTap, child: face),
    );
  }
}
