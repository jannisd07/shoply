// B4: article images. Order: own illustration, Open Food Facts photo (only
// with a barcode, white background, credited), category symbol, neutral
// square. Nothing at all from AX1 on or with "Artikelbilder anzeigen" off.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/utils/product_name_normalizer.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/article_image_resolver.dart';
import 'package:shoply/data/services/open_food_facts_service.dart';
import 'package:shoply/presentation/providers/article_image_settings_provider.dart';
import 'package:shoply/core/services/shared_preferences_provider.dart';
import 'package:shoply/presentation/widgets/article_image.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

void main() {
  ShoppingItemModel itemOf(
    String name, {
    String? barcode,
    String? categoryId,
    String? category,
  }) => ShoppingItemModel(
    id: 'item-$name',
    listId: 'list-1',
    name: name,
    barcode: barcode,
    categoryId: categoryId,
    category: category,
    createdAt: DateTime(2026, 11, 8),
    updatedAt: DateTime(2026, 11, 8),
  );

  const barcode = '4000417025005';
  const photo = OffProductPhoto(
    barcode: barcode,
    smallUrl: 'https://images.openfoodfacts.org/images/products/small.jpg',
    displayUrl: 'https://images.openfoodfacts.org/images/products/display.jpg',
  );
  const resolver = ArticleImageResolver(illustrations: {'milch': 'milk'});

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ArticleImageResolver', () {
    test('illustration first, then photo, category symbol, neutral', () {
      final all = resolver.candidatesFor(
        itemOf('Milch', barcode: barcode, categoryId: 'dairy'),
      );
      expect(all, const [
        IllustrationImage('milk'),
        OffPhotoImage(barcode),
        CategorySymbolImage('dairy'),
        NeutralImage(),
      ]);

      expect(
        resolver.candidatesFor(
          itemOf('Hafermilch Barista', barcode: barcode, categoryId: 'dairy'),
        ),
        const [
          OffPhotoImage(barcode),
          CategorySymbolImage('dairy'),
          NeutralImage(),
        ],
      );
      expect(resolver.candidatesFor(itemOf('Zahnseide')), const [
        NeutralImage(),
      ]);
    });

    test('a photo needs a real barcode', () {
      for (final code in ['', 'abc', '123', '40004170250051234']) {
        expect(resolver.candidatesFor(itemOf('Kekse', barcode: code)), const [
          NeutralImage(),
        ], reason: code);
      }
      expect(
        resolver.candidatesFor(itemOf('Kekse', barcode: '96385074')).first,
        const OffPhotoImage('96385074'),
      );
    });

    test('legacy category names and own categories', () {
      expect(
        resolver.candidatesFor(itemOf('Käse', category: 'Milchprodukte')),
        const [CategorySymbolImage('dairy'), NeutralImage()],
      );
      expect(
        resolver.candidatesFor(itemOf('Schrauben', category: 'Baumarkt')),
        const [
          CategorySymbolImage(ArticleImageResolver.customCategory),
          NeutralImage(),
        ],
      );
    });

    test('illustration keys match the normalized name, without numbers, '
        'else its last word', () {
      expect(resolver.illustrationKeyFor('Milch'), 'milk');
      expect(resolver.illustrationKeyFor('  MILCH '), 'milk');
      expect(resolver.illustrationKeyFor('Milch 1,5 %'), 'milk');
      expect(resolver.illustrationKeyFor('Frische Milch'), 'milk');
      expect(resolver.illustrationKeyFor('Milchreis'), isNull);
      expect(resolver.illustrationKeyFor('Milch Schokolade'), isNull);
      expect(
        const ArticleImageResolver(
          illustrations: {'gruene bohnen': 'green_beans'},
        ).illustrationKeyFor('Grüne Bohnen'),
        'green_beans',
      );
    });

    test('the shipped map uses normalized names and existing assets', () {
      for (final MapEntry(:key, :value) in articleIllustrationKeys.entries) {
        expect(normalizeProductName(key), key);
        expect(
          File('assets/illustrations/$value.webp').existsSync(),
          isTrue,
          reason: 'assets/illustrations/$value.webp',
        );
      }
      if (articleIllustrationKeys.isNotEmpty) {
        expect(
          File('pubspec.yaml').readAsStringSync(),
          contains('assets/illustrations/'),
        );
      }
    });
  });

  group('ArticleImage', () {
    testWidgets('shows the illustration from the asset folder', (tester) async {
      await _pump(
        tester,
        ArticleImage(item: itemOf('Milch', barcode: barcode)),
        overrides: [
          ..._photoOverrides(photo),
          articleImageResolverProvider.overrideWithValue(resolver),
        ],
      );
      expect(_assetImage('assets/illustrations/milk.webp'), findsOneWidget);
    });

    testWidgets('a missing illustration falls back to the photo', (
      tester,
    ) async {
      await _pump(
        tester,
        ArticleImage(item: itemOf('Milch', barcode: barcode)),
        overrides: [
          ..._photoOverrides(photo),
          articleImageResolverProvider.overrideWithValue(
            const ArticleImageResolver(
              illustrations: {'milch': 'gibt_es_nicht'},
            ),
          ),
        ],
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(
        find.byWidgetPredicate((w) => w is Image && w.image is _UrlImage),
        findsOneWidget,
      );
    });

    testWidgets('keeps a neutral square of its size while the photo loads', (
      tester,
    ) async {
      final pending = Completer<OffProductPhoto?>();
      await _pump(
        tester,
        ArticleImage(item: itemOf('Weidemilch', barcode: barcode), size: 52),
        overrides: [
          offPhotoLookupProvider.overrideWithValue((_) => pending.future),
          articleNetworkImageProvider.overrideWithValue(_UrlImage.new),
        ],
      );
      expect(find.byType(Image), findsNothing);
      expect(tester.getSize(find.byType(ArticleImage)), const Size.square(52));
      expect(_neutralSquare(tester), findsOneWidget);

      pending.complete(photo);
      await tester.pump();
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('a rate-limited photo stays neutral and loads once a slot '
        'is free', (tester) async {
      var calls = 0;
      await _pump(
        tester,
        ArticleImage(item: itemOf('Weidemilch', barcode: barcode)),
        overrides: [
          offPhotoLookupProvider.overrideWithValue((_) async {
            calls++;
            if (calls == 1) {
              throw const OffRateLimited(Duration(seconds: 20));
            }
            return photo;
          }),
          articleNetworkImageProvider.overrideWithValue(_UrlImage.new),
        ],
      );
      expect(find.byType(Image), findsNothing);
      expect(_neutralSquare(tester), findsOneWidget);
      expect(calls, 1);

      await tester.pump(const Duration(seconds: 19));
      expect(calls, 1);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(calls, 2);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('shows the Open Food Facts photo on white, not cropped', (
      tester,
    ) async {
      await _pump(
        tester,
        ArticleImage(item: itemOf('Weidemilch', barcode: barcode)),
        overrides: _photoOverrides(photo),
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.contain);
      expect((image.image as _UrlImage).url, photo.smallUrl);
      expect(offPhotoBackground, const Color(0xFFFFFFFF));
      expect(
        find.descendant(
          of: find.byType(ArticleImage),
          matching: find.byWidgetPredicate(
            (w) => w is ColoredBox && w.color == offPhotoBackground,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('uses the larger photo at 88 pt', (tester) async {
      await _pump(
        tester,
        ArticleImage(
          item: itemOf('Weidemilch', barcode: barcode),
          size: 88,
          radius: 20,
        ),
        overrides: _photoOverrides(photo),
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as _UrlImage).url, photo.displayUrl);
      final clip = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byType(ArticleImage),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(clip.borderRadius, BorderRadius.circular(20));
      expect(tester.getSize(find.byType(ArticleImage)), const Size.square(88));
    });

    testWidgets('without a photo it falls back to the category symbol', (
      tester,
    ) async {
      await _pump(
        tester,
        ArticleImage(
          item: itemOf('Joghurt', barcode: barcode, categoryId: 'dairy'),
        ),
        overrides: [
          ..._photoOverrides(null),
          articleCategorySymbolsProvider.overrideWithValue(const {
            'dairy': AvoIcons.heart,
          }),
        ],
      );
      expect(find.byType(Image), findsNothing);
      expect(tester.widget<AvoIcon>(find.byType(AvoIcon)).icon, AvoIcons.heart);
    });

    testWidgets('without any picture it keeps a neutral square of its size', (
      tester,
    ) async {
      await _pump(
        tester,
        ArticleImage(
          item: itemOf('Joghurt', categoryId: 'dairy'),
          size: 52,
          radius: 12,
        ),
      );
      expect(find.byType(Image), findsNothing);
      expect(find.byType(AvoIcon), findsNothing);
      expect(tester.getSize(find.byType(ArticleImage)), const Size.square(52));
    });

    testWidgets('is decorative for VoiceOver', (tester) async {
      final semantics = tester.ensureSemantics();
      const row = Key('row');
      await _pump(
        tester,
        Semantics(
          key: row,
          container: true,
          label: 'Weidemilch',
          child: ArticleImage(item: itemOf('Weidemilch', barcode: barcode)),
        ),
        overrides: _photoOverrides(photo),
      );
      expect(find.byType(Image), findsOneWidget);
      final node = tester.getSemantics(find.byKey(row));
      expect(node.label, 'Weidemilch');
      expect(node.childrenCount, 0);
      semantics.dispose();
    });

    testWidgets('renders nothing from AX1 on', (tester) async {
      final item = itemOf('Weidemilch', barcode: barcode);
      await _pump(
        tester,
        ArticleImage(item: item),
        overrides: _photoOverrides(photo),
        textScale: 28 / 17,
      );
      expect(tester.getSize(find.byType(ArticleImage)), Size.zero);
      expect(find.byType(Image), findsNothing);

      await _pump(
        tester,
        ArticleImage(item: item),
        overrides: _photoOverrides(photo),
        textScale: 23 / 17,
      );
      expect(tester.getSize(find.byType(ArticleImage)), const Size.square(44));
    });

    testWidgets('renders nothing with "show article images" off', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        showArticleImagesPrefsKey: false,
      });
      final item = itemOf('Weidemilch', barcode: barcode);
      await _pump(
        tester,
        Column(
          children: [
            ArticleImage(item: item),
            ArticleImageCredit(item: item),
          ],
        ),
        overrides: _photoOverrides(photo),
      );
      expect(tester.getSize(find.byType(ArticleImage)), Size.zero);
      expect(find.byType(OffPhotoCredit), findsNothing);
    });

    testWidgets('with the setting off the first frame is empty and asks '
        'Open Food Facts nothing', (tester) async {
      SharedPreferences.setMockInitialValues({
        showArticleImagesPrefsKey: false,
      });
      // main() hands the preloaded instance over the same way.
      final prefs = await SharedPreferences.getInstance();
      var lookups = 0;
      final item = itemOf('Weidemilch', barcode: barcode);
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              ArticleImage(item: item),
              ArticleImageCredit(item: item),
            ],
          ),
          overrides: [
            sharedPreferencesProvider.overrideWith((ref) => prefs),
            offPhotoLookupProvider.overrideWithValue((_) async {
              lookups++;
              return photo;
            }),
            articleNetworkImageProvider.overrideWithValue(_UrlImage.new),
          ],
        ),
      );
      expect(tester.getSize(find.byType(ArticleImage)), Size.zero);
      expect(lookups, 0);
      await tester.pump();
      expect(tester.getSize(find.byType(ArticleImage)), Size.zero);
      expect(lookups, 0);
    });

    testWidgets('shows nothing and asks nothing until the setting is read', (
      tester,
    ) async {
      var lookups = 0;
      await tester.pumpWidget(
        _app(
          ArticleImage(item: itemOf('Weidemilch', barcode: barcode)),
          overrides: [
            offPhotoLookupProvider.overrideWithValue((_) async {
              lookups++;
              return photo;
            }),
            articleNetworkImageProvider.overrideWithValue(_UrlImage.new),
          ],
        ),
      );
      expect(tester.getSize(find.byType(ArticleImage)), Size.zero);
      expect(lookups, 0);

      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(tester.getSize(find.byType(ArticleImage)), const Size.square(44));
      expect(lookups, 1);
    });
  });

  group('photo credit', () {
    testWidgets('appears with an Open Food Facts photo and opens its page', (
      tester,
    ) async {
      final opened = <Uri>[];
      await _pump(
        tester,
        ArticleImageCredit(item: itemOf('Weidemilch', barcode: barcode)),
        overrides: [
          ..._photoOverrides(photo),
          offLinkOpenerProvider.overrideWithValue(
            (uri) async => opened.add(uri),
          ),
        ],
      );
      expect(find.text('Photo: Open Food Facts, CC BY-SA'), findsOneWidget);
      expect(
        tester.getSize(find.byType(OffPhotoCredit)).height,
        greaterThanOrEqualTo(44),
      );
      await tester.tap(find.byType(OffPhotoCredit));
      expect(opened, [
        Uri.parse('https://world.openfoodfacts.org/product/$barcode'),
      ]);
    });

    testWidgets('VoiceOver and Switch Control can open the product page', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final opened = <Uri>[];
      await _pump(
        tester,
        ArticleImageCredit(item: itemOf('Weidemilch', barcode: barcode)),
        overrides: [
          ..._photoOverrides(photo),
          offLinkOpenerProvider.overrideWithValue(
            (uri) async => opened.add(uri),
          ),
        ],
      );
      expect(
        tester.getSemantics(find.byType(OffPhotoCredit)),
        isSemantics(
          label: 'Photo: Open Food Facts, CC BY-SA',
          isLink: true,
          hasTapAction: true,
        ),
      );
      tester.semantics.tap(
        find.semantics.byLabel('Photo: Open Food Facts, CC BY-SA'),
      );
      expect(opened, [
        Uri.parse('https://world.openfoodfacts.org/product/$barcode'),
      ]);
      semantics.dispose();
    });

    testWidgets('compact is plain text, a tap on it picks the row', (
      tester,
    ) async {
      final opened = <Uri>[];
      var rowTaps = 0;
      await _pump(
        tester,
        InkWell(
          onTap: () => rowTaps++,
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Weidemilch'),
                OffPhotoCredit(barcode: barcode, compact: true),
              ],
            ),
          ),
        ),
        overrides: [
          offLinkOpenerProvider.overrideWithValue(
            (uri) async => opened.add(uri),
          ),
        ],
      );
      expect(find.text('Photo: Open Food Facts, CC BY-SA'), findsOneWidget);
      await tester.tap(find.byType(OffPhotoCredit));
      expect(rowTaps, 1);
      expect(opened, isEmpty);
    });

    testWidgets('disappears with the photo when the photo fails to load', (
      tester,
    ) async {
      final item = itemOf('Weidemilch', barcode: barcode);
      await _pump(
        tester,
        Column(
          children: [
            ArticleImage(item: item, size: 88, radius: 20),
            ArticleImageCredit(item: item),
          ],
        ),
        overrides: [
          offProductPhotoProvider.overrideWith((ref, code) async => photo),
          articleNetworkImageProvider.overrideWithValue(
            (_) => const _BrokenImage(),
          ),
        ],
      );
      await tester.pump();
      expect(_neutralSquare(tester), findsOneWidget);
      expect(find.text('Photo: Open Food Facts, CC BY-SA'), findsNothing);
    });

    testWidgets('a credit tied to a photo shows only while it is not broken', (
      tester,
    ) async {
      await _pump(
        tester,
        Column(
          children: [
            OffPhotoCredit(
              barcode: barcode,
              compact: true,
              photo: _UrlImage(photo.smallUrl),
            ),
            const OffPhotoCredit(
              barcode: '96385074',
              compact: true,
              photo: _BrokenImage(),
            ),
          ],
        ),
      );
      await tester.pump();
      expect(find.text('Photo: Open Food Facts, CC BY-SA'), findsOneWidget);
    });

    testWidgets('is German in German', (tester) async {
      await _pump(
        tester,
        ArticleImageCredit(item: itemOf('Weidemilch', barcode: barcode)),
        overrides: _photoOverrides(photo),
        locale: const Locale('de'),
      );
      expect(find.text('Foto: Open Food Facts, CC BY-SA'), findsOneWidget);
    });

    testWidgets('is absent without a photo or with an illustration', (
      tester,
    ) async {
      await _pump(
        tester,
        Column(
          children: [
            ArticleImageCredit(item: itemOf('Weidemilch')),
            ArticleImageCredit(item: itemOf('Milch', barcode: barcode)),
          ],
        ),
        overrides: [
          ..._photoOverrides(photo),
          articleImageResolverProvider.overrideWithValue(resolver),
        ],
      );
      expect(find.byType(OffPhotoCredit), findsNothing);

      await _pump(
        tester,
        ArticleImageCredit(item: itemOf('Weidemilch', barcode: barcode)),
        overrides: _photoOverrides(null),
      );
      expect(find.byType(OffPhotoCredit), findsNothing);
    });
  });

  group('showArticleImagesProvider', () {
    Future<ProviderContainer> preloaded() async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => prefs),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('is on by default and saves a change on the device', () async {
      final container = await preloaded();
      expect(container.read(showArticleImagesProvider), isTrue);

      await container.read(showArticleImagesProvider.notifier).set(false);
      expect(container.read(showArticleImagesProvider), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(showArticleImagesPrefsKey), isFalse);
    });

    test('knows the saved choice at once when prefs are preloaded', () async {
      SharedPreferences.setMockInitialValues({
        showArticleImagesPrefsKey: false,
      });
      final container = await preloaded();
      expect(container.read(showArticleImagesProvider), isFalse);
    });

    test('is unknown (null) until SharedPreferences is read', () async {
      SharedPreferences.setMockInitialValues({
        showArticleImagesPrefsKey: false,
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(showArticleImagesProvider), isNull);
      await container.read(sharedPreferencesProvider.future);
      expect(container.read(showArticleImagesProvider), isFalse);
    });
  });
}

