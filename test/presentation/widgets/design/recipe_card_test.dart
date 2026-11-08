import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/glass_surface.dart';
import 'package:shoply/presentation/widgets/design/pro_badge.dart';
import 'package:shoply/presentation/widgets/design/recipe_card.dart';

import '../../../layout/layout_matrix.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  LayoutCase layout = const LayoutCase(width: 390, scale: 1),
  bool scrollable = false,
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
      scrollable
          ? SingleChildScrollView(child: padded)
          : Align(alignment: Alignment.topCenter, child: padded),
    ),
  );
}

/// Stands in for a photo; tests never load network images.
const Widget _photo = ColoredBox(color: Color(0xFF9C6B3F));

const _title = 'Avocado-Pasta';
const _meta = '15 Min · ★ 4,5';
const _longTitle =
    'Ofengemüse mit Halloumi, Kichererbsen und Zitronen-Joghurt-Dip';
const _longMeta = '35 Min · 2 Portionen · 540 kcal · ★ 4,6 (1.248)';

const _heroTitle = 'Shakshuka mit Feta';
const _heroMeta = '25 Min · ★ 4,8 (126) · vegetarisch';
const _eyebrow = 'Passt zu deiner Liste';
const _chip = '4 von 6 Zutaten da';
const _action = 'Zutaten auf die Liste';

/// D2-Rezepte grid column on a 390 pt screen: (390 − 32 − 12) / 2.
const double _gridColumn = 173;

double _scale(WidgetTester tester, Finder of) => tester
    .widget<Transform>(
      find.descendant(of: of, matching: find.byType(Transform)).first,
    )
    .transform
    .storage[0];

