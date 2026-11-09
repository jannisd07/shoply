// The one door to Claude: the edge function "ai".
//
// What matters here is the contract with the function and the failure
// modes the user can feel: an error must arrive as a typed code (never a
// raw HTTP error), a hung request must give up on time, and Avo's stream
// must survive the network cutting events into arbitrary pieces.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shoply/data/services/claude_service.dart';

final _endpoint = Uri.parse('https://project.test/functions/v1/ai');

ClaudeService _service(
  http.Client client, {
  String locale = 'en',
}) =>
    ClaudeService(
      httpClientFactory: () => client,
      accessToken: () async => 'user-jwt',
      locale: () => locale,
      endpoint: _endpoint,
      anonKey: 'anon-key',
    );

/// Serves [chunks] as one text/event-stream response, byte for byte.
MockClient _sse(List<String> chunks, {int status = 200}) =>
    MockClient.streaming((request, body) async {
      await body.drain<void>();
      return http.StreamedResponse(
        Stream.fromIterable(chunks.map(utf8.encode)),
        status,
        headers: {'content-type': 'text/event-stream'},
      );
    });

/// Records whether [close] was called, to prove a cancel frees the socket.
class _ClosableClient extends http.BaseClient {
  _ClosableClient(this._inner);
  final http.Client _inner;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);

  @override
  void close() {
    closed = true;
    _inner.close();
  }
}

/// Just enough of the Supabase auth client for the token rule.
class _FakeAuth implements GoTrueClient {
  _FakeAuth(this.currentSession, this._refresh);

  @override
  final Session? currentSession;
  final Future<AuthResponse> Function() _refresh;
  int refreshes = 0;

