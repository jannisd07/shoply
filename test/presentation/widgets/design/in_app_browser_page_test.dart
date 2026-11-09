import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/in_app_browser_page.dart';

import '../../../layout/layout_matrix.dart';

class _Loader implements WebDocumentLoader {
  _Loader({this.document, this.fail = false});

  WebDocument? document;
  bool fail;
  int loads = 0;

  @override
  Future<WebDocument> load(Uri url) async {
    loads++;
    if (fail) throw Exception('offline');
    return document ?? const WebDocument(blocks: []);
  }
}

const _privacy = WebDocument(
  blocks: [
    WebBlock(WebBlockKind.title, 'Datenschutzerklärung'),
    WebBlock(
      WebBlockKind.paragraph,
      'Wir verarbeiten nur die Daten, die für deine Listen nötig sind.',
    ),
    WebBlock(WebBlockKind.heading, '1. Welche Daten wir speichern'),
    WebBlock(WebBlockKind.listItem, 'Deine Listen und Artikel'),
    WebBlock(WebBlockKind.listItem, 'Rezepte, die du speicherst'),
    WebBlock(WebBlockKind.subheading, 'Speicherdauer'),
    WebBlock(
      WebBlockKind.paragraph,
      'Solange dein Konto besteht. Löschst du es, ist alles weg.',
    ),
  ],
);

Finder _glass(String label) => find.byWidgetPredicate(
  (w) => w is GlassIconButton && w.semanticLabel == label,
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await loadLayoutFonts();
  tester.view.physicalSize = const Size(390 * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    layoutHarness(const LayoutCase(width: 390, scale: 1), child),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('parseWebDocument', () {
    test('keeps headings, paragraphs and list items of <main>', () {
      final doc = parseWebDocument('''
<html><head><title>x</title><style>p{}</style></head><body>
<header><h1>Shoply</h1><nav><a>Home</a></nav></header>
<main>
  <h1>Privacy   Policy</h1>
  <p>We keep <b>only</b> what you need.</p>
  <h2>1. Data</h2>
  <ul><li>Lists</li><li>Recipes</li></ul>
  <h3>Storage</h3>
  <script>var a = 1;</script>
  <p>  </p>
  <form><p>Sign up</p></form>
</main>
<footer><p>© 2026</p></footer>
</body></html>''');
      expect(doc.blocks, const [
        WebBlock(WebBlockKind.title, 'Privacy Policy'),
        WebBlock(WebBlockKind.paragraph, 'We keep only what you need.'),
        WebBlock(WebBlockKind.heading, '1. Data'),
        WebBlock(WebBlockKind.listItem, 'Lists'),
        WebBlock(WebBlockKind.listItem, 'Recipes'),
        WebBlock(WebBlockKind.subheading, 'Storage'),
      ]);
    });

    test('falls back to <body> and skips navigation', () {
      final doc = parseWebDocument(
        '<body><nav><p>Menu</p></nav><div><p>Impressum</p></div></body>',
      );
      expect(doc.blocks, const [WebBlock(WebBlockKind.paragraph, 'Impressum')]);
    });

    test('a page without text is empty', () {
      expect(parseWebDocument('<html><body></body></html>').isEmpty, isTrue);
    });
  });

  layoutMatrix(
    'InAppBrowserPage with a page',
    (_) => InAppBrowserPage(
      title: 'Datenschutz',
      url: Uri.parse('https://joinavo.app/privacy'),
      loader: _Loader(document: _privacy),
      onOpenExternally: (_) async {},
    ),
  );

  layoutMatrix(
    'InAppBrowserPage offline',
    (_) => InAppBrowserPage(
      title: 'Nutzungsbedingungen',
      url: Uri.parse('https://joinavo.app/terms'),
      loader: _Loader(fail: true),
      onOpenExternally: (_) async {},
    ),
  );

  testWidgets('shows the page under the inline title', (tester) async {
    await _pump(
      tester,
      InAppBrowserPage(
        title: 'Datenschutz',
        url: Uri.parse('https://joinavo.app/privacy'),
        loader: _Loader(document: _privacy),
        onOpenExternally: (_) async {},
      ),
    );
    expect(find.text('Datenschutz'), findsOneWidget);
    expect(find.text('Datenschutzerklärung'), findsOneWidget);
    expect(find.text('Deine Listen und Artikel'), findsOneWidget);
    expect(find.text('•'), findsNWidgets(2));
  });

  testWidgets('"In Safari öffnen" hands the address to Safari', (tester) async {
    final opened = <Uri>[];
    await _pump(
      tester,
      InAppBrowserPage(
        title: 'Impressum',
        url: Uri.parse('https://joinavo.app/impressum'),
        loader: _Loader(document: _privacy),
        onOpenExternally: (u) async => opened.add(u),
      ),
    );
    await tester.tap(_glass('Open in Safari'));
    expect(opened, [Uri.parse('https://joinavo.app/impressum')]);
  });

  testWidgets('offline: "Needs a connection." and retry loads again', (
    tester,
  ) async {
    final loader = _Loader(fail: true);
    await _pump(
      tester,
      InAppBrowserPage(
        title: 'Datenschutz',
        url: Uri.parse('https://joinavo.app/privacy'),
        loader: loader,
        onOpenExternally: (_) async {},
      ),
    );
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Needs a connection.'), findsOneWidget);

    loader
      ..fail = false
      ..document = _privacy;
    await tester.tap(find.text('Retry'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(loader.loads, 2);
    expect(find.text('Datenschutzerklärung'), findsOneWidget);
  });

  testWidgets('a page without readable text offers Safari', (tester) async {
    final opened = <Uri>[];
    await _pump(
      tester,
      InAppBrowserPage(
        title: 'Anleitung',
        url: Uri.parse('https://shoplyai.app/guide'),
        loader: _Loader(),
        onOpenExternally: (u) async => opened.add(u),
      ),
    );
    expect(find.text('This page can\'t be shown here.'), findsOneWidget);
    await tester.tap(find.text('Open in Safari').last);
    expect(opened, hasLength(1));
  });

  testWidgets('pushed: a glass back button pops the page', (tester) async {
    await _pump(
      tester,
      Builder(
        builder: (context) => CupertinoButton(
          onPressed: () => Navigator.of(context).push(
            CupertinoPageRoute<void>(
              builder: (_) => InAppBrowserPage(
                title: 'Datenschutz',
                url: Uri.parse('https://joinavo.app/privacy'),
                loader: _Loader(document: _privacy),
                onOpenExternally: (_) async {},
                backLabel: 'Back to Legal',
              ),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Datenschutzerklärung'), findsOneWidget);
    await tester.tap(_glass('Back to Legal'));
    await tester.pumpAndSettle();
    expect(find.text('Datenschutzerklärung'), findsNothing);
  });
}
