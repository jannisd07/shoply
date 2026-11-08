import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shoply/core/config/env.dart';
import 'package:shoply/core/localization/app_localizations.dart';

/// A failed call to the edge function `ai`, as a machine-readable [code].
///
/// Server codes: `unauthorized`, `bad_request`, `quota_exceeded`,
/// `rate_limited`, `ai_disabled`, `refused`, `no_items_found`,
/// `unreadable_image`, `no_food_detected`, `provider_error`, `timeout`.
/// Client codes: `network_error` (no connection) and `not_signed_in`.
/// The UI maps codes to its own texts; it never shows a raw error.
class ClaudeException implements Exception {
  const ClaudeException(this.code, {this.retryAfterS});

  final String code;

  /// Seconds the server asked us to wait (rate limit, quota), if it said.
  final int? retryAfterS;

  @override
  String toString() => retryAfterS == null
      ? 'ClaudeException($code)'
      : 'ClaudeException($code, retry after ${retryAfterS}s)';
}

/// One event of an Avo answer stream (task `avo_chat`).
sealed class AvoStreamEvent {
  const AvoStreamEvent();
}

/// A piece of answer text to append to the bubble.
final class AvoTextDelta extends AvoStreamEvent {
  const AvoTextDelta(this.text);

  final String text;
}

/// The finished assistant turn: all content blocks exactly as Claude sent
/// them (text, tool_use, thinking), to be appended to the history unchanged.
/// [contextMessage] is the server's context message for this question (store
/// it right before the assistant turn); [toolCalls] are the checked tool
/// calls in content order.
final class AvoMessageDone extends AvoStreamEvent {
  const AvoMessageDone(
    this.content,
    this.stopReason, {
    this.usage,
    this.contextMessage,
    this.toolCalls = const [],
  });

  final List<Map<String, dynamic>> content;
  final String stopReason;
  final Map<String, dynamic>? usage;
  final Map<String, dynamic>? contextMessage;
  final List<AvoToolCall> toolCalls;
}

/// One tool call of an Avo answer, checked by the server: run it with
/// [input], or, when [error] is set, answer with an is_error tool_result
/// carrying [error] and do not run it.
final class AvoToolCall {
  const AvoToolCall({
    required this.id,
    required this.name,
    this.input = const {},
    this.error,
  });

  factory AvoToolCall.fromJson(Map<String, dynamic> json) => AvoToolCall(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        input: (json['input'] as Map?)?.cast<String, Object?>() ?? const {},
        error: json['error'] as String?,
      );

  final String id;
  final String name;
  final Map<String, Object?> input;
  final String? error;
}

/// The stream failed and ends here; [code] as in [ClaudeException].
final class AvoStreamError extends AvoStreamEvent {
  const AvoStreamError(this.code, {this.retryAfterS});

  final String code;
  final int? retryAfterS;
}

/// The app's only way to Claude: POST `<SUPABASE_URL>/functions/v1/ai` with
/// the user's own JWT. Prompts, tools, models, quota and the API key all
/// live in the edge function; this client holds no key of any kind.
///
/// It uses its own [http.Client] because `functions.invoke` can neither
/// stream (Avo) nor give up after a deadline.
class ClaudeService {
  ClaudeService({
    http.Client Function()? httpClientFactory,
    Future<String> Function()? accessToken,
    String Function()? locale,
    Uri? endpoint,
    String? anonKey,
  })  : _newClient = httpClientFactory ?? http.Client.new,
        _accessToken = accessToken ?? _supabaseAccessToken,
        _locale = locale ?? _appLocale,
        _endpointOverride = endpoint,
        _anonKeyOverride = anonKey;

  static ClaudeService _instance = ClaudeService();
  static ClaudeService get instance => _instance;
  @visibleForTesting
  static set instance(ClaudeService service) => _instance = service;

  static const int protocolVersion = 1;

  static const Set<String> serverCodes = {
    'unauthorized',
    'bad_request',
    'quota_exceeded',
    'rate_limited',
    'ai_disabled',
    'refused',
    'no_items_found',
    'unreadable_image',
    'no_food_detected',
    'provider_error',
    'timeout',
  };

