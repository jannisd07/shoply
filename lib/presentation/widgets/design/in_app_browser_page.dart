import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';

/// Gap between the toolbar row and the first line of the page (D2: content
/// starts 12 pt under the toolbar).
const double _kContentTop = AvoSpacing.m; // D2

/// Space between two blocks of the page.
const double _kBlockGap = AvoSpacing.m;

/// Extra space above a heading.
const double _kHeadingGap = AvoSpacing.l;

/// Indent of list items next to their bullet.
const double _kBulletIndent = AvoSpacing.l;

/// How long a page may take before it counts as unreachable.
const Duration _kLoadTimeout = Duration(seconds: 15);

/// What one block of a [WebDocument] is.
enum WebBlockKind {
  /// The page title (`h1`).
  title,

  /// A section heading (`h2`).
  heading,

  /// A smaller heading (`h3` to `h6`).
  subheading,

  /// A paragraph.
  paragraph,

  /// One item of a list.
  listItem,
}

/// One block of text of a web page.
@immutable
class WebBlock {
  /// Creates a block.
  const WebBlock(this.kind, this.text);

  /// Heading, paragraph or list item.
  final WebBlockKind kind;

  /// The text with whitespace collapsed.
  final String text;

  @override
  bool operator ==(Object other) =>
      other is WebBlock && other.kind == kind && other.text == text;

  @override
  int get hashCode => Object.hash(kind, text);

  @override
  String toString() => 'WebBlock(${kind.name}, $text)';
}

/// The readable text of a web page: headings, paragraphs and list items in
/// page order (what the in-app browser shows).
@immutable
class WebDocument {
  /// Creates a document.
  const WebDocument({required this.blocks});

  /// The blocks in reading order.
  final List<WebBlock> blocks;

  /// Nothing readable was found.
  bool get isEmpty => blocks.isEmpty;
}

/// Loads a page for an [InAppBrowserPage]. Overridden in tests.
abstract interface class WebDocumentLoader {
  /// Loads [url]; throws when it cannot be reached.
  Future<WebDocument> load(Uri url);
}

/// Loads pages over HTTPS and keeps their readable text ([parseWebDocument]).
class HttpWebDocumentLoader implements WebDocumentLoader {
  /// Creates the loader.
  const HttpWebDocumentLoader();

  @override
  Future<WebDocument> load(Uri url) async {
    final response = await http.get(url).timeout(_kLoadTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException('HTTP ${response.statusCode}', url);
    }
    return parseWebDocument(response.body);
  }
}

/// Elements whose content is never part of the reading text.
const Set<String> _kSkippedTags = {
  'script',
  'style',
  'noscript',
  'template',
  'svg',
  'nav',
  'header',
  'footer',
  'form',
  'button',
  'select',
  'iframe',
};

