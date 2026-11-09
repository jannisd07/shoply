// Layout matrix (A11) for `EmailCodePage`, the address screen behind
// "Deine E-Mail-Adresse" and "Passwort zurücksetzen", in German (the longer
// texts), in every state it has: empty, filled with the password link,
// sending, field error, status line, offline, reset.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/presentation/screens/auth/widgets/email_code_page.dart';
import 'package:shoply/presentation/screens/onboarding/widgets/onboarding_step_scaffold.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthApiException;

import '../../layout/layout_matrix.dart';
import 'auth_fakes.dart';

const _progress = StepProgress(
  step: 3,
  total: 6,
  semanticLabel: 'Schritt 3 von 6',
);

const _email = 'maximiliane.sophie.brandt-wellershoff@beispiel-postfach.de';

/// Narrowest and a common width at default and the largest text, for the
/// extra states.
const _stateCases = [
  LayoutCase(width: 320, scale: 1),
  LayoutCase(width: 320, scale: 3.1),
  LayoutCase(width: 390, scale: 1),
  LayoutCase(width: 390, scale: 3.1, bold: true),
  LayoutCase(width: 390, scale: 1, brightness: Brightness.dark),
];

Widget _host(
  BuildContext context, {
  FakeAuthGateway? gateway,
  bool offline = false,
  CodePurpose purpose = CodePurpose.signIn,
  String? initialEmail = _email,
  bool withPassword = false,
  ValueChanged<String>? onCodeSent,
}) => ProviderScope(
  overrides: [
    ...authOverrides(gateway ?? FakeAuthGateway()),
    if (offline) testOfflineProvider.overrideWith((ref) => true),
  ],
  child: SizedBox.expand(
    child: Localizations.override(
      context: context,
      locale: const Locale('de'),
      child: EmailCodePage(
        title: purpose == CodePurpose.signIn
            ? 'Deine E-Mail-Adresse'
            : 'Passwort zurücksetzen',
        message: purpose == CodePurpose.signIn
            ? 'Wir schicken dir einen Code, mit dem du dich anmeldest oder '
                  'dein Konto anlegst.'
            : 'Gib die Adresse deines Kontos ein. Wir schicken dir einen '
                  'Code, mit dem du ein neues Passwort setzt.',
        purpose: purpose,
        initialEmail: initialEmail,
        onCodeSent: onCodeSent ?? (_) {},
        onBack: () {},
        progress: purpose == CodePurpose.signIn ? _progress : null,
        onPassword: withPassword ? () {} : null,
      ),
    ),
  ),
);

/// Presses "Code senden" (by its callback, so large text that pushes it
/// below the fold does not matter).
Future<void> _send(WidgetTester tester) async {
  final button = tester.widget<AppButton>(
    find.byWidgetPredicate((w) => w is AppButton && w.label == 'Code senden'),
  );
  button.onPressed!();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  layoutMatrix(
    'EmailCodePage leer',
    (context) => _host(context, initialEmail: null),
  );

  layoutMatrix(
    'EmailCodePage mit Adresse und Passwort-Link',
    (context) => _host(context, withPassword: true),
  );

  layoutMatrix(
    'EmailCodePage sendet',
    (context) => _host(
      context,
      gateway: FakeAuthGateway()..hold = Completer<void>(),
      withPassword: true,
    ),
    cases: _stateCases,
    afterPump: _send,
  );

  layoutMatrix(
    'EmailCodePage Adresse ungültig',
    (context) => _host(
      context,
      gateway: FakeAuthGateway()
        ..nextError = AuthApiException('x', code: 'email_address_invalid'),
    ),
    cases: _stateCases,
    afterPump: _send,
  );

  layoutMatrix(
    'EmailCodePage zu viele Versuche',
    (context) => _host(
      context,
      gateway: FakeAuthGateway()
        ..nextError = AuthApiException('x', code: 'over_email_send_rate_limit'),
      withPassword: true,
    ),
    cases: _stateCases,
    afterPump: _send,
  );

  layoutMatrix(
    'EmailCodePage Serverfehler',
    (context) => _host(
      context,
      gateway: FakeAuthGateway()..nextError = Exception('boom'),
    ),
    cases: _stateCases,
    afterPump: _send,
  );

  layoutMatrix(
    'EmailCodePage offline',
    (context) => _host(context, offline: true, withPassword: true),
  );

  layoutMatrix(
    'EmailCodePage Passwort zurücksetzen',
    (context) => _host(context, purpose: CodePurpose.passwordReset),
  );

  layoutMatrix(
    'EmailCodePage tap targets',
    (context) => _host(context, withPassword: true),
    cases: const [
      LayoutCase(width: 390, scale: 1),
      LayoutCase(width: 320, scale: 3.1),
    ],
    checkTapTargets: true,
  );

  group('EmailCodePage states', () {
    Future<void> pump(WidgetTester tester, Widget Function(BuildContext) b) =>
        tester.pumpWidget(
          layoutHarness(
            const LayoutCase(width: 390, scale: 1),
            Builder(builder: b),
          ),
        );

    testWidgets('without a valid address "Code senden" is off', (tester) async {
      await pump(tester, (c) => _host(c, initialEmail: 'lena@'));
      final button = tester.widget<AppButton>(
        find.byWidgetPredicate(
          (w) => w is AppButton && w.label == 'Code senden',
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('field error shows under the field, the step stays', (
      tester,
    ) async {
      final sent = <String>[];
      await pump(
        tester,
        (c) => _host(
          c,
          gateway: FakeAuthGateway()
            ..nextError = AuthApiException('x', code: 'email_address_invalid'),
          onCodeSent: sent.add,
        ),
      );
      await _send(tester);
      expect(
        find.text('Diese E-Mail-Adresse sieht nicht richtig aus.'),
        findsOneWidget,
      );
      expect(sent, isEmpty);
    });

    testWidgets('offline: nothing is sent, the status line says why', (
      tester,
    ) async {
      final gateway = FakeAuthGateway();
      await pump(tester, (c) => _host(c, gateway: gateway, offline: true));
      await _send(tester);
      expect(gateway.calls, isEmpty);
      expect(find.byType(OnboardingStepPage), findsOneWidget);
    });

    testWidgets('reset: an unknown address is answered like a known one', (
      tester,
    ) async {
      final sent = <String>[];
      final gateway = FakeAuthGateway()
        ..nextError = AuthApiException('x', code: 'user_not_found');
      await pump(
        tester,
        (c) => _host(
          c,
          gateway: gateway,
          purpose: CodePurpose.passwordReset,
          initialEmail: '  Lena@Posteo.de ',
          onCodeSent: sent.add,
        ),
      );
      await _send(tester);
      expect(gateway.calls, ['sendPasswordResetCode:lena@posteo.de']);
      expect(sent, ['lena@posteo.de']);
    });
  });
}