TextStyle _style(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

Finder _tintedGlass() =>
    find.byWidgetPredicate((w) => w is ContentGlass && w.tinted);

void main() {
  group('RecipeCard', () {
    testWidgets('grid: photo 4:3 radius 20, 17/22 title, 13/18 tabular meta', (
      tester,
    ) async {
      await _pump(
        tester,
        const SizedBox(
          width: _gridColumn,
          child: RecipeCard(image: _photo, title: _title, meta: _meta),
        ),
      );
      final clip = find.descendant(
        of: find.byType(RecipeCard),
        matching: find.byType(ClipRRect),
      );
      expect(
        tester.widget<ClipRRect>(clip).borderRadius,
        BorderRadius.circular(AvoRadii.card),
      );
      final photo = tester.getRect(clip);
      expect(photo.size, const Size(_gridColumn, _gridColumn * 3 / 4));

      final title = _style(tester, _title);
      expect(title.fontSize, 17);
      expect(title.fontWeight, FontWeight.w600);
      expect(title.color, AvoColors.light.label);
      final titleText = tester.widget<Text>(find.text(_title));
      expect(titleText.maxLines, 2);
      expect(titleText.overflow, TextOverflow.ellipsis);
      expect(tester.getRect(find.text(_title)).top, photo.bottom + 8);

      final meta = _style(tester, _meta);
      expect(meta.fontSize, 13);
      expect(meta.color, AvoColors.light.secondaryLabel);
      expect(meta.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(
        tester.getRect(find.text(_meta)).top,
        tester.getRect(find.text(_title)).bottom + 2,
      );

      // No card surface in the grid (D2-Rezepte).
      expect(
        find.descendant(
          of: find.byType(RecipeCard),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
    });

    testWidgets('rail: white card 148 wide, radius 20, D2 shadow, 148 × 111', (
      tester,
    ) async {
      await _pump(
        tester,
        const Align(
          alignment: Alignment.topLeft,
          child: RecipeCard(
            image: _photo,
            title: _title,
            meta: _meta,
            style: RecipeCardStyle.rail,
          ),
        ),
      );
      final card = tester.getRect(find.byType(RecipeCard));
      expect(card.width, 148);
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: find.byType(RecipeCard),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.color, AvoColors.light.surface);
      expect(decoration.borderRadius, BorderRadius.circular(20));
      expect(decoration.boxShadow, [
        BoxShadow(
          color: const Color(0xFF000000).withValues(alpha: 0.07),
          spreadRadius: 0.5,
        ),
        BoxShadow(
          color: const Color(0xFF000000).withValues(alpha: 0.07),
          offset: const Offset(0, 6),
          blurRadius: 18,
        ),
      ]);
      final photo = tester.getRect(
        find.descendant(
          of: find.byType(RecipeCard),
          matching: find.byType(AspectRatio),
        ),
      );
      expect(photo.size, const Size(148, 111));
      final title = tester.getRect(find.text(_title));
      expect(title.left, card.left + 10);
      expect(title.top, photo.bottom + 8);
      expect(
        tester.getRect(find.text(_meta)).bottom + 10,
        closeTo(card.bottom, 0.01),
      );
      expect(tester.widget<Text>(find.text(_title)).maxLines, 1);
    });

    testWidgets('rail in dark mode uses the dark surface', (tester) async {
      await _pump(
        tester,
        const Align(
          alignment: Alignment.topLeft,
          child: RecipeCard(
            image: _photo,
            title: _title,
            style: RecipeCardStyle.rail,
          ),
        ),
        layout: const LayoutCase(
          width: 390,
          scale: 1,
          brightness: Brightness.dark,
        ),
      );
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: find.byType(RecipeCard),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.color, AvoColors.dark.surface);
    });

    testWidgets('placeholder colour behind the photo', (tester) async {
      Color fill() => tester
          .widget<ColoredBox>(
            find
                .descendant(
                  of: find.byType(RecipeCard),
                  matching: find.byType(ColoredBox),
                )
                .first,
          )
          .color;
      await _pump(
        tester,
        const SizedBox(
          width: _gridColumn,
          child: RecipeCard(image: SizedBox.shrink(), title: _title),
        ),
      );
      expect(fill(), AvoColors.light.fill);
      await _pump(
        tester,
        const SizedBox(
          width: _gridColumn,
          child: RecipeCard(
            image: SizedBox.shrink(),
            title: _title,
            placeholderColor: Color(0xFFE9E4DC),
          ),
        ),
      );
      expect(fill(), const Color(0xFFE9E4DC));
    });

    testWidgets('tap runs onTap; the card shrinks while pressed', (
      tester,
    ) async {
      var taps = 0;
      await _pump(
        tester,
        SizedBox(
          width: _gridColumn,
          child: RecipeCard(
            image: _photo,
            title: _title,
            meta: _meta,
            onTap: () => taps++,
          ),
        ),
      );
      final card = find.byType(RecipeCard);
      final gesture = await tester.startGesture(tester.getCenter(card));
      await tester.pumpAndSettle();
      expect(_scale(tester, card), closeTo(AvoMotion.pressedScale, 0.002));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_scale(tester, card), closeTo(1, 0.002));
      expect(taps, 1);
    });

    testWidgets('VoiceOver: one button with title and meta', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        SizedBox(
          width: _gridColumn,
          child: RecipeCard(
            image: _photo,
            title: _title,
            meta: _meta,
            onTap: () {},
          ),
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('$_title, $_meta')),
        isSemantics(isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('VoiceOver: without onTap it is not a button', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const SizedBox(
          width: _gridColumn,
          child: RecipeCard(image: _photo, title: _title, meta: _meta),
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('$_title, $_meta')),
        isSemantics(isButton: false, hasTapAction: false),
      );
      handle.dispose();
    });

    testWidgets('VoiceOver: Pro is named, semanticLabel replaces the text', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        SizedBox(
          width: _gridColumn,
          child: RecipeCard(
            image: _photo,
            title: _title,
            meta: _meta,
            pro: true,
            onTap: () {},
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('$_title, Pro feature, $_meta'),
        findsOneWidget,
      );
      await _pump(
        tester,
        SizedBox(
          width: _gridColumn,
          child: RecipeCard(
            image: _photo,
            title: _title,
            meta: _meta,
            semanticLabel: 'Avocado-Pasta, 15 Minuten, Bewertung 4,5',
            onTap: () {},
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('Avocado-Pasta, 15 Minuten, Bewertung 4,5'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('Pro badge after the title, below it from AX1', (tester) async {
      Widget card() => const SizedBox(
        width: _gridColumn,
        child: RecipeCard(image: _photo, title: _title, pro: true),
      );
      await _pump(tester, card());
      var title = tester.getRect(find.text(_title));
      var badge = tester.getRect(find.byType(ProBadge));
      expect(badge.left, greaterThanOrEqualTo(title.right));
      expect(badge.top, lessThan(title.bottom));

      await _pump(
        tester,
        card(),
        layout: const LayoutCase(width: 390, scale: 2),
      );
      title = tester.getRect(find.text(_title));
      badge = tester.getRect(find.byType(ProBadge));
      expect(badge.top, greaterThanOrEqualTo(title.bottom));
    });

    testWidgets('title keeps its line limit up to xxxL, shows in full at AX', (
      tester,
    ) async {
      Widget card(RecipeCardStyle style) => SizedBox(
        width: _gridColumn,
        child: RecipeCard(image: _photo, title: _longTitle, style: style),
      );
      await _pump(
        tester,
        card(RecipeCardStyle.grid),
        layout: const LayoutCase(width: 390, scale: 1.35),
      );
      expect(tester.widget<Text>(find.text(_longTitle)).maxLines, 2);
      await _pump(
        tester,
        card(RecipeCardStyle.grid),
        layout: const LayoutCase(width: 390, scale: 2),
        scrollable: true,
      );
      expect(tester.widget<Text>(find.text(_longTitle)).maxLines, isNull);
      await _pump(
        tester,
        card(RecipeCardStyle.rail),
        layout: const LayoutCase(width: 390, scale: 2),
        scrollable: true,
      );
      expect(tester.widget<Text>(find.text(_longTitle)).maxLines, isNull);
    });

    testWidgets('badge sits below the meta and adds its semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        SizedBox(
          width: _gridColumn,
          child: RecipeCard(
            image: _photo,
            title: _title,
            meta: _meta,
            badge: const Text('Enthält Erdnuss'),
            onTap: () {},
          ),
        ),
      );
      expect(
        tester.getRect(find.text('Enthält Erdnuss')).top,
        tester.getRect(find.text(_meta)).bottom + 4,
      );
      expect(
        find.bySemanticsLabel('$_title, $_meta\nEnthält Erdnuss'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('RecipeHeroCard', () {
    Widget hero({
      RecipeHeroStyle style = RecipeHeroStyle.regular,
      VoidCallback? onTap,
      VoidCallback? onAction,
      bool chip = true,
      AvoPose? pose = AvoPose.excited,
      String title = _heroTitle,
      double? minHeight,
      bool? expandAction,
    }) => RecipeHeroCard(
      image: _photo,
      title: title,
      eyebrow: _eyebrow,
      meta: _heroMeta,
      chipLabel: chip ? _chip : null,
      chipPose: pose,
      actionLabel: _action,
      onAction: onAction,
      onTap: onTap,
      style: style,
      minHeight: minHeight,
      expandAction: expandAction,
    );

    testWidgets('D2-Rezepte: 248 high, radius 26, panel 12 in with radius 20', (
      tester,
    ) async {
      await _pump(tester, hero(onAction: () {}), scrollable: true);
      final card = tester.getRect(find.byType(RecipeHeroCard));
      expect(card.size, const Size(358, 248));
      expect(
        tester
            .widget<ClipRRect>(
              find
                  .descendant(
                    of: find.byType(RecipeHeroCard),
                    matching: find.byType(ClipRRect),
                  )
                  .first,
            )
            .borderRadius,
        BorderRadius.circular(AvoRadii.group),
      );
      final panel = tester.getRect(find.byType(GlassInfoPanel));
      expect(panel.left, card.left + 12);
      expect(panel.right, card.right - 12);
      expect(panel.bottom, card.bottom - 12);
      final glass = tester.widget<ContentGlass>(
        find
            .descendant(
              of: find.byType(GlassInfoPanel),
              matching: find.byType(ContentGlass),
            )
            .first,
      );
      expect(glass.tinted, isFalse);
      expect(glass.radius, AvoRadii.card);
      expect(
        glass.padding,
        const EdgeInsetsDirectional.fromSTEB(16, 12, 14, 12),
      );

      final eyebrow = 'PASST ZU DEINER LISTE';
      final eyebrowStyle = _style(tester, eyebrow);
      expect(eyebrowStyle.fontSize, 11);
      expect(eyebrowStyle.fontWeight, FontWeight.w600);
      expect(eyebrowStyle.color, AvoColors.light.tint);
      expect(eyebrowStyle.letterSpacing, 0.4);
      expect(
        tester.getRect(find.text(eyebrow)).topLeft,
        panel.topLeft + const Offset(16, 12),
      );
      expect(
        tester.getRect(find.text(_heroTitle)).top,
        tester.getRect(find.text(eyebrow)).bottom + 2,
      );
      final title = _style(tester, _heroTitle);
      expect(title.fontSize, 20);
      expect(title.fontWeight, FontWeight.w600);
      final meta = _style(tester, _heroMeta);
      expect(meta.fontSize, 13);
      expect(meta.color, AvoColors.light.tertiaryLabel);
      expect(meta.fontFeatures, contains(const FontFeature.tabularFigures()));

      // Chip: 12 in from the top corner, 32 high, with a small figure.
      final chip = tester.getRect(
        find.ancestor(
          of: find.text(_chip),
          matching: find.byType(ContentGlass),
        ),
      );
      expect(chip.topLeft, card.topLeft + const Offset(12, 12));
      expect(chip.height, 32);
      expect(find.byType(AvoFigure), findsOneWidget);
      expect(_style(tester, _chip).fontWeight, FontWeight.w600);
    });

    testWidgets('compact action: 36 pt tinted capsule in a 44 pt target', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, hero(onAction: () {}), scrollable: true);
      final capsule = tester.getRect(_tintedGlass());
      expect(capsule.height, 36);
      final panel = tester.getRect(find.byType(GlassInfoPanel));
      expect(capsule.left, panel.left + 16);
      expect(capsule.width, lessThan(panel.width - 30));
      final target = tester.getRect(find.bySemanticsLabel(_action));
      expect(target.height, 44);
      expect(target.bottom, panel.bottom - 12);
      expect(target.top, tester.getRect(find.text(_heroMeta)).bottom + 6);
      final label = _style(tester, _action);
      expect(label.fontSize, 15);
      expect(label.fontWeight, FontWeight.w600);
      expect(label.color, AvoColors.light.onTint);
      handle.dispose();
    });

    testWidgets('large: 270 high, 22/28 bold, full-width 44 pt action', (
      tester,
    ) async {
      await _pump(
        tester,
        hero(style: RecipeHeroStyle.large, onAction: () {}),
        scrollable: true,
      );
      expect(tester.getSize(find.byType(RecipeHeroCard)).height, 270);
      final title = _style(tester, _heroTitle);
      expect(title.fontSize, 22);
      expect(title.fontWeight, FontWeight.w700);
      final panel = tester.getRect(find.byType(GlassInfoPanel));
      final button = tester.getRect(find.byType(AppButton));
      expect(button.width, panel.width - 32);
      expect(button.height, 44);
      expect(button.bottom, panel.bottom - 16);
      expect(
        tester.getRect(find.text(_heroMeta)).top,
        tester.getRect(find.text(_heroTitle)).bottom + 2,
      );
      expect(button.top, tester.getRect(find.text(_heroMeta)).bottom + 12);
    });

    testWidgets('"Heute kochen": regular title, expanded action, 220 high', (
      tester,
    ) async {
      await _pump(
        tester,
        hero(minHeight: 220, expandAction: true, pose: null, onAction: () {}),
        scrollable: true,
      );
      expect(tester.getSize(find.byType(RecipeHeroCard)).height, 220);
      expect(find.byType(AppButton), findsOneWidget);
      expect(find.byType(AvoFigure), findsNothing);
      expect(
        tester.getRect(find.byType(AppButton)).top,
        tester.getRect(find.text(_heroMeta)).bottom + 10,
      );
    });

    testWidgets('action runs onAction only; the card stays still meanwhile', (
      tester,
    ) async {
      var taps = 0;
      var actions = 0;
      await _pump(
        tester,
        hero(onTap: () => taps++, onAction: () => actions++),
        scrollable: true,
      );
      final card = find.byType(RecipeHeroCard);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text(_action)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(_scale(tester, card), 1);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(actions, 1);
      expect(taps, 0);

      await tester.tap(find.text(_action));
      await tester.pumpAndSettle();
      expect(actions, 2);
      expect(taps, 0);
    });

    testWidgets('tapping the photo opens the recipe; the card shrinks', (
      tester,
    ) async {
      var taps = 0;
      var actions = 0;
      await _pump(
        tester,
        hero(onTap: () => taps++, onAction: () => actions++),
        scrollable: true,
      );
      final card = find.byType(RecipeHeroCard);
      final photoSpot = tester.getTopRight(card) + const Offset(-24, 24);
      final gesture = await tester.startGesture(photoSpot);
      await tester.pumpAndSettle();
      expect(_scale(tester, card), closeTo(AvoMotion.pressedScale, 0.002));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(actions, 0);
    });

    testWidgets('VoiceOver: the card is one element, the action its own', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        hero(onTap: () {}, onAction: () {}),
        scrollable: true,
      );
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('$_heroTitle, $_eyebrow, $_heroMeta, $_chip'),
        ),
        isSemantics(isButton: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(_action)),
        isSemantics(
          isButton: true,
          hasTapAction: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('disabled action is dimmed and announced as such', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      for (final style in RecipeHeroStyle.values) {
        await _pump(tester, hero(style: style), scrollable: true);
        expect(
          tester.getSemantics(find.bySemanticsLabel(_action)),
          isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
          reason: '$style',
        );
        expect(
          find.descendant(
            of: find.byType(GlassInfoPanel),
            matching: find.byWidgetPredicate(
              (w) => w is Opacity && w.opacity == 0.4,
            ),
          ),
          findsOneWidget,
          reason: '$style',
        );
      }
      handle.dispose();
    });

    testWidgets('AX5 on 320 pt: grows instead of clipping, panel at bottom', (
      tester,
    ) async {
      await _pump(
        tester,
        hero(
          title: 'Shakshuka mit Feta, Paprika und gerösteten Kichererbsen',
          onAction: () {},
        ),
        layout: const LayoutCase(width: 320, scale: 3.1),
        scrollable: true,
      );
      expect(tester.takeException(), isNull);
      expectNoClippedText(tester);
      final card = tester.getRect(find.byType(RecipeHeroCard));
      expect(card.height, greaterThan(248));
      final panel = tester.getRect(find.byType(GlassInfoPanel));
      expect(panel.bottom, card.bottom - 12);
      final chip = tester.getRect(
        find.ancestor(
          of: find.text(_chip),
          matching: find.byType(ContentGlass),
        ),
      );
      expect(chip.top, card.top + 12);
      expect(chip.bottom + 12, lessThanOrEqualTo(panel.top + 0.01));
    });

    testWidgets('the decorative plus is left out from AX1 on', (tester) async {
      for (final style in RecipeHeroStyle.values) {
        await _pump(
          tester,
          hero(style: style, onAction: () {}),
          scrollable: true,
        );
        expect(
          find.descendant(
            of: find.byType(GlassInfoPanel),
            matching: find.byType(AvoIcon),
          ),
          findsOneWidget,
          reason: '$style',
        );
        await _pump(
          tester,
          hero(style: style, onAction: () {}),
          layout: const LayoutCase(width: 320, scale: 2),
          scrollable: true,
        );
        expect(
          find.descendant(
            of: find.byType(GlassInfoPanel),
            matching: find.byType(AvoIcon),
          ),
          findsNothing,
          reason: '$style',
        );
      }
    });

    testWidgets('in a loose parent it keeps its minimum height', (
      tester,
    ) async {
      await _pump(tester, hero(onAction: () {}));
      expect(tester.getSize(find.byType(RecipeHeroCard)).height, 248);
    });

    testWidgets('without a chip the panel still sits at the bottom', (
      tester,
    ) async {
      await _pump(tester, hero(chip: false, onAction: () {}), scrollable: true);
      final card = tester.getRect(find.byType(RecipeHeroCard));
      expect(card.height, 248);
      expect(
        tester.getRect(find.byType(GlassInfoPanel)).bottom,
        card.bottom - 12,
      );
      expect(find.byType(AvoFigure), findsNothing);
    });

    testWidgets('Reduce Motion: pressing dims but does not scale', (
      tester,
    ) async {
      await _pump(
        tester,
        hero(onTap: () {}, onAction: () {}),
        layout: const LayoutCase(width: 390, scale: 1, reduceMotion: true),
        scrollable: true,
      );
      final card = find.byType(RecipeHeroCard);
      final gesture = await tester.startGesture(
        tester.getTopRight(card) + const Offset(-24, 24),
      );
      await tester.pumpAndSettle();
      expect(_scale(tester, card), 1);
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('GlassInfoPanel', () {
    testWidgets('ContentGlass with radius 20 and the D2 padding', (
      tester,
    ) async {
      await _pump(
        tester,
        const GlassInfoPanel(
          padding: GlassInfoPanel.largePadding,
          child: Text('Shakshuka mit Feta'),
        ),
      );
      final glass = tester.widget<ContentGlass>(find.byType(ContentGlass));
      expect(glass.radius, 20);
      expect(
        glass.padding,
        const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 16),
      );
    });
  });

  // ------------------------------------------------------------- layout

  layoutMatrix(
    'RecipeCard grid in two columns, long title, Pro and badge',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: RecipeCard(
              image: _photo,
              title: _longTitle,
              meta: _longMeta,
              pro: true,
              badge: Text(
                'Enthält Erdnuss und Sesam',
                style: context.text(
                  AvoTextStyle.footnote,
                  color: context.colors.destructive,
                ),
              ),
              onTap: () {},
            ),
          ),
          const SizedBox(width: AvoSpacing.m),
          Expanded(
            child: RecipeCard(
              image: _photo,
              title: 'Rotes Linsen-Dal',
              meta: '30 Min · ★ 4,9',
              onTap: () {},
            ),
          ),
        ],
      ),
    ),
    scrollable: true,
    checkTapTargets: true,
  );

  layoutMatrix(
    'RecipeCard grid in one column',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: RecipeCard(
        image: _photo,
        title: _longTitle,
        meta: _longMeta,
        onTap: () {},
      ),
    ),
    scrollable: true,
    checkTapTargets: true,
  );

  layoutMatrix(
    'RecipeCard rail with long title and Pro',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: RecipeCard(
          image: _photo,
          title: _longTitle,
          meta: _longMeta,
          style: RecipeCardStyle.rail,
          pro: true,
          onTap: () {},
        ),
      ),
    ),
    scrollable: true,
    checkTapTargets: true,
  );

  layoutMatrix(
    'RecipeHeroCard regular with chip, eyebrow and compact action',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: RecipeHeroCard(
        image: _photo,
        title: 'Shakshuka mit Feta, Paprika und gerösteten Kichererbsen',
        eyebrow: _eyebrow,
        meta: _longMeta,
        chipLabel: '4 von 6 Zutaten hast du schon zu Hause',
        actionLabel: 'Fehlende 2 Zutaten auf die Einkaufsliste',
        onAction: () {},
        onTap: () {},
      ),
    ),
    scrollable: true,
    checkTapTargets: true,
  );

  layoutMatrix(
    'RecipeHeroCard large with full-width action',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: RecipeHeroCard(
        image: _photo,
        title: 'Ofengemüse mit Halloumi und Zitronen-Joghurt-Dip',
        meta: _heroMeta,
        chipLabel: _chip,
        actionLabel: _action,
        style: RecipeHeroStyle.large,
        onAction: () {},
        onTap: () {},
      ),
    ),
    scrollable: true,
    checkTapTargets: true,
  );

  layoutMatrix(
    'RecipeHeroCard "Heute kochen" without figure',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: RecipeHeroCard(
        image: _photo,
        title: _heroTitle,
        meta: '25 Min · ★ 4,8',
        chipLabel: '4 von 6 Zutaten hast du schon',
        chipPose: null,
        actionLabel: 'Fehlende 2 auf die Liste',
        expandAction: true,
        minHeight: 220,
        onAction: () {},
      ),
    ),
    scrollable: true,
    checkTapTargets: true,
  );
}
