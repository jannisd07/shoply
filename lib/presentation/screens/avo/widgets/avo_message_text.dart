import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';

// Kap. 2.3: every word fades in over 120 ms (only opacity, so also under
// Reduce Motion).
const Duration _wordFade = Duration(milliseconds: 120); // D2
const double _bodyLeading = 23 / 17; // D2 Body 17/23 for Avo's text
const double _bulletIndent = AvoSpacing.l; // Kap. 2.3: 16 pt
const double _paragraphGap = AvoSpacing.s;

/// One block of Avo's text: a paragraph or a bullet.
@immutable
class AvoTextBlock {
  const AvoTextBlock(this.chars, {this.bullet = false});

  /// The visible characters with their index in the source text, so the
  /// fade can follow the stream through the markup.
  final List<(int, String)> chars;
  final bool bullet;

  String get text => chars.map((c) => c.$2).join();
}

/// Splits Avo's answer into paragraphs and bullets. Bullets start with
/// "- ", "* " or "• "; headings lose their "#", bold loses its "**" (Kap.
/// 2.3: no headings, no bold in Avo's text). Blank lines end a paragraph,
/// single line breaks stay.
List<AvoTextBlock> parseAvoText(String source) {
  final blocks = <AvoTextBlock>[];
  var paragraph = <(int, String)>[];

  void flush() {
    while (paragraph.isNotEmpty && paragraph.last.$2.trim().isEmpty) {
      paragraph.removeLast();
    }
    if (paragraph.isNotEmpty) blocks.add(AvoTextBlock(paragraph));
    paragraph = <(int, String)>[];
  }

  var offset = 0;
  for (final line in source.split('\n')) {
    final start = offset;
    offset += line.length + 1;
    final trimmed = line.trimLeft();
    if (trimmed.isEmpty) {
      flush();
      continue;
    }
    final lead = line.length - trimmed.length;
    var skip = 0;
    var bullet = false;
    final marker = RegExp(r'^([-*•])\s+').firstMatch(trimmed);
    final heading = RegExp(r'^#{1,6}\s+').firstMatch(trimmed);
    if (marker != null) {
      bullet = true;
      skip = marker.end;
    } else if (heading != null) {
      skip = heading.end;
    }
    final chars = <(int, String)>[];
    var i = lead + skip;
    while (i < line.length) {
      if (line.startsWith('**', i)) {
        i += 2;
        continue;
      }
      chars.add((start + i, line[i]));
      i++;
    }
    if (bullet) {
      flush();
      blocks.add(AvoTextBlock(chars, bullet: true));
    } else {
      if (paragraph.isNotEmpty) paragraph.add((start - 1, '\n'));
      paragraph.addAll(chars);
    }
  }
  flush();
  return blocks;
}

/// Avo's answer: no bubble, full content width, 17/23 in the label colour
/// (Kap. 2.3). New words fade in while [text] grows. VoiceOver reads it with
/// "Avo:" in front. A long press offers "Kopieren".
class AvoMessageText extends StatefulWidget {
  const AvoMessageText({super.key, required this.text});

  final ValueListenable<String> text;

  @override
  State<AvoMessageText> createState() => _AvoMessageTextState();
}

class _AvoMessageTextState extends State<AvoMessageText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: _wordFade,
    value: 1,
  );

  /// Source characters before this index are fully visible.
  int _settled = 0;

  /// Characters from [_settled] up to here are fading in.
  int _length = 0;

  @override
  void initState() {
    super.initState();
    _settled = _length = widget.text.value.length;
    widget.text.addListener(_onText);
  }

  @override
  void didUpdateWidget(covariant AvoMessageText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      oldWidget.text.removeListener(_onText);
      widget.text.addListener(_onText);
      _settled = _length = widget.text.value.length;
    }
  }

  void _onText() {
    final length = widget.text.value.length;
    setState(() {
      if (length < _length) {
        // Replaced (a tool started): show the new text as it is.
        _settled = _length = length;
        _fade.value = 1;
        return;
      }
      // The previous words are done; the new ones start their fade.
      _settled = _length;
      _length = length;
      _fade.forward(from: 0);
    });
  }

  @override
  void dispose() {
    widget.text.removeListener(_onText);
    _fade.dispose();
    super.dispose();
  }

  void _menu(BuildContext anchor) {
    final text = widget.text.value;
    showAvoMenu(
      anchor,
      items: [
        AvoMenuItem(
          label: anchor.tr('avo_copy'),
          onSelected: () => Clipboard.setData(ClipboardData(text: text)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.text.value;
    if (source.trim().isEmpty) return const SizedBox.shrink();
    final blocks = parseAvoText(source);
    final base = context.text(AvoTextStyle.body).copyWith(height: _bodyLeading);
    final label = context.colors.label;

    Widget block(AvoTextBlock b) => AnimatedBuilder(
      animation: _fade,
      builder: (context, _) {
        final spans = <TextSpan>[];
        final buffer = StringBuffer();
        bool? fading;
        void push() {
          if (buffer.isEmpty) return;
          spans.add(
            TextSpan(
              text: buffer.toString(),
              style: fading == true
                  ? TextStyle(color: label.withValues(alpha: _fade.value))
                  : null,
            ),
          );
          buffer.clear();
        }

        for (final (index, char) in b.chars) {
          final f = index >= _settled;
          if (fading != null && f != fading) push();
          fading = f;
          buffer.write(char);
        }
        push();
        return Text.rich(TextSpan(style: base, children: spans));
      },
    );

    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      if (i > 0) children.add(const SizedBox(height: _paragraphGap));
      if (b.bullet) {
        children.add(
          Padding(
            padding: const EdgeInsetsDirectional.only(start: AvoSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _bulletIndent,
                  child: Text('•', style: base),
                ),
                Expanded(child: block(b)),
              ],
            ),
          ),
        );
      } else {
        children.add(block(b));
      }
    }

    return Builder(
      builder: (anchor) => GestureDetector(
        // VoiceOver gets "Kopieren" as a custom action instead.
        excludeFromSemantics: true,
        onLongPress: () => _menu(anchor),
        child: Semantics(
          container: true,
          customSemanticsActions: {
            CustomSemanticsAction(label: context.tr('avo_copy')): () =>
                Clipboard.setData(ClipboardData(text: widget.text.value)),
          },
          label:
              '${context.tr('avo_a11y_prefix')} '
              '${blocks.map((b) => b.text).join('\n')}',
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}
