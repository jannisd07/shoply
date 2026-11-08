import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/avatar.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/glass_surface.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';
import 'package:shoply/presentation/widgets/design/list_card.dart';
import 'package:shoply/presentation/widgets/design/progress.dart';

import '../../../layout/layout_matrix.dart';

const _meta = '12 Artikel · 4 offen · vor 2 Std.';
const _longTitle = 'Wocheneinkauf für die ganze WG mit Grillabend am Samstag';

/// Stand-in for Teil B's `ListOfferCountBadge` (D2-Home: pseudo glass,
/// 11/13 semibold tint).
class _OfferCount extends StatelessWidget {
  const _OfferCount();

  @override
  Widget build(BuildContext context) => Semantics(
    label: '2 Artikel im Angebot',
    child: ExcludeSemantics(
      child: ContentGlass(
        radius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '2 Angebote',
          style: context.text(
            AvoTextStyle.caption2,
            weight: FontWeight.w600,
            color: context.colors.tint,
          ),
        ),
      ),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  LayoutCase layout = const LayoutCase(width: 390, scale: 1),
  bool scroll = false,
}) async {
  await loadLayoutFonts();
  tester.view.physicalSize = Size(layout.width * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final padded = Padding(
    padding: const EdgeInsets.all(AvoSpacing.screen),
    child: child,
  );
  await tester.pumpWidget(
    layoutHarness(
      layout,
      scroll
          ? SingleChildScrollView(child: padded)
          : Align(alignment: Alignment.topCenter, child: padded),
    ),
  );
}

/// The scale of the press transform inside [of].
double _scale(WidgetTester tester, Finder of) {
  final transform = tester.widget<Transform>(
    find.descendant(of: of, matching: find.byType(Transform)).first,
  );
  return transform.transform.storage[0];
}

ListCard _card({
  VoidCallback? onTap,
  Widget? badge,
  String title = 'Wocheneinkauf',
}) => ListCard(
  title: title,
  done: 8,
  total: 12,
  meta: _meta,
  color: const Color(0xFF5E5CE6),
  sharedLabel: 'mit Lena',
  sharedName: 'Lena',
  badge: badge,
  onTap: onTap,
);

void main() {
  group('ListCard', () {
    testWidgets('D2: radius 26, surface, shadow, 72 pt cover', (tester) async {
      await _pump(tester, _card(onTap: () {}));
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(ListCard),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = box.decoration as ShapeDecoration;
      expect(decoration.color, AvoColors.light.surface);
      expect(
        (decoration.shape as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(AvoRadii.group),
      );
      final shadows = decoration.shadows!;
      expect(shadows, hasLength(2));
      expect(shadows[0].spreadRadius, 0.5);
      expect(shadows[0].color.a, closeTo(0.07, 0.005));
      expect(shadows[1].offset, const Offset(0, 6));
      expect(shadows[1].blurRadius, 18);
      expect(shadows[1].color.a, closeTo(0.07, 0.005));

      final band = find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == const Color(0xFF5E5CE6),
      );
      expect(tester.getSize(band).height, 72);
      expect(
        tester.getSize(band).width,
        tester.getSize(find.byType(ListCard)).width,
      );
    });

    testWidgets('D2 text: 17/22 semibold, 8/12 13/18 tabular, meta 15/20', (
      tester,
    ) async {
      await _pump(tester, _card());
      final title = tester.widget<Text>(find.text('Wocheneinkauf')).style!;
      expect(title.fontSize, 17);
      expect(title.fontWeight, FontWeight.w600);
      expect(title.color, AvoColors.light.label);
      final counter = tester.widget<Text>(find.text('8/12')).style!;
      expect(counter.fontSize, 13);
      expect(counter.color, AvoColors.light.secondaryLabel);
      expect(
        counter.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      final meta = tester.widget<Text>(find.text(_meta)).style!;
      expect(meta.fontSize, 15);
      expect(meta.color, AvoColors.light.secondaryLabel);
      expect(
        tester.widget<ProgressLine>(find.byType(ProgressLine)).value,
        closeTo(8 / 12, 1e-9),
      );
      // Counter on the title's baseline at the end.
      final t = tester.getRect(find.text('Wocheneinkauf'));
      final c = tester.getRect(find.text('8/12'));
      expect(c.left, greaterThan(t.right));
      final card = tester.getRect(find.byType(ListCard));
      expect(c.right, card.right - 16);
      // D2 padding 12 16 14.
      expect(t.left, card.left + 16);
      expect(t.top, card.top + 72 + 12);
      final line = tester.getRect(find.byType(ProgressLine));
      expect(line.height, 4);
      expect(card.bottom - line.bottom, 14);
    });

    testWidgets('chip: pseudo glass at 10 / 10, 28 high, avatar 20', (
      tester,
    ) async {
      await _pump(tester, _card());
      final glass = find.byType(ContentGlass);
      expect(glass, findsOneWidget);
      expect(tester.widget<ContentGlass>(glass).radius, 14);
      final chip = tester.getRect(glass);
      final card = tester.getRect(find.byType(ListCard));
      expect(chip.height, 28);
      expect(chip.top, card.top + 10);
      expect(chip.right, card.right - 10);
      final avatar = tester.widget<Avatar>(find.byType(Avatar));
      expect(avatar.size, AvatarSize.small);
      expect(tester.getSize(find.byType(Avatar)), const Size(20, 20));
      final label = tester.widget<Text>(find.text('mit Lena')).style!;
      expect(label.fontSize, 12);
      expect(label.fontWeight, FontWeight.w600);
    });

    testWidgets('cover widget fills the band; badge at the top start', (
      tester,
    ) async {
      await _pump(
        tester,
        ListCard(
          title: 'Wocheneinkauf',
          done: 8,
          total: 12,
          cover: const ColoredBox(key: Key('cover'), color: Color(0xFF888888)),
          badge: const _OfferCount(),
          sharedLabel: 'mit Lena',
          sharedName: 'Lena',
        ),
      );
      final card = tester.getRect(find.byType(ListCard));
      final cover = tester.getRect(find.byKey(const Key('cover')));
      expect(cover.height, 72);
      expect(cover.width, card.width);
      final badge = tester.getRect(find.byType(_OfferCount));
      expect(badge.left, card.left + 10);
      expect(badge.top, card.top + 10);
      final chip = tester.getRect(find.byType(ContentGlass).last);
      expect(chip.right, card.right - 10);
    });

    testWidgets('no items: no counter and no progress line', (tester) async {
      await _pump(
        tester,
        const ListCard(title: 'Drogerie', done: 0, total: 0, meta: 'Leer'),
      );
      expect(find.byType(ProgressLine), findsNothing);
      expect(find.text('0/0'), findsNothing);
      // Without colour and cover the band is the neutral fill.
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == AvoColors.light.fill,
        ),
        findsOneWidget,
      );
    });

    testWidgets('tap opens; shrinks while pressed', (tester) async {
      var taps = 0;
      await _pump(tester, _card(onTap: () => taps++));
      final card = find.byType(ListCard);
      final gesture = await tester.startGesture(tester.getCenter(card));
      await tester.pumpAndSettle();
      expect(_scale(tester, card), closeTo(AvoMotion.pressedScale, 0.002));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_scale(tester, card), closeTo(1, 0.002));
      expect(taps, 1);
      await tester.tap(find.text('mit Lena'));
      expect(taps, 2);
    });

    testWidgets('Reduce Motion: no scaling on press', (tester) async {
      await _pump(
        tester,
        _card(onTap: () {}),
        layout: const LayoutCase(width: 390, scale: 1, reduceMotion: true),
      );
      final card = find.byType(ListCard);
      final gesture = await tester.startGesture(tester.getCenter(card));
      await tester.pumpAndSettle();
      expect(_scale(tester, card), 1);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('VoiceOver: one button with the whole summary and badge', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await _pump(
        tester,
        _card(onTap: () => taps++, badge: const _OfferCount()),
      );
      final finder = find.bySemanticsLabel(RegExp('^Wocheneinkauf'));
      expect(finder, findsOneWidget);
      final node = tester.getSemantics(finder);
      expect(
        node.label,
        'Wocheneinkauf, $_meta, 8 of 12, mit Lena\n2 Artikel im Angebot',
      );
      expect(node, isSemantics(isButton: true, hasTapAction: true));
      expect(find.bySemanticsLabel('Lena'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('%')), findsNothing);
      tester.semantics.tap(find.semantics.byLabel(RegExp('^Wocheneinkauf')));
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('from AX1 the counter moves below the title', (tester) async {
      await _pump(
        tester,
        _card(),
        layout: const LayoutCase(width: 390, scale: 2),
        scroll: true,
      );
      final t = tester.getRect(find.text('Wocheneinkauf'));
      final c = tester.getRect(find.text('8/12'));
      expect(c.top, greaterThanOrEqualTo(t.bottom));
      expect(c.left, t.left);
    });

    testWidgets('chips stop growing at AX2, the title does not', (
      tester,
    ) async {
      await _pump(
        tester,
        _card(),
        layout: const LayoutCase(width: 390, scale: 3.1),
        scroll: true,
      );
      final chip = tester.renderObject<RenderParagraph>(find.text('mit Lena'));
      final title = tester.renderObject<RenderParagraph>(
        find.text('Wocheneinkauf'),
      );
      double px(RenderParagraph p, double size) => p.textScaler.scale(size);
      final chipStyle = tester.widget<Text>(find.text('mit Lena')).style!;
      final titleStyle = tester.widget<Text>(find.text('Wocheneinkauf')).style!;
      expect(px(chip, chipStyle.fontSize!), lessThanOrEqualTo(26 + 0.5));
      expect(px(title, titleStyle.fontSize!), closeTo(53, 0.5));
    });

    testWidgets('dark mode', (tester) async {
      await _pump(
        tester,
        _card(),
        layout: const LayoutCase(
          width: 390,
          scale: 1,
          brightness: Brightness.dark,
        ),
      );
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(ListCard),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((box.decoration as ShapeDecoration).color, AvoColors.dark.surface);
      expect(
        tester.widget<Text>(find.text('Wocheneinkauf')).style!.color,
        AvoColors.dark.label,
      );
    });
  });

  group('ListRow', () {
    Widget section(List<Widget> rows) =>
        InsetSection(separatorIndent: ListRow.separatorIndent, children: rows);

    testWidgets('D2: 60 pt, colour square 44 r12, text at 72', (tester) async {
      await _pump(
        tester,
        ListRow(
          title: 'WG Küche',
          meta: '7 offen',
          color: const Color(0xFFFF9F0A),
          glyph: const AvoIcon(AvoIcons.home, filled: true),
          onTap: () {},
        ),
      );
      final row = tester.getRect(find.byType(ListRow));
      expect(row.height, 60);
      final square = find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is ShapeDecoration &&
            (w.decoration as ShapeDecoration).color == const Color(0xFFFF9F0A),
      );
      expect(tester.getSize(square), const Size(44, 44));
      final shape =
          (tester.widget<DecoratedBox>(square).decoration as ShapeDecoration)
                  .shape
              as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(12));
      expect(tester.getRect(square).left, row.left + 16);
      final title = tester.getRect(find.text('WG Küche'));
      expect(title.left - row.left, ListRow.separatorIndent);
      expect(ListRow.separatorIndent, 72);
      final style = tester.widget<Text>(find.text('WG Küche')).style!;
      expect(style.fontSize, 17);
      expect(style.fontWeight, FontWeight.w600);
      final meta = tester.widget<Text>(find.text('7 offen')).style!;
      expect(meta.fontSize, 15);
      expect(meta.color, AvoColors.light.secondaryLabel);
      // Chevron 8 × 14 at the end.
      final chevron = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.size == const Size(8, 14),
      );
      expect(chevron, findsOneWidget);
      expect(tester.getRect(chevron).right, row.right - 16);
    });

    testWidgets('cover 44 r10, counter 15/20 tabular', (tester) async {
      await _pump(
        tester,
        ListRow(
          title: 'Grillabend Samstag',
          meta: 'Alles erledigt',
          complete: true,
          cover: const ItemThumb(),
          done: 9,
          total: 9,
          onTap: () {},
        ),
      );
      expect(tester.getSize(find.byType(ItemThumb)), const Size(44, 44));
      final clip = tester.widget<ClipRRect>(
        find
            .ancestor(
              of: find.byType(ItemThumb),
              matching: find.byType(ClipRRect),
            )
            .first,
      );
      expect(clip.borderRadius, BorderRadius.circular(10));
      final counter = tester.widget<Text>(find.text('9/9')).style!;
      expect(counter.fontSize, 15);
      expect(
        counter.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      // Complete: meta in tint with a check disc before it.
      final meta = tester.widget<Text>(find.text('Alles erledigt')).style!;
      expect(meta.color, AvoColors.light.tint);
      expect(
        find.descendant(
          of: find.byType(ListRow),
          matching: find.byType(AvoIcon),
        ),
        findsOneWidget,
      );
    });

    testWidgets('ring variant: 28 pt ring', (tester) async {
      await _pump(
        tester,
        const ListRow(
          title: 'Wocheneinkauf',
          meta: '4 offen · mit Lena',
          done: 8,
          total: 12,
          progress: ListRowProgress.ring,
        ),
      );
      final ring = tester.widget<ProgressRing>(find.byType(ProgressRing));
      expect(ring.size, 28);
      expect(ring.strokeWidth, 3.5);
      expect(ring.value, closeTo(8 / 12, 1e-9));
      expect(find.text('8/12'), findsNothing);
    });

    testWidgets('accessory before the progress; menu row without chevron', (
      tester,
    ) async {
      await _pump(
        tester,
        const ListRow(
          title: 'WG Küche',
          meta: '7 offen',
          accessory: AvatarStack(names: ['Jannis', 'Lena', 'Mia']),
          done: 2,
          total: 9,
          showChevron: false,
        ),
      );
      final stack = tester.getRect(find.byType(AvatarStack));
      final counter = tester.getRect(find.text('2/9'));
      expect(stack.right, lessThan(counter.left));
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.size == const Size(8, 14),
        ),
        findsNothing,
      );
      final row = tester.getRect(find.byType(ListRow));
      expect(counter.right, row.right - 16);
    });

    testWidgets('tap highlights and opens', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        ListRow(title: 'Drogerie', meta: '3 offen', onTap: () => taps++),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ListRow)),
      );
      await tester.pump();
      final highlight = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(ListRow),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(highlight.color, AvoColors.light.fillStrong);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(
        find.descendant(
          of: find.byType(ListRow),
          matching: find.byType(ColoredBox),
        ),
        findsNothing,
      );
    });

    testWidgets('VoiceOver: one element with progress, avatars and actions', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var shared = 0;
      await _pump(
        tester,
        ListRow(
          title: 'Wocheneinkauf',
          meta: '4 offen · Lidl',
          done: 8,
          total: 12,
          progress: ListRowProgress.ring,
          accessory: const AvatarStack(
            names: ['Lena'],
            semanticLabel: 'geteilt mit Lena',
          ),
          onTap: () {},
          semanticActions: {'Teilen': () => shared++},
        ),
      );
      final finder = find.bySemanticsLabel(RegExp('^Wocheneinkauf'));
      expect(finder, findsOneWidget);
      final node = tester.getSemantics(finder);
      expect(
        node.label,
        'Wocheneinkauf, 4 offen · Lidl, 8 of 12\ngeteilt mit Lena',
      );
      expect(
        node,
        isSemantics(
          isButton: true,
          hasTapAction: true,
          customActions: const [CustomSemanticsAction(label: 'Teilen')],
        ),
      );
      tester.semantics.performAction(
        find.semantics.byLabel(RegExp('^Wocheneinkauf')),
        SemanticsAction.customAction,
        args: CustomSemanticsAction.getIdentifier(
          const CustomSemanticsAction(label: 'Teilen'),
        ),
      );
      expect(shared, 1);
      handle.dispose();
    });

    testWidgets('from AX1: accessory below the text, chevron on line one', (
      tester,
    ) async {
      await _pump(
        tester,
        section([
          ListRow(
            title: 'Wocheneinkauf',
            meta: '4 offen',
            color: const Color(0xFF0062CC),
            accessory: const AvatarStack(names: ['Jannis', 'Lena']),
            done: 8,
            total: 12,
            onTap: () {},
          ),
        ]),
        layout: const LayoutCase(width: 390, scale: 2),
      );
      final meta = tester.getRect(find.text('4 offen'));
      final stack = tester.getRect(find.byType(AvatarStack));
      expect(stack.top, greaterThanOrEqualTo(meta.bottom));
      final title = tester.getRect(find.text('Wocheneinkauf'));
      final chevron = tester.getRect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.size == const Size(8, 14),
        ),
      );
      final context = tester.element(find.byType(ListRow));
      final line = context.typography.lineHeightOf(AvoTextStyle.headline);
      expect(chevron.center.dy, closeTo(title.top + line / 2, 0.5));
    });
  });

  layoutMatrix(
    'ListCard with chip, badge, long title and meta',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: Column(
        children: [
          ListCard(
            title: _longTitle,
            done: 8,
            total: 12,
            meta: '12 Artikel · 4 offen · vor 2 Std. · zuletzt von Lena',
            color: const Color(0xFF5E5CE6),
            sharedLabel: 'mit Lena und Maximilian',
            sharedName: 'Lena',
            badge: const _OfferCount(),
            onTap: () {},
          ),
          const SizedBox(height: AvoSpacing.m),
          const ListCard(title: 'Drogerie', done: 0, total: 0),
        ],
      ),
    ),
    scrollable: true,
    checkTapTargets: true,
  );

  layoutMatrix(
    'ListRow overview: avatars, counter, ring, complete',
    (context) => InsetSection(
      header: 'Meine Listen',
      separatorIndent: ListRow.separatorIndent,
      children: [
        ListRow(
          title: _longTitle,
          meta: '11 offen · Lidl · Lena kauft gerade ein',
          color: const Color(0xFF0062CC),
          glyph: AvoIcon(
            AvoIcons.cart,
            color: context.colors.onTint,
            filled: true,
          ),
          accessory: const AvatarStack(
            names: ['Jannis', 'Lena', 'Mia', 'Tom', 'Max'],
          ),
          done: 8,
          total: 12,
          badge: const _OfferCount(),
          onTap: () {},
        ),
        ListRow(
          title: 'Grillabend Samstag',
          meta: 'Alles erledigt',
          complete: true,
          cover: const ItemThumb(),
          done: 9,
          total: 9,
          progress: ListRowProgress.ring,
          onTap: () {},
        ),
        ListRow(title: 'Drogerie', meta: '3 offen', onTap: () {}),
      ],
    ),
    scrollable: true,
    checkTapTargets: true,
  );
}