  final http.Client Function() _newClient;
  final Future<String> Function() _accessToken;
  final String Function() _locale;
  final Uri? _endpointOverride;
  final String? _anonKeyOverride;

  /// Shared by all [run] calls so connections are reused.
  late final http.Client _runClient = _newClient();
  final Set<_AvoStreamSession> _sessions = {};

  /// The language every request asks for (`de` or `en`): the app
  /// language, so callers can key what they remember by it.
  String get locale => _locale();

  Uri get _endpoint =>
      _endpointOverride ?? Uri.parse('${Env.supabaseUrl}/functions/v1/ai');
  String get _anonKey => _anonKeyOverride ?? Env.supabaseAnonKey;

  /// Runs one non-streamed [task] and returns its `result` object.
  ///
  /// Gives up after [timeout] (token refresh included) with code `timeout`
  /// and aborts the request. Throws only [ClaudeException].
  Future<Map<String, dynamic>> run(
    String task,
    Map<String, dynamic> input, {
    required Duration timeout,
  }) async {
    final abort = Completer<void>();
    try {
      return await _run(task, input, abort.future).timeout(timeout);
    } on TimeoutException {
      debugPrint('⚠️ [CLAUDE] $task timed out after ${timeout.inMilliseconds} ms');
      throw const ClaudeException('timeout');
    } on ClaudeException catch (e) {
      debugPrint('❌ [CLAUDE] $task failed: ${e.code}');
      rethrow;
    } finally {
      if (!abort.isCompleted) abort.complete();
    }
  }

  Future<Map<String, dynamic>> _run(
    String task,
    Map<String, dynamic> input,
    Future<void> abort,
  ) async {
    final token = await _accessToken();
    final request = http.AbortableRequest('POST', _endpoint, abortTrigger: abort)
      ..headers.addAll(_headers(token, accept: 'application/json'))
      ..body = _envelope(task, input);

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _runClient.send(request));
    } catch (e) {
      debugPrint('❌ [CLAUDE] $task network error: $e');
      throw const ClaudeException('network_error');
    }

    final body = _decodeObject(utf8.decode(response.bodyBytes, allowMalformed: true));
    if (response.statusCode == 200) {
      final result = body?['result'];
      if (result is Map<String, dynamic>) return result;
      throw const ClaudeException('provider_error');
    }
    throw _errorFrom(response.statusCode, body, response.headers);
  }

  /// Streams one Avo turn (task `avo_chat`).
  ///
  /// Ends after `done`, after an [AvoStreamError] (also for HTTP errors and
  /// timeouts: nothing at all within [firstEventTimeout], or the whole turn
  /// over [totalTimeout]), when the listener cancels, or on
  /// [cancelAvoStream]. It never emits a stream error.
  Stream<AvoStreamEvent> streamAvo(
    Map<String, dynamic> input, {
    Duration firstEventTimeout = const Duration(seconds: 8),
    Duration totalTimeout = const Duration(seconds: 60),
  }) {
    final session = _AvoStreamSession(this, input, firstEventTimeout, totalTimeout);
    _sessions.add(session);
    return session.controller.stream;
  }

  /// Stops every running Avo stream and closes its connection. Their
  /// streams end without a further event.
  void cancelAvoStream() {
    for (final session in _sessions.toList()) {
      session.finish();
    }
  }

  Map<String, String> _headers(String token, {required String accept}) => {
        'Authorization': 'Bearer $token',
        'apikey': _anonKey,
        'Content-Type': 'application/json',
        'Accept': accept,
      };

  String _envelope(String task, Map<String, dynamic> input) => jsonEncode({
        'task': task,
        'v': protocolVersion,
        'locale': _locale(),
        'input': input,
      });

  static ClaudeException _errorFrom(
    int status,
    Map<String, dynamic>? body,
    Map<String, String> headers,
  ) {
    final retryAfterS = (body?['retry_after_s'] as num?)?.toInt() ??
        int.tryParse(headers['retry-after'] ?? '');
    final code = body?['code'];
    if (code is String && serverCodes.contains(code)) {
      return ClaudeException(code, retryAfterS: retryAfterS);
    }
    final byStatus = switch (status) {
      401 || 403 => 'unauthorized',
      400 || 413 => 'bad_request',
      429 => 'rate_limited',
      504 => 'timeout',
      _ => 'provider_error',
    };
    return ClaudeException(byStatus, retryAfterS: retryAfterS);
  }

  static Map<String, dynamic>? _decodeObject(String text) {
    if (text.isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// The signed-in user's access token, see [accessTokenFrom].
  static Future<String> _supabaseAccessToken() async {
    final GoTrueClient auth;
    try {
      auth = Supabase.instance.client.auth;
    } catch (_) {
      throw const ClaudeException('not_signed_in');
    }
    return accessTokenFrom(auth);
  }

  /// [auth]'s access token, refreshed first when it expires within a minute
  /// (same rule as the list import). A refresh the auth server refuses
  /// (revoked or expired refresh token) means signing in again
  /// (`unauthorized`); one that cannot reach it is `network_error`.
  @visibleForTesting
  static Future<String> accessTokenFrom(GoTrueClient auth) async {
    var session = auth.currentSession;
    if (session == null) throw const ClaudeException('not_signed_in');

    final expiresAt = session.expiresAt;
    final expiresSoon = expiresAt != null &&
        DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000)
            .isBefore(DateTime.now().add(const Duration(minutes: 1)));
    if (expiresSoon) {
      try {
        session = (await auth.refreshSession()).session ?? session;
      } on AuthSessionMissingException {
        throw const ClaudeException('not_signed_in');
      } on AuthRetryableFetchException catch (e) {
        debugPrint('❌ [CLAUDE] Token refresh could not reach the server: $e');
        throw const ClaudeException('network_error');
      } on AuthException catch (e) {
        debugPrint('❌ [CLAUDE] Token refresh refused: ${e.statusCode}');
        throw const ClaudeException('unauthorized');
      } catch (e) {
        debugPrint('❌ [CLAUDE] Token refresh failed: $e');
        throw const ClaudeException('network_error');
      }
    }
    return session.accessToken;
  }

  /// The app language (not the device language): what the user reads.
  static String _appLocale() =>
      AppLocalizations.currentLanguageCode == 'de' ? 'de' : 'en';
}

