import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/services/food_log_service.dart';

FoodLogEntry _entry({
  FoodEntryOrigin? origin,
  FoodLogSource source = FoodLogSource.manual,
  bool estimated = false,
  EstimateConfidence? confidence,
}) =>
    FoodLogEntry(
      id: 'e1',
      userId: 'u1',
      loggedDate: DateTime(2026, 11, 7),
      mealType: MealType.lunch,
      source: source,
      origin: origin,
      foodName: 'Spaghetti Bolognese',
      calories: 650,
      proteinG: 32,
      estimated: estimated,
      confidence: confidence,
      loggedTime: const FoodLogTime(12, 41),
      photoPath: 'u1/1.jpg',
      createdAt: DateTime.utc(2026, 11, 7, 11, 41),
      updatedAt: DateTime.utc(2026, 11, 7, 11, 45),
    );

void main() {
  test('origin defaults to the legacy source and maps back to it', () {
    expect(_entry(source: FoodLogSource.recipe).origin, FoodEntryOrigin.recipe);
    expect(_entry(origin: FoodEntryOrigin.search).source, FoodLogSource.barcode);
    expect(_entry(origin: FoodEntryOrigin.manualEstimated).source, FoodLogSource.manual);
  });

  test('new sources use their own DB values', () {
    expect(FoodEntryOrigin.search.dbValue, 'search');
    expect(FoodEntryOrigin.manualEstimated.dbValue, 'manual_estimated');
    expect(FoodEntryOriginX.fromDb('manual_estimated'), FoodEntryOrigin.manualEstimated);
    expect(FoodEntryOriginX.fromDb('nonsense'), FoodEntryOrigin.manual);
  });

  test('full JSON round-trip keeps estimate, time, photo and timestamps', () {
    final e = _entry(
      origin: FoodEntryOrigin.photo,
      estimated: true,
      confidence: EstimateConfidence.low,
    );
    final copy = FoodLogEntry.fromJson(e.toJson());
    expect(copy, e);
    expect(copy.loggedTime, const FoodLogTime(12, 41));
    expect(copy.confidence, EstimateConfidence.low);
  });

  test('upsert with the new schema sends id and the new columns', () {
    final json = _entry(
      origin: FoodEntryOrigin.search,
      estimated: true,
      confidence: EstimateConfidence.medium,
    ).toUpsertJson(schemaV2: true);
    expect(json['id'], 'e1');
    expect(json['source'], 'search');
    expect(json['estimated'], true);
    expect(json['confidence'], 'medium');
    expect(json['logged_time'], '12:41');
    expect(json['photo_path'], 'u1/1.jpg');
    expect(json['logged_date'], '2026-11-07');
  });

  test('upsert before the migration only sends columns that exist today', () {
    final json = _entry(origin: FoodEntryOrigin.manualEstimated, estimated: true)
        .toUpsertJson(schemaV2: false);
    expect(json['source'], 'manual');
    for (final key in ['estimated', 'confidence', 'logged_time', 'photo_path', 'health_uuid', 'updated_at']) {
      expect(json.containsKey(key), isFalse, reason: key);
    }
  });

  test('rows written before the migration still parse', () {
    final legacy = FoodLogEntry.fromJson({
      'id': 'x',
      'user_id': 'u1',
      'logged_date': '2026-11-07',
      'meal_type': 'dinner',
      'source': 'barcode',
      'food_name': 'Skyr',
      'calories': 158,
      'created_at': '2026-11-07T18:00:00Z',
    });
    expect(legacy.estimated, isFalse);
    expect(legacy.loggedTime, isNull);
    expect(legacy.origin, FoodEntryOrigin.barcode);
  });

  test('time parses HH:mm and HH:mm:ss', () {
    expect(FoodLogTime.tryParse('07:05:00'), const FoodLogTime(7, 5));
    expect(FoodLogTime.tryParse('25:00'), isNull);
    expect(const FoodLogTime(7, 5).toString(), '07:05');
  });

  test('server sums are grouped per day from number-only rows', () {
    final sums = FoodLogService.sumByDay([
      {'logged_date': '2026-11-07', 'calories': 420, 'protein_g': 20, 'carbs_g': null, 'fat_g': 10.5},
      {'logged_date': '2026-11-07', 'calories': 650, 'protein_g': 32.5, 'carbs_g': 78, 'fat_g': null},
      {'logged_date': '2026-11-06', 'calories': 300},
    ]);
    expect(sums.keys, unorderedEquals(['2026-11-07', '2026-11-06']));
    expect(sums['2026-11-07']!.calories, 1070);
    expect(sums['2026-11-07']!.proteinG, 52.5);
    expect(sums['2026-11-07']!.carbsG, 78);
    expect(sums['2026-11-07']!.fatG, 10.5);
    expect(sums['2026-11-06']!.calories, 300);
  });
}
