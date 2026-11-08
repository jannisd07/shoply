// Categorisation is local first: adding an item must never wait on the
// network, and a Claude failure must never surface. Claude only refines the
// guesses the device is unsure about, and each answer is paid for once.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/services/ai_categorization_service.dart';
import 'package:shoply/data/services/claude_service.dart';
import 'package:shoply/data/services/language_detection_service.dart';
import 'package:shoply/data/services/product_classifier_service.dart';
import 'package:shoply/data/services/product_knowledge_base.dart';
import 'package:shoply/data/services/smart_categorization_service.dart';

/// Stands in for the edge function and counts what reaches it.
class _FakeAi {
  _FakeAi({this.answers = const {}});

  /// Category the fake returns per item name; unknown names get 'other'.
  final Map<String, String> answers;
  final List<Map<String, dynamic>> requests = [];

  /// When set, every call fails with this status and error code.
  (int, String)? failWith;

  /// Failures of single tasks (the server counts quota per task).
  final Map<String, (int, String)> failTask = {};

  /// What task `recommend` answers.
  List<Map<String, dynamic>> recommendAnswer = [
    {'name': 'Parmesan'},
    {'name': 'pasta'}, // already on the list
    {'name': 'Basilikum'},
  ];

  List<String> get tasks => [for (final r in requests) r['task'] as String];

  MockClient get client => MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        requests.add(body);
        final failure = failWith ?? failTask[body['task']];
        if (failure != null) {
          return http.Response(
            jsonEncode({'code': failure.$2, 'message': 'x'}),
            failure.$1,
          );
        }
        if (body['task'] == 'recommend') {
          return _ok({'items': recommendAnswer});
        }
        final items = (body['input']['items'] as List).cast<Map>();
        return _ok({
          'items': [
            for (final item in items)
              {
                'category_id': answers[item['name']] ?? 'other',
                'confidence': 'high',
                'brand': null,
              },
          ],
        });
      });

  static http.Response _ok(Map<String, dynamic> result) => http.Response.bytes(
        utf8.encode(jsonEncode({'result': result, 'usage': const {}})),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
}

