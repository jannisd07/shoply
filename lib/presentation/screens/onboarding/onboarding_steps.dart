/// The steps of the first-start flow (Konzept 17 §1.1) and their ids in
/// `/onboarding?step=<id>`. Shared by the flow and the account steps.
enum OnboardingStep {
  welcome('welcome'),
  modules('modules'),

  /// Only with the offers module on (B's `OffersSetupStep`).
  region('region'),
  account('account'),
  email('email'),
  code('code'),

  /// From here on there is no way back to the steps before (§1.1).
  name('name'),
  diet('diet'),

  /// Only with the calories module on.
  goal('goal'),
  firstList('first-list');

  const OnboardingStep(this.id);

  /// Value of the `step` query parameter.
  final String id;

  static OnboardingStep? fromId(String? id) {
    for (final s in values) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// How the account steps are used: in the new-user flow (3.5–3.7) or from
/// "Ich habe schon ein Konto" (4.1).
enum AccountStepMode { signUp, login }

/// Query parameter for the list the flow opens at the end (Konzept 17
/// §3.12): `/lists/<id>?arrival=new|joined|existing`.
enum OnboardingArrival {
  /// After "Liste anlegen": add field focused, tip T1.
  created('new'),

  /// After joining a shared list: no keyboard, tip T5.
  joined('joined'),

  /// An account that was already set up: one status line, no tip.
  existing('existing');

  const OnboardingArrival(this.id);

  final String id;

  static const queryKey = 'arrival';

  static OnboardingArrival? fromId(String? id) {
    for (final a in values) {
      if (a.id == id) return a;
    }
    return null;
  }
}
