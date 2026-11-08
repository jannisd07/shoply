// N2 (W1 re-review 2): on short phones at accessibility sizes the status
// row stays in the conversation below the large title and never covers it
// (375x667 and 320x568 at text scale 3.1, offline and AI off).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/presentation/widgets/design/status_row.dart';

import '../../../screens/avo/avo_fakes.dart';
import '../../layout_matrix.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('layout: Avo status row on short phones', () {
    for (final (w, h) in [(375.0, 667.0), (320.0, 568.0)]) {
      for (final aiOn in [true, false]) {
        final label = aiOn ? 'offline' : 'AI off';
        testWidgets('${w.toInt()}x${h.toInt()} @3.1 $label: in the '
            'conversation, below the title, nothing cut', (tester) async {
          await pumpAvoAt(
            tester,
            width: w,
            height: h,
            scale: 3.1,
            offline: aiOn,
            aiOn: aiOn,
          );
          expect(tester.takeException(), isNull);
          expectNoClippedText(tester);
          expect(find.byType(StatusRow), findsOneWidget);
          expect(avoStatusInConversation(tester), isTrue);
          final title = tester.getRect(find.text('Avo').first);
          final row = tester.getRect(find.byType(StatusRow));
          expect(row.top, greaterThanOrEqualTo(title.bottom - 0.5));
          // Scrolled down, it stays in the conversation (never pinned).
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -300),
          );
          await settle(tester);
          expect(tester.takeException(), isNull);
          if (find.byType(StatusRow).evaluate().isNotEmpty) {
            expect(avoStatusInConversation(tester), isTrue);
          }
        });
      }
    }
  });
}
