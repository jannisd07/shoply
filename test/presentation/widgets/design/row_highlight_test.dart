import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/row_highlight.dart';

Widget _app(String? rowId) => CupertinoApp(
  home: AvoDesignScope(
    child: RowHighlightScope(
      rowId: rowId,
      child: const CupertinoPageScaffold(
        child: Column(
          children: [
            HighlightableRow(id: 'diet.allergies', child: Text('Allergies')),
            HighlightableRow(id: 'diet.adapt', child: Text('Adapt')),
          ],
        ),
      ),
    ),
  ),
);

Finder _fillOf(String text) => find.descendant(
  of: find.widgetWithText(HighlightableRow, text),
  matching: find.byType(DecoratedBox),
);

void main() {
  testWidgets('only the named row lights up and fades after a second', (
    tester,
  ) async {
    await tester.pumpWidget(_app('diet.allergies'));
    await tester.pump();
    expect(_fillOf('Allergies'), findsOneWidget);
    expect(_fillOf('Adapt'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    expect(_fillOf('Allergies'), findsNothing);
  });

  testWidgets('no row lights up without a row id', (tester) async {
    await tester.pumpWidget(_app(null));
    await tester.pump();
    expect(_fillOf('Allergies'), findsNothing);
    expect(_fillOf('Adapt'), findsNothing);
  });
}
