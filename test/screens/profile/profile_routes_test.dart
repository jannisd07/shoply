import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/presentation/screens/profile/account/account_screen.dart';
import 'package:shoply/presentation/screens/profile/account/delete_account_screen.dart';
import 'package:shoply/presentation/screens/profile/account/profile_edit_screen.dart';
import 'package:shoply/presentation/screens/profile/profile_root_data.dart';
import 'package:shoply/presentation/screens/profile/profile_root_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/appearance_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/diet_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/help_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/language_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/legal_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/lists_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/modules_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/notifications_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/personal_settings_screen.dart';
import 'package:shoply/presentation/widgets/design/row_highlight.dart';
import 'package:shoply/routes/areas/avo_routes.dart';
import 'package:shoply/routes/areas/calories_routes.dart';
import 'package:shoply/routes/areas/history_routes.dart';
import 'package:shoply/routes/areas/offers_routes.dart';
import 'package:shoply/routes/areas/plan_routes.dart';
import 'package:shoply/routes/areas/profile_routes.dart';
import 'package:shoply/routes/areas/system_routes.dart';
import 'package:shoply/routes/route_error_screen.dart';
import 'package:shoply/routes/route_paths.dart';

/// Builds the widget [location] resolves to without pumping it (the pages
/// are filled by other parts and need their own fakes).
Widget _resolve(GoRouter router, BuildContext context, String location) {
  final matches = router.configuration.findMatch(location);
  expect(matches.isError, isFalse, reason: location);
  final match = matches.last;
  final route = match.route;
  final state = match.buildState(router.configuration, matches);
  final builder = route.builder;
  if (builder != null) return builder(context, state);
  final page = route.pageBuilder!(context, state);
  return (page as NoTransitionPage<void>).child;
}

void main() {
  late GoRouter router;
  late BuildContext context;

  Future<void> setUpRouter(WidgetTester tester) async {
    router = GoRouter(routes: [...profileBranchRoutes, ...profileRoutes]);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox.shrink();
        },
      ),
    );
  }

  test('every settings page of E18-11 is registered', () {
    final patterns = collectRoutePatterns(profileBranchRoutes);
    expect(
      patterns,
      containsAll([
        RoutePaths.profile,
        RoutePaths.settings,
        RoutePaths.settingsProfile,
        RoutePaths.settingsModules,
        RoutePaths.settingsDiet,
        RoutePaths.settingsPersonal,
        RoutePaths.settingsLists,
        RoutePaths.settingsNotifications,
        RoutePaths.settingsAppearance,
        RoutePaths.settingsLanguage,
        RoutePaths.settingsHelp,
        RoutePaths.settingsLegal,
        RoutePaths.settingsLegalSources,
        '${RoutePaths.settingsLegal}/:doc',
        RoutePaths.settingsAccount,
        RoutePaths.settingsAccountDelete,
      ]),
    );
  });

  test("Teil B's settings routes stay mounted below /settings", () {
    final settings = profileBranchRoutes.whereType<GoRoute>().singleWhere(
      (r) => r.path == RoutePaths.settings,
    );
    expect(
      settings.routes.length,
      profileSettingsRoutes.length +
          offersSettingsRoutes.length +
          avoSettingsRoutes.length +
          planSettingsRoutes.length +
          caloriesSettingsRoutes.length +
          historySettingsRoutes.length +
          systemSettingsRoutes.length,
    );
  });

  testWidgets('/profile and /settings both show the profile root', (
    tester,
  ) async {
    await setUpRouter(tester);
    expect(
      _resolve(router, context, RoutePaths.profile),
      isA<ProfileRootScreen>(),
    );
    expect(
      _resolve(router, context, RoutePaths.settings),
      isA<ProfileRootScreen>(),
    );
  });

  testWidgets('each page gets ?row= as highlight scope and parameter', (
    tester,
  ) async {
    await setUpRouter(tester);
    final pages = <String, Type>{
      RoutePaths.settingsProfile: ProfileEditScreen,
      RoutePaths.settingsModules: ModulesSettingsScreen,
      RoutePaths.settingsDiet: DietSettingsScreen,
      RoutePaths.settingsPersonal: PersonalSettingsScreen,
      RoutePaths.settingsLists: ListsSettingsScreen,
      RoutePaths.settingsNotifications: NotificationsSettingsScreen,
      RoutePaths.settingsAppearance: AppearanceSettingsScreen,
      RoutePaths.settingsLanguage: LanguageSettingsScreen,
      RoutePaths.settingsHelp: HelpSettingsScreen,
      RoutePaths.settingsLegal: LegalSettingsScreen,
      RoutePaths.settingsLegalSources: DataSourcesScreen,
      RoutePaths.settingsAccount: AccountScreen,
      RoutePaths.settingsAccountDelete: DeleteAccountScreen,
    };
    for (final entry in pages.entries) {
      final location = RoutePaths.settingsRow(entry.key, 'page.row');
      final widget = _resolve(router, context, location);
      expect(widget, isA<RowHighlightScope>(), reason: location);
      final scope = widget as RowHighlightScope;
      expect(scope.rowId, 'page.row', reason: location);
      expect(scope.child.runtimeType, entry.value, reason: location);
      expect(
        (scope.child as dynamic).highlightRowId as String?,
        'page.row',
        reason: location,
      );
      final plain = _resolve(router, context, entry.key) as RowHighlightScope;
      expect(plain.rowId, isNull, reason: entry.key);
    }
  });

  testWidgets('legal documents by id, unknown ids show the error page', (
    tester,
  ) async {
    await setUpRouter(tester);
    for (final d in LegalDocument.values) {
      final widget =
          _resolve(router, context, RoutePaths.settingsLegalDocument(d.id))
              as RowHighlightScope;
      expect((widget.child as LegalDocumentScreen).document, d);
    }
    expect(
      _resolve(router, context, RoutePaths.settingsLegalDocument('nope')),
      isA<RouteErrorScreen>(),
    );
  });

  testWidgets('/diet-preferences opens the diet page (alias)', (tester) async {
    await setUpRouter(tester);
    final widget =
        _resolve(router, context, '/diet-preferences?row=diet.allergies')
            as RowHighlightScope;
    expect(widget.rowId, 'diet.allergies');
    expect(
      (widget.child as DietSettingsScreen).highlightRowId,
      'diet.allergies',
    );
  });
}
