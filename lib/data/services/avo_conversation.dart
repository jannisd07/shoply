import 'dart:convert';
import 'dart:math';

/// Avo's conversation in the shape the server's `avo_chat` task expects:
/// Anthropic messages, append-only. Assistant turns and the server's context
/// messages are stored exactly as they came back (thinking blocks included),
/// because Claude Sonnet 5.5 ties its thinking to an unchanged history.
///
/// Pure state, no I/O, so the rules are tested on their own.
class AvoConversation {
  AvoConversation({
    DateTime Function()? now,
    this.maxMessages = 40,
    this.maxChars = 150000,
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// Kept below the server's limits (60 messages, 200,000 characters).
  final int maxMessages;
  final int maxChars;

  /// A conversation ends after a day without activity (Kap. 16).
  static const lifetime = Duration(hours: 24);

  /// One tool result is clipped to this many characters (server: 40,000).
  static const maxToolResultChars = 20000;

  final List<Map<String, dynamic>> _messages = [];
  DateTime? _lastActivity;

  /// Fixed for a conversation (`full` or `no_offers`): a changed tool list
  /// would invalidate the prompt cache and the thinking blocks.
  String? toolsVariant;

  /// The consents the conversation was started with. Taking one back ends
  /// the conversation, because earlier turns may hold what is now withheld.
  ({bool health, bool body})? consents;

  List<Map<String, dynamic>> get messages => List.unmodifiable(_messages);
  bool get isEmpty => _messages.isEmpty;

  bool get isExpired {
    final last = _lastActivity;
    return last != null && _now().difference(last) > lifetime;
  }

  void reset() {
    _messages.clear();
    _lastActivity = null;
    toolsVariant = null;
    consents = null;
  }

  /// Ends the conversation when a consent was taken back since it started.
  void applyConsents({required bool health, required bool body}) {
    final before = consents;
    if (before != null && ((before.health && !health) || (before.body && !body))) {
      reset();
    }
    consents = (health: health, body: body);
  }

  /// Appends the person's question. Returns a mark for [rollback].
  int addQuestion(String text) {
    final mark = _messages.length;
    _messages.add({
      'role': 'user',
      'content': [
        {'type': 'text', 'text': text},
      ],
    });
    _lastActivity = _now();
    return mark;
  }

  /// Stores one answer: the server's context message (if any) and the
  /// assistant turn, both verbatim.
  void addAnswer(
    List<Map<String, dynamic>> content, {
    Map<String, dynamic>? contextMessage,
  }) {
    if (contextMessage != null) _messages.add(contextMessage);
    _messages.add({'role': 'assistant', 'content': content});
    _lastActivity = _now();
  }

  /// All tool results of one answer, in one user turn.
  void addToolResults(List<Map<String, dynamic>> results) {
    if (results.isEmpty) return;
    _messages.add({'role': 'user', 'content': results});
  }

  /// Drops everything after [mark]: a failed question leaves no half turn
  /// behind, so the next question starts on a valid history.
  void rollback(int mark) {
    if (mark < 0 || mark >= _messages.length) return;
    _messages.removeRange(mark, _messages.length);
  }

  /// Cuts the oldest turns until both limits hold. It only cuts right before
  /// a question of the person, so tool calls and their results stay together
  /// and the history still starts with a question. The newest question is
  /// never cut away.
  void trim() {
    while (_messages.length > maxMessages || _chars() > maxChars) {
      final cut = _nextQuestion(1);
      if (cut == null) return;
      _messages.removeRange(0, cut);
    }
  }

  int? _nextQuestion(int from) {
    for (var i = from; i < _messages.length; i++) {
      if (isQuestion(_messages[i])) return i;
    }
    return null;
  }

  int _chars() => _messages.fold(0, (sum, m) => sum + jsonEncode(m).length);

  /// A user turn with text and no tool results.
  static bool isQuestion(Map<String, dynamic> message) {
    if (message['role'] != 'user') return false;
    final content = message['content'];
    if (content is String) return true;
    if (content is! List) return false;
    var text = false;
    for (final block in content) {
      if (block is! Map) continue;
      if (block['type'] == 'tool_result') return false;
      if (block['type'] == 'text') text = true;
    }
    return text;
  }

  /// The visible text of an assistant turn.
  static String textOf(List<Map<String, dynamic>> content) => [
        for (final block in content)
          if (block['type'] == 'text' && block['text'] is String)
            block['text'] as String,
      ].join('\n').trim();

  /// A tool_result block for [toolUseId]; [result] is JSON-encoded and
  /// clipped to [maxToolResultChars].
  static Map<String, dynamic> toolResult(
    String toolUseId,
    Object? result, {
    bool isError = false,
  }) {
    var text = result is String
        ? result
        : jsonEncode(result, toEncodable: (value) => value.toString());
    if (text.length > maxToolResultChars) {
      text = '${text.substring(0, maxToolResultChars)}…';
    }
    return {
      'type': 'tool_result',
      'tool_use_id': toolUseId,
      'content': text,
      if (isError) 'is_error': true,
    };
  }
}

/// What a confirm-delete card may delete (Kap. 16, 15.3).
enum AvoDeleteTarget { item, list, foodLog, planEntry, historyTrip, listMember }

AvoDeleteTarget? avoDeleteTargetFromJson(String? value) => switch (value) {
      'item' => AvoDeleteTarget.item,
      'list' => AvoDeleteTarget.list,
      'food_log' => AvoDeleteTarget.foodLog,
      'plan_entry' => AvoDeleteTarget.planEntry,
      'history_trip' => AvoDeleteTarget.historyTrip,
      'list_member' => AvoDeleteTarget.listMember,
      _ => null,
    };

/// A deletion Avo proposed. Only a tap on its card runs it, with this
/// one-time [token], within [AvoPendingDeletes.lifetime] and only while the
/// target is unchanged ([version]).
class AvoPendingDelete {
  const AvoPendingDelete({
    required this.token,
    required this.target,
    required this.targetId,
    required this.name,
    required this.expiresAt,
    this.parentId,
    this.version,
  });

  final String token;
  final AvoDeleteTarget target;
  final String targetId;

  /// The list of an item, so the delete runs on the right list.
  final String? parentId;

  /// The app's own stored name of the target, shown on the card.
  final String name;

  /// e.g. `updated_at` when the card was made; null when the target has none.
  final String? version;
  final DateTime expiresAt;
}

/// Pending deletions of the current conversation, by one-time token.
class AvoPendingDeletes {
  AvoPendingDeletes({DateTime Function()? now, Random? random})
      : _now = now ?? DateTime.now,
        _random = random ?? Random.secure();

  static const lifetime = Duration(minutes: 10);

  final DateTime Function() _now;
  final Random _random;
  final Map<String, AvoPendingDelete> _byToken = {};

  AvoPendingDelete propose({
    required AvoDeleteTarget target,
    required String targetId,
    required String name,
    String? parentId,
    String? version,
  }) {
    final token = List.generate(16, (_) => _random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final pending = AvoPendingDelete(
      token: token,
      target: target,
      targetId: targetId,
      parentId: parentId,
      name: name,
      version: version,
      expiresAt: _now().add(lifetime),
    );
    _byToken[token] = pending;
    return pending;
  }

  /// Takes the pending deletion for [token] out, once. Null for an unknown,
  /// used or expired token.
  AvoPendingDelete? take(String token) {
    final pending = _byToken.remove(token);
    if (pending == null || !_now().isBefore(pending.expiresAt)) return null;
    return pending;
  }

  /// Puts a deletion back after [take] when deleting failed (network), so
  /// "Erneut versuchen" on the card can use the same token while it lasts.
  void restore(AvoPendingDelete pending) {
    if (_now().isBefore(pending.expiresAt)) _byToken[pending.token] = pending;
  }

  void clear() => _byToken.clear();
}
