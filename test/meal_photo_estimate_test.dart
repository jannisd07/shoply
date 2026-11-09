// Meal photo -> nutrition estimate (plan B1.7, client half).
//
// What matters: the server's answer (task `meal_photo`) arrives as the model
// the entry screen already reads (foodName, calories, confidence low/medium/
// high) plus components, the confidence word and allergens; every failure
// arrives as one of the fixed MealPhotoException codes; and photos in the
// now private `meal-photos` bucket are shown through signed URLs that are
// cached by storage path, never through public links.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:shoply/data/models/dietary_preference.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/services/claude_service.dart';
import 'package:shoply/data/services/meal_photo_analysis_service.dart';
import 'package:shoply/data/services/meal_photo_storage_service.dart';

typedef _Call = ({String task, Map<String, dynamic> input, Duration timeout});

/// Answers `run` without any network; records what was asked.
class _FakeClaude extends ClaudeService {
  _FakeClaude(this._answer, {String locale = 'de'}) : super(locale: () => locale);

  final Future<Map<String, dynamic>> Function() _answer;
  final List<_Call> calls = [];

  @override
  Future<Map<String, dynamic>> run(
    String task,
    Map<String, dynamic> input, {
    required Duration timeout,
  }) {
    calls.add((task: task, input: input, timeout: timeout));
    return _answer();
  }
}

class _FakeBucket implements MealPhotoBucket {
  final List<({String path, String contentType, int bytes})> uploads = [];
  final List<String> removed = [];

  @override
  Future<void> remove(List<String> paths) async => removed.addAll(paths);

  final List<({String path, Duration expiresIn})> signs = [];
  Object? uploadError;
  Object? signError;
  Completer<void>? signGate;
  int _n = 0;

  @override
  Future<void> upload(String path, Uint8List bytes, {required String contentType}) async {
    if (uploadError != null) throw uploadError!;
    uploads.add((path: path, contentType: contentType, bytes: bytes.length));
  }

  @override
  Future<String> createSignedUrl(String path, Duration expiresIn) async {
    signs.add((path: path, expiresIn: expiresIn));
    if (signGate != null) await signGate!.future;
    if (signError != null) throw signError!;
    _n++;
    return 'https://project.test/storage/v1/object/sign/meal-photos/$path?token=t$_n';
  }
}

Uint8List _jpeg() => Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8)));
Uint8List _png() => Uint8List.fromList(img.encodePng(img.Image(width: 8, height: 8)));

Map<String, dynamic> _result({
  String dish = 'Spaghetti Bolognese',
  String confidence = 'unsicher',
  List<Object?> allergens = const ['gluten', 'milk', 'celery'],
}) =>
    {
      'dish': dish,
      'components': [
        {'name': 'Spaghetti', 'grams': 250, 'kcal': 390},
        {'name': 'Bolognese-Soße', 'grams': 150, 'kcal': 210},
        {'name': 'Parmesan', 'grams': 10, 'kcal': 40},
      ],
      'kcal': 640,
      'protein_g': 28.5,
      'carbs_g': 82,
      'fat_g': 19.2,
      'confidence': confidence,
      'allergens': allergens,
      'no_food': false,
    };