/// One running `avo_chat` request: owns its client, timers and the
/// controller the listener sees.
class _AvoStreamSession {
  _AvoStreamSession(
    this._service,
    this._input,
    this._firstEventTimeout,
    this._totalTimeout,
  ) {
    controller = StreamController<AvoStreamEvent>(
      onListen: _start,
      onCancel: finish,
    );
  }

  final ClaudeService _service;
  final Map<String, dynamic> _input;
  final Duration _firstEventTimeout;
  final Duration _totalTimeout;

  late final StreamController<AvoStreamEvent> controller;
  final Completer<void> _abort = Completer<void>();
  http.Client? _client;
  StreamSubscription<_SseEvent>? _events;
  Timer? _firstEventTimer;
  Timer? _totalTimer;
  bool _finished = false;
  bool _sawMessage = false;

  Future<void> _start() async {
    _firstEventTimer = Timer(_firstEventTimeout, () => _fail('timeout'));
    _totalTimer = Timer(_totalTimeout, () => _fail('timeout'));
    try {
      final token = await _service._accessToken();
      if (_finished) return;
      final client = _client = _service._newClient();
      final request = http.AbortableRequest(
        'POST',
        _service._endpoint,
        abortTrigger: _abort.future,
      )
        ..headers.addAll(_service._headers(token, accept: 'text/event-stream'))
        ..body = _service._envelope('avo_chat', _input);

      final response = await client.send(request);
      if (_finished) return;
      if (response.statusCode != 200) {
        final bytes = await response.stream.toBytes();
        final error = ClaudeService._errorFrom(
          response.statusCode,
          ClaudeService._decodeObject(utf8.decode(bytes, allowMalformed: true)),
          response.headers,
        );
        _fail(error.code, retryAfterS: error.retryAfterS);
        return;
      }
      _events = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .transform(const _SseDecoder())
          .listen(
            _onEvent,
            onError: (Object e) => _fail('network_error'),
            onDone: () => _sawMessage ? finish() : _fail('network_error'),
          );
    } on ClaudeException catch (e) {
      _fail(e.code, retryAfterS: e.retryAfterS);
    } catch (e) {
      if (!_finished) debugPrint('❌ [CLAUDE] avo_chat network error: $e');
      _fail('network_error');
    }
  }

