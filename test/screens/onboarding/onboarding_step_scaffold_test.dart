import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/presentation/screens/onboarding/widgets/onboarding_step_scaffold.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';

import '../../layout/layout_matrix.dart';

Widget _page({VoidCallback? onSkip, VoidCallback? onBack, int step = 3}) =>
    OnboardingStepPage(
      title: 'Ernährung und Unverträglichkeiten',
      message: 'Avo passt Rezepte daran an. Du kannst das jederzeit ändern.',
      progress: StepProgress(
        step: step,
        total: 6,
        semanticLabel: 'Schritt $step von 6',
      ),
      onBack: onBack ?? () {},
      onSkip: onSkip,
      primaryAction: AppButton.primary(
        label: 'Weiter',
        onPressed: () {},
        expand: true,
      ),
      children: [
        for (final label in ['Vegetarisch', 'Vegan', 'Glutenfrei'])
          ToggleRow(title: label, value: false, onChanged: (_) {}),
      ],
    );

Future<void> _pump(WidgetTester tester, Widget page, LayoutCase c) async {
  tester.view.physicalSize = Size(c.width * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(layoutHarness(c, page));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('skip sits in the top bar at default size', (tester) async {
    await _pump(
      tester,
      _page(onSkip: () {}),
      const LayoutCase(width: 390, scale: 1),
    );
    final skip = tester.getRect(find.text('Skip'));
    final next = tester.getRect(find.text('Weiter'));
    expect(skip.top, lessThan(next.top));
    expect(
      skip.top,
      lessThan(
        tester.getRect(find.text('Ernährung und Unverträglichkeiten')).top,
      ),
    );
  });

  testWidgets('skip moves below the main action from AX1', (tester) async {
    await _pump(
      tester,
      _page(onSkip: () {}),
      const LayoutCase(width: 390, scale: 2),
    );
    await tester.dragUntilVisible(
      find.text('Skip'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    expect(
      tester.getRect(find.text('Skip')).top,
      greaterThan(tester.getRect(find.text('Weiter')).top),
    );
  });

  testWidgets('scrolled to the end, the last line clears the bar fade', (
    tester,
  ) async {
    await _pump(
      tester,
      OnboardingStepPage(
        title: 'Was soll Avo für dich tun?',
        message: 'Listen und Rezepte sind immer dabei.',
        onBack: () {},
        primaryAction: AppButton.primary(
          label: 'Weiter',
          onPressed: () {},
          expand: true,
        ),
        children: [
          for (var i = 0; i < 8; i++)
            ToggleRow(title: 'Modul $i', value: false, onChanged: (_) {}),
          const Text('KI-Hinweis am Ende'),
        ],
      ),
      const LayoutCase(width: 390, scale: 1),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    final last = tester.getRect(find.text('KI-Hinweis am Ende'));
    final button = tester.getRect(find.text('Weiter'));
    // 40 pt fade above the bar, whose padding puts the button 16 pt lower.
    expect(button.top - last.bottom, greaterThanOrEqualTo(40 + 16));
  });

  testWidgets('progress glides and announces the step', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _page(step: 2), const LayoutCase(width: 390, scale: 1));
    expect(
      tester.getSemantics(find.byType(StepProgress)),
      matchesSemantics(label: 'Schritt 2 von 6'),
    );
    await tester.pumpWidget(
      layoutHarness(const LayoutCase(width: 390, scale: 1), _page(step: 4)),
    );
    await tester.pumpAndSettle();
    final track = tester.getSize(find.byType(StepProgress));
    expect(track, const Size(96, 3));
    handle.dispose();
  });

  testWidgets('no back button after the account step', (tester) async {
    await _pump(
      tester,
      OnboardingStepPage(
        title: 'Wie heißt du?',
        primaryAction: AppButton.primary(label: 'Weiter', onPressed: () {}),
      ),
      const LayoutCase(width: 390, scale: 1),
    );
    expect(find.bySemanticsLabel('Back'), findsNothing);
  });

  testWidgets('without a main action there is no action bar (A-O1)', (
    tester,
  ) async {
    await _pump(
      tester,
      OnboardingStepPage(
        title: 'Angebote in deiner Region',
        onBack: () {},
        onSkip: () {},
        children: const [Text('B-Inhalt mit eigenem Weiter')],
      ),
      const LayoutCase(width: 390, scale: 1),
    );
    expect(find.byType(AppButton), findsOneWidget); // only "Skip"
    expect(find.text('Weiter'), findsNothing);
    expect(find.text('B-Inhalt mit eigenem Weiter'), findsOneWidget);
    expect(
      tester.getRect(find.text('Skip')).top,
      lessThan(tester.getRect(find.text('Angebote in deiner Region')).top),
    );
  });

  testWidgets('skip can sit below the main action at every size', (
    tester,
  ) async {
    await _pump(
      tester,
      OnboardingStepPage(
        title: 'Was soll Avo für dich tun?',
        onSkip: () {},
        skipLabel: 'Später entscheiden',
        skipBelowAction: true,
        primaryAction: AppButton.primary(label: 'Weiter', onPressed: () {}),
      ),
      const LayoutCase(width: 440, scale: 1),
    );
    expect(
      tester.getRect(find.text('Später entscheiden')).top,
      greaterThan(tester.getRect(find.text('Weiter')).top),
    );
  });

  testWidgets('status, title trailing and action header have their place', (
    tester,
  ) async {
    await _pump(
      tester,
      OnboardingStepPage(
        title: 'Dein Ziel',
        message: 'Aus ein paar Angaben schätzen wir dein Tagesziel.',
        status: const Text('Status'),
        titleTrailing: const SizedBox.square(dimension: 72, child: Text('Avo')),
        actionHeader: const Text('Etwa 1.650 kcal am Tag'),
        primaryAction: AppButton.primary(label: 'Weiter', onPressed: () {}),
        children: const [Text('Inhalt')],
      ),
      const LayoutCase(width: 390, scale: 1),
    );
    final title = tester.getRect(find.text('Dein Ziel'));
    expect(tester.getRect(find.text('Avo')).left, greaterThan(title.right));
    expect(
      tester.getRect(find.text('Status')).top,
      greaterThan(
        tester
            .getRect(
              find.text('Aus ein paar Angaben schätzen wir dein Tagesziel.'),
            )
            .bottom,
      ),
    );
    expect(
      tester.getRect(find.text('Inhalt')).top,
      greaterThanOrEqualTo(tester.getRect(find.text('Status')).bottom),
    );
    expect(
      tester.getRect(find.text('Etwa 1.650 kcal am Tag')).bottom,
      lessThanOrEqualTo(tester.getRect(find.text('Weiter')).top),
    );
  });

  layoutMatrix('OnboardingStepPage', (context) => _page(onSkip: () {}));

  layoutMatrix(
    'OnboardingStepPage ohne Hauptaktion',
    (context) => OnboardingStepPage(
      title: 'Angebote in deiner Region',
      message: 'Du siehst nur Angebote der Märkte, in denen du einkaufst.',
      onBack: () {},
      onSkip: () {},
    ),
  );
}
