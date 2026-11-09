import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/presentation/screens/auth/auth_errors.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthApiException, AuthException, AuthRetryableFetchException;

AuthErrorKind _k(
  Object e, [
  AuthAttempt attempt = AuthAttempt.password,
  Duration? since,
]) => classifyAuthError(e, attempt: attempt, sinceCodeSent: since);

void main() {
  group('classifyAuthError (Konzept 17 §4.6, codes instead of texts)', () {
    test('network failures are offline', () {
      expect(_k(const SocketException('no route')), AuthErrorKind.offline);
      expect(_k(TimeoutException('slow')), AuthErrorKind.offline);
      expect(_k(AuthRetryableFetchException()), AuthErrorKind.offline);
      expect(
        _k(PlatformException(code: 'network_error'), AuthAttempt.google),
        AuthErrorKind.offline,
      );
    });

    test('rate limits by status and code', () {
      expect(
        _k(const AuthException('x', statusCode: '429')),
        AuthErrorKind.rateLimited,
      );
      expect(
        _k(
          AuthApiException('x', code: 'over_email_send_rate_limit'),
          AuthAttempt.sendCode,
        ),
        AuthErrorKind.rateLimited,
      );
    });

    test('password errors', () {
      expect(
        _k(AuthApiException('Invalid login', code: 'invalid_credentials')),
        AuthErrorKind.invalidCredentials,
      );
      expect(
        _k(AuthApiException('x', code: 'email_not_confirmed')),
        AuthErrorKind.emailNotConfirmed,
      );
      // Older servers without a code.
      expect(
        _k(const AuthException('Invalid login credentials')),
        AuthErrorKind.invalidCredentials,
      );
    });

    test('a wrong and an expired code share otp_expired; time decides', () {
      final e = AuthApiException(
        'Token has expired or is invalid',
        code: 'otp_expired',
      );
      expect(
        _k(e, AuthAttempt.verifyCode, const Duration(minutes: 2)),
        AuthErrorKind.codeInvalid,
      );
      expect(
        _k(e, AuthAttempt.verifyCode, const Duration(hours: 2)),
        AuthErrorKind.codeExpired,
      );
    });

    test('address errors', () {
      expect(
        _k(
          AuthApiException('x', code: 'email_address_invalid'),
          AuthAttempt.sendCode,
        ),
        AuthErrorKind.emailInvalid,
      );
      expect(
        _k(
          AuthApiException('x', code: 'validation_failed'),
          AuthAttempt.sendCode,
        ),
        AuthErrorKind.emailInvalid,
      );
    });

    test('new password errors', () {
      expect(
        _k(
          AuthApiException('x', code: 'same_password'),
          AuthAttempt.newPassword,
        ),
        AuthErrorKind.samePassword,
      );
      expect(
        _k(
          AuthApiException('x', code: 'weak_password'),
          AuthAttempt.newPassword,
        ),
        AuthErrorKind.weakPassword,
      );
      expect(
        _k(
          AuthApiException('x', code: 'user_not_found'),
          AuthAttempt.newPassword,
        ),
        AuthErrorKind.accountDeleted,
      );
    });

    test('Apple and Google: cancel, not available, failed', () {
      expect(
        _k(PlatformException(code: 'sign_in_canceled'), AuthAttempt.google),
        AuthErrorKind.cancelled,
      );
      // SupabaseService still wraps these in German texts.
      expect(
        _k(
          Exception('Apple Sign-In ist auf diesem Gerät nicht verfügbar.'),
          AuthAttempt.apple,
        ),
        AuthErrorKind.socialUnavailable,
      );
      expect(
        _k(
          Exception('Google Sign-In ist noch nicht konfiguriert.'),
          AuthAttempt.google,
        ),
        AuthErrorKind.socialUnavailable,
      );
      expect(
        _k(Exception('Apple Sign-In Fehler: boom'), AuthAttempt.apple),
        AuthErrorKind.socialFailed,
      );
      expect(
        _k(
          AuthApiException('Email exists with google', code: 'email_exists'),
          AuthAttempt.apple,
        ),
        AuthErrorKind.accountUsesGoogle,
      );
    });

    test('anything else is unknown', () {
      expect(_k(StateError('?')), AuthErrorKind.unknown);
      expect(
        _k(AuthApiException('x', code: 'unexpected_failure')),
        AuthErrorKind.unknown,
      );
    });

    test('unknown address on reset is recognised (privacy, §4.3)', () {
      expect(
        isUnknownAccountError(
          AuthApiException('Signups not allowed for otp', code: 'otp_disabled'),
        ),
        isTrue,
      );
      expect(
        isUnknownAccountError(AuthApiException('x', code: 'user_not_found')),
        isTrue,
      );
      expect(isUnknownAccountError(const SocketException('x')), isFalse);
    });
  });

  group('texts', () {
    Future<Map<AuthErrorKind, AuthErrorMessage?>> messages(
      WidgetTester tester,
      Locale locale, {
      AuthAttempt? attempt,
      bool appleAvailable = true,
    }) async {
      late Map<AuthErrorKind, AuthErrorMessage?> out;
      await tester.pumpWidget(
        Localizations(
          locale: locale,
          delegates: const [
            DefaultWidgetsLocalizations.delegate,
            DefaultMaterialLocalizations.delegate,
          ],
          child: Builder(
            builder: (context) {
              out = {
                for (final k in AuthErrorKind.values)
                  k: authErrorMessage(
                    context,
                    k,
                    attempt: attempt,
                    appleAvailable: appleAvailable,
                  ),
              };
              return const SizedBox();
            },
          ),
        ),
      );
      return out;
    }

    testWidgets('German texts follow §4.6 word for word', (tester) async {
      final de = await messages(tester, const Locale('de'));
      expect(de[AuthErrorKind.cancelled], isNull);
      expect(
        de[AuthErrorKind.offline]!.text,
        'Offline. Zum Anmelden brauchst du eine Verbindung.',
      );
      expect(
        de[AuthErrorKind.rateLimited]!.text,
        'Zu viele Versuche. Bitte warte eine Minute.',
      );
      expect(
        de[AuthErrorKind.invalidCredentials]!.text,
        'E-Mail oder Passwort stimmt nicht.',
      );
      expect(de[AuthErrorKind.invalidCredentials]!.actionLabel, 'Code senden');
      expect(
        de[AuthErrorKind.emailNotConfirmed]!.text,
        'Bestätige zuerst deine E-Mail-Adresse.',
      );
      expect(
        de[AuthErrorKind.codeInvalid]!.text,
        'Der Code stimmt nicht. Prüfe ihn oder lass dir einen neuen schicken.',
      );
      expect(de[AuthErrorKind.codeInvalid]!.actionLabel, 'Neuen Code senden');
      expect(de[AuthErrorKind.codeExpired]!.text, 'Der Code ist abgelaufen.');
      expect(
        de[AuthErrorKind.emailInvalid]!.text,
        'Diese E-Mail-Adresse sieht nicht richtig aus.',
      );
      expect(
        de[AuthErrorKind.accountUsesGoogle]!.text,
        'Diese Adresse gehört zu einem Konto mit Google.',
      );
      expect(
        de[AuthErrorKind.accountUsesGoogle]!.actionLabel,
        'Mit Google fortfahren',
      );
      expect(
        de[AuthErrorKind.socialFailed]!.text,
        'Anmelden mit Google hat nicht geklappt.',
      );
      expect(de[AuthErrorKind.socialFailed]!.actionLabel, 'Erneut versuchen');
      expect(
        de[AuthErrorKind.accountDeleted]!.text,
        'Dieses Konto gibt es nicht mehr.',
      );
      expect(de[AuthErrorKind.unknown]!.text, 'Das hat nicht geklappt.');
      expect(de[AuthErrorKind.unknown]!.actionLabel, 'Erneut versuchen');

      // With a retry button the text does not ask "Erneut versuchen?".
      for (final m in de.values.whereType<AuthErrorMessage>()) {
        expect(m.text.contains('?'), isFalse, reason: m.text);
      }
    });

    testWidgets('Apple rows name Apple; Google without Apple says email', (
      tester,
    ) async {
      final apple = await messages(
        tester,
        const Locale('de'),
        attempt: AuthAttempt.apple,
      );
      expect(
        apple[AuthErrorKind.socialUnavailable]!.text,
        'Anmelden mit Apple klappt gerade nicht. Nimm Google oder E-Mail.',
      );
      expect(
        apple[AuthErrorKind.socialFailed]!.text,
        'Anmelden mit Apple hat nicht geklappt.',
      );
      final google = await messages(
        tester,
        const Locale('de'),
        attempt: AuthAttempt.google,
        appleAvailable: false,
      );
      expect(
        google[AuthErrorKind.socialUnavailable]!.text,
        'Anmelden mit Google klappt gerade nicht. Nimm E-Mail.',
      );
    });

    testWidgets('no raw error and no "Shoply" in any text', (tester) async {
      for (final locale in const [Locale('de'), Locale('en')]) {
        final all = await messages(tester, locale);
        for (final m in all.values.whereType<AuthErrorMessage>()) {
          expect(m.text, isNot(contains('Exception')));
          expect(m.text, isNot(contains('auth_')));
          expect(m.text.toLowerCase(), isNot(contains('shoply')));
        }
      }
    });
  });
}
