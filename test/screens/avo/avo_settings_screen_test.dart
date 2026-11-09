// "Avo" in the settings (`/settings/avo`, Kap. 16 §10): consents, the
// conversation and deleting it, the disclosure.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/presentation/providers/avo_consents_provider.dart';
import 'package:shoply/presentation/screens/avo/avo_backend.dart';
import 'package:shoply/presentation/screens/avo/avo_chat.dart';
import 'package:shoply/presentation/screens/avo/avo_settings_screen.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';

import '../profile/settings/settings_test_helpers.dart';
import 'avo_fakes.dart' hide settle;

List<Override> _overrides(
  FakeAvoBackend backend, {
  AvoChat? chat,
  bool calories = true,
}) => [
  ...settingsOverrides(
    modules: FakeModuleStore(exampleModules(calories: calories)),
  ),
  avoBackendProvider.overrideWithValue(backend),
  avoChatProvider.overrideWith(
    (ref) => chat ?? AvoChat(backend, proHints: FakeProHints()),
  ),
];

/// A chat with one answered question, attached to a ref of [container].
Future<AvoChat> _chatWithTurn(
  WidgetTester tester,
  FakeAvoBackend backend,
) async {
  late WidgetRef ref;
  await tester.pumpWidget(
    ProviderScope(
      overrides: avoOverrides(backend: backend),
      child: Consumer(
        builder: (context, r, _) {
          ref = r;
          return const SizedBox();
        },
      ),
    ),
  );
  final chat = AvoChat(backend, proHints: FakeProHints());
  chat.attach(ref);
  chat.send('Was steht auf meiner Liste?');
  await tester.pump();
  await tester.pump();
  return chat;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('consents start off and save at once', (tester) async {
    final container = await pumpSettings(
      tester,
      const AvoSettingsScreen(),
      overrides: _overrides(FakeAvoBackend()),
    );
    expect(find.text('Avo'), findsOneWidget);
    expect(find.text('Diet and allergies'), findsOneWidget);
    expect(find.text('Calories, weight and goals'), findsOneWidget);
    final toggles = tester.widgetList<ToggleRow>(find.byType(ToggleRow));
    expect(toggles.map((t) => t.value), everyElement(isFalse));

    await tester.tap(find.text('Diet and allergies'));
    await settle(tester);
    expect(container.read(avoConsentsProvider).health, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('avo_consent_health'), isTrue);
    expect(prefs.getBool('avo_consent_body'), isNot(isTrue));
  });

  testWidgets('without the Kalorien module the body consent is gone', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      const AvoSettingsScreen(),
      overrides: _overrides(FakeAvoBackend(), calories: false),
    );
    expect(find.text('Diet and allergies'), findsOneWidget);
    expect(find.text('Calories, weight and goals'), findsNothing);
  });

  testWidgets('no conversation: delete is off and says so', (tester) async {
    await pumpSettings(
      tester,
      const AvoSettingsScreen(),
      overrides: _overrides(FakeAvoBackend()),
    );
    expect(find.byType(DestructiveRow), findsNothing);
    expect(find.text('Delete conversation'), findsOneWidget);
    expect(find.text('No conversation saved'), findsOneWidget);
    expect(find.text('Kept'), findsOneWidget);
    expect(find.text('Up to 24 hours, only on this iPhone'), findsOneWidget);
    expect(find.text('Avo uses Claude by Anthropic.'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
    // S6 P3: the link is as large as the sentence before it.
    expect(
      tester.getSize(find.text('Privacy')).height,
      tester.getSize(find.text('Avo uses Claude by Anthropic.')).height,
    );
    expect(find.textContaining('This switch only decides'), findsOneWidget);
  });

  testWidgets('"Gespräch löschen" asks first, then deletes for good', (
    tester,
  ) async {
    final backend = FakeAvoBackend();
    // The provider of the page disposes it.
    final chat = await _chatWithTurn(tester, backend);
    expect(chat.hasConversation, isTrue);

    await pumpSettings(
      tester,
      const AvoSettingsScreen(),
      overrides: _overrides(backend, chat: chat),
    );
    await tester.tap(find.byType(DestructiveRow));
    await settle(tester);
    expect(find.text('Delete conversation?'), findsOneWidget);
    expect(
      find.text('Your chat with Avo will be deleted from this iPhone.'),
      findsOneWidget,
    );

    // Abbrechen keeps it.
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(chat.hasConversation, isTrue);

    await tester.tap(find.byType(DestructiveRow));
    await settle(tester);
    await tester.tap(find.text('Delete').last);
    await settle(tester);
    expect(chat.hasConversation, isFalse);
    expect(backend.resets, greaterThan(0));
    expect(find.text('No conversation saved'), findsOneWidget);
  });

  testWidgets('deleteConversation also drops a "Neues Gespräch" undo', (
    tester,
  ) async {
    final backend = FakeAvoBackend();
    final chat = await _chatWithTurn(tester, backend);
    addTearDown(chat.dispose);
    chat.newConversation();
    expect(chat.isEmpty, isTrue);
    expect(chat.hasConversation, isTrue);
    chat.deleteConversation();
    expect(chat.hasConversation, isFalse);
    chat.undoNewConversation();
    expect(chat.isEmpty, isTrue);
  });

  testWidgets('a search hit highlights its row', (tester) async {
    await pumpSettings(
      tester,
      const AvoSettingsScreen(
        highlightRowId: AvoSettingsRows.deleteConversation,
      ),
      overrides: _overrides(FakeAvoBackend()),
    );
    expect(tester.takeException(), isNull);
    // The highlight fades after a second.
    await tester.pump(const Duration(seconds: 2));
  });
}
