import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_prefs.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_steps.dart';
import 'package:shoply/routes/app_router.dart';
import 'package:shoply/routes/route_paths.dart';

/// Runs [entryRedirect] for [path] and records remembered/consumed links.
({String? to, String? remembered, bool consumed}) _go(
  String path,
  EntryState state,
) {
  final uri = Uri.parse(path);
  String? remembered;
  var consumed = false;
  final to = entryRedirect(
    uri,
    uri.path,
    state,
    remember: (p) => remembered = p,
    consumeLink: () => consumed = true,
  );
  return (to: to, remembered: remembered, consumed: consumed);
}

void main() {
  const fresh = EntryState(signedIn: false);
  const returning = EntryState(signedIn: false, deviceOnboarded: true);
  const signedIn = EntryState(signedIn: true, deviceOnboarded: true);

  group('neu, ohne Konto', () {
    test('every private route leads to the onboarding', () {
      expect(_go('/home', fresh).to, RoutePaths.onboarding);
      expect(_go('/lists', fresh).to, RoutePaths.onboarding);
      expect(_go('/profile', fresh).to, RoutePaths.onboarding);
      expect(_go(RoutePaths.namePrompt, fresh).to, RoutePaths.onboarding);
    });

    test('the onboarding, Anmelden and E-Mail stay', () {
      expect(_go(RoutePaths.onboarding, fresh).to, isNull);
      expect(_go(RoutePaths.login, fresh).to, isNull);
      expect(_go('/login?method=password', fresh).to, isNull);
      expect(_go(RoutePaths.signup, fresh).to, isNull);
    });

    test('a run in progress resumes instead of the Anmelden variant', () {
      const running = EntryState(
        signedIn: false,
        deviceOnboarded: true,
        resumeStep: OnboardingStep.region,
      );
      expect(_go(RoutePaths.welcome, running).to, RoutePaths.onboarding);
      expect(_go(RoutePaths.onboarding, running).to, isNull);
      expect(_go('/home', running).to, RoutePaths.onboarding);
    });
  });

  group('Bestand, abgemeldet', () {
    test('/onboarding shows the Anmelden variant /welcome', () {
      expect(_go(RoutePaths.onboarding, returning).to, RoutePaths.welcome);
      expect(_go(RoutePaths.welcome, returning).to, isNull);
      expect(_go('/home', returning).to, RoutePaths.welcome);
    });

    test('signed in, entry routes lead home unless the flow decides', () {
      expect(_go(RoutePaths.welcome, signedIn).to, RoutePaths.home);
      expect(_go(RoutePaths.onboarding, signedIn).to, RoutePaths.home);
      expect(_go(RoutePaths.login, signedIn).to, RoutePaths.home);
      const deciding = EntryState(
        signedIn: true,
        deviceOnboarded: true,
        flowActive: true,
      );
      expect(_go(RoutePaths.login, deciding).to, isNull);
      expect(_go(RoutePaths.onboarding, deciding).to, isNull);
    });

    test('app routes stay open when signed in', () {
      expect(_go('/home', signedIn).to, isNull);
      expect(_go('/lists/abc', signedIn).to, isNull);
      expect(_go('/profile', signedIn).to, isNull);
    });
  });

  group('neues Konto, Ablauf nicht beendet (5.5)', () {
    const open = EntryState(signedIn: true, resumeStep: OnboardingStep.diet);

    test('every app route goes back to the onboarding', () {
      expect(_go('/home', open).to, RoutePaths.onboarding);
      expect(_go('/lists/abc', open).to, RoutePaths.onboarding);
    });

    test('the flow routes stay', () {
      expect(_go(RoutePaths.onboarding, open).to, isNull);
      expect(_go(RoutePaths.namePrompt, open).to, isNull);
    });
  });

  group('Einladung', () {
    test('an invite without a session is remembered, Willkommen opens', () {
      final r = _go('/invite/list-1?code=AB12CD', fresh);
      expect(r.to, RoutePaths.onboarding);
      expect(r.remembered, '/invite/list-1?code=AB12CD');

      final j = _go('/join/AB12CD', returning);
      expect(j.to, RoutePaths.welcome);
      expect(j.remembered, '/join/AB12CD');

      expect(_go('/list/list-1', fresh).remembered, '/list/list-1');
      expect(_go('/lists/list-1', fresh).remembered, '/lists/list-1');
      expect(_go('/author/a1', fresh).remembered, '/author/a1');
    });

    test('the remembered link opens once home is reached', () {
      final state = EntryState(
        signedIn: true,
        deviceOnboarded: true,
        pendingLink: PendingLink(
          path: '/join/AB12CD',
          savedAt: DateTime(2026, 11, 8),
        ),
      );
      final r = _go('/home', state);
      expect(r.to, '/join/AB12CD');
      expect(r.consumed, isTrue);
      // Only on the tab roots, not in the middle of something else.
      expect(_go('/recipes', state).to, isNull);
    });

    test('a link is remembered for seven days', () {
      final link = PendingLink(
        path: '/join/AB12CD',
        savedAt: DateTime(2026, 11, 1),
      );
      expect(link.isExpired(DateTime(2026, 11, 7)), isFalse);
      expect(link.isExpired(DateTime(2026, 11, 9)), isTrue);
      expect(link.joinCode, 'AB12CD');
      expect(
        PendingLink(
          path: '/invite/l1?code=XY',
          savedAt: DateTime(2026),
        ).joinCode,
        'XY',
      );
      expect(
        PendingLink(path: '/invite/l1', savedAt: DateTime(2026)).joinCode,
        isNull,
      );
      expect(
        PendingLink(path: '/author/a1', savedAt: DateTime(2026)).isInvitation,
        isFalse,
      );
    });
  });

  group('Rezept-Link', () {
    test('a shared recipe is readable without an account', () {
      final r = _go('/recipe/r1', fresh);
      expect(r.to, isNull);
      expect(r.remembered, isNull);
      expect(_go('/recipe/r1', signedIn).to, isNull);
    });
  });

  group('Reset', () {
    test('/reset-password is open with and without a session', () {
      expect(_go(RoutePaths.resetPassword, fresh).to, isNull);
      expect(_go(RoutePaths.resetPassword, signedIn).to, isNull);
    });

    test('a reset that was interrupted continues at the next start', () {
      const pending = EntryState(
        signedIn: true,
        deviceOnboarded: true,
        passwordResetPending: true,
      );
      expect(_go('/home', pending).to, RoutePaths.resetPassword);
      expect(_go(RoutePaths.resetPassword, pending).to, isNull);
    });
  });

  test('isPrivateLink knows shared content, not recipes or tab roots', () {
    expect(isPrivateLink('/invite/x'), isTrue);
    expect(isPrivateLink('/join/x'), isTrue);
    expect(isPrivateLink('/lists/x'), isTrue);
    expect(isPrivateLink('/lists'), isFalse);
    expect(isPrivateLink('/recipe/x'), isFalse);
  });
}
