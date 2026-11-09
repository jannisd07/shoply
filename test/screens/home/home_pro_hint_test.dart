import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/presentation/screens/home/widgets/home_pro_hint.dart';
import 'package:shoply/presentation/widgets/design/pro_badge.dart';
import '../../layout/layout_matrix.dart';

void main() {
  setUpAll(loadLayoutFonts);

  layoutMatrix(
    'HomeProHint',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: HomeProHint(onNever: () {}),
    ),
    checkTapTargets: true,
  );

  test('the offer names Avo Pro and the trial length in both languages', () {
    for (final lang in ['de', 'en']) {
      for (final key in ['pro_hint_trial', 'pro_hint_view', 'pro_hint_never']) {
        expect(AppTranslations.get(key, lang), isNot(key), reason: key);
      }
      expect(AppTranslations.get('pro_hint_trial', lang), contains('{pro}'));
      expect(AppTranslations.get('pro_hint_trial', lang), contains('{days}'));
    }
  });

  testWidgets('ProBadge instead of a symbol; a full swipe hides it for good',
      (tester) async {
    tester.view.physicalSize = const Size(390 * 3, kLayoutHeight * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    var never = 0;
    await tester.pumpWidget(
      layoutHarness(
        const LayoutCase(width: 390, scale: 1),
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(AvoSpacing.screen),
            child: HomeProHint(onNever: () => never++),
          ),
        ),
      ),
    );
    expect(find.byType(ProBadge), findsOneWidget);
    final text = find.textContaining('Avo Pro');
    expect(text, findsOneWidget);
    await tester.drag(text, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(never, 1);
  });
}