void main() {
  group('MealPhotoEstimate.fromJson', () {
    test('maps the meal_photo result onto the existing fields and the new ones', () {
      final e = MealPhotoEstimate.fromJson(_result());

      expect(e.foodName, 'Spaghetti Bolognese');
      expect(e.calories, 640);
      expect(e.proteinG, 28.5);
      expect(e.carbsG, 82.0);
      expect(e.fatG, 19.2);
      expect(e.components.map((c) => (c.name, c.grams, c.kcal)), [
        ('Spaghetti', 250, 390),
        ('Bolognese-Soße', 150, 210),
        ('Parmesan', 10, 40),
      ]);
      expect(e.allergens, [AllergyType.gluten, AllergyType.milk, AllergyType.celery]);
    });

    test('the confidence word keeps the old low/medium/high keys working', () {
      final sure = MealPhotoEstimate.fromJson(_result(confidence: 'recht_sicher'));
      final unsure = MealPhotoEstimate.fromJson(_result(confidence: 'unsicher'));
      final rough = MealPhotoEstimate.fromJson(_result(confidence: 'grob'));

      expect([sure.confidence, unsure.confidence, rough.confidence], ['high', 'medium', 'low']);
      expect([sure.confidenceWord, unsure.confidenceWord, rough.confidenceWord],
          ['recht_sicher', 'unsicher', 'grob']);
      expect([sure.confidenceLevel, unsure.confidenceLevel, rough.confidenceLevel],
          [EstimateConfidence.high, EstimateConfidence.medium, EstimateConfidence.low]);
    });

    test('an unknown or missing confidence is the roughest level, never "sure"', () {
      expect(MealPhotoEstimate.fromJson(_result(confidence: '95%')).confidenceWord, 'grob');
      final missing = _result()..remove('confidence');
      expect(MealPhotoEstimate.fromJson(missing).confidence, 'low');
    });

    test('unknown allergen ids are dropped and duplicates collapse', () {
      final e = MealPhotoEstimate.fromJson(
        _result(allergens: ['milk', 'shellfish', 'milk', 7, null, 'yeast']),
      );
      expect(e.allergens, [AllergyType.milk, AllergyType.yeast]);
    });

    test('an empty dish name falls back to the given name', () {
      final e = MealPhotoEstimate.fromJson(_result(dish: '  '), fallbackName: 'Mahlzeit');
      expect(e.foodName, 'Mahlzeit');
    });

    test('broken components are skipped, the rest stays', () {
      final json = _result()
        ..['components'] = [
          {'name': '', 'grams': 10, 'kcal': 5},
          {'name': 'Reis', 'grams': 'viel', 'kcal': 200},
          'Salat',
          {'name': ' Reis ', 'grams': 180.4, 'kcal': 230.6},
        ];
      final e = MealPhotoEstimate.fromJson(json);
      expect(e.components.map((c) => (c.name, c.grams, c.kcal)), [('Reis', 180, 231)]);
    });

    test('an answer without kcal is broken (FormatException)', () {
      final json = _result()..remove('kcal');
      expect(() => MealPhotoEstimate.fromJson(json), throwsFormatException);
    });

    test('the old constructor still works without the new fields', () {
      const e = MealPhotoEstimate(foodName: 'Apfel', calories: 80, confidence: 'high');
      expect(e.components, isEmpty);
      expect(e.allergens, isEmpty);
      expect(e.confidenceWord, 'recht_sicher');
    });
  });

  group('MealPhotoAnalysisService.analyzePhoto', () {
    test('sends task meal_photo with the photo, its type and the note, deadline 30 s', () async {
      final claude = _FakeClaude(() async => _result());
      final service = MealPhotoAnalysisService(claude: () => claude);
      final photo = _jpeg();

      final e = await service.analyzePhoto(photo, meal: '  Mittagessen, halbe Portion ');

      expect(e.calories, 640);
      expect(claude.calls, hasLength(1));
      final call = claude.calls.single;
      expect(call.task, 'meal_photo');
      expect(call.timeout, const Duration(seconds: 30));
      expect(base64Decode(call.input['image_b64'] as String), photo);
      expect(call.input['media_type'], 'image/jpeg');
      expect(call.input['meal'], 'Mittagessen, halbe Portion');
    });

    test('a PNG keeps its own media type; an empty note is left out', () async {
      final claude = _FakeClaude(() async => _result());
      final service = MealPhotoAnalysisService(claude: () => claude);

      await service.analyzePhoto(_png(), meal: '   ');

      expect(claude.calls.single.input['media_type'], 'image/png');
      expect(claude.calls.single.input.containsKey('meal'), isFalse);
    });

    test('a note longer than the server allows is cut to 300 characters', () async {
      final claude = _FakeClaude(() async => _result());
      final service = MealPhotoAnalysisService(claude: () => claude);

      await service.analyzePhoto(_jpeg(), meal: 'a' * 400);

      expect((claude.calls.single.input['meal'] as String).length, 300);
    });

    test('bytes that are no photo are unreadable_image and cost no request', () async {
      final claude = _FakeClaude(() async => _result());
      final service = MealPhotoAnalysisService(claude: () => claude);

      await expectLater(
        service.analyzePhoto(Uint8List.fromList(utf8.encode('%PDF-1.4 not a photo'))),
        throwsA(isA<MealPhotoException>().having((e) => e.code, 'code', 'unreadable_image')),
      );
      expect(claude.calls, isEmpty);
    });

    test('the fallback dish name follows the app language', () async {
      final claude = _FakeClaude(() async => _result(dish: ''), locale: 'en');
      final service = MealPhotoAnalysisService(claude: () => claude);

      expect((await service.analyzePhoto(_jpeg())).foodName, 'Meal');
    });

    test('a no_food answer is no_food_detected', () async {
      final claude = _FakeClaude(() async => {..._result(), 'no_food': true});
      final service = MealPhotoAnalysisService(claude: () => claude);

      await expectLater(
        service.analyzePhoto(_jpeg()),
        throwsA(isA<MealPhotoException>().having((e) => e.code, 'code', 'no_food_detected')),
      );
    });

    test('a broken answer is provider_error', () async {
      final claude = _FakeClaude(() async => {'dish': 'x'});
      final service = MealPhotoAnalysisService(claude: () => claude);

      await expectLater(
        service.analyzePhoto(_jpeg()),
        throwsA(isA<MealPhotoException>().having((e) => e.code, 'code', 'provider_error')),
      );
    });

    const mapping = {
      'no_food_detected': 'no_food_detected',
      'unreadable_image': 'unreadable_image',
      'refused': 'refused',
      'quota_exceeded': 'quota_exceeded',
      'rate_limited': 'rate_limited',
      'timeout': 'timeout',
      'network_error': 'network_error',
      'not_signed_in': 'not_signed_in',
      'unauthorized': 'not_signed_in',
      'ai_disabled': 'ai_disabled',
      'bad_request': 'provider_error',
      'no_items_found': 'provider_error',
      'provider_error': 'provider_error',
      'something_new': 'provider_error',
    };
    for (final MapEntry(key: server, value: expected) in mapping.entries) {
      test('server code $server -> $expected', () async {
        final claude = _FakeClaude(() async => throw ClaudeException(server));
        final service = MealPhotoAnalysisService(claude: () => claude);

        await expectLater(
          service.analyzePhoto(_jpeg()),
          throwsA(isA<MealPhotoException>().having((e) => e.code, 'code', expected)),
        );
        expect(MealPhotoException.codes, contains(expected));
      });
    }
  });

  group('MealPhotoStorageService', () {
    late _FakeBucket bucket;
    late DateTime now;
    String? userId;

    MealPhotoStorageService service() => MealPhotoStorageService(
          bucket: bucket,
          currentUserId: () => userId,
          now: () => now,
          newFileId: () => 'f1',
        );

    setUp(() {
      bucket = _FakeBucket();
      now = DateTime(2026, 11, 8, 12);
      userId = 'u1';
    });

    test('uploadPhoto stores the photo in the own folder and returns its path, not a link', () async {
      final path = await service().uploadPhoto(_jpeg());

      expect(path, 'u1/f1.jpg');
      expect(bucket.uploads.single.path, 'u1/f1.jpg');
      expect(bucket.uploads.single.contentType, 'image/jpeg');
    });

    test('uploadPhoto names a PNG as PNG', () async {
      expect(await service().uploadPhoto(_png()), 'u1/f1.png');
      expect(bucket.uploads.single.contentType, 'image/png');
    });

    test('uploadPhoto is best effort: signed out, no photo or a failed upload give null', () async {
      userId = null;
      expect(await service().uploadPhoto(_jpeg()), isNull);
      userId = 'u1';
      expect(await service().uploadPhoto(Uint8List.fromList([1, 2, 3])), isNull);
      bucket.uploadError = Exception('offline');
      expect(await service().uploadPhoto(_jpeg()), isNull);
      expect(bucket.uploads, isEmpty);
    });

    test('signedUrl signs the storage path for one hour', () async {
      final url = await service().signedUrl('u1/f1.jpg');

      expect(url, contains('/object/sign/meal-photos/u1/f1.jpg'));
      expect(bucket.signs.single, (path: 'u1/f1.jpg', expiresIn: const Duration(hours: 1)));
    });

    test('the cache key is the path: a second ask reuses the URL', () async {
      final s = service();
      final first = await s.signedUrl('u1/f1.jpg');
      final second = await s.signedUrl('u1/f1.jpg');
      await s.signedUrl('u1/f2.jpg');

      expect(second, first);
      expect(bucket.signs.map((r) => r.path), ['u1/f1.jpg', 'u1/f2.jpg']);
    });

    test('a URL close to its end is renewed', () async {
      final s = service();
      final first = await s.signedUrl('u1/f1.jpg');
      now = now.add(const Duration(minutes: 50));
      expect(await s.signedUrl('u1/f1.jpg'), first);
      now = now.add(const Duration(minutes: 6));
      final renewed = await s.signedUrl('u1/f1.jpg');

      expect(renewed, isNot(first));
      expect(bucket.signs, hasLength(2));
    });

    test('tiles asking at the same time share one request', () async {
      final s = service();
      bucket.signGate = Completer<void>();
      final a = s.signedUrl('u1/f1.jpg');
      final b = s.signedUrl('u1/f1.jpg');
      bucket.signGate!.complete();

      expect(await a, await b);
      expect(bucket.signs, hasLength(1));
    });

    test('a failed signing gives null and is not cached', () async {
      final s = service();
      bucket.signError = Exception('offline');
      expect(await s.signedUrl('u1/f1.jpg'), isNull);
      bucket.signError = null;
      expect(await s.signedUrl('u1/f1.jpg'), isNotNull);
      expect(bucket.signs, hasLength(2));
    });

    test('signedUrl refuses something that is no storage path', () async {
      expect(await service().signedUrl('https://evil.test/x.jpg'), isNull);
      expect(await service().signedUrl('u1/../u2/x.jpg'), isNull);
      expect(bucket.signs, isEmpty);
    });

    group('pathOf', () {
      test('a plain path stays as it is', () {
        expect(MealPhotoStorageService.pathOf('u1/1731067200000.jpg'), 'u1/1731067200000.jpg');
      });

      test('an old public link gives its path', () {
        expect(
          MealPhotoStorageService.pathOf(
            'https://abc.supabase.co/storage/v1/object/public/meal-photos/u1/1731067200000.jpg',
          ),
          'u1/1731067200000.jpg',
        );
      });

      test('a signed link gives its path without the token', () {
        expect(
          MealPhotoStorageService.pathOf(
            'https://abc.supabase.co/storage/v1/object/sign/meal-photos/u1/a%20b.jpg?token=xyz',
          ),
          'u1/a b.jpg',
        );
      });

      test('anything else is null', () {
        expect(MealPhotoStorageService.pathOf(null), isNull);
        expect(MealPhotoStorageService.pathOf(''), isNull);
        expect(MealPhotoStorageService.pathOf('photo.jpg'), isNull);
        expect(MealPhotoStorageService.pathOf('u1/../u2/x.jpg'), isNull);
        expect(
          MealPhotoStorageService.pathOf(
            'https://abc.supabase.co/storage/v1/object/public/avatars/u1/x.jpg',
          ),
          isNull,
        );
        expect(MealPhotoStorageService.pathOf('https://example.com/u1/x.jpg'), isNull);
      });
    });

    test('mediaTypeOf reads the magic bytes', () {
      expect(MealPhotoStorageService.mediaTypeOf(_jpeg()), 'image/jpeg');
      expect(MealPhotoStorageService.mediaTypeOf(_png()), 'image/png');
      expect(
        MealPhotoStorageService.mediaTypeOf(
          Uint8List.fromList([...utf8.encode('RIFF'), 0, 0, 0, 0, ...utf8.encode('WEBPVP8 ')]),
        ),
        'image/webp',
      );
      expect(MealPhotoStorageService.mediaTypeOf(Uint8List.fromList(utf8.encode('GIF89a'))), isNull);
      expect(MealPhotoStorageService.mediaTypeOf(Uint8List(0)), isNull);
    });
  });
}
