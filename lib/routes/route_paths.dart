/// Route paths of all areas, in one place so both parts link the same way.
///
/// Teil A owns this file. Teil B owns every route below its roots
/// ([avo], [calories], [plan], [offers], [history]) and defines them in
/// `lib/routes/areas/<area>_routes.dart`. B screens link to A screens (and the
/// other way round) only through these constants.
abstract final class RoutePaths {
  // --- Teil A ---------------------------------------------------------------
  static const onboarding = '/onboarding';
  static const welcome = '/welcome';
  static const login = '/login';
  static const signup = '/signup';
  static const resetPassword = '/reset-password';
  static const namePrompt = '/name-prompt';

  /// `/login?method=password` (Konzept 17 §4.2) and `?method=reset` (§4.3).
  static const loginPassword = '/login?method=password';
  static const loginReset = '/login?method=reset';

  /// A step of the first-start flow (`/onboarding?step=<id>`, Konzept 17).
  static String onboardingStep(String stepId) =>
      Uri(path: onboarding, queryParameters: {'step': stepId}).toString();

  /// Invitation by share code (`/join/<code>`, Konzept 17 §5.1).
  static const join = '/join';
  static String joinCode(String code) => '$join/$code';

  /// Tab "Home".
  static const home = '/home';

  /// Tab "Listen" (list overview). Registered from S2 on; before that the
  /// overview lives on [home].
  static const lists = '/lists';

  /// One list, full screen.
  static String list(String listId, {String? name}) => Uri(
    path: '$lists/$listId',
    queryParameters: name == null ? null : {'name': name},
  ).toString();

  /// One list as the end of the onboarding (Konzept 17 §3.12):
  /// `arrival` is `new`, `joined` or `existing` (`OnboardingArrival`).
  static String listArrival(String listId, String arrival, {String? name}) =>
      Uri(
        path: '$lists/$listId',
        queryParameters: {if (name != null) 'name': name, 'arrival': arrival},
      ).toString();

  /// Shopping mode of a list (full screen above the tab bar).
  static String shopping(String listId) => '$lists/$listId/shopping';

  /// Tab "Rezepte".
  static const recipes = '/recipes';

  /// The Wochenplan segment inside the Rezepte tab (its content is Teil B's).
  static const recipesPlanSegment = '/recipes?segment=plan';

  /// One recipe (inside the Rezepte tab).
  static String recipe(String recipeId) => '$recipes/$recipeId';

  /// Tab "Profil".
  static const profile = '/profile';
  static const dietPreferences = '/diet-preferences';

  /// Settings pages live below this path (in the Profil tab). Teil B mounts
  /// its pages here: `/settings/offers`, `/settings/avo`, `/settings/plan`,
  /// `/settings/health`.
  static const settings = '/settings';

  /// Paywall (full screen); `?feature=<id>` names the feature that led here.
  /// Registered with A9.
  static const pro = '/pro';

  /// The paywall for one feature (`/pro?feature=<id>`).
  static String proFor(String feature) =>
      Uri(path: pro, queryParameters: {'feature': feature}).toString();

  // --- Teil B roots -----------------------------------------------------------
  /// Tab "Avo" from S2 on (before that a full-screen route).
  static const avo = '/avo';

  /// Kalorien: full-screen push screens (a tab until S2).
  static const calories = '/calories';

  /// Wochenplan push screens below this root (the plan overview itself is
  /// [recipesPlanSegment]).
  static const plan = '/plan';

  /// Angebote: "Angebote der Woche", "Preise & Angebote" and the rest.
  static const offers = '/offers';

  /// Verlauf, Ersparnis, Kosten teilen.
  static const history = '/history';

  /// Further roots reserved for Teil B (Konzept 12): open amounts, choosing a
  /// store, finishing a shopping trip.
  static const splits = '/splits';
  static const stores = '/stores';
  static const checkout = '/checkout';

  // --- Debug ------------------------------------------------------------------
  /// Component gallery (`ComponentGallery`): every design component in light,
  /// dark, AX5 and Increase Contrast, to compare with D2. Registered in debug
  /// builds only (`kDebugMode`); release builds show the error page.
  static const debugComponents = '/debug/components';
}