  @override
  Future<AuthResponse> refreshSession([String? refreshToken]) {
    refreshes++;
    return _refresh();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A session whose token expires [expiresIn] from now.
Session _session(String token, Duration expiresIn) => Session(
      accessToken: token,
      tokenType: 'bearer',
      user: User(
        id: 'u1',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-11-08T00:00:00Z',
      ),
    )..expiresAt =
        DateTime.now().add(expiresIn).millisecondsSinceEpoch ~/ 1000;

Future<String?> _codeOf(Future<String> call) async {
  try {
    await call;
    return null;
  } on ClaudeException catch (e) {
    return e.code;
  }
}

void main() {
  group('run', () {
    test('posts the task envelope with the user token and returns result',
        () async {
      late http.Request sent;
      final client = MockClient((request) async {
        sent = request;
        return http.Response(
          jsonEncode({
            'result': {
              'items': [
                {'category_id': 'dairy'}
              ]
            },
            'usage': {'input_tokens': 10, 'output_tokens': 3},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final result = await _service(client, locale: 'de').run(
        'categorize',
        {
          'items': [
            {'name': 'Milch'}
          ]
        },
        timeout: const Duration(seconds: 8),
      );

      expect(result, {
        'items': [
          {'category_id': 'dairy'}
        ]
      });
      expect(sent.method, 'POST');
      expect(sent.url, _endpoint);
      expect(sent.headers['Authorization'], 'Bearer user-jwt');
      expect(sent.headers['apikey'], 'anon-key');
      expect(jsonDecode(sent.body), {
        'task': 'categorize',
        'v': 1,
        'locale': 'de',
        'input': {
          'items': [
            {'name': 'Milch'}
          ]
        },
      });
    });

    test('429 becomes rate_limited with the retry hint', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'code': 'rate_limited',
              'message': 'slow down',
              'retry_after_s': 30,
            }),
            429,
          ));

      await expectLater(
        _service(client).run('categorize', const {},
            timeout: const Duration(seconds: 8)),
        throwsA(isA<ClaudeException>()
            .having((e) => e.code, 'code', 'rate_limited')
            .having((e) => e.retryAfterS, 'retryAfterS', 30)),
      );
    });

    test('429 without a JSON body is still rate_limited', () async {
      final client = MockClient((_) async => http.Response('Too Many', 429));

      await expectLater(
        _service(client).run('categorize', const {},
            timeout: const Duration(seconds: 8)),
        throwsA(isA<ClaudeException>()
            .having((e) => e.code, 'code', 'rate_limited')),
      );
    });

    test('a request that never answers fails with timeout', () async {
      final client =
          MockClient((_) => Completer<http.Response>().future);

      await expectLater(
        _service(client).run('categorize', const {},
            timeout: const Duration(milliseconds: 50)),
        throwsA(isA<ClaudeException>().having((e) => e.code, 'code', 'timeout')),
      );
    });

    test('a server error without a known code is provider_error', () async {
      final client =
          MockClient((_) async => http.Response('<html>oops</html>', 502));

      await expectLater(
        _service(client).run('categorize', const {},
            timeout: const Duration(seconds: 8)),
        throwsA(isA<ClaudeException>()
            .having((e) => e.code, 'code', 'provider_error')),
      );
    });

    test('a dropped connection is network_error', () async {
      final client = MockClient((_) async => throw http.ClientException('down'));

      await expectLater(
        _service(client).run('categorize', const {},
            timeout: const Duration(seconds: 8)),
        throwsA(isA<ClaudeException>()
            .having((e) => e.code, 'code', 'network_error')),
      );
    });

    test('a 200 without a result object is provider_error', () async {
      final client =
          MockClient((_) async => http.Response(jsonEncode({'ok': true}), 200));

      await expectLater(
        _service(client).run('categorize', const {},
            timeout: const Duration(seconds: 8)),
        throwsA(isA<ClaudeException>()
            .having((e) => e.code, 'code', 'provider_error')),
      );
    });
  });

  group('streamAvo', () {
    test('reassembles events cut across chunks, CRLF and multi-line data',
        () async {
      // One 'text' event split mid-JSON and mid-umlaut-free word, a second
      // with CRLF line ends, then a 'message' whose JSON spans two data lines.
      final client = _sse([
        'event: text\ndata: {"del',
        'ta":"Hal"}\n',
        '\nevent: text\r\ndata: {"delta":"lo"}\r\n\r',
        '\n: keep-alive comment\n\n',
        'event: message\ndata: {"content":[{"type":"text",\n',
        'data: "text":"Hallo"}],"stop_reason":"end_turn"}\n\n',
        'event: done\ndata: {}\n\n',
      ]);

      final events = await _service(client).streamAvo(const {
        'messages': [],
      }).toList();

      expect(events, hasLength(3));
      expect((events[0] as AvoTextDelta).text, 'Hal');
      expect((events[1] as AvoTextDelta).text, 'lo');
      final done = events[2] as AvoMessageDone;
      expect(done.stopReason, 'end_turn');
      expect(done.content, [
        {'type': 'text', 'text': 'Hallo'}
      ]);
    });

    test('a multi-byte character split between chunks survives', () async {
      final bytes = utf8.encode('event: text\ndata: {"delta":"Grüße"}\n\n');
      final cut = bytes.indexOf(0xC3) + 1; // inside the two bytes of "ü"
      final client = MockClient.streaming((request, body) async {
        await body.drain<void>();
        return http.StreamedResponse(
          Stream.fromIterable([
            bytes.sublist(0, cut),
            bytes.sublist(cut),
            utf8.encode('event: done\ndata: {}\n\n'),
          ]),
          200,
        );
      });

      final events = await _service(client).streamAvo(const {}).toList();

      expect((events.single as AvoTextDelta).text, 'Grüße');
    });

    test('an error event ends the stream with its code', () async {
      final client = _sse([
        'event: text\ndata: {"delta":"Ich"}\n\n',
        'event: error\ndata: {"code":"quota_exceeded","message":"x"}\n\n',
        'event: text\ndata: {"delta":"never"}\n\n',
      ]);

      final events = await _service(client).streamAvo(const {}).toList();

      expect(events, hasLength(2));
      expect((events.last as AvoStreamError).code, 'quota_exceeded');
    });

    test('an HTTP error before the stream starts becomes AvoStreamError',
        () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'code': 'rate_limited', 'retry_after_s': 12}),
            429,
          ));

      final events = await _service(client).streamAvo(const {}).toList();

      final error = events.single as AvoStreamError;
      expect(error.code, 'rate_limited');
      expect(error.retryAfterS, 12);
      expect(error.httpStatus, 429);
    });

    test('an error inside the stream has no HTTP status', () async {
      final client = _sse([
        'event: error\ndata: {"code":"provider_error"}\n\n',
      ]);

      final events = await _service(client).streamAvo(const {}).toList();

      final error = events.single as AvoStreamError;
      expect(error.code, 'provider_error');
      expect(error.httpStatus, isNull);
    });

    test('no first event in time gives timeout', () async {
      final client = MockClient.streaming((request, body) async {
        await body.drain<void>();
        return http.StreamedResponse(
          StreamController<List<int>>().stream, // never emits
          200,
        );
      });

      final events = await _service(client)
          .streamAvo(const {},
              firstEventTimeout: const Duration(milliseconds: 50))
          .toList();

      expect((events.single as AvoStreamError).code, 'timeout');
    });

    test('the total limit cuts a stream that keeps trickling', () async {
      final controller = StreamController<List<int>>();
      final ticker = Timer.periodic(const Duration(milliseconds: 10), (_) {
        controller.add(utf8.encode('event: text\ndata: {"delta":"."}\n\n'));
      });
      addTearDown(ticker.cancel);
      final client = MockClient.streaming((request, body) async {
        await body.drain<void>();
        return http.StreamedResponse(controller.stream, 200);
      });

      final events = await _service(client)
          .streamAvo(const {},
              totalTimeout: const Duration(milliseconds: 80))
          .toList();

      expect(events.whereType<AvoTextDelta>(), isNotEmpty);
      expect((events.last as AvoStreamError).code, 'timeout');
    });

    test('sends task avo_chat with the locale and asks for SSE', () async {
      late http.BaseRequest sent;
      late String sentBody;
      final client = MockClient.streaming((request, body) async {
        sent = request;
        sentBody = await body.bytesToString();
        return http.StreamedResponse(
          Stream.value(utf8.encode('event: done\ndata: {}\n\n')),
          200,
        );
      });

      await _service(client, locale: 'de').streamAvo(const {
        'messages': [
          {'role': 'user', 'content': 'Hallo'}
        ],
      }).toList();

      expect(sent.headers['Accept'], 'text/event-stream');
      expect(sent.headers['Authorization'], 'Bearer user-jwt');
      expect(jsonDecode(sentBody), {
        'task': 'avo_chat',
        'v': 1,
        'locale': 'de',
        'input': {
          'messages': [
            {'role': 'user', 'content': 'Hallo'}
          ]
        },
      });
    });

    test('cancelAvoStream ends the stream and closes the client', () async {
      final body = StreamController<List<int>>();
      final client = _ClosableClient(MockClient.streaming((request, b) async {
        await b.drain<void>();
        return http.StreamedResponse(body.stream, 200);
      }));
      final service = _service(client);

      final events = <AvoStreamEvent>[];
      final finished = Completer<void>();
      service.streamAvo(const {}).listen(events.add,
          onDone: finished.complete);
      body.add(utf8.encode('event: text\ndata: {"delta":"Hi"}\n\n'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      service.cancelAvoStream();
      await finished.future.timeout(const Duration(seconds: 1));

      expect(events.whereType<AvoTextDelta>().single.text, 'Hi');
      expect(client.closed, isTrue);
    });

    test('a listener that cancels also closes the client', () async {
      final body = StreamController<List<int>>();
      final client = _ClosableClient(MockClient.streaming((request, b) async {
        await b.drain<void>();
        return http.StreamedResponse(body.stream, 200);
      }));

      final first = Completer<AvoStreamEvent>();
      final sub = _service(client).streamAvo(const {}).listen(first.complete);
      body.add(utf8.encode('event: text\ndata: {"delta":"Hi"}\n\n'));
      await first.future.timeout(const Duration(seconds: 1));
      await sub.cancel();

      expect(client.closed, isTrue);
    });
  });

  group('access token', () {
    test('a token that stays valid is used as it is', () async {
      final auth = _FakeAuth(
        _session('fresh', const Duration(hours: 1)),
        () => throw StateError('no refresh expected'),
      );

      expect(await ClaudeService.accessTokenFrom(auth), 'fresh');
      expect(auth.refreshes, 0);
    });

    test('a token about to expire is refreshed first', () async {
      final auth = _FakeAuth(
        _session('old', const Duration(seconds: 20)),
        () async => AuthResponse(
            session: _session('new', const Duration(hours: 1))),
      );

      expect(await ClaudeService.accessTokenFrom(auth), 'new');
      expect(auth.refreshes, 1);
    });

    test('no session means not signed in', () async {
      final auth = _FakeAuth(null, () => throw StateError('unused'));

      expect(await _codeOf(ClaudeService.accessTokenFrom(auth)),
          'not_signed_in');
    });

    test('a refresh the server refuses means signing in again', () async {
      final auth = _FakeAuth(
        _session('old', Duration.zero),
        () async => throw AuthApiException('Invalid Refresh Token',
            statusCode: '400'),
      );

      expect(await _codeOf(ClaudeService.accessTokenFrom(auth)),
          'unauthorized');
    });

    test('a refresh without a connection is a network error', () async {
      final auth = _FakeAuth(
        _session('old', Duration.zero),
        () async => throw AuthRetryableFetchException(),
      );

      expect(await _codeOf(ClaudeService.accessTokenFrom(auth)),
          'network_error');
    });
  });

  test('the locale the service sends is readable', () {
    expect(_service(MockClient((_) async => http.Response('', 200)),
            locale: 'de')
        .locale, 'de');
  });
}
