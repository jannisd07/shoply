// Layout matrix (widths 320-440 pt, text 1.0-3.1, bold, dark, contrast) for
// Teil B's settings pages of A8 (Avo, Kalorien & Gesundheit, Siri &
// Kurzbefehle, Widgets) and SettingsInfoRow, in German, where the texts are
// longest: no overflow, no clipped text.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/presentation/screens/avo/avo_backend.dart';
import 'package:shoply/presentation/screens/avo/avo_chat.dart';
import 'package:shoply/presentation/screens/avo/avo_settings_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/data/notification_settings.dart';
import 'package:shoply/presentation/screens/system/siri_settings_screen.dart';
import 'package:shoply/presentation/screens/system/widgets/settings_info_row.dart';
import 'package:shoply/presentation/screens/system/widgets_settings_screen.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';

import '../../../screens/avo/avo_fakes.dart' show FakeAvoBackend, FakeProHints;
import '../../../screens/profile/settings/settings_test_helpers.dart';
import '../../layout_matrix.dart';

/// [child] in German with the settings fakes and [extra] overrides.
Widget _de(Widget child, {List<Override> extra = const []}) => ProviderScope(
  overrides: [
    ...settingsOverrides(
      modules: FakeModuleStore(exampleModules(calories: true)),
    ),
    avoBackendProvider.overrideWithValue(FakeAvoBackend()),
    avoChatProvider.overrideWith(
      (ref) => AvoChat(FakeAvoBackend(), proHints: FakeProHints()),
    ),
    calorieGoalStateProvider.overrideWith(
      (ref) => CalorieGoalState(
        CalorieGoalStatus.set,
        NutritionGoal(
          userId: 'u1',
          dailyCalorieTarget: 12500,
          createdAt: DateTime(2026, 11, 1),
          updatedAt: DateTime(2026, 11, 1),
        ),
      ),
    ),
    ...extra,
  ],
  child: Builder(
    builder: (context) => Localizations.override(
      context: context,
      locale: const Locale('de'),
      delegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      child: child,
    ),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  layoutMatrix('AvoSettingsScreen', (_) => _de(const AvoSettingsScreen()));

  layoutMatrix(
    'CaloriesSettingsScreen',
    (_) => _de(const CaloriesSettingsScreen()),
  );

  layoutMatrix(
    'CaloriesSettingsScreen (notifications off in iOS)',
    (_) => _de(
      const CaloriesSettingsScreen(),
      extra: [
        notificationPermissionBackendProvider.overrideWithValue(
          FakePermissionBackend(NotificationPermissionState.denied),
        ),
      ],
    ),
  );

  layoutMatrix(
    'CaloriesSettingsScreen (Avo notifications off)',
    (_) => _de(
      const CaloriesSettingsScreen(),
      extra: [
        notificationSettingsBackendProvider.overrideWithValue(
          FakeNotificationBackend(master: false),
        ),
      ],
    ),
  );

  layoutMatrix('SiriSettingsScreen', (_) => _de(const SiriSettingsScreen()));

  layoutMatrix(
    'WidgetsSettingsScreen',
    (_) => _de(const WidgetsSettingsScreen()),
  );

  layoutMatrix(
    'SettingsInfoRow',
    (_) => _de(
      const InsetSection(
        children: [
          SettingsInfoRow(
            title: '„Zeige gespeicherte Rezepte in Avo“',
            subtitle: 'Öffnet deine gespeicherten Rezepte',
          ),
          SettingsInfoRow(
            title: 'Gespeicherte Rezepte',
            subtitle: 'Deine gespeicherten Rezepte auf einen Blick.',
            value: 'Klein, mittel, groß',
          ),
        ],
      ),
    ),
    scrollable: true,
  );
}
