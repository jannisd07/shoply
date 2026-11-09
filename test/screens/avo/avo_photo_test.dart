// Foto an Avo (Kap. 7, B5 slice W1b): the composer's photo button and its
// menu, the camera's explanation before the system prompt, the "Kamera ist
// aus" row, the photo choice, the shopping note and the meal estimate.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/services/list_import_service.dart';
import 'package:shoply/data/services/meal_photo_analysis_service.dart';
import 'package:shoply/presentation/providers/avo_screen_context_provider.dart';
import 'package:shoply/presentation/screens/avo/avo_tab_screen.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_user_bubble.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

import 'avo_fakes.dart';

const _meal = MealPhotoEstimate(
  foodName: 'Spaghetti Bolognese',
  calories: 650,
  proteinG: 28,
  carbsG: 72,
  fatG: 24,
  confidence: 'medium',
  components: [MealPhotoComponent(name: 'Spaghetti', grams: 400, kcal: 650)],
);

Future<void> _pumpTab(
  WidgetTester tester,
  FakeAvoBackend backend,
  FakePhotoSource photos, {
  AvoScreenContext? screen,
  Set<AppModule> modules = const {AppModule.calories, AppModule.offers},
  bool offline = false,
}) async {
  await tester.pumpWidget(
    avoHarness(
      const AvoTabScreen(),
      avoCardOverrides(
        backend: backend,
        photos: photos,
        screen: screen,
        modules: modules,
        offline: offline,
      ),
    ),
  );
  await settle(tester);
}

/// Scrolls [finder] to the middle of the conversation (clear of the head
/// and the composer) and taps it.
Future<void> _tapInChat(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await settle(tester);
  await tester.tap(finder);
  await settle(tester);
}

