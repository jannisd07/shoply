import 'package:flutter/widgets.dart';

import 'package:flutter_test/flutter_test.dart';

import 'perf_harness.dart';

/// S5 "Rezepte-Tab scrollen" (Konzept 20 §5.1): every section with photos,
/// cold image cache (new photo URLs each run, decoded cache emptied); the
/// photos load and decode while the tab scrolls down and back up.
/// Target: 90th percentile ≤ 8.3 ms; limit: ≤ 16 ms.
void main() {
  perfBinding();
  late PerfImageServer images;

  setUpAll(() async => images = await PerfImageServer.start());
  tearDownAll(() => images.close());

  testWidgets('S5 recipes tab scroll', (tester) async {
    coldImageCache();
    final recipes = perfRecipes(images);
    await tester.pumpWidget(
      perfApp(
        overrides: recipesTabOverrides(recipes),
        router: recipesTabRouter(),
      ),
    );
    // Only the layout settles; the photos stay for the measurement.
    await idle(tester, const Duration(milliseconds: 300));
    expect(find.byType(Scrollable), findsWidgets);

    final tab = mainScrollable();
    await measure('s5_recipes_tab', () async {
      await flingSeries(tester, tab, down: true, times: 5);
      await flingSeries(tester, tab, down: false, times: 5);
    });
  });
}