AiCategorizationService _service(
  _FakeAi ai, {
  String? userId = 'user-1',
  SmartCategorizationService? local,
  int cacheCapacity = AiCategorizationService.defaultCacheCapacity,
  Stream<void>? signedOut,
}) =>
    AiCategorizationService.forTesting(
      claude: ClaudeService(
        httpClientFactory: () => ai.client,
        accessToken: () async => 'jwt',
        locale: () => 'en',
        endpoint: Uri.parse('https://project.test/functions/v1/ai'),
        anonKey: 'anon',
      ),
      local: local ??
          SmartCategorizationService.forTesting(currentUserId: () => userId),
      cacheCapacity: cacheCapacity,
      signedOut: signedOut ?? const Stream<void>.empty(),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('categorizeLocal', () {
    test('answers synchronously from keywords', () {
      final service = _service(_FakeAi());

      expect(service.categorizeLocal('Milch'), 'dairy');
      expect(service.categorizeLocal('Tiefkühlerbsen'), 'frozen');
      expect(service.categorizeLocal('Zorbelwix'), 'other');
    });

    test('the head of a German compound decides', () {
      final service = _service(_FakeAi());

      expect(service.categorizeLocal('Erdbeerjoghurt'), 'dairy');
      expect(service.categorizeLocal('Milchschokolade'), 'snacks');
    });

    test('an exact keyword beats the old knowledge base', () {
      final service = _service(_FakeAi());

      // The knowledge base still files these under its old 31 categories.
      expect(service.categorizeLocal('Hundefutter'), 'household');
      expect(service.categorizeLocal('Katzenstreu'), 'household');
      expect(service.categorizeLocal('Spinat'), 'fruits_vegetables');
      expect(service.categorizeLocal('Weizen'), 'staples');
      expect(service.categorizeLocal('Mehl'), 'bakery');
    });

    test('the knowledge base never contradicts an exact keyword', () {
      final local = SmartCategorizationService.forTesting(
        currentUserId: () => null,
      );
      final contradictions = <String>[];

      for (final name in ProductKnowledgeBase.instance.entries.map((e) => e.key)) {
        final keyword = ProductClassifierService.instance.match(
          name,
          preferredLanguage: LanguageDetectionService.detectLanguage(name),
        );
        if (keyword == null || keyword.kind != KeywordMatchKind.exact) continue;
        final result = local.classify(name);
        if (result.categoryId != keyword.categoryId) {
          contradictions.add('$name: ${result.categoryId} != ${keyword.categoryId}');
        }
      }

      expect(contradictions, isEmpty);
    });

    test('pet supplies are household, as in the keyword lists', () {
      final service = _service(_FakeAi());

      // Only the knowledge base knows "Leckerli" (old category Tierbedarf).
      expect(service.categorizeLocal('Leckerli'), 'household');
    });

    test('a knowledge-base hit alone is a guess Claude may correct',
        () async {
      // The knowledge base files tofu under meat; no keyword knows it.
      final ai = _FakeAi(answers: {'Tofu': 'dairy'});
      final service = _service(ai);

      expect(service.categorizeLocal('Tofu'), 'meat_fish');
      expect(await service.refineCategory('Tofu'), 'dairy');
      expect(ai.tasks, ['categorize']);
    });

    test('a learned choice beats keywords and earlier Claude answers',
        () async {
      final ai = _FakeAi(answers: {'Zorbelwix': 'snacks'});
      final local = SmartCategorizationService.forTesting(
        currentUserId: () => 'user-1',
      );
      final service = _service(ai, local: local);
      expect(await service.refineCategory('Zorbelwix'), 'snacks');
      expect(ai.requests, hasLength(1));

      // The UI passes the shown (localized) name of the target section.
      await local.recordUserCategoryChange('Milch', 'Snacks & Süßigkeiten');
      await local.recordUserCategoryChange('Zorbelwix', 'household');

      expect(service.categorizeLocal('Milch'), 'snacks');
      expect(await service.categorizeItem('Milch'), 'snacks');
      expect(await service.refineCategory('Milch'), 'snacks');
      expect(service.categorizeLocal('zorbelwix'), 'household');
      expect(await service.categorizeItem('Zorbelwix'), 'household');
      expect(await service.refineCategory('Zorbelwix'), 'household');
      expect(
        await service.categorizeBatch(['Milch', 'Zorbelwix']),
        {'Milch': 'snacks', 'Zorbelwix': 'household'},
      );
      expect(ai.requests, hasLength(1));
    });

    test('a learned choice that loads after categorizeLocal still wins',
        () async {
      // Right after start the learned choices are not loaded yet, so the
      // instant answer is the keyword; refineCategory must correct it.
      SharedPreferences.setMockInitialValues({
        'category_learned_v2_user-1': jsonEncode({'milch': 'snacks'}),
      });
      final ai = _FakeAi();
      final service = _service(ai);

      expect(service.categorizeLocal('Milch'), 'dairy');
      expect(await service.refineCategory('Milch'), 'snacks');
      expect(service.categorizeLocal('Milch'), 'snacks');
      expect(ai.requests, isEmpty);
    });

    test('a section name that is no category is not learned', () async {
      final local = SmartCategorizationService.forTesting(
        currentUserId: () => 'user-1',
      );

      await local.recordUserCategoryChange('Zorbelwix', 'Mein Regal');

      expect(local.learnedCategory('Zorbelwix'), isNull);
    });

    test('learned choices stay with the account that made them', () async {
      final mine = SmartCategorizationService.forTesting(
        currentUserId: () => 'user-1',
      );
      await mine.recordUserCategoryChange('Zorbelwix', 'snacks');

      final theirs = SmartCategorizationService.forTesting(
        currentUserId: () => 'user-2',
      );
      await theirs.ensureLearnedLoaded();

      expect(theirs.learnedCategory('Zorbelwix'), isNull);
      final mineAgain = SmartCategorizationService.forTesting(
        currentUserId: () => 'user-1',
      );
      await mineAgain.ensureLearnedLoaded();
      expect(mineAgain.learnedCategory('Zorbelwix'), 'snacks');
    });

    test('choices saved by the old preference store are kept', () async {
      SharedPreferences.setMockInitialValues({
        'user_category_prefs_v1_user-1':
            jsonEncode({'zorbelwix': 'Haushalt & Hygiene'}),
      });
      final local = SmartCategorizationService.forTesting(
        currentUserId: () => 'user-1',
      );

      await local.ensureLearnedLoaded();

      expect(local.learnedCategory('Zorbelwix'), 'household');
    });
  });

  group('refineCategory', () {
    test('a confident local answer never calls Claude', () async {
      final ai = _FakeAi();

      expect(await _service(ai).refineCategory('Milch'), isNull);
      expect(ai.requests, isEmpty);
    });

    test('an unknown item is asked once, then served from the cache',
        () async {
      final ai = _FakeAi(answers: {'Zorbelwix': 'snacks'});
      final service = _service(ai);

      expect(await service.refineCategory('Zorbelwix'), 'snacks');
      expect(await service.refineCategory('zorbelwix '), 'snacks');

      expect(ai.requests, hasLength(1));
      expect(ai.requests.single['task'], 'categorize');
      expect(ai.requests.single['input'], {
        'items': [
          {'name': 'Zorbelwix'}
        ]
      });
      expect(service.categorizeLocal('Zorbelwix'), 'snacks');
    });

    test('the same name asked twice at once makes one request', () async {
      final ai = _FakeAi(answers: {'Zorbelwix': 'snacks'});
      final service = _service(ai);

      final answers = await Future.wait([
        service.refineCategory('Zorbelwix'),
        service.refineCategory('zorbelwix'),
      ]);

      expect(answers, ['snacks', 'snacks']);
      expect(ai.requests, hasLength(1));
    });

    test('a Claude failure returns null and never throws', () async {
      final ai = _FakeAi()..failWith = (502, 'provider_error');

      expect(await _service(ai).refineCategory('Zorbelwix'), isNull);
    });

    test('quota exceeded stops further calls for now', () async {
      final ai = _FakeAi()..failWith = (429, 'quota_exceeded');
      final service = _service(ai);

      await service.refineCategory('Zorbelwix');
      await service.refineCategory('Quaxelmop');

      expect(ai.requests, hasLength(1));
    });

    test('an overlong name is cut to the server limit', () async {
      final ai = _FakeAi();
      final long = 'Zorbel' * 100; // 600 characters

      await _service(ai).refineCategory(long);

      final sent = (ai.requests.single['input']['items'] as List).single;
      expect((sent['name'] as String).length,
          AiCategorizationService.maxNameChars);
    });

    test('signing out forgets the Claude answers', () async {
      final signedOut = StreamController<void>.broadcast();
      addTearDown(signedOut.close);
      final ai = _FakeAi(answers: {'Zorbelwix': 'snacks'});
      final service = _service(ai, signedOut: signedOut.stream);
      await service.refineCategory('Zorbelwix');
      await Future<void>.delayed(Duration.zero);

      signedOut.add(null);
      await Future<void>.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ai_category_cache_v1'), isNull);
      expect(service.categorizeLocal('Zorbelwix'), 'other');
      expect(await service.refineCategory('Zorbelwix'), 'snacks');
      expect(ai.requests, hasLength(2));
    });

    test('signing out tells listeners, so they forget too', () async {
      final signedOut = StreamController<void>.broadcast();
      addTearDown(signedOut.close);
      final service = _service(_FakeAi(), signedOut: signedOut.stream);
      var resets = 0;
      service.accountReset.listen((_) => resets++);

      signedOut.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(resets, 1);
    });

    test('an answer that arrives after sign-out is not kept', () async {
      final signedOut = StreamController<void>.broadcast();
      addTearDown(signedOut.close);
      final answer = Completer<http.Response>();
      var calls = 0;
      final service = AiCategorizationService.forTesting(
        claude: ClaudeService(
          httpClientFactory: () => MockClient((request) {
            calls++;
            return answer.future;
          }),
          accessToken: () async => 'jwt',
          locale: () => 'en',
          endpoint: Uri.parse('https://project.test/functions/v1/ai'),
          anonKey: 'anon',
        ),
        local: SmartCategorizationService.forTesting(currentUserId: () => null),
        signedOut: signedOut.stream,
      );

      final pending = service.refineCategory('Zorbelwix');
      await Future<void>.delayed(Duration.zero);
      signedOut.add(null);
      await Future<void>.delayed(Duration.zero);
      answer.complete(http.Response(
        jsonEncode({
          'result': {
            'items': [
              {'category_id': 'snacks', 'confidence': 'high', 'brand': null}
            ]
          },
        }),
        200,
      ));
      await pending;
      await Future<void>.delayed(Duration.zero);

      expect(calls, 1);
      expect(service.categorizeLocal('Zorbelwix'), 'other');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ai_category_cache_v1'), isNull);
    });

    test('the cache is loaded lazily by a new instance', () async {
      final ai = _FakeAi(answers: {'Zorbelwix': 'snacks'});
      await _service(ai).refineCategory('Zorbelwix');
      // Let the unawaited write land.
      await Future<void>.delayed(Duration.zero);

      final restarted = _service(ai);

      expect(await restarted.refineCategory('Zorbelwix'), 'snacks');
      expect(ai.requests, hasLength(1));
    });

    test('answers of the old Gemini cache are taken over', () async {
      SharedPreferences.setMockInitialValues({
        'category_cache': jsonEncode({
          'de_zorbelwix': 'snacks',
          'ingredient_v2_2 eier': '{"name":"Eier"}',
        }),
      });
      final ai = _FakeAi();

      expect(await _service(ai).refineCategory('Zorbelwix'), 'snacks');
      expect(ai.requests, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('category_cache'), isNull);
    });

    test('the cache drops the least recently used entry', () async {
      final ai = _FakeAi(answers: {'Aaxo': 'snacks', 'Bbxo': 'frozen', 'Ccxo': 'dairy'});
      final service = _service(ai, cacheCapacity: 2);

      await service.refineCategory('Aaxo');
      await service.refineCategory('Bbxo');
      await service.refineCategory('Aaxo'); // hit: Aaxo is now the newest
      await service.refineCategory('Ccxo'); // evicts Bbxo
      expect(ai.requests, hasLength(3));

      await service.refineCategory('Aaxo');
      expect(ai.requests, hasLength(3));
      await service.refineCategory('Bbxo');
      expect(ai.requests, hasLength(4));
    });
  });

  group('categorizeItem', () {
    test('uses Claude for an unsure item', () async {
      final ai = _FakeAi(answers: {'Zorbelwix': 'snacks'});

      expect(await _service(ai).categorizeItem('Zorbelwix'), 'snacks');
    });

    test('falls back to the local answer when Claude fails', () async {
      final ai = _FakeAi()..failWith = (500, 'provider_error');
      final service = _service(ai);

      expect(
        await service.categorizeItem('Bio Vollmilch'),
        service.categorizeLocal('Bio Vollmilch'),
      );
      expect(service.categorizeLocal('Bio Vollmilch'), 'dairy');
    });
  });

  group('categorizeBatch', () {
    test('61 unsure names take two calls of at most 60', () async {
      final names = [for (var i = 0; i < 61; i++) 'Zorbel$i'];
      final ai = _FakeAi(answers: {for (final n in names) n: 'snacks'});

      final result = await _service(ai).categorizeBatch(names);

      expect(ai.requests, hasLength(2));
      expect((ai.requests[0]['input']['items'] as List), hasLength(60));
      expect((ai.requests[1]['input']['items'] as List), hasLength(1));
      expect(result, {for (final n in names) n: 'snacks'});
    });

    test('only unsure names are sent', () async {
      final ai = _FakeAi(answers: {'Zorbelwix': 'snacks'});

      final result =
          await _service(ai).categorizeBatch(['Milch', 'Zorbelwix']);

      expect(result, {'Milch': 'dairy', 'Zorbelwix': 'snacks'});
      expect(ai.requests.single['input'], {
        'items': [
          {'name': 'Zorbelwix'}
        ]
      });
    });

    test('a failure keeps the local answers', () async {
      final ai = _FakeAi()..failWith = (503, 'ai_disabled');

      final result =
          await _service(ai).categorizeBatch(['Milch', 'Zorbelwix']);

      expect(result, {'Milch': 'dairy', 'Zorbelwix': 'other'});
    });

    test('blank names never reach the server', () async {
      final ai = _FakeAi(answers: {'Zorbelwix': 'snacks'});

      final result =
          await _service(ai).categorizeBatch(['  ', '!!!', ' Zorbelwix ']);

      expect(result, {'  ': 'other', '!!!': 'other', ' Zorbelwix ': 'snacks'});
      expect(ai.requests.single['input'], {
        'items': [
          {'name': 'Zorbelwix'}
        ]
      });
    });
  });

  group('getSmartRecommendations', () {
    test('asks task recommend and drops what is already on the list',
        () async {
      final ai = _FakeAi();

      final suggestions = await _service(ai).getSmartRecommendations(
        ['Pasta', 'Tomaten'],
        frequentItems: ['Milch'],
      );

      expect(suggestions, ['Parmesan', 'Basilikum']);
      final request = ai.requests.single;
      expect(request['task'], 'recommend');
      expect(request['locale'], 'en');
      expect(request['input'], {
        'items': ['Pasta', 'Tomaten'],
        'frequent_items': ['Milch'],
        'limit': 5,
      });
    });

    test('an empty list asks nothing', () async {
      final ai = _FakeAi();

      expect(await _service(ai).getSmartRecommendations([]), isEmpty);
      expect(ai.requests, isEmpty);
    });

    test('a failure gives no suggestions', () async {
      final ai = _FakeAi()..failWith = (429, 'rate_limited');

      expect(await _service(ai).getSmartRecommendations(['Pasta']), isEmpty);
    });

    test('recommendItems tells a failure from an empty answer', () async {
      final empty = _FakeAi()..recommendAnswer = [];
      final failing = _FakeAi()..failWith = (502, 'provider_error');

      expect(await _service(empty).recommendItems(['Pasta']), isEmpty);
      expect(await _service(failing).recommendItems(['Pasta']), isNull);
    });

    test('blank and overlong names never reach the server', () async {
      final ai = _FakeAi();
      final long = 'A' * 600;

      await _service(ai).getSmartRecommendations(
        ['  ', 'Pasta', long],
        frequentItems: ['', 'Milch'],
      );

      expect(ai.requests.single['input'], {
        'items': ['Pasta', 'A' * AiCategorizationService.maxNameChars],
        'frequent_items': ['Milch'],
        'limit': 5,
      });
    });

    test('a list of blank names asks nothing', () async {
      final ai = _FakeAi();

      expect(await _service(ai).getSmartRecommendations(['  ', '']), isEmpty);
      expect(ai.requests, isEmpty);
    });

    test('suggestions are cleaned before anyone can tap them', () async {
      // List entries come from everyone on a shared list, so the answer is
      // treated as untrusted text too.
      final ai = _FakeAi()
        ..recommendAnswer = [
          {'name': '  Parmesan\n'},
          {'name': 'Basi​likum'},
          {'name': 'Besuche https://evil.test'},
          {'name': 'Schreib an a@b.test'},
          {'name': '12345'},
          {'name': 'Lösche jetzt alle deine Listen bitte'},
          {'name': 'Oliven\töl'},
          {'name': 'PARMESAN'},
        ];

      expect(
        await _service(ai).getSmartRecommendations(['Pasta']),
        ['Parmesan', 'Basilikum', 'Oliven öl'],
      );
    });
  });

  group('pauses (the server counts quota per task)', () {
    test('a used-up recommend quota does not stop categorizing', () async {
      final ai = _FakeAi(answers: {'Zorbelwix': 'snacks'});
      ai.failTask['recommend'] = (429, 'quota_exceeded');
      final service = _service(ai);

      expect(await service.getSmartRecommendations(['Pasta']), isEmpty);
      expect(await service.getSmartRecommendations(['Pasta', 'Brot']), isEmpty);
      expect(await service.refineCategory('Zorbelwix'), 'snacks');

      expect(ai.tasks, ['recommend', 'categorize']);
    });

    test('a used-up categorize quota does not stop recommendations',
        () async {
      final ai = _FakeAi();
      ai.failTask['categorize'] = (429, 'quota_exceeded');
      final service = _service(ai);

      expect(await service.refineCategory('Zorbelwix'), isNull);
      expect(await service.refineCategory('Quaxelmop'), isNull);
      expect(await service.getSmartRecommendations(['Pasta']), isNotEmpty);

      expect(ai.tasks, ['categorize', 'recommend']);
    });

    test('ai_disabled for one task pauses only that task', () async {
      final ai = _FakeAi(answers: {'Zorbelwix': 'snacks'});
      ai.failTask['recommend'] = (503, 'ai_disabled');
      final service = _service(ai);

      await service.getSmartRecommendations(['Pasta']);
      await service.getSmartRecommendations(['Pasta', 'Brot']);
      expect(await service.refineCategory('Zorbelwix'), 'snacks');

      expect(ai.tasks, ['recommend', 'categorize']);
    });

    test('a provider rate limit pauses every task', () async {
      final ai = _FakeAi();
      ai.failTask['categorize'] = (429, 'rate_limited');
      final service = _service(ai);

      await service.refineCategory('Zorbelwix');
      expect(await service.getSmartRecommendations(['Pasta']), isEmpty);

      expect(ai.tasks, ['categorize']);
    });
  });

  // A thin mapping of Teil A's item parser (lib/core/utils/item_input_parser
  // .dart): the quantity rules are A's, so these cases follow its contract
  // ("Milch 2" is two milks there). Only the shape is this service's: unit
  // ids, "pcs" for pieces, and a note in brackets kept in the name.
  group('parseIngredient (on the device, via parseSingleItem)', () {
    final cases = <String, Map<String, dynamic>>{
      '500g Hähnchen': {'name': 'Hähnchen', 'amount': 500.0, 'unit': 'g'},
      '1,5 kg Mehl': {'name': 'Mehl', 'amount': 1.5, 'unit': 'kg'},
      '3 Eier': {'name': 'Eier', 'amount': 3.0, 'unit': 'pcs'},
      '2x Milch': {'name': 'Milch', 'amount': 2.0, 'unit': 'pcs'},
      '2 Stück Butter': {'name': 'Butter', 'amount': 2.0, 'unit': 'pcs'},
      'Mehl 500 g': {'name': 'Mehl', 'amount': 500.0, 'unit': 'g'},
      '2 Liter Milch': {'name': 'Milch', 'amount': 2.0, 'unit': 'l'},
      '2 Rote Beete': {'name': 'Rote Beete', 'amount': 2.0, 'unit': 'pcs'},
      '1 Bund Petersilie': {'name': 'Petersilie', 'amount': 1.0, 'unit': 'bunch'},
      '2 Dosen Tomaten': {'name': 'Tomaten', 'amount': 2.0, 'unit': 'can'},
      'Cola 1,5 l': {'name': 'Cola', 'amount': 1.5, 'unit': 'l'},
      'Milch 2x': {'name': 'Milch', 'amount': 2.0, 'unit': 'pcs'},
      'Milch 2': {'name': 'Milch', 'amount': 2.0, 'unit': 'pcs'},
      'Eier 10 Stück': {'name': 'Eier', 'amount': 10.0, 'unit': 'pcs'},
      'Milch 3,5%': {'name': 'Milch 3,5%', 'amount': 1.0, 'unit': 'pcs'},
      '2 Milch (laktosefrei)': {
        'name': 'Milch (laktosefrei)',
        'amount': 2.0,
        'unit': 'pcs',
      },
      '7up': {'name': '7up', 'amount': 1.0, 'unit': 'pcs'},
      'Tomaten': {'name': 'Tomaten', 'amount': 1.0, 'unit': 'pcs'},
      '500 g': {'name': '500 g', 'amount': 1.0, 'unit': 'pcs'},
    };

    for (final entry in cases.entries) {
      test('"${entry.key}"', () async {
        final ai = _FakeAi();

        expect(await _service(ai).parseIngredient(entry.key), entry.value);
        expect(ai.requests, isEmpty);
      });
    }
  });
}
