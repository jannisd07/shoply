// log_workout reads the activity as people say it (W1b): "Joggen" is
// running, unknown words are a workout.
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/data/models/workout.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';

void main() {
  test('German and English words map to the workout type', () {
    expect(AvoAssistantService.workoutTypeOf('Joggen'), WorkoutType.running);
    expect(AvoAssistantService.workoutTypeOf('Laufen im Park'), WorkoutType.running);
    expect(AvoAssistantService.workoutTypeOf('Krafttraining'), WorkoutType.strength);
    expect(AvoAssistantService.workoutTypeOf('Radfahren'), WorkoutType.cycling);
    expect(AvoAssistantService.workoutTypeOf('Schwimmen'), WorkoutType.swimming);
    expect(AvoAssistantService.workoutTypeOf('Wandern'), WorkoutType.hiking);
    expect(AvoAssistantService.workoutTypeOf('yoga'), WorkoutType.yoga);
    expect(AvoAssistantService.workoutTypeOf('Tischtennis'), WorkoutType.other);
  });
}