List<Override> _photoOverrides(OffProductPhoto? photo) => [
  offProductPhotoProvider.overrideWith((ref, code) async => photo),
  articleNetworkImageProvider.overrideWithValue(_UrlImage.new),
];

Finder _assetImage(String path) => find.byWidgetPredicate(
  (w) =>
      w is Image &&
      w.image is AssetImage &&
      (w.image as AssetImage).assetName == path,
);

Finder _neutralSquare(WidgetTester tester) {
  final fill = AvoColors.light.fill;
  return find.descendant(
    of: find.byType(ArticleImage),
    matching: find.byWidgetPredicate((w) => w is ColoredBox && w.color == fill),
  );
}

Widget _app(
  Widget child, {
  List<Override> overrides = const [],
  double textScale = 1,
  Locale locale = const Locale('en'),
}) => ProviderScope(
  key: UniqueKey(),
  overrides: overrides,
  child: MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('de')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: app!,
    ),
    home: Scaffold(body: Center(child: child)),
  ),
);

/// Pumps [child] with SharedPreferences preloaded, as `main()` does.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  double textScale = 1,
  Locale locale = const Locale('en'),
}) async {
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    _app(
      child,
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => prefs),
        ...overrides,
      ],
      textScale: textScale,
      locale: locale,
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// A network image that never loads (offline, deleted on the server).
class _BrokenImage extends ImageProvider<_BrokenImage> {
  const _BrokenImage();

  @override
  Future<_BrokenImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _BrokenImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(
    Future<ImageInfo>.error(const SocketException('offline')),
  );
}

/// A network image stand-in that remembers its URL and paints a 1×1 pixel.
class _UrlImage extends MemoryImage {
  _UrlImage(this.url) : super(_pixel);

  final String url;

  static final Uint8List _pixel = Uint8List.fromList(const [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0A,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0x00,
    0x01,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0x0D,
    0x0A,
    0x2D,
    0xB4,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ]);
}
