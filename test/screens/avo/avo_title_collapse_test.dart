// S6 P2: the Avo tab shows one title at a time, like iOS. The large title is
// visible ⇒ no small title in the head; collapsed ⇒ only the small one.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/presentation/screens/avo/widgets/avo_large_title.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';

import 'avo_fakes.dart';

Future<void> _ask(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(EditableText), text);
  await tester.testTextInput.receiveAction(TextInputAction.send);
  await settle(tester);
}

/// Whether some of the large title can be seen: below the head and not
/// faded out.
bool _largeTitleSeen(WidgetTester tester) {
  final title = find.descendant(
    of: find.byType(AvoLargeTitle),
    matching: find.text('Avo'),
  );
  final head = tester.getRect(find.byType(GlassToolbar));
  final below = tester.getRect(title).bottom > head.bottom + 0.5;
  final opacities = tester.widgetList<Opacity>(
    find.ancestor(of: title, matching: find.byType(Opacity)),
  );
  final shown = opacities.every((o) => o.opacity > 0);
  return below && shown;
}

bool _smallTitleSeen(WidgetTester tester) => find
    .descendant(of: find.byType(GlassToolbar), matching: find.text('Avo'))
    .evaluate()
    .isNotEmpty;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final scale in [1.0, 2.0]) {
    testWidgets('never both titles at once while scrolling (scale $scale)', (
      tester,
    ) async {
      await pumpAvoAt(tester, width: 390, height: 844, scale: scale);
      expect(_largeTitleSeen(tester), isTrue);
      expect(_smallTitleSeen(tester), isFalse);

      await _ask(tester, 'Erste Frage');
      await tester.pump(const Duration(seconds: 2));
      expect(
        _largeTitleSeen(tester) && _smallTitleSeen(tester),
        isFalse,
        reason: 'after the first question',
      );

      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      for (var offset = 0.0; offset <= 160; offset += 4) {
        position.jumpTo(offset.clamp(0.0, position.maxScrollExtent));
        await tester.pump();
        final large = _largeTitleSeen(tester);
        final small = _smallTitleSeen(tester);
        expect(large && small, isFalse, reason: 'both at offset $offset');
        expect(large || small, isTrue, reason: 'none at offset $offset');
      }
    });
  }
}
