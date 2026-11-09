import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/article_image_resolver.dart';
import 'package:shoply/data/services/open_food_facts_service.dart';
import 'package:shoply/presentation/providers/article_image_settings_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

/// Category symbols drawn when an item has no illustration or photo, by
/// category ID (`categories.dart`) or [ArticleImageResolver.customCategory].
///
/// Empty on purpose: the owner's table asks for carrot, cake, fish, basket,
/// popcorn, bottle, bubbles, drop, snowflake, bag and tag, and none of the
/// D2 icons in `avo_icons.dart` shows a category (fork and knife and the
/// cart are tab icons, the tag means "offer"). Until Teil A adds those
/// glyphs, items fall back to the neutral square.
const Map<String, AvoIconData> articleCategorySymbols = {};

/// Behind an Open Food Facts photo: white in light and dark mode, as the
/// product shots are taken on white. `AvoColors` has no colour that stays
/// white in dark mode (`surface` turns dark); this literal goes once Teil A
/// adds one.
const Color offPhotoBackground = Color(0xFFFFFFFF); // D2 white behind photos

/// Which pictures an item can have; overridden in tests.
final articleImageResolverProvider = Provider<ArticleImageResolver>(
  (ref) => const ArticleImageResolver(),
);

/// The category symbols in use; overridden in tests.
final articleCategorySymbolsProvider = Provider<Map<String, AvoIconData>>(
  (ref) => articleCategorySymbols,
);

/// Looks up the Open Food Facts front photo of a barcode; overridden in
/// tests.
final offPhotoLookupProvider =
    Provider<Future<OffProductPhoto?> Function(String)>(
      (ref) => OpenFoodFactsService.instance.productPhoto,
    );

/// The Open Food Facts front photo of a barcode (cached, rate limited).
///
/// When the lookup is skipped at the rate limit it stays loading (the
/// neutral square) and asks again once a slot is free, as long as the
/// image is on screen.
final offProductPhotoProvider = FutureProvider.autoDispose
    .family<OffProductPhoto?, String>((ref, barcode) async {
      var disposed = false;
      Timer? retry;
      ref.onDispose(() {
        disposed = true;
        retry?.cancel();
      });
      try {
        return await ref.watch(offPhotoLookupProvider)(barcode);
      } on OffRateLimited catch (e) {
        if (!disposed) retry = Timer(e.retryAfter, ref.invalidateSelf);
        // Never completes: the retry above replaces this future.
        return Completer<OffProductPhoto?>().future;
      }
    });

/// Loads a photo URL; cached on disk, so scrolling a list asks once.
final articleNetworkImageProvider = Provider<ImageProvider Function(String)>(
  (ref) => CachedNetworkImageProvider.new,
);

/// Opens the Open Food Facts product page of a photo credit.
final offLinkOpenerProvider = Provider<Future<void> Function(Uri)>(
  (ref) => _openExternally,
);

Future<void> _openExternally(Uri uri) async {
  try {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('⚠️ [ARTICLE_IMAGES] Could not open $uri');
    }
  } catch (e) {
    debugPrint('❌ [ARTICLE_IMAGES] Opening $uri failed: $e');
  }
}

/// Whether article images show at all: the setting "Artikelbilder
/// anzeigen" is known and on, and the text size is below AX1.
///
/// AX1 is the content size category of `AvoTypography` (body text nearest
/// to 28 pt rather than 23 pt), i.e. a Flutter text scale of about 1.5 and
/// up. Hosts use this to drop the gap next to the image as well, since
/// [ArticleImage] then renders `SizedBox.shrink()`.
bool articleImagesShown(BuildContext context, WidgetRef ref) =>
    ref.watch(showArticleImagesProvider) == true &&
    !context.isAccessibilityText;

/// Picture of an item, [size] points square with corner [radius] (contract
/// `b_slots.dart`; D2: 44/10 row, 52/12 tile, 88/20 article detail).
///
/// Shows the first available of: own illustration
/// (`assets/illustrations/<key>.webp`), the Open Food Facts photo of the
/// item's barcode (white background, not cut out; place
/// [ArticleImageCredit] near it, at least in the article detail), the
/// category symbol, a neutral square in `fill`. While a photo loads the
/// square stays neutral, so hosts lay out with the final size.
///
/// From AX1 on and with "Artikelbilder anzeigen" off it renders
/// `SizedBox.shrink()` (see [articleImagesShown]). Decorative: hidden from
/// VoiceOver, the row carries the name.
class ArticleImage extends ConsumerWidget {
  const ArticleImage({
    super.key,
    required this.item,
    this.size = 44,
    this.radius = 10,
  });

  final ShoppingItemModel item;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!articleImagesShown(context, ref)) return const SizedBox.shrink();
    final candidates = ref
        .watch(articleImageResolverProvider)
        .candidatesFor(item);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: _ArticlePicture(candidates: candidates, size: size),
        ),
      ),
    );
  }
}

/// Shows `candidates.first`, or the rest of the list when it is not
/// available (asset missing, no photo, no symbol, load error).
class _ArticlePicture extends ConsumerWidget {
  const _ArticlePicture({required this.candidates, required this.size});

