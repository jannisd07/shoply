import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_detail_composer.dart';
import 'package:shoply/presentation/widgets/common/liquid_glass_container.dart';
import 'package:shoply/presentation/widgets/design/add_item_accessory.dart';
import 'package:shoply/presentation/widgets/design/glass_surface.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

import '../../layout/layout_matrix.dart';

/// A3 for the add field of the list: on iOS the old composer clipped its
/// text (owner's mother, iPhone 13 Pro, display zoom "Larger Text" =
/// 320 pt, and larger text sizes at 390 pt). The list's [ListDetailComposer]
/// must never be shorter than its text at any width from 320 to 440 pt and
/// any text size up to 3.1×, with and without the "≈ … €" sum.
const _long = 'Laktosefreie Bio-Vollmilch 3,8 % für den Kaffee am Morgen';
const _sum = '≈ 23,80 €';

Future<void> _pump(
  WidgetTester tester, {
  required LayoutCase layout,
  String text = '',
  String? sum,
  TextEditingController? controller,
  FocusNode? focus,
  ValueChanged<String>? onSubmitted,
  List<Override> overrides = const [],
}) async {
  await loadLayoutFonts();
  tester.view.physicalSize = Size(layout.width * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final field = controller ?? TextEditingController(text: text);
  final node = focus ?? FocusNode();
  if (controller == null) addTearDown(field.dispose);
  if (focus == null) addTearDown(node.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        offersAvailableProvider.overrideWithValue(false),
        ...overrides,
      ],
      child: layoutHarness(
        layout,
        Stack(
          children: [
            AccessoryDock(
              child: ListDetailComposer(
                listId: 'l1',
                controller: field,
                focusNode: node,
                onSubmitted: onSubmitted ?? (_) {},
                totalText: sum,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

void _expectFieldNotClipped(WidgetTester tester, String label) {
  final box = tester.renderObject<RenderBox>(find.byType(CupertinoTextField));
  final needed = box.getMinIntrinsicHeight(box.size.width);
  expect(
    box.size.height,
    greaterThanOrEqualTo(needed - 0.5),
    reason:
        '$label: field is ${box.size.height.toStringAsFixed(1)} pt tall '
        'but its text needs ${needed.toStringAsFixed(1)} pt',
  );
  final glass = tester.getSize(
    find
        .descendant(
          of: find.byType(AddItemAccessory),
          matching: find.byType(GlassSurface),
        )
        .first,
  );
  expect(
    glass.height,
    greaterThanOrEqualTo(box.size.height - 0.5),
    reason: '$label: the glass must be as tall as the field',
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('A3 on the iOS glass path (list add field)', () {
    final iOS = TargetPlatformVariant.only(TargetPlatform.iOS);
    for (final width in kLayoutWidths) {
      for (final scale in kLayoutTextScales) {
        final layout = LayoutCase(width: width, scale: scale);
        for (final sum in [null, _sum]) {
          final withSum = sum == null ? '' : ', with sum';
          testWidgets('placeholder fits at $width pt, text x$scale$withSum', (
            tester,
          ) async {
            await _pump(tester, layout: layout, sum: sum);
            expect(
              find.byType(LiquidGlassContainer),
              findsOneWidget,
              reason: 'the iOS glass path must be the one under test',
            );
            _expectFieldNotClipped(tester, 'empty');
            expectNoClippedText(tester, reason: 'empty at $layout');
            expect(tester.takeException(), isNull);
          }, variant: iOS);

          testWidgets('long entry wraps instead of clipping at $width pt, '
              'text x$scale$withSum', (tester) async {
            await _pump(tester, layout: layout, text: _long, sum: sum);
            _expectFieldNotClipped(tester, 'long text');
            expectNoClippedText(tester, reason: 'long at $layout');
            expect(tester.takeException(), isNull);
          }, variant: iOS);
        }
      }
    }

    testWidgets('bold text at 320 pt and AX5 is not clipped either', (
      tester,
    ) async {
      await _pump(
        tester,
        layout: const LayoutCase(width: 320, scale: 3.1, bold: true),
        text: _long,
        sum: _sum,
      );
      _expectFieldNotClipped(tester, 'bold AX5');
      expectNoClippedText(tester);
    }, variant: iOS);
  });

  group('ListDetailComposer', () {
    const layout = LayoutCase(width: 390, scale: 1);

    testWidgets('placeholder "Add item", sum at the end, no mic', (
      tester,
    ) async {
      await _pump(tester, layout: layout, sum: _sum);
      expect(find.text('Add item'), findsOneWidget);
      expect(find.text(_sum), findsOneWidget);
      expect(find.bySemanticsLabel('Dictate'), findsNothing);
      expect(
        tester.widget<AddItemAccessory>(find.byType(AddItemAccessory)).onDictate,
        isNull,
      );
    });

    testWidgets('no sum without a total', (tester) async {
      await _pump(tester, layout: layout);
      expect(find.textContaining('≈'), findsNothing);
    });

    testWidgets('Return hands the text over', (tester) async {
      final submitted = <String>[];
      await _pump(tester, layout: layout, onSubmitted: submitted.add);
      await tester.enterText(find.byType(CupertinoTextField), ' 2 Milch ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(submitted, ['2 Milch']);
    });

    testWidgets('offer suggestions appear from two letters, after a pause', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await _pump(tester, layout: layout, controller: controller);
      expect(find.byType(OfferSuggestionsBar), findsNothing);

      controller.text = 'M';
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(OfferSuggestionsBar), findsNothing);

      controller.text = 'Mi';
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byType(OfferSuggestionsBar),
        findsNothing,
        reason: 'waits for the typing pause',
      );
      await tester.pump(const Duration(milliseconds: 300));
      final bar = tester.widget<OfferSuggestionsBar>(
        find.byType(OfferSuggestionsBar),
      );
      expect(bar.listId, 'l1');
      expect(bar.query, 'Mi');

      // A tapped offer is added by Teil B, then the field empties.
      bar.onAdded!();
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(find.byType(OfferSuggestionsBar), findsNothing);
    });
  });

  layoutMatrix(
    'ListDetailComposer with sum',
    (context) => ProviderScope(
      overrides: [offersAvailableProvider.overrideWithValue(false)],
      child: SizedBox(
        height: kLayoutHeight,
        child: Stack(
          children: [
            AccessoryDock(
              child: ListDetailComposer(
                listId: 'l1',
                controller: TextEditingController(text: _long),
                focusNode: FocusNode(),
                onSubmitted: (_) {},
                totalText: _sum,
              ),
            ),
          ],
        ),
      ),
    ),
    checkTapTargets: true,
  );
}