Future<void> _menu(WidgetTester tester, String entry) async {
  await tester.tap(find.bySemanticsLabel('Add photo'));
  await settle(tester);
  await tester.tap(find.text(entry));
  await settle(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a photo without context asks what it is; a shopping note is '
      'chosen from, goes to the chosen list, with undo', (tester) async {
    final backend = FakeAvoBackend()
      ..listPhoto = ListImportResult(
        items: [
          ExtractedListItem(name: 'Milch', quantity: 2),
          ExtractedListItem(name: 'Eier', quantity: 10),
        ],
        unparsedLines: const ['xyz'],
      );
    final photos = FakePhotoSource(photo: kTinyPng);
    await _pumpTab(tester, backend, photos);

    await _menu(tester, 'Choose photo');
    expect(photos.chooses, 1);
    expect(
      find.descendant(
        of: find.byType(AvoUserBubble),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
    expect(find.text('What should I do with this photo?'), findsOneWidget);
    expect(find.text('Log as a meal'), findsOneWidget);
    expect(backend.asked, isEmpty, reason: 'never sent to avo_chat');

    await _tapInChat(tester, find.text('Add items to a list'));
    expect(find.text('2 items found'), findsOneWidget);
    expect(find.text("Couldn't read"), findsOneWidget);
    expect(find.text('Which list?'), findsOneWidget);
    // Nothing goes anywhere before a list is chosen.
    expect(find.text('Add 2'), findsOneWidget);
    await _tapInChat(tester, find.text('Add 2'));
    expect(backend.cardWrites, isEmpty);

    await _tapInChat(tester, find.text('Eier'));
    expect(find.text('Add 1'), findsOneWidget);
    await _tapInChat(tester, find.text('Drogerie').last);
    await _tapInChat(tester, find.text('Add 1'));
    expect(backend.cardWrites, ['items:d:Milch']);
    expect(find.text('1 added'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('on the calories screen a photo is a meal: estimate, never '
      'saved before "Eintragen"', (tester) async {
    final backend = FakeAvoBackend()
      ..mealPhoto = _meal
      ..holdPhoto = true;
    final photos = FakePhotoSource(photo: kTinyPng);
    await _pumpTab(
      tester,
      backend,
      photos,
      screen: const AvoScreenContext(screen: 'calories'),
    );
    await _menu(tester, 'Choose photo');
    expect(find.text('Estimating the meal'), findsOneWidget);
    expect(find.text('What should I do with this photo?'), findsNothing);
    backend.releasePhoto();
    await settle(tester);
    expect(find.text('Spaghetti Bolognese'), findsOneWidget);
    expect(find.text('about 650 kcal · estimated, unsure'), findsOneWidget);
    expect(find.text('Amount · about 400 g'), findsOneWidget);
    expect(backend.cardWrites, isEmpty);
    await _tapInChat(tester, find.text('Log'));
    expect(backend.cardWrites.single, startsWith('food:Spaghetti Bolognese:'));
  });

  testWidgets('without the calories module the choice has no meal row', (
    tester,
  ) async {
    final photos = FakePhotoSource(photo: kTinyPng);
    await _pumpTab(
      tester,
      FakeAvoBackend(),
      photos,
      modules: const {AppModule.offers},
    );
    await _menu(tester, 'Choose photo');
    expect(find.text('Log as a meal'), findsNothing);
    expect(find.text('Add items to a list'), findsOneWidget);
  });

  testWidgets('no food and an unreadable photo say what to do next', (
    tester,
  ) async {
    final backend = FakeAvoBackend()
      ..mealPhoto = const MealPhotoException('no_food_detected')
      ..listPhoto = const ListImportException('unreadable_image');
    final photos = FakePhotoSource(photo: kTinyPng);
    await _pumpTab(
      tester,
      backend,
      photos,
      screen: const AvoScreenContext(screen: 'calories'),
    );
    await _menu(tester, 'Choose photo');
    expect(find.text("I can't see any food in this photo."), findsOneWidget);
    expect(find.text('Add manually'), findsOneWidget);
  });

  testWidgets('an unreadable note offers a new photo (the menu again)', (
    tester,
  ) async {
    final backend = FakeAvoBackend()
      ..listPhoto = const ListImportException('unreadable_image');
    final photos = FakePhotoSource(photo: kTinyPng);
    await _pumpTab(
      tester,
      backend,
      photos,
      screen: const AvoScreenContext(
        screen: 'list',
        listId: 'w',
        listName: 'Wocheneinkauf',
      ),
    );
    await _menu(tester, 'Choose photo');
    expect(
      find.text(
        "I can't read this photo. Try again with more light and a bit closer.",
      ),
      findsOneWidget,
    );
    await _tapInChat(tester, find.text('New photo'));
    expect(find.text('Take photo'), findsOneWidget);
  });

  testWidgets('the camera explains itself once, before the first system '
      'prompt', (tester) async {
    final photos = FakePhotoSource(photo: kTinyPng, explained: false);
    await _pumpTab(tester, FakeAvoBackend(), photos);
    await _menu(tester, 'Take photo');
    expect(find.text('Photo for Avo'), findsOneWidget);
    expect(find.text('Avo needs the camera for this photo.'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await settle(tester);
    expect(photos.takes, 0);
    expect(photos.explained, isFalse, reason: 'asked again next time');

    await _menu(tester, 'Take photo');
    await tester.tap(find.text('Continue'));
    await settle(tester);
    expect(photos.takes, 1);
    expect(photos.explained, isTrue);
    expect(find.text('What should I do with this photo?'), findsOneWidget);

    // Once explained, the camera opens at once.
    await _menu(tester, 'Take photo');
    expect(find.text('Photo for Avo'), findsNothing);
    expect(photos.takes, 2);
  });

  testWidgets('camera off (image_picker said camera_access_denied): the '
      'status row with Settings and "choose a photo instead"', (tester) async {
    final photos = FakePhotoSource(photo: kTinyPng, denied: true);
    await _pumpTab(tester, FakeAvoBackend(), photos);
    await _menu(tester, 'Take photo');
    expect(find.byType(StatusRow), findsOneWidget);
    expect(find.text('Camera is off. Allow it in Settings'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await settle(tester);
    expect(photos.settings, 1);
    await tester.tap(find.text('Choose a photo instead'));
    await settle(tester);
    expect(photos.chooses, 1);
    expect(find.byType(StatusRow), findsNothing);
  });

  testWidgets('offline a photo stays "Nicht gesendet"', (tester) async {
    final photos = FakePhotoSource(photo: kTinyPng);
    await _pumpTab(tester, FakeAvoBackend(), photos, offline: true);
    await _menu(tester, 'Choose photo');
    expect(find.text('Not sent'), findsOneWidget);
    expect(find.text('What should I do with this photo?'), findsNothing);
  });

  testWidgets('"Stopp" while a meal is read ends the round at once', (
    tester,
  ) async {
    final backend = FakeAvoBackend()
      ..mealPhoto = _meal
      ..holdPhoto = true;
    final photos = FakePhotoSource(photo: kTinyPng);
    await _pumpTab(
      tester,
      backend,
      photos,
      screen: const AvoScreenContext(screen: 'calories'),
    );
    await _menu(tester, 'Choose photo');
    expect(find.text('Estimating the meal'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    await settle(tester);
    // Stopped before the estimate arrives.
    expect(find.text('Stopped.'), findsOneWidget);
    expect(find.text('Estimating the meal'), findsNothing);
    backend.releasePhoto();
    await settle(tester);
    expect(find.text('Stopped.'), findsOneWidget);
    expect(find.text('Spaghetti Bolognese'), findsNothing);
  });
}