  final List<ArticleImageSource> candidates;
  final double size;

  Widget get _next =>
      _ArticlePicture(candidates: candidates.sublist(1), size: size);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final neutral = ColoredBox(
      color: colors.fill,
      child: SizedBox.square(dimension: size),
    );
    switch (candidates.first) {
      case IllustrationImage(:final assetPath):
        return ColoredBox(
          color: colors.fill,
          child: Image.asset(
            assetPath,
            width: size,
            height: size,
            // Our own square pictures fill the tile like the D2 artboards.
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => _next,
          ),
        );
      case OffPhotoImage(:final barcode):
        return ref
            .watch(offProductPhotoProvider(barcode))
            .when(
              loading: () => neutral,
              error: (_, _) => _next,
              data: (photo) {
                if (photo == null) return _next;
                final image = ref.watch(articleNetworkImageProvider);
                // White, uncropped and unedited: a cut-out would be an
                // adaptation under CC BY-SA.
                return ColoredBox(
                  color: offPhotoBackground,
                  child: Image(
                    image: image(photo.urlFor(size)),
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => _next,
                  ),
                );
              },
            );
      case CategorySymbolImage(:final categoryId):
        final icon = ref.watch(articleCategorySymbolsProvider)[categoryId];
        if (icon == null) return _next;
        return ColoredBox(
          color: colors.fill,
          child: SizedBox.square(
            dimension: size,
            child: Center(
              child: AvoIcon(
                icon,
                size: size * 0.5,
                color: colors.secondaryLabel,
              ),
            ),
          ),
        );
      case NeutralImage():
        return neutral;
    }
  }
}

/// The credit "Foto: Open Food Facts, CC BY-SA" for the photo the
/// [ArticleImage] of [item] at [size] shows, linking to the product page;
/// nothing when it shows no Open Food Facts photo or the photo failed to
/// load. Teil A places it as a footnote under the 88 pt image of the article
/// detail; pass the image's [size] when it is another one (the credit
/// follows that exact photo).
class ArticleImageCredit extends ConsumerWidget {
  const ArticleImageCredit({super.key, required this.item, this.size = 88});

  final ShoppingItemModel item;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!articleImagesShown(context, ref)) return const SizedBox.shrink();
    final first = ref
        .watch(articleImageResolverProvider)
        .candidatesFor(item)
        .first;
    if (first is! OffPhotoImage) return const SizedBox.shrink();
    final photo = ref.watch(offProductPhotoProvider(first.barcode)).valueOrNull;
    if (photo == null) return const SizedBox.shrink();
    final image = ref.watch(articleNetworkImageProvider);
    return OffPhotoCredit(
      barcode: photo.barcode,
      photo: image(photo.urlFor(size)),
    );
  }
}

/// The credit line for an Open Food Facts photo of [barcode]: a link to its
/// product page with a 44 pt touch height.
///
/// [compact] is plain text without its own tap, for dense rows whose tap
/// picks the item (a link there would be a mis-tap trap below 44 pt); the
/// text alone credits the photo, the link lives in the article detail.
///
/// With [photo] (the same image provider the picture next to it uses, so
/// nothing loads twice) the credit disappears when that photo fails to
/// load, as the picture then falls back to a placeholder.
class OffPhotoCredit extends ConsumerStatefulWidget {
  const OffPhotoCredit({
    super.key,
    required this.barcode,
    this.compact = false,
    this.photo,
  });

  final String barcode;
  final bool compact;
  final ImageProvider? photo;

  @override
  ConsumerState<OffPhotoCredit> createState() => _OffPhotoCreditState();
}

class _OffPhotoCreditState extends ConsumerState<OffPhotoCredit> {
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(
    (_, _) => _setBroken(false),
    onError: (_, _) => _setBroken(true),
  );
  bool _broken = false;

  void _setBroken(bool broken) {
    if (mounted && broken != _broken) setState(() => _broken = broken);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _follow();
  }

  @override
  void didUpdateWidget(OffPhotoCredit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo != widget.photo) {
      _broken = false;
      _follow();
    }
  }

  /// Listens to [OffPhotoCredit.photo] like an `Image` does (shared through
  /// the image cache).
  void _follow() {
    final stream = widget.photo?.resolve(
      createLocalImageConfiguration(context),
    );
    if (stream?.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream?..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_broken) return const SizedBox.shrink();
    final label = context.tr('sys_off_photo_credit');
    final style = context.text(
      AvoTextStyle.footnote,
      color: context.colors.secondaryLabel,
    );
    if (widget.compact) return Text(label, style: style);
    final page = offProductPageUrl(widget.barcode);
    void open() => ref.read(offLinkOpenerProvider)(page);
    return Semantics(
      link: true,
      linkUrl: page,
      label: label,
      hint: context.tr('sys_off_photo_credit_hint'),
      // The gesture's semantics are excluded, so the node carries the tap.
      onTap: open,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              label,
              style: style.copyWith(decoration: TextDecoration.underline),
            ),
          ),
        ),
      ),
    );
  }
}
