// S5 "Schätzung prüfen" of docs/redesign/b-screens/kalorien.md: the pill
// while estimating, the result card with "ca." and the confidence word,
// parts with grams in place, allergies, "Foto im Tagebuch behalten", every
// error state, the discard question and logging (entry stays "geschätzt",
// the photo is uploaded afterwards and never blocks it).
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/user_model.dart';
import 'package:shoply/data/services/meal_photo_analysis_service.dart';
import 'package:shoply/presentation/screens/calories/calories_estimate_screen.dart';
import 'package:shoply/presentation/state/calorie_entry_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';

import 'calorie_fakes.dart';

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CaloriesEstimateScreen)));

UserModel _user(List<String> allergies) => UserModel(
      id: kUser,
      email: 'a@example.invalid',
      displayName: 'A',
      allergies: allergies,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Future<void> _pump(WidgetTester tester, CalorieTestEnv env, {Object? result, UserModel? user, FakeMealPhotoBucket? bucket}) async {
  await pumpCalories(
    tester,
    CaloriesEstimateScreen(photo: kJpeg, meal: MealType.lunch),
    overrides: env.overrides(
      user: user,
      bucket: bucket,
      analyzer: (photo) async {
        if (result is MealPhotoException) throw result;
        return result as MealPhotoEstimate;
      },
    ),
  );
  await settleFrames(tester);
}

void main() {
  testWidgets('while estimating: the pill, tone blocks, "Log" off', (tester) async {
    final env = await CalorieTestEnv.create();
    await pumpCalories(tester, CaloriesEstimateScreen(photo: kJpeg),
        overrides: env.overrides(analyzer: (_) => Completer<MealPhotoEstimate>().future));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Estimating…'), findsOneWidget);
    expect(find.textContaining('about'), findsNothing);
    await tester.tap(find.text('Log'));
    await tester.pump();
    expect(_container(tester).read(calorieDayProvider(kToday)).day?.entries ?? const [], isEmpty);
  });

  testWidgets('the result: "about 650 kcal", "Unsure", parts with grams; never percent', (tester) async {
    final env = await CalorieTestEnv.create();
    final semantics = tester.ensureSemantics();
    await _pump(tester, env, result: photoEstimate());

    expect(find.text('Estimated'), findsOneWidget);
    expect(find.text('Spaghetti Bolognese'), findsOneWidget);
    expect(find.text('about 650 kcal'), findsOneWidget);
    expect(find.text('Unsure'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('WHAT\'S ON THE PLATE'), findsOneWidget);
    expect(find.text('about 220 g'), findsOneWidget);
    expect(find.text('345 kcal'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'^Spaghetti Bolognese, about 650 calories, estimated, Unsure\. 32 grams of protein')),
      findsOneWidget,
    );
    expect(find.text('Keep photo in diary'), findsOneWidget);
    expect(find.text('The photo is stored privately. Deleting the entry deletes the photo too.'), findsOneWidget);
    expect(find.textContaining('Settings'), findsNothing, reason: 'no promise of a setting that does not exist');
    expect(find.text('Also saved to Apple Health'), findsNothing, reason: 'Health is not connected');
    semantics.dispose();
  });

  testWidgets('more grams on a part: its kcal and the total follow; "Adjusted by you."', (tester) async {
    final env = await CalorieTestEnv.create();
    final semantics = tester.ensureSemantics();
    await _pump(tester, env, result: photoEstimate());

    await tester.ensureVisible(find.text('Spaghetti, gekocht'));
    await settleFrames(tester);
    await tester.tap(find.text('Spaghetti, gekocht'));
    await settleFrames(tester);
    await tester.ensureVisible(find.bySemanticsLabel('Increase'));
    await settleFrames(tester);
    await tester.tap(find.bySemanticsLabel('Increase'));
    await settleFrames(tester);
    expect(find.text('about 230 g'), findsOneWidget);
    expect(find.text('about 666 kcal'), findsOneWidget);
    expect(find.textContaining('Adjusted by you.'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('"Log" keeps "geschätzt" and the level; the photo is uploaded and added afterwards', (tester) async {
    final env = await CalorieTestEnv.create();
    final bucket = FakeMealPhotoBucket();
    await _pump(tester, env, result: photoEstimate(), bucket: bucket);
    final container = _container(tester);

    await tester.tap(find.text('Log'));
    await settleFrames(tester);
    final entry = container.read(calorieDayProvider(kToday)).day!.entries.single;
    expect(entry.origin, FoodEntryOrigin.photo);
    expect(entry.estimated, isTrue);
    expect(entry.confidence, EstimateConfidence.medium);
    expect(entry.calories, 650);
    expect(entry.mealType, MealType.lunch);
    expect(entry.photoPath, '$kUser/photo1.jpg');
    expect(bucket.files.keys, ['$kUser/photo1.jpg']);
    expect(find.text('Spaghetti Bolognese logged'), findsOneWidget);
  });

  testWidgets('a slow upload still attaches the photo after the screen is gone', (tester) async {
    final env = await CalorieTestEnv.create();
    final bucket = FakeMealPhotoBucket()..uploadGate = Completer<void>();
    await _pump(tester, env, result: photoEstimate(), bucket: bucket);
    final container = _container(tester);

    await tester.tap(find.text('Log'));
    await settleFrames(tester);
    expect(find.byType(CaloriesEstimateScreen), findsNothing);
    expect(container.read(calorieDayProvider(kToday)).day!.entries.single.photoPath, isNull);

    bucket.uploadGate!.complete();
    await settleFrames(tester);
    expect(container.read(calorieDayProvider(kToday)).day!.entries.single.photoPath, '$kUser/photo1.jpg');
    expect(tester.takeException(), isNull);
  });

  testWidgets('undone before the upload finished: the uploaded photo is deleted again', (tester) async {
    final env = await CalorieTestEnv.create();
    final bucket = FakeMealPhotoBucket()..uploadGate = Completer<void>();
    await _pump(tester, env, result: photoEstimate(), bucket: bucket);
    final container = _container(tester);

    await tester.tap(find.text('Log'));
    await settleFrames(tester);
    await tester.tap(find.text('Undo'));
    await settleFrames(tester);
    bucket.uploadGate!.complete();
    await settleFrames(tester);
    expect(container.read(calorieDayProvider(kToday)).day!.entries, isEmpty);
    expect(bucket.removed, ['$kUser/photo1.jpg']);
    expect(bucket.files, isEmpty);
  });

  testWidgets('"Keep photo" off: nothing is uploaded', (tester) async {
    final env = await CalorieTestEnv.create();
    final bucket = FakeMealPhotoBucket();
    await _pump(tester, env, result: photoEstimate(), bucket: bucket);
    final container = _container(tester);

    await tester.ensureVisible(find.text('Keep photo in diary'));
    await tester.tap(find.text('Keep photo in diary'));
    await settleFrames(tester);
    await tester.tap(find.text('Log'));
    await settleFrames(tester);
    expect(container.read(calorieDayProvider(kToday)).day!.entries.single.photoPath, isNull);
    expect(bucket.files, isEmpty);
  });

  testWidgets('an allergy in a part: "May contain peanuts …" until that part is gone', (tester) async {
    final env = await CalorieTestEnv.create();
    await _pump(
      tester,
      env,
      user: _user(['peanuts']),
      result: photoEstimate(dish: 'Bowl', components: [
        {'name': 'Reis', 'grams': 200, 'kcal': 260},
        {'name': 'Erdnusssoße', 'grams': 40, 'kcal': 200},
      ]),
    );

    expect(find.text('May contain peanuts. Your profile lists a peanut allergy.'), findsOneWidget);
    expect(find.text('This check doesn\'t replace reading the ingredients.'), findsOneWidget);

    await tester.ensureVisible(find.text('Erdnusssoße'));
    await settleFrames(tester);
    await tester.drag(find.text('Erdnusssoße'), const Offset(-400, 0));
    await settleFrames(tester);
    expect(find.textContaining('May contain'), findsNothing);
  });

  testWidgets('leaving with a result asks "Discard estimate?"', (tester) async {
    final env = await CalorieTestEnv.create();
    await _pump(tester, env, result: photoEstimate());

    await tester.tap(find.bySemanticsLabel('Back'));
    await settleFrames(tester);
    expect(find.text('Discard estimate?'), findsOneWidget);
    expect(find.text('The food won\'t be logged.'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await settleFrames(tester);
    expect(find.byType(CaloriesEstimateScreen), findsNothing);
  });

  group('problems', () {
    testWidgets('no food: "New photo" and "Enter manually"', (tester) async {
      final env = await CalorieTestEnv.create();
      await _pump(tester, env, result: const MealPhotoException('no_food_detected'));
      expect(find.text('There\'s no food in this photo.'), findsOneWidget);
      expect(find.text('New photo'), findsOneWidget);
      expect(find.text('Enter manually'), findsOneWidget);
      expect(find.text('Log'), findsNothing);
    });

    testWidgets('unreadable: "too dark or blurry"', (tester) async {
      final env = await CalorieTestEnv.create();
      await _pump(tester, env, result: const MealPhotoException('unreadable_image'));
      expect(find.text('The photo is too dark or blurry.'), findsOneWidget);
      expect(find.text('New photo'), findsOneWidget);
    });

    testWidgets('refused: no new photo, manual entry', (tester) async {
      final env = await CalorieTestEnv.create();
      await _pump(tester, env, result: const MealPhotoException('refused'));
      expect(find.text('This photo can\'t be estimated.'), findsOneWidget);
      expect(find.text('New photo'), findsNothing);
      expect(find.text('Enter manually'), findsOneWidget);
    });

    testWidgets('failed: status with retry; a retry can succeed', (tester) async {
      final env = await CalorieTestEnv.create();
      var calls = 0;
      await pumpCalories(
        tester,
        CaloriesEstimateScreen(photo: kJpeg),
        overrides: env.overrides(analyzer: (_) async {
          calls++;
          if (calls == 1) throw const MealPhotoException('timeout');
          return photoEstimate();
        }),
      );
      await settleFrames(tester);
      expect(find.text('The estimate didn\'t work.'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await settleFrames(tester);
      expect(find.text('about 650 kcal'), findsOneWidget);
    });

    testWidgets('offline: says the estimate needs a connection', (tester) async {
      final env = await CalorieTestEnv.create();
      await pumpCalories(
        tester,
        CaloriesEstimateScreen(photo: kJpeg),
        overrides: env.overrides(offline: true, analyzer: (_) async => throw const MealPhotoException('network_error')),
      );
      await settleFrames(tester);
      expect(find.text('You\'re offline. The estimate needs a connection.'), findsOneWidget);
    });

    testWidgets('daily limit: the limit text, remembered for S3', (tester) async {
      final env = await CalorieTestEnv.create();
      await _pump(tester, env, result: const MealPhotoException('quota_exceeded'));
      expect(find.text('You\'ve used today\'s photo estimates. They\'re back tomorrow, or get up to 15 a day with Avo Pro.'),
          findsOneWidget);
      expect(find.text('See Avo Pro'), findsOneWidget);
      expect(_container(tester).read(caloriePhotoLimitReachedProvider), isTrue);
      expect(env.prefs.getString('cal_photo_limit_v1_$kUser'), kToday);
    });

    testWidgets('AI off: "Photo estimates aren\'t available right now."', (tester) async {
      final env = await CalorieTestEnv.create();
      await _pump(tester, env, result: const MealPhotoException('ai_disabled'));
      expect(find.text('Photo estimates aren\'t available right now.'), findsOneWidget);
    });
  });
}
