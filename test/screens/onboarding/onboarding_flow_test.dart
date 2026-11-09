import 'dart:convert';

import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/services/onboarding_answers_service.dart';
import 'package:shoply/presentation/screens/auth/steps/account_step.dart';
import 'package:shoply/presentation/screens/auth/steps/code_step.dart';
import 'package:shoply/presentation/screens/auth/steps/email_step.dart';
import 'package:shoply/presentation/screens/auth/steps/name_step.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_flow.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_prefs.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_steps.dart';
import 'package:shoply/presentation/screens/onboarding/steps/account_check_step.dart';
import 'package:shoply/presentation/screens/onboarding/steps/diet_step.dart';
import 'package:shoply/presentation/screens/onboarding/steps/first_list_step.dart';
import 'package:shoply/presentation/screens/onboarding/steps/goal_step.dart';
import 'package:shoply/presentation/screens/onboarding/steps/join_step.dart';
import 'package:shoply/presentation/screens/onboarding/steps/modules_step.dart';
import 'package:shoply/presentation/screens/onboarding/steps/region_step.dart';
import 'package:shoply/presentation/screens/onboarding/steps/welcome_step.dart';

import '../../layout/layout_matrix.dart';
// The account steps are Teil "Konto"'s; their fake gateway keeps Supabase
// out of these tests.
import '../auth/auth_fakes.dart';
import 'onboarding_fakes.dart';

class _Harness {
  final backend = FakeOnboardingBackend();
  final store = FakeModuleStore();
  final exits = <String>[];
  final gateway = FakeAuthGateway();
  bool signedIn = false;
  PendingLink? link;

  Widget app(OnboardingEntry entry) => layoutHarness(
    const LayoutCase(width: 390, scale: 1),
    ProviderScope(
      overrides: [
        ...authOverrides(gateway),
        ...onboardingOverrides(backend: backend, store: store),
        onboardingSessionProvider.overrideWithValue(() => signedIn),
        onboardingPendingLinkProvider.overrideWithValue(() => link),
        onboardingCreateListProvider.overrideWithValue(
          (name) async => (id: 'new-1', name: name),
        ),
        onboardingJoinProvider.overrideWithValue(
          (code) async =>
              code == 'AB12CD' ? (id: 'shared-1', name: 'Wocheneinkauf') : null,
        ),
        onboardingExitProvider.overrideWithValue(
          (context, location) => exits.add(location),
        ),
      ],
      child: OnboardingFlow(entry: entry),
    ),
  );

  Future<void> pump(
    WidgetTester tester, {
    OnboardingEntry entry = OnboardingEntry.start,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, kLayoutHeight * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(entry));
    await tester.pumpAndSettle();
  }
}

