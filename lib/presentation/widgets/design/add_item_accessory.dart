import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
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
const double _stopGlyph = 18; // D2: stop.fill square, heavier than the waveform

/// The character counter shows once this many characters are left: 5 % of
/// the limit, at least 10 (4000 characters: from 3800, as in avo.md §2.11).
int _counterThreshold(int maxLength) => math.max(10, maxLength ~/ 20);

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
///
/// A third state, "Antwort anhalten": while [responding] is true and
/// [onStop] is set, the round button shows a square and stops the answer,
/// whatever the field holds. [enabled] false greys the whole capsule and
/// makes it unfocusable. [maxLength] stops input at the limit and shows
/// "Noch n Zeichen" above the capsule shortly before it. The camera button
/// can open a pull-down menu ([photoMenuItems]) instead of calling
/// [onCamera].
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
    this.onStop,
    this.responding = false,
    this.stopLabel,
    this.enabled = true,
    this.maxLength,
    this.semanticLabel,
    this.photoMenuItems,
  }) : assert(maxLines >= 1),
       assert(maxLength == null || maxLength > 0),
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

  /// Stops the running answer. Together with [responding] it turns the round
  /// button into "Antwort anhalten" (a square), also while the field has
  /// text. Null never shows the stop state.
  final VoidCallback? onStop;

  /// True while Avo is answering. Only has an effect with [onStop].
  final bool responding;

  /// VoiceOver label of the stop state; defaults to "Antwort anhalten"
  /// (`common_stop_answer`; Avo's own `avo_stop_answer` text goes here).
  final String? stopLabel;

  /// False greys the capsule (40 %), keeps the keyboard away and ignores
  /// every tap, also from VoiceOver.
  final bool enabled;

  /// Longest text; the field takes no more. A counter appears above the
  /// capsule when 5 % (at least 10 characters) are left.
  final int? maxLength;

  /// VoiceOver label of the text field; defaults to [placeholder]. Use it
  /// when the placeholder is not a good name ("Avo fragen").
  final String? semanticLabel;

  /// Rows of a pull-down menu that the camera button opens (for example
  /// "Foto aufnehmen" with [AvoIcons.camera], "Foto auswählen" with
  /// [AvoIcons.photo]). It shows the camera button without [onCamera]; when
  /// both are set the menu wins. Label: [cameraLabel], else "Foto
  /// hinzufügen" (`common_add_photo`).
  final List<AvoMenuEntry>? photoMenuItems;

  @override
  Widget build(BuildContext context) {
    final scale = _iconScale(context);
    final menu = photoMenuItems;
    final hasMenu = menu != null && menu.any((e) => e is AvoMenuItem);
    final hasCamera = hasMenu || onCamera != null;
    final cameraOverlap = (AvoSizes.hitTarget - _cameraWidth) / 2;
    final voiceOverlap = (AvoSizes.hitTarget - _voiceCircle) / 2;
    final short = shortPlaceholder;
    final text = short != null && context.isAccessibilityText
        ? short
        : placeholder;

    final stopping = responding && onStop != null;

    return _GlassInput(
      placeholder: text,
      semanticLabel: semanticLabel ?? placeholder,
      enabled: enabled,
      maxLength: maxLength,
      controller: controller,
      focusNode: focusNode,
      // While "Antwort anhalten" is offered, Return must not start a
      // second request.
      onSubmitted: stopping ? null : onSubmitted,
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
          if (hasMenu)
            Builder(
              builder: (buttonContext) {
                final label = cameraLabel ?? context.tr('common_add_photo');
                return _GlyphButton(
                  icon: AvoIcons.camera,
                  size: _cameraGlyph * scale,
                  label: label,
                  onPressed: enabled
                      ? () => showAvoMenu(
                          buttonContext,
                          items: menu,
                          semanticLabel: label,
                        )
                      : null,
                );
              },
            )
          else
            _GlyphButton(
              icon: AvoIcons.camera,
              size: _cameraGlyph * scale,
              label: cameraLabel!,
              onPressed: enabled ? onCamera : null,
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
          stopping: stopping,
          sendLabel: sendLabel,
          voiceLabel: voiceLabel,
          stopLabel: stopLabel ?? context.tr('common_stop_answer'),
          // The capsule already dims everything when it is disabled.
          dimSelf: enabled,
          onSend: enabled ? input.submit : null,
          onVoice: enabled ? onVoice : null,
          onStop: enabled ? onStop : null,
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
    this.enabled = true,
    this.maxLength,
  });

  final bool enabled;
  final int? maxLength;
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

  /// Characters in the field, tracked only near [_GlassInput.maxLength].
  int _length = 0;
  bool _nearLimit = false;

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
    _readLength(text);
  }

  /// Returns true when the counter's number or visibility changed.
  bool _readLength(String text) {
    final max = widget.maxLength;
    if (max == null) return false;
    final length = text.characters.length;
    final near = max - length <= _counterThreshold(max);
    final changed = near != _nearLimit || (near && length != _length);
    _length = length;
    _nearLimit = near;
    return changed;
  }

  void _onText() {
    final text = _controller.text;
    final empty = text.isEmpty;
    final canSubmit = text.trim().isNotEmpty;
    final counter = _readLength(text);
    // Rebuild only when the placeholder, the buttons or the counter change,
    // not per key.
    if (empty != _empty || canSubmit != _canSubmit || counter) {
      setState(() {
        _empty = empty;
        _canSubmit = canSubmit;
      });
    }
  }

  /// Hands the trimmed text to the caller; keeps text and focus.
  void submit() {
    if (!widget.enabled) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmitted?.call(text);
  }

  void _focusField() {
    if (!widget.enabled) return;
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
            autofocus: widget.autofocus && widget.enabled,
            enabled: widget.enabled,
            maxLength: widget.maxLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
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
    if (!widget.enabled) {
      content = Opacity(opacity: _disabledOpacity, child: content);
    }
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
    final max = widget.maxLength;
    final counter = max != null && _nearLimit
        ? _CharCounter(left: math.max(0, max - _length))
        : null;
    if (above == null && counter == null) return capsule;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?above,
        if (above != null && counter != null)
          const SizedBox(height: AvoSpacing.xs),
        ?counter,
        const SizedBox(height: _dockGap),
        capsule,
      ],
    );
  }
}

