// Layout matrix (320–440 pt, text up to 3.1×, bold, dark, contrast) for
// every account screen, in German (the longer texts).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/presentation/screens/auth/password_login_screen.dart';
import 'package:shoply/presentation/screens/auth/reset_password_screen.dart';
import 'package:shoply/presentation/screens/auth/steps/account_step.dart';
import 'package:shoply/presentation/screens/auth/steps/code_step.dart';
import 'package:shoply/presentation/screens/auth/steps/email_step.dart';
import 'package:shoply/presentation/screens/auth/steps/name_step.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_steps.dart';
import 'package:shoply/presentation/screens/onboarding/widgets/onboarding_step_scaffold.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthApiException;

import '../../layout/layout_matrix.dart';
import 'auth_fakes.dart';

const _progress = StepProgress(
  step: 3,
  total: 6,
  semanticLabel: 'Schritt 3 von 6',
);

Widget _host(
  BuildContext context,
  Widget child, {
  FakeAuthGateway? gateway,
  bool offline = false,
}) => ProviderScope(
  overrides: [
    ...authOverrides(gateway ?? FakeAuthGateway(suggestedFirstName: 'Lena')),
    if (offline) testOfflineProvider.overrideWith((ref) => true),
  ],
  child: SizedBox.expand(
    child: Localizations.override(
      context: context,
      locale: const Locale('de'),
      child: child,
    ),
  ),
);

/// Scrolls the step until field [index] is built (large text pushes it
/// below the fold), then types into it.
Future<void> _type(WidgetTester tester, int index, String text) async {
  final fields = find.byType(EditableText);
  for (var i = 0; i < 20 && fields.evaluate().length <= index; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pump();
  }
  await tester.ensureVisible(fields.at(index));
  await tester.enterText(fields.at(index), text);
  await tester.pump();
}

void main() {
  layoutMatrix(
    'AccountStep Konto anlegen',
    (context) => _host(
      context,
      AccountStep(
        onEmail: () {},
        onSignedIn: () {},
        onBack: () {},
        progress: _progress,
      ),
    ),
  );

  layoutMatrix(
    'AccountStep Anmelden, offline',
    (context) => _host(
      context,
      AccountStep(
        mode: AccountStepMode.login,
        onEmail: () {},
        onSignedIn: () {},
        onPassword: () {},
        onBack: () {},
      ),
      offline: true,
    ),
  );

  layoutMatrix(
    'AccountStep tap targets',
    (context) => _host(
      context,
      AccountStep(
        mode: AccountStepMode.login,
        onEmail: () {},
        onSignedIn: () {},
        onPassword: () {},
        onBack: () {},
      ),
    ),
    cases: const [
      LayoutCase(width: 390, scale: 1),
      LayoutCase(width: 320, scale: 3.1),
    ],
    checkTapTargets: true,
  );

  layoutMatrix(
    'EmailStep mit Passwort-Link',
    (context) => _host(
      context,
      EmailStep(
        onCodeSent: (_) {},
        onBack: () {},
        progress: _progress,
        initialEmail: 'lena.berger@posteo.de',
        onPassword: () {},
      ),
    ),
  );

  layoutMatrix(
    'CodeStep falscher Code',
    (context) {
      final gateway = FakeAuthGateway()
        ..nextError = AuthApiException('x', code: 'otp_expired');
      return _host(
        context,
        CodeStep(
          email: 'lena.berger@posteo.de',
          onVerified: () {},
          onBack: () {},
          progress: _progress,
        ),
        gateway: gateway,
      );
    },
    afterPump: (tester) async {
      await _type(tester, 0, '111111');
      await tester.pump(const Duration(milliseconds: 600));
    },
  );

  layoutMatrix(
    'CodeStep Zurücksetzen',
    (context) => _host(
      context,
      CodeStep(
        email: 'lena.berger@posteo.de',
        purpose: CodePurpose.passwordReset,
        onVerified: () {},
        onBack: () {},
      ),
    ),
  );

  layoutMatrix(
    'NameStep',
    (context) => _host(
      context,
      NameStep(onDone: () {}, onSkip: () {}, progress: _progress),
    ),
  );

  layoutMatrix(
    'PasswordLoginScreen falsche Daten',
    (context) {
      final gateway = FakeAuthGateway()
        ..nextError = AuthApiException('x', code: 'invalid_credentials');
      return _host(
        context,
        PasswordLoginScreen(onSignedIn: () {}),
        gateway: gateway,
      );
    },
    afterPump: (tester) async {
      await _type(tester, 0, 'jannis.dietrich@beispiel.de');
      await _type(tester, 1, 'Geheim123');
      await tester.tap(find.text('Anmelden').last, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 600));
    },
  );

  layoutMatrix(
    'ResetPasswordRequestScreen',
    (context) => _host(
      context,
      const ResetPasswordRequestScreen(initialEmail: 'jannis@beispiel.de'),
    ),
  );

  layoutMatrix(
    'ResetPasswordScreen',
    (context) => _host(context, const ResetPasswordScreen()),
    afterPump: (tester) async {
      await _type(tester, 0, 'Abcdefgh');
      await tester.pump(const Duration(milliseconds: 600));
    },
  );
}
