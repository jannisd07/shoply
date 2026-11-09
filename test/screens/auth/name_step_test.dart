import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/presentation/screens/auth/auth_gateway.dart';
import 'package:shoply/presentation/screens/auth/name_save.dart';
import 'package:shoply/presentation/screens/auth/steps/name_step.dart';

import 'auth_fakes.dart';

void main() {
  group('first name suggestion (§3.8, never the email prefix)', () {
    test('Apple/Google given name, else first word of the full name', () {
      expect(firstNameFromMetadata({'given_name': 'Lena'}), 'Lena');
      expect(firstNameFromMetadata({'full_name': 'Lena Berger'}), 'Lena');
      expect(firstNameFromMetadata({'name': '  Jannis  Dietrich '}), 'Jannis');
    });

    test('nothing that comes from the email', () {
      expect(
        firstNameFromMetadata({'name': 'lena.berger'}, email: 'lena.berger@x.de'),
        isNull,
      );
      expect(firstNameFromMetadata({'name': 'lena@x.de'}), isNull);
      expect(firstNameFromMetadata({'email': 'lena@x.de'}), isNull);
      expect(firstNameFromMetadata(null), isNull);
    });
  });

  test('initials: one word one letter, two words first and last', () {
    expect(nameInitials('lena'), 'L');
    expect(nameInitials('Lena Berger'), 'LB');
    expect(nameInitials('Lena Marie Berger'), 'LB');
    expect(nameInitials('  '), '');
  });

  group('NameStep', () {
    late FakeAuthGateway gateway;
    var done = 0;

    setUp(() {
      gateway = FakeAuthGateway(suggestedFirstName: 'Lena');
      done = 0;
    });

    Widget step() => NameStep(onDone: () => done++, onSkip: () {});

    testWidgets('prefilled first name and live initials', (tester) async {
      await pumpAuth(tester, step(), gateway);
      expect(find.text('What’s your name?'), findsOneWidget);
      expect(find.text('Lena'), findsOneWidget);
      expect(find.text('L'), findsOneWidget);

      await tester.enterText(find.byType(CupertinoTextField), 'Lena Berger');
      await tester.pump();
      expect(find.text('LB'), findsOneWidget);
    });

    testWidgets('no back button, skip is there', (tester) async {
      await pumpAuth(tester, step(), gateway);
      expect(find.bySemanticsLabel('Back'), findsNothing);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('continue moves on at once and saves in the background', (
      tester,
    ) async {
      await pumpAuth(tester, step(), gateway);
      await tester.tap(find.text('Continue'));
      expect(done, 1);
      await tester.pump();
      expect(gateway.calls, ['saveDisplayName:Lena']);
    });

    testWidgets('empty name writes nothing', (tester) async {
      gateway.suggestedFirstName = null;
      await pumpAuth(tester, step(), gateway);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(done, 1);
      expect(gateway.calls, isEmpty);
    });

    testWidgets('a failed save shows in the next step with retry', (
      tester,
    ) async {
      gateway.nextError = Exception('offline');
      await pumpAuth(tester, step(), gateway);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(done, 1);

      // The flow puts NameSaveStatus into the next step.
      await tester.pumpWidget(authApp(const NameSaveStatus(), gateway));
      await tester.pump();
      expect(find.text('Your name isn’t saved yet.'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(gateway.calls, ['saveDisplayName:Lena', 'saveDisplayName:Lena']);
      expect(find.text('Your name isn’t saved yet.'), findsNothing);
    });

    testWidgets('after a failure it saves again when back online', (
      tester,
    ) async {
      gateway.nextError = Exception('offline');
      await pumpAuth(tester, step(), gateway);
      setOffline(tester, true);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(authContainer(tester).read(nameSaveProvider).failed, isTrue);

      setOffline(tester, false);
      await tester.pump();
      await tester.pump();
      expect(gateway.calls, ['saveDisplayName:Lena', 'saveDisplayName:Lena']);
      expect(authContainer(tester).read(nameSaveProvider).failed, isFalse);
    });
  });
}
