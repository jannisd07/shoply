// Fakes and a pump helper for the A8 settings pages (Teil "Seiten").
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/models/user_model.dart';
import 'package:shoply/data/models/user_preferences_model.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/theme_service.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_data.dart';
import 'package:shoply/presentation/screens/profile/settings/data/notification_settings.dart';
import 'package:shoply/presentation/screens/profile/settings/data/profile_settings.dart';
import 'package:shoply/presentation/screens/profile/settings/data/settings_services.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/theme_provider.dart';
import 'package:shoply/presentation/widgets/design/in_app_browser_page.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

import '../../../layout/layout_matrix.dart';

/// The example person of Konzept 18 §2.
UserModel exampleUser({
  List<String> diet = const ['vegetarian'],
  List<String> allergies = const ['peanuts'],
  int? age = 34,
  double? height = 182,
  String? heightUnit = 'cm',
  String? gender = 'male',
}) => UserModel(
  id: 'u1',
  email: 'jannis.d@beispiel.de',
  displayName: 'Jannis Dietrich',
  age: age,
  height: height,
  heightUnit: heightUnit,
  gender: gender,
  dietPreferences: diet,
  allergies: allergies,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 11, 7),
);

/// Records the account writes and serves them back as the profile.
class FakeProfileBackend implements ProfileSettingsBackend {
  FakeProfileBackend([UserModel? user]) : user = user ?? exampleUser();

  UserModel user;
  bool fail = false;
  final List<({List<String> diet, List<String> allergies})> dietWrites = [];
  final List<PersonalSettings> personalWrites = [];
  final List<String> languageWrites = [];

  @override
  Future<void> saveDiet({
    required List<String> dietPreferences,
    required List<String> allergies,
  }) async {
    if (fail) throw StateError('offline');
    dietWrites.add((diet: dietPreferences, allergies: allergies));
    user = UserModel(
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      age: user.age,
      height: user.height,
      heightUnit: user.heightUnit,
      gender: user.gender,
      dietPreferences: dietPreferences,
      allergies: allergies,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    );
  }

  @override
  Future<void> savePersonal(PersonalSettings values) async {
    if (fail) throw StateError('offline');
    personalWrites.add(values);
    user = UserModel(
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      age: values.age,
      height: values.heightCm,
      heightUnit: values.unit.storageKey,
      gender: values.gender,
      dietPreferences: user.dietPreferences,
      allergies: user.allergies,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    );
  }

  @override
  Future<void> saveLanguage(String languageCode) async {
    languageWrites.add(languageCode);
  }
}

/// Records the system calls.
class FakeExternalActions implements SettingsExternalActions {
  bool mailOpens = true;

  /// What [openUrl] answers (false: nothing could open the link).
  bool urlOpens = true;
  final List<({String to, String subject, String? body})> mails = [];
  final List<Uri> urls = [];
  final List<String> copied = [];
  int appSettings = 0;
  int reviews = 0;

  @override
  Future<bool> openMail({
    required String to,
    required String subject,
    String? body,
  }) async {
    mails.add((to: to, subject: subject, body: body));
    return mailOpens;
  }

  @override
  Future<bool> openUrl(Uri url) async {
    urls.add(url);
    return urlOpens;
  }

  @override
  Future<void> openAppSettings() async => appSettings++;

  @override
  Future<void> requestReview() async => reviews++;

  @override
  Future<void> copy(String text) async => copied.add(text);
}

/// In-memory module choices.
class FakeModuleStore implements ModuleStore {
  FakeModuleStore([this.local]);

  Map<String, bool>? local;
  Map<String, bool>? remote;

  @override
  Future<Map<String, dynamic>?> readLocal() async => local;

  @override
  Future<void> writeLocal(Map<String, bool> json) async => local = json;

  @override
  Future<bool?> readLegacyCalories() async => null;

  @override
  Future<Map<String, dynamic>?> readRemote() async => null;

  @override
  Future<void> writeRemote(Map<String, bool> json) async => remote = json;
}

/// Module choices of the example person: offers, Avo and cost split on,
/// calories off.
Map<String, bool> exampleModules({bool calories = false}) => {
  'offers': true,
  'meal_plan': true,
  'avo': true,
  'calories': calories,
  'cost_split': true,
};

/// Notification choices kept in memory.
class FakeNotificationBackend implements NotificationSettingsBackend {
  FakeNotificationBackend({this.master = true});

  bool master;
  final Map<NotificationSetting, bool> values = {};
  final Map<NotificationTimeSlot, ReminderTime> times = {};

  @override
  Future<NotificationSettings> load() async => NotificationSettings(
    master: master,
    values: {...values},
    times: {...times},
    loaded: true,
  );

  @override
  Future<bool?> refreshMaster() async => master;