/// Scrolls [text] into view and taps it. [settle] false pumps a second
/// instead (a working spinner never settles).
Future<void> _tap(
  WidgetTester tester,
  String text, {
  bool settle = true,
}) async {
  await tester.ensureVisible(find.text(text, skipOffstage: false).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}

/// The semantics of the module card that starts with [title].
Future<SemanticsNode> _card(WidgetTester tester, String title) async {
  await tester.ensureVisible(find.text(title, skipOffstage: false).last);
  await tester.pumpAndSettle();
  return tester.getSemantics(find.bySemanticsLabel(RegExp('^$title')));
}

T _top<T extends Widget>(WidgetTester tester) =>
    tester.widget<T>(find.byType(T).last);

void main() {
  setUp(() async {
    OnboardingFlowPresence.reset();
    await attachPrefs();
  });

  tearDown(() => OnboardingPrefs.instance.detach());

  testWidgets('neu, Standardweg: Willkommen bis zur eigenen Liste', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);
    expect(find.byType(WelcomeStep), findsOneWidget);
    expect(OnboardingFlowPresence.active, isTrue);

    await _tap(tester, 'Get started');
    expect(find.byType(ModulesStep), findsOneWidget);

    // Teil B's region shell has nothing to show: no push, straight on.
    await _tap(tester, 'Next');
    expect(find.byType(RegionStep), findsNothing);
    expect(find.byType(AccountStep), findsOneWidget);

    h.signedIn = true;
    _top<AccountStep>(tester).onSignedIn();
    await tester.pumpAndSettle();
    expect(find.byType(NameStep), findsOneWidget);
    // After the account there is no way back (§1.1).
    expect(find.bySemanticsLabel('Back'), findsNothing);
    expect(h.store.remote?['offers'], isTrue);

    _top<NameStep>(tester).onDone();
    await tester.pumpAndSettle();
    expect(find.byType(DietStep), findsOneWidget);
    await _tap(tester, 'Vegetarian');
    await _tap(tester, 'Peanuts');
    await _tap(tester, 'Next');
    expect(h.backend.diets.single.diet, ['vegetarian', 'nut_free']);
    expect(h.backend.diets.single.allergies, ['peanuts']);

    // Calories off: no goal step.
    expect(find.byType(GoalStep), findsNothing);
    expect(find.byType(FirstListStep), findsOneWidget);
    await _tap(tester, 'Create list');
    expect(h.exits, ['/lists/new-1?name=Weekly+shop&arrival=new']);
    expect(h.backend.completed, 1);
    expect(OnboardingPrefs.instance.resumeStep, isNull);
    expect(OnboardingPrefs.instance.deviceOnboarded, isTrue);
  });

  testWidgets('mit Kalorien kommt Dein Ziel nach Ernährung', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await _tap(tester, 'Get started');
    await _tap(tester, 'Calories & health');
    await _tap(tester, 'Next');
    h.signedIn = true;
    _top<AccountStep>(tester).onSignedIn();
    await tester.pumpAndSettle();
    _top<NameStep>(tester).onSkip!();
    await tester.pumpAndSettle();
    await _tap(tester, 'Next');
    expect(find.byType(GoalStep), findsOneWidget);
    await _tap(tester, 'Next');
    expect(find.byType(FirstListStep), findsOneWidget);
    // Without body data no goal is saved, only the calories switch.
    expect(h.backend.goals, isEmpty);
    expect(h.backend.calorieSwitches, 1);
    expect(h.store.remote?['calories'], isTrue);
  });

  testWidgets('Überspringen nimmt Standardwerte und schreibt nichts', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);
    await _tap(tester, 'Get started');
    await _tap(tester, 'Calories & health');
    await _tap(tester, 'Decide later');
    h.signedIn = true;
    _top<AccountStep>(tester).onSignedIn();
    await tester.pumpAndSettle();
    // The defaults, not the toggled calories.
    expect(h.store.remote?['calories'], isFalse);
    _top<NameStep>(tester).onSkip!();
    await tester.pumpAndSettle();
    await _tap(tester, 'Skip');
    expect(h.backend.diets, isEmpty);
    await _tap(tester, 'Skip');
    expect(h.exits, ['/lists']);
    expect(h.backend.completed, 1);
  });

  testWidgets('E-Mail und Code gehören zum Schritt Konto', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await _tap(tester, 'Get started');
    await _tap(tester, 'Next');
    _top<AccountStep>(tester).onEmail();
    await tester.pumpAndSettle();
    expect(find.byType(EmailStep), findsOneWidget);
    _top<EmailStep>(tester).onCodeSent('lena@example.com');
    await tester.pumpAndSettle();
    expect(_top<CodeStep>(tester).email, 'lena@example.com');
    expect(OnboardingPrefs.instance.resumeStep, OnboardingStep.account);
    h.signedIn = true;
    _top<CodeStep>(tester).onVerified();
    await tester.pumpAndSettle();
    expect(find.byType(NameStep), findsOneWidget);
  });

  testWidgets('Bestandskonto: lokale Antworten weg, Liste von heute', (
    tester,
  ) async {
    final h = _Harness()..backend.status = AccountSetupStatus.setUp;
    await h.pump(tester);
    await _tap(tester, 'I already have an account');
    expect(_top<AccountStep>(tester).mode, AccountStepMode.login);
    h.signedIn = true;
    _top<AccountStep>(tester).onSignedIn();
    await tester.pumpAndSettle();
    expect(h.exits, ['/lists/list-9?arrival=existing']);
    expect(h.store.remote, isNull);
    expect(OnboardingPrefs.instance.deviceOnboarded, isTrue);
  });

  testWidgets('Anmelden mit neuem Konto: Module kommen nach dem Konto', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester, entry: OnboardingEntry.login);
    expect(find.byType(AccountStep), findsOneWidget);
    h.signedIn = true;
    _top<AccountStep>(tester).onSignedIn();
    await tester.pumpAndSettle();
    expect(find.byType(ModulesStep), findsOneWidget);
    expect(find.bySemanticsLabel('Back'), findsNothing);
    await _tap(tester, 'Split costs');
    await _tap(tester, 'Next');
    await tester.pumpAndSettle();
    expect(find.byType(NameStep), findsOneWidget);
    // The account exists already: the choice goes in at once.
    expect(h.store.remote?['cost_split'], isTrue);
  });

  testWidgets('Einladung: Willkommen zeigt sie, Beitreten statt Erste Liste', (
    tester,
  ) async {
    final h = _Harness()
      ..link = PendingLink(path: '/join/AB12CD', savedAt: DateTime.now());
    await h.pump(tester);
    expect(find.text('You’ve been invited to a list.'), findsOneWidget);
    await _tap(tester, 'Get started');
    await _tap(tester, 'Next');
    h.signedIn = true;
    _top<AccountStep>(tester).onSignedIn();
    await tester.pumpAndSettle();
    _top<NameStep>(tester).onDone();
    await tester.pumpAndSettle();
    await _tap(tester, 'Next');
    expect(find.byType(JoinStep), findsOneWidget);
    await _tap(tester, 'Join', settle: false);
    expect(h.exits, ['/lists/shared-1?name=Wocheneinkauf&arrival=joined']);
    expect(h.backend.completed, 1);
  });

  testWidgets('Nicht beitreten führt zur ersten Liste', (tester) async {
    final h = _Harness()
      ..link = PendingLink(path: '/join/AB12CD', savedAt: DateTime.now());
    await h.pump(tester);
    await _tap(tester, 'Get started');
    await _tap(tester, 'Next');
    h.signedIn = true;
    _top<AccountStep>(tester).onSignedIn();
    await tester.pumpAndSettle();
    _top<NameStep>(tester).onDone();
    await tester.pumpAndSettle();
    await _tap(tester, 'Next');
    await _tap(tester, 'Don’t join');
    expect(find.byType(FirstListStep), findsOneWidget);
  });

  testWidgets('Konto-Prüfung scheitert: Erneut versuchen fragt nur neu', (
    tester,
  ) async {
    final h = _Harness()..backend.failStatus = true;
    await h.pump(tester);
    await _tap(tester, 'Get started');
    await _tap(tester, 'Next');
    h.signedIn = true;
    _top<AccountStep>(tester).onSignedIn();
    await tester.pumpAndSettle();
    expect(find.byType(AccountCheckStep), findsOneWidget);
    expect(find.text('Your choices aren’t saved yet.'), findsOneWidget);
    h.backend.failStatus = false;
    await _tap(tester, 'Retry');
    expect(find.byType(NameStep), findsOneWidget);
  });

  testWidgets('Wiederaufnahme vor dem Konto: derselbe Schritt, Zurück geht', (
    tester,
  ) async {
    await attachPrefs({
      kOnboardingStepKey: 'modules',
      kPendingModulesKey: jsonEncode({'calories': true}),
    });
    final h = _Harness();
    await h.pump(tester);
    expect(find.byType(ModulesStep), findsOneWidget);
    await tester.pumpAndSettle();
    expect(
      await _card(tester, 'Calories & health'),
      isSemantics(isToggled: true),
    );
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeStep), findsOneWidget);
  });

  testWidgets('Wiederaufnahme nach dem Konto: Start im offenen Schritt', (
    tester,
  ) async {
    await attachPrefs({
      kOnboardingStepKey: 'diet',
      kOnboardingDraftKey: jsonEncode({'account_ready': true}),
    });
    final h = _Harness()..signedIn = true;
    await h.pump(tester);
    expect(find.byType(DietStep), findsOneWidget);
    expect(find.bySemanticsLabel('Back'), findsNothing);
  });

  testWidgets('Sitzung ohne Entscheidung: die App prüft das Konto selbst', (
    tester,
  ) async {
    await attachPrefs({kOnboardingStepKey: 'account'});
    final h = _Harness()..signedIn = true;
    await h.pump(tester);
    expect(find.byType(NameStep), findsOneWidget);
  });

  testWidgets('Region beim Wiederaufnehmen ohne Inhalt verschwindet', (
    tester,
  ) async {
    await attachPrefs({kOnboardingStepKey: 'region'});
    final h = _Harness();
    await h.pump(tester);
    expect(find.byType(RegionStep), findsNothing);
    expect(find.byType(AccountStep), findsOneWidget);
    // Back goes to the module step, not to the region.
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(ModulesStep), findsOneWidget);
  });

  testWidgets('/welcome bietet zuerst Anmelden, Neues Konto startet frisch', (
    tester,
  ) async {
    await attachPrefs({
      kOnboardingCompleteKey: true,
      kPendingModulesKey: jsonEncode({'calories': true}),
    });
    final h = _Harness();
    await h.pump(tester, entry: OnboardingEntry.welcomeBack);
    expect(find.text('Sign in'), findsOneWidget);
    await _tap(tester, 'Create a new account');
    expect(find.byType(ModulesStep), findsOneWidget);
    await tester.pumpAndSettle();
    expect(
      await _card(tester, 'Calories & health'),
      isSemantics(isToggled: false),
    );
    expect(AppModule.calories.onboardingDefault, isFalse);
  });
}
