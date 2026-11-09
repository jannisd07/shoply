import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/presentation/screens/lists/list_detail_screen.dart';

import 'perf_harness.dart';

/// S1 "Liste scrollen" (Konzept 20 §5.1): "Wocheneinkauf" with 60 items in
/// 8 aisles, each with a photo; three flings down, three up.
/// Target: 90th percentile ≤ 8.3 ms; limit: no frame over 16 ms.
void main() {
  perfBinding();
  late PerfImageServer images;

  setUpAll(() async => images = await PerfImageServer.start());
  tearDownAll(() => images.close());

  testWidgets('S1 list scroll', (tester) async {
    coldImageCache();
    await tester.pumpWidget(
      perfApp(
        overrides: listScreenOverrides(images),
        home: const ListDetailScreen(
          listId: perfListId,
          listName: perfListName,
        ),
      ),
    );
    // First rows and their photos in place before the clock starts.
    await idle(tester, const Duration(seconds: 2));
    expect(find.text('Bananen'), findsWidgets);

    final list = mainScrollable();
    await measure('s1_scroll_list', () async {
      await flingSeries(tester, list, down: true);
      await flingSeries(tester, list, down: false);
    });
  });
}
