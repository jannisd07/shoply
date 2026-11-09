import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_data.dart';

import '../../layout/layout_matrix.dart';

void main() {
  testWidgets('listDate: the year only for earlier years (A11b)', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      layoutHarness(
        const LayoutCase(width: 390, scale: 1),
        Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox();
          },
        ),
      ),
    );
    final now = DateTime(2026, 11, 9, 12);
    expect(
      listDate(ctx, DateTime(2026, 3, 4, 12), now),
      isNot(contains('2026')),
    );
    expect(listDate(ctx, DateTime(2025, 12, 7, 12), now), contains('2025'));
  });
}