/// "Noch 12 Zeichen" above the capsule, announced politely when it changes.
class _CharCounter extends StatelessWidget {
  const _CharCounter({required this.left});

  final int left;

  @override
  Widget build(BuildContext context) {
    final text = left == 1
        ? context.tr('common_chars_left_one')
        : context.tr('common_chars_left', params: {'n': '$left'});
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: AvoSpacing.s),
        child: Semantics(
          liveRegion: true,
          child: Text(
            text,
            textAlign: TextAlign.end,
            style: context.text(
              AvoTextStyle.footnote,
              color: left == 0
                  ? context.colors.destructive
                  : context.colors.secondaryLabel,
              tabular: true,
            ),
          ),
        ),
      ),
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
/// empty, arrow ("Senden") once there is text, square ("Antwort anhalten")
/// while an answer runs and can be stopped.
class _VoiceSendButton extends StatefulWidget {
  const _VoiceSendButton({
    required this.hasText,
    required this.stopping,
    required this.sendLabel,
    required this.voiceLabel,
    required this.stopLabel,
    required this.onSend,
    required this.onVoice,
    required this.onStop,
    required this.dimSelf,
  });

  final bool dimSelf;
  final bool hasText;
  final bool stopping;
  final String sendLabel;
  final String voiceLabel;
  final String stopLabel;
  final VoidCallback? onSend;
  final VoidCallback? onVoice;
  final VoidCallback? onStop;

  @override
  State<_VoiceSendButton> createState() => _VoiceSendButtonState();
}

/// Which glyph the round button shows.
enum _Face { voice, send, stop }

class _VoiceSendButtonState extends State<_VoiceSendButton>
    with TickerProviderStateMixin {
  /// One 0..1 weight per face; the current face animates to 1, the others
  /// to 0, each on its own quick spring.
  late final List<AnimationController> _weights = [
    for (final face in _Face.values)
      AnimationController(vsync: this, value: face == _faceOf(widget) ? 1 : 0),
  ];

  /// Read in build: the text can change while the element is unmounting.
  bool _reduceMotion = false;

  static _Face _faceOf(_VoiceSendButton w) => w.stopping
      ? _Face.stop
      : w.hasText
      ? _Face.send
      : _Face.voice;

  @override
  void didUpdateWidget(covariant _VoiceSendButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final face = _faceOf(widget);
    if (_faceOf(oldWidget) == face) return;
    for (final f in _Face.values) {
      final c = _weights[f.index];
      final target = f == face ? 1.0 : 0.0;
      if (_reduceMotion) {
        c.animateTo(
          target,
          duration: AvoMotion.fadeReduced,
          curve: Curves.easeInOut,
        );
      } else {
        c.animateWith(
          SpringSimulation(
            AvoMotion.quick,
            c.value,
            target,
            c.velocity,
            snapToEnd: true,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final c in _weights) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = context.reduceMotion;
    final onTint = context.colors.onTint;
    final face = _faceOf(widget);
    final onTap = switch (face) {
      _Face.stop => widget.onStop,
      _Face.send => widget.onSend,
      _Face.voice => widget.onVoice,
    };
    final enabled = onTap != null;
    final label = switch (face) {
      _Face.stop => widget.stopLabel,
      _Face.send => widget.sendLabel,
      _Face.voice => widget.voiceLabel,
    };

    Widget glyph(_Face f, AvoIconData icon, double size) {
      final c = _weights[f.index];
      return AnimatedBuilder(
        animation: c,
        builder: (context, _) {
          final t = c.value.clamp(0.0, 1.0);
          // The incoming glyph grows from 0.6 (Konzept 00 §10.2 morph).
          final scale = _reduceMotion ? 1.0 : 0.6 + 0.4 * t;
          return Opacity(
            opacity: t,
            child: Transform.scale(
              scale: scale,
              child: AvoIcon(icon, size: size, color: onTint),
            ),
          );
        },
      );
    }

    Widget button = SizedBox.square(
      dimension: AvoSizes.hitTarget,
      child: Center(
        child: _TintCircle(
          diameter: _voiceCircle,
          child: Stack(
            alignment: Alignment.center,
            children: [
              glyph(_Face.voice, _waveformIcon, _voiceGlyph),
              glyph(_Face.send, _sendIcon, _voiceGlyph),
              glyph(_Face.stop, AvoIcons.stopFill, _stopGlyph),
            ],
          ),
        ),
      ),
    );
    if (!enabled && widget.dimSelf) {
      button = Opacity(opacity: _disabledOpacity, child: button);
    }

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: PressableScale(onPressed: onTap, child: button),
    );
  }
}