  @override
  Future<void> setMaster(bool on) async => master = on;

  @override
  Future<void> setEnabled(NotificationSetting setting, bool on) async =>
      values[setting] = on;

  @override
  Future<void> setTime(NotificationTimeSlot slot, ReminderTime time) async =>
      times[slot] = time;
}

/// A permission that changes when asked.
class FakePermissionBackend implements NotificationPermissionBackend {
  FakePermissionBackend(this.state, {this.afterRequest});

  NotificationPermissionState state;
  final NotificationPermissionState? afterRequest;
  int requests = 0;

  @override
  Future<NotificationPermissionState> status() async => state;

  @override
  Future<bool> request() async {
    requests++;
    final next = afterRequest;
    if (next != null) state = next;
    return state == NotificationPermissionState.allowed;
  }
}

/// A page from memory, or a failure.
class FakeWebLoader implements WebDocumentLoader {
  FakeWebLoader({this.document, this.fail = false});

  WebDocument? document;
  bool fail;
  int loads = 0;
  final List<Uri> urls = [];

  @override
  Future<WebDocument> load(Uri url) async {
    loads++;
    urls.add(url);
    if (fail) throw Exception('offline');
    return document ?? const WebDocument(blocks: []);
  }
}

/// Theme writes without Supabase.
class FakeThemeService extends ThemeService {
  final List<String> saved = [];

  @override
  Future<UserPreferencesModel?> getUserPreferences() async => null;

  @override
  Future<void> saveThemeMode(String themeMode) async => saved.add(themeMode);
}

/// The overrides every settings page needs.
List<Override> settingsOverrides({
  FakeProfileBackend? profile,
  FakeExternalActions? actions,
  FakeModuleStore? modules,
  FakeNotificationBackend? notifications,
  FakePermissionBackend? permission,
  FakeWebLoader? web,
  FakeThemeService? theme,
  bool offline = false,
  bool killSwitch = false,
  String? version = '1.1.4 (31)',
  void Function()? resetTips,
  List<ShoppingListModel> lists = const [],
}) {
  final backend = profile ?? FakeProfileBackend();
  return [
    authUserIdProvider.overrideWithValue('u1'),
    currentUserProvider.overrideWith((ref) async => backend.user),
    profileSettingsBackendProvider.overrideWithValue(backend),
    settingsExternalActionsProvider.overrideWithValue(
      actions ?? FakeExternalActions(),
    ),
    moduleStoreProvider.overrideWithValue(
      modules ?? FakeModuleStore(exampleModules()),
    ),
    notificationSettingsBackendProvider.overrideWithValue(
      notifications ?? FakeNotificationBackend(),
    ),
    notificationPermissionBackendProvider.overrideWithValue(
      permission ?? FakePermissionBackend(NotificationPermissionState.allowed),
    ),
    settingsWebLoaderProvider.overrideWithValue(web ?? FakeWebLoader()),
    themeServiceProvider.overrideWithValue(theme ?? FakeThemeService()),
    userPreferencesProvider.overrideWith((ref) async => null),
    isOfflineProvider.overrideWithValue(offline),
    offersKillSwitchProvider.overrideWithValue(killSwitch),
    settingsAppVersionProvider.overrideWithValue(version),
    settingsSystemVersionProvider.overrideWithValue('26.1'),
    settingsTipsResetProvider.overrideWithValue(resetTips ?? () {}),
    allListsSourceProvider.overrideWithValue(AsyncData(lists)),
  ];
}

/// Pumps [child] full screen at 390 pt (or [width]) with a toast host.
Future<ProviderContainer> pumpSettings(
  WidgetTester tester,
  Widget child, {
  List<Override>? overrides,
  double width = 390,
  double height = kLayoutHeight,
  double scale = 1,
  Locale? locale,
}) async {
  await loadLayoutFonts();
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: overrides ?? settingsOverrides(),
  );
  addTearDown(container.dispose);
  final l = locale;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: layoutHarness(
        LayoutCase(width: width, scale: scale),
        AvoToastHost(
          child: l == null
              ? child
              : Builder(
                  builder: (context) => Localizations.override(
                    context: context,
                    locale: l,
                    child: child,
                  ),
                ),
        ),
      ),
    ),
  );
  await settle(tester);
  return container;
}

/// Lets async loads finish and animations end.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump(const Duration(milliseconds: 600));
}

/// Lets a toast run out, so no timer is left when the test ends.
Future<void> letToastsExpire(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 11));
  await tester.pump(const Duration(seconds: 1));
}

/// A screen inside a `ProviderScope` for [layoutMatrix].
Widget scoped(Widget child, {List<Override>? overrides}) =>
    ProviderScope(overrides: overrides ?? settingsOverrides(), child: child);