String _collapse(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Keeps the readable text of [source]: headings, paragraphs and list items
/// of `<main>` (else `<article>`, else `<body>`), without navigation, header,
/// footer, scripts and forms. Pure, so it is tested without a network.
WebDocument parseWebDocument(String source) {
  final document = html_parser.parse(source);
  final root =
      document.querySelector('main') ??
      document.querySelector('article') ??
      document.body;
  if (root == null) return const WebDocument(blocks: []);
  final blocks = <WebBlock>[];

  void add(WebBlockKind kind, dom.Element element) {
    final text = _collapse(element.text);
    if (text.isEmpty) return;
    if (blocks.isNotEmpty && blocks.last.text == text) return;
    blocks.add(WebBlock(kind, text));
  }

  void visit(dom.Element element) {
    final tag = element.localName ?? '';
    if (_kSkippedTags.contains(tag)) return;
    switch (tag) {
      case 'h1':
        add(WebBlockKind.title, element);
      case 'h2':
        add(WebBlockKind.heading, element);
      case 'h3' || 'h4' || 'h5' || 'h6':
        add(WebBlockKind.subheading, element);
      case 'p':
        add(WebBlockKind.paragraph, element);
      case 'li':
        add(WebBlockKind.listItem, element);
      default:
        for (final child in element.children) {
          visit(child);
        }
    }
  }

  visit(root);
  return WebDocument(blocks: blocks);
}

/// A web page inside the app (Konzept 18 E18-08, K18-15): a push with a
/// glass back button, the page name as the inline title and "In Safari
/// öffnen" (`square.and.arrow.up`) on the right. No Safari window slides up
/// from the bottom.
///
/// The page is shown as readable text (headings, paragraphs, lists) in the
/// Avo type scale, so it follows Dynamic Type, dark mode and VoiceOver.
/// Without a connection it shows "Braucht eine Verbindung." with "Erneut
/// versuchen"; a page without readable text offers Safari instead.
class InAppBrowserPage extends StatefulWidget {
  /// Creates a browser page for [url].
  const InAppBrowserPage({
    super.key,
    required this.title,
    required this.url,
    this.loader = const HttpWebDocumentLoader(),
    this.onOpenExternally,
    this.backLabel,
  });

  /// Inline title ("Datenschutz").
  final String title;

  /// The page.
  final Uri url;

  /// Where the page comes from; a fake in tests.
  final WebDocumentLoader loader;

  /// Opens [url] in Safari; defaults to `url_launcher` with an external
  /// application.
  final Future<void> Function(Uri url)? onOpenExternally;

  /// VoiceOver label of the back button ("Zurück zu Rechtliches"); defaults
  /// to "Zurück".
  final String? backLabel;

  @override
  State<InAppBrowserPage> createState() => _InAppBrowserPageState();
}

class _InAppBrowserPageState extends State<InAppBrowserPage> {
  late Future<WebDocument> _document = _load();

  Future<WebDocument> _load() => widget.loader.load(widget.url);

  void _retry() {
    // A block, not an arrow: the assignment's value is a Future, which
    // setState refuses.
    setState(() {
      _document = _load();
    });
  }

  Future<void> _openExternally() async {
    final open = widget.onOpenExternally;
    if (open != null) return open(widget.url);
    try {
      await launchUrl(widget.url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('⚠️ [BROWSER] Opening Safari failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final canPop = Navigator.maybeOf(context)?.canPop() ?? false;
    final safari = context.tr('setp_browser_open_safari');
    final toolbar = GlassToolbar(
      leading: canPop
          ? GlassIconButton(
              icon: const AvoIcon(AvoIcons.chevronBack),
              semanticLabel: widget.backLabel ?? context.tr('back'),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      title: widget.title,
      trailing: [
        GlassIconButton(
          icon: const AvoIcon(AvoIcons.share),
          semanticLabel: safari,
          onPressed: _openExternally,
        ),
      ],
    );
    final top =
        GlassToolbar.topOffset(context) + AvoSizes.toolbarButton + _kContentTop;
    final bottom = MediaQuery.paddingOf(context).bottom + AvoSpacing.section;

    final content = FutureBuilder<WebDocument>(
      future: _document,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Padding(
            padding: EdgeInsets.only(top: top + AvoSpacing.xxxl),
            child: Semantics(
              label: context.tr('setp_browser_loading'),
              child: const Center(child: CupertinoActivityIndicator()),
            ),
          );
        }
        final Widget body;
        if (snapshot.hasError) {
          body = Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
            child: EmptyState(
              title: context.tr('setp_browser_offline_title'),
              message: context.tr('setp_browser_offline_body'),
              actionLabel: context.tr('retry'),
              onAction: _retry,
            ),
          );
        } else if (snapshot.data?.isEmpty ?? true) {
          body = Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
            child: EmptyState(
              title: context.tr('setp_browser_empty_title'),
              message: context.tr('setp_browser_empty_body'),
              actionLabel: safari,
              onAction: _openExternally,
            ),
          );
        } else {
          body = _DocumentView(document: snapshot.data!);
        }
        return SingleChildScrollView(
          padding: EdgeInsets.only(top: top, bottom: bottom),
          child: body,
        );
      },
    );

    return ColoredBox(
      color: colors.background,
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              container: true,
              sortKey: const OrdinalSortKey(1),
              child: content,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              sortKey: const OrdinalSortKey(0),
              child: Stack(
                children: [
                  const Positioned.fill(child: ScrollEdgeFade()),
                  Padding(
                    padding: EdgeInsets.only(
                      top: GlassToolbar.topOffset(context),
                      bottom: AvoSpacing.s,
                    ),
                    child: toolbar,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The blocks of a page in the Avo type scale.
class _DocumentView extends StatelessWidget {
  const _DocumentView({required this.document});

  final WebDocument document;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final children = <Widget>[];
    for (var i = 0; i < document.blocks.length; i++) {
      final block = document.blocks[i];
      final heading =
          block.kind == WebBlockKind.title ||
          block.kind == WebBlockKind.heading ||
          block.kind == WebBlockKind.subheading;
      if (i > 0) {
        children.add(
          SizedBox(height: heading ? _kHeadingGap + _kBlockGap : _kBlockGap),
        );
      }
      final style = switch (block.kind) {
        WebBlockKind.title => context.text(AvoTextStyle.title1),
        WebBlockKind.heading => context.text(AvoTextStyle.title3),
        WebBlockKind.subheading => context.text(AvoTextStyle.headline),
        WebBlockKind.paragraph ||
        WebBlockKind.listItem => context.text(AvoTextStyle.body),
      };
      Widget text = Text(block.text, style: style);
      if (heading) text = Semantics(header: true, child: text);
      if (block.kind == WebBlockKind.listItem) {
        text = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _kBulletIndent,
              child: ExcludeSemantics(
                child: Text(
                  '•',
                  style: context.text(
                    AvoTextStyle.body,
                    color: colors.secondaryLabel,
                  ),
                ),
              ),
            ),
            Expanded(child: text),
          ],
        );
      }
      children.add(text);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}
