import 'package:flutter/foundation.dart';

import 'package:shoply/data/services/avo_assistant_service.dart';

/// What a photo for Avo is (Kap. 7.1): a meal to estimate or a shopping
/// note to read.
enum AvoPhotoIntent { meal, list }

/// Where one question of the Avo tab stands (Kap. 3.2, 3.3).
enum AvoTurnPhase {
  /// Sent while another answer was running: "Wird nach dieser Antwort
  /// gesendet".
  queued,

  /// Offline when sent: "Nicht gesendet · Erneut senden". Never resent by
  /// itself.
  notSent,

  /// Avo is answering (status line, then cards and text).
  working,

  /// Answered.
  done,

  /// Stopped with "Stopp" (or the app was left mid-answer): "Angehalten."
  stopped,

  /// The answer failed; [AvoTurn.errorCode] says why.
  failed,
}

/// The status line text while Avo works (table 3.4): a translation key and
/// its parameters.
@immutable
class AvoWorkStep {
  const AvoWorkStep(this.key, [this.params = const {}]);

  static const thinking = AvoWorkStep('avo_status_thinking');

  final String key;
  final Map<String, String> params;

  @override
  bool operator ==(Object other) =>
      other is AvoWorkStep &&
      other.key == key &&
      mapEquals(other.params, params);

  @override
  int get hashCode => Object.hash(
    key,
    Object.hashAll(params.entries.map((e) => Object.hash(e.key, e.value))),
  );
}

/// The status line step for the tool [name] the app is about to run, with
/// the list name from [listName] ("Schreibt auf Wocheneinkauf"). Unknown or
/// unnamed targets fall back to "Denkt nach".
AvoWorkStep avoWorkStepFor(
  String name,
  Map<String, Object?> input, {
  String? Function(String listId)? listName,
  String? Function(String? listId)? storeName,
}) {
  String? list(String key) {
    final id = input[key];
    if (id is! String || id.isEmpty) return null;
    final n = listName?.call(id)?.trim();
    return n == null || n.isEmpty ? null : n;
  }

  AvoWorkStep withList(String key, String? name) =>
      name == null ? AvoWorkStep.thinking : AvoWorkStep(key, {'list': name});

  switch (name) {
    case 'get_list_contents':
      return withList('avo_status_reading_list', list('list_id'));
    case 'add_item_to_list':
    case 'check_items':
    case 'update_item':
    case 'complete_list':
    case 'add_history_items_to_list':
    case 'add_recipe_to_list':
    case 'plan_to_list':
      return withList('avo_status_writing_list', list('list_id'));
    case 'move_items':
      return withList('avo_status_writing_list', list('to_list_id'));
    case 'search_recipes':
    case 'get_saved_recipes':
    case 'get_recipe_nutrition':
      return const AvoWorkStep('avo_status_recipes');
    case 'log_food':
      return const AvoWorkStep('avo_status_estimate');
    case 'get_plan':
    case 'add_to_plan':
    case 'move_in_plan':
      return const AvoWorkStep('avo_status_plan');
    case 'update_setting':
    case 'set_module':
    case 'setup_nutrition_goal':
      return const AvoWorkStep('avo_status_setting');
    case 'get_shopping_history':
    case 'get_restock_suggestions':
    case 'get_savings_summary':
    case 'split_trip_cost':
      return const AvoWorkStep('avo_status_history');
    case 'search_offers':
    case 'get_personalized_deals':
      final id = input['list_id'];
      final store = storeName
          ?.call(id is String && id.isNotEmpty ? id : null)
          ?.trim();
      return store == null || store.isEmpty
          ? AvoWorkStep.thinking
          : AvoWorkStep('avo_status_offers', {'store': store});
    default:
      return AvoWorkStep.thinking;
  }
}

/// One question and its answer in the Avo tab.
class AvoTurn {
  AvoTurn(
    this.id,
    this.question,
    this.askedAt, {
    this.sentText,
    this.carried = const [],
    this.proHintAllowed = false,
    this.photo,
    this.photoIntent,
  });

  final int id;
  final String question;
  final DateTime askedAt;

  /// A photo for Avo (Kap. 7): shown in the bubble, read on the device's
  /// behalf through `meal_photo` or `list_import`, never part of the chat
  /// history sent to the server.
  final Uint8List? photo;

  /// What the photo is; null until the context or the person's choice says.
  AvoPhotoIntent? photoIntent;

  bool get isPhoto => photo != null;

  /// What goes to Avo when it differs from [question] (a retry that tells
  /// Avo what is already done).
  final String? sentText;

  /// Done changes of the earlier failed rounds this one asks again for, so
  /// a second retry still tells Avo about all of them.
  final List<AvoWidgetPayload> carried;

  /// Free with a known Pro limit when it was asked (or last retried).
  bool proHintAllowed;

  /// Asked again as a new round after it failed with done changes: the
  /// changes keep their cards, the retry button goes.
  bool retried = false;

  /// Everything already done for this question: earlier rounds' and its own.
  List<AvoWidgetPayload> get doneChanges => [
    ...carried,
    for (final p in payloads)
      if (p.isDoneChange) p,
  ];

  AvoTurnPhase phase = AvoTurnPhase.working;

  /// What the status line says while [phase] is [AvoTurnPhase.working].
  AvoWorkStep step = AvoWorkStep.thinking;

  /// The answer text; grows while it is written. Its own notifier so only
  /// the text rebuilds per word.
  final ValueNotifier<String> text = ValueNotifier('');

  /// Result cards, in the order their tools finished.
  final List<AvoWidgetPayload> payloads = [];

  /// Why it failed (see [AvoResponse.errorCode]).
  String? errorCode;

  /// When "Erneut versuchen" turns active again (`rate_limited`).
  DateTime? retryAt;

  /// Avo refused: the text is `avo_err_refused`, without an error symbol.
  bool refused = false;

  /// Daily limit reached on Free: the Pro row may show (once a week).
  bool proHint = false;

  /// Whether the status line still holds the place of the answer.
  bool get showsStatus =>
      phase == AvoTurnPhase.working &&
      text.value.isEmpty &&
      // The invisible "done" marker of a card-less write is no content, and
      // an answered photo choice stands above the line.
      payloads.every(
        (p) => p.kind == AvoPayloadKind.wrote || p.card is AvoPhotoChoiceCard,
      );

  /// Back to a fresh answer (a retry without done changes).
  void restart() {
    phase = AvoTurnPhase.working;
    step = AvoWorkStep.thinking;
    text.value = '';
    payloads.clear();
    errorCode = null;
    retryAt = null;
    refused = false;
    proHint = false;
  }
}
