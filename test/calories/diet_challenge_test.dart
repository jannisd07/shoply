import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/diet_challenge.dart';

Map<String, dynamic> _row({
  String type = 'fasting_16_8',
  Map<String, bool> jsonb = const {},
  List<Map<String, dynamic>>? checkins,
  String? targetEnd,
}) =>
    {
      'id': 'c1',
      'user_id': 'u1',
      'challenge_type': type,
      'status': 'active',
      'started_at': '2026-11-03T08:00:00Z',
      'target_end_at': targetEnd,
      'created_at': '2026-11-03T08:00:00Z',
      'daily_checkins': jsonb,
      'title': type == 'custom' ? 'Kein Alkohol unter der Woche' : null,
      'duration_days': type == 'custom' ? 28 : null,
      'question': type == 'custom' ? 'Heute ohne Alkohol?' : null,
      if (checkins != null) 'challenge_checkins': checkins,
    };

void main() {
  test('check-in rows win over the old jsonb map, per day', () {
    final c = DietChallenge.fromJson(_row(
      jsonb: {'2026-11-03': true, '2026-11-04': false},
      checkins: [
        {'date': '2026-11-04', 'kept': true},
        {'date': '2026-11-05', 'kept': false},
      ],
    ));
    expect(c.dailyCheckins, {
      '2026-11-03': true,
      '2026-11-04': true,
      '2026-11-05': false,
    });
  });

  test('custom challenges keep title, question and duration', () {
    final c = DietChallenge.fromJson(_row(type: 'custom'));
    expect(c.title, 'Kein Alkohol unter der Woche');
    expect(c.question, 'Heute ohne Alkohol?');
    expect(c.fixedDurationDays, 28);
  });

  test('insert JSON carries the custom fields only with the new schema', () {
    final c = DietChallenge.fromJson(_row(type: 'custom'));
    expect(c.toInsertJson(schemaV2: true)['title'], 'Kein Alkohol unter der Woche');
    expect(c.toInsertJson(schemaV2: true)['duration_days'], 28);
    expect(c.toInsertJson().containsKey('title'), isFalse);
  });

  test('a fixed challenge past its end reads as completed without a write', () {
    final c = DietChallenge.fromJson(_row(type: 'no_sugar_30', targetEnd: '2026-10-01T08:00:00Z'));
    expect(c.isPastTargetEnd, isTrue);
    final shown = c.asDisplayed();
    expect(shown.status, ChallengeStatus.completed);
    expect(shown.completedAt, DateTime.utc(2026, 10, 1, 8));
    final running = DietChallenge.fromJson(_row());
    expect(running.asDisplayed(), running);
  });
}
