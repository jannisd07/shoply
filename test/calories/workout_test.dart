import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/workout.dart';

void main() {
  test('kcal = MET x kg x hours', () {
    // Krafttraining, mittel, 45 min, 72,4 kg: 5.0 * 72.4 * 0.75 = 271.5
    final e = estimateWorkoutCalories(
      type: WorkoutType.strength,
      intensity: WorkoutIntensity.moderate,
      durationMin: 45,
      weightKg: 72.4,
    );
    expect(e.kcal, 272);
    expect(e.usedDefaultWeight, isFalse);
  });

  test('without a weight it assumes 70 kg and says so', () {
    final e = estimateWorkoutCalories(
      type: WorkoutType.running,
      intensity: WorkoutIntensity.light,
      durationMin: 30,
    );
    expect(e.weightKg, 70);
    expect(e.usedDefaultWeight, isTrue);
    expect(e.kcal, (7.0 * 70 * 0.5).round());
  });

  test('harder means more kcal for every type', () {
    for (final type in WorkoutType.values) {
      final mets = WorkoutIntensity.values.map((i) => WorkoutMet.of(type, i)).toList();
      expect(mets[0] < mets[1] && mets[1] < mets[2], isTrue, reason: type.name);
    }
  });

  test('DB values round-trip, unknown values fall back', () {
    for (final t in WorkoutType.values) {
      expect(WorkoutTypeX.fromDb(t.dbValue), t);
    }
    expect(WorkoutTypeX.fromDb('curling'), WorkoutType.other);
    expect(WorkoutIntensityX.fromDb(null), WorkoutIntensity.moderate);
  });

  test('Health workouts are read-only and keep their source name', () {
    final w = Workout.fromJson({
      'id': 'hk-1',
      'user_id': 'u1',
      'started_at': '2026-11-07T17:05:00Z',
      'duration_min': 32,
      'type': 'running',
      'calories': 280,
      'source': 'health',
      'source_name': 'Apple Watch',
      'created_at': '2026-11-07T17:40:00Z',
    });
    expect(w.isReadOnly, isTrue);
    expect(w.sourceName, 'Apple Watch');
    expect(Workout.fromJson(w.toJson()), w);
    expect(w.toUpsertJson().containsKey('source'), isFalse);
  });
}