  void _onEvent(_SseEvent event) {
    if (_finished) return;
    _firstEventTimer?.cancel();
    final data = ClaudeService._decodeObject(event.data);
    switch (event.event) {
      case 'text':
        final delta = data?['delta'];
        if (delta is String && delta.isNotEmpty) controller.add(AvoTextDelta(delta));
      case 'message':
        final content = data?['content'];
        final stopReason = data?['stop_reason'];
        if (content is! List || stopReason is! String) {
          _fail('provider_error');
          return;
        }
        _sawMessage = true;
        final usage = data?['usage'];
        final contextMessage = data?['context_message'];
        final toolCalls = data?['tool_calls'];
        controller.add(AvoMessageDone(
          content.whereType<Map<String, dynamic>>().toList(),
          stopReason,
          usage: usage is Map<String, dynamic> ? usage : null,
          contextMessage:
              contextMessage is Map<String, dynamic> ? contextMessage : null,
          toolCalls: [
            if (toolCalls is List)
              for (final call in toolCalls.whereType<Map<String, dynamic>>())
                AvoToolCall.fromJson(call),
          ],
        ));
      case 'error':
        final code = data?['code'];
        _fail(
          code is String && code.isNotEmpty ? code : 'provider_error',
          retryAfterS: (data?['retry_after_s'] as num?)?.toInt(),
        );
      case 'done':
        finish();
    }
  }

  void _fail(String code, {int? retryAfterS}) {
    if (_finished) return;
    debugPrint('❌ [CLAUDE] avo_chat ended with $code');
    controller.add(AvoStreamError(code, retryAfterS: retryAfterS));
    finish();
  }

  /// Ends the session: stops timers, aborts the request, closes the client
  /// and the stream. Safe to call more than once.
  void finish() {
    if (_finished) return;
    _finished = true;
    _firstEventTimer?.cancel();
    _totalTimer?.cancel();
    _events?.cancel();
    if (!_abort.isCompleted) _abort.complete();
    _client?.close();
    controller.close();
    _service._sessions.remove(this);
  }
}

/// One server-sent event: its `event:` name and its `data:` lines joined
/// by "\n".
class _SseEvent {
  const _SseEvent(this.event, this.data);

  final String event;
  final String data;
}

/// Turns SSE lines (already split, any line ending) into events. Comments
/// are skipped; an event without a name is a `message` (as the spec says).
class _SseDecoder extends StreamTransformerBase<String, _SseEvent> {
  const _SseDecoder();

  @override
  Stream<_SseEvent> bind(Stream<String> lines) =>
      Stream<_SseEvent>.eventTransformed(lines, _SseSink.new);
}

class _SseSink implements EventSink<String> {
  _SseSink(this._out);

  final EventSink<_SseEvent> _out;
  String _event = '';
  final StringBuffer _data = StringBuffer();
  bool _hasData = false;

  @override
  void add(String line) {
    if (line.isEmpty) {
      if (_hasData || _event.isNotEmpty) {
        _out.add(_SseEvent(_event.isEmpty ? 'message' : _event, _data.toString()));
      }
      _event = '';
      _data.clear();
      _hasData = false;
      return;
    }
    if (line.startsWith(':')) return;

    final colon = line.indexOf(':');
    final field = colon == -1 ? line : line.substring(0, colon);
    var value = colon == -1 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    switch (field) {
      case 'event':
        _event = value;
      case 'data':
        if (_hasData) _data.write('\n');
        _data.write(value);
        _hasData = true;
    }
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _out.addError(error, stackTrace);

  /// An event cut off by the end of the stream is dropped, as in the spec.
  @override
  void close() => _out.close();
}
