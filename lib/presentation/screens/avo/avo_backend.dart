import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/data/services/offline_cache_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';

/// How a tap on "Löschen" in a confirm card went.
enum AvoDeleteOutcome {
  /// Deleted.
  deleted,

  /// The token expired (10 min), was used, or the target changed.
  expired,

  /// Nothing was deleted (network); the card may try again.
  failed,
}

/// What the Avo tab needs from the assistant. The app uses
/// [AssistantAvoBackend]; widget tests put a fake in [avoBackendProvider].
abstract interface class AvoBackend {
  /// Asks [question] and resolves with the whole answer. [onText] gets the
  /// text while it is written, [onTool] each tool right before it runs,
  /// [onPayload] each card as soon as its tool is done.
  Future<AvoResponse> ask(
    String question,
    WidgetRef ref, {
    required void Function(String delta) onText,
    required void Function(String name, Map<String, Object?> input) onTool,
    required void Function(AvoWidgetPayload payload) onPayload,
  });

  /// "Stopp": ends the answer being written.
  void stop();

  /// "Neues Gespräch": forgets the conversation and pending deletions.
  void reset();

  /// Runs a deletion from its confirm card.
  Future<AvoDeleteOutcome> confirmDelete(String token, WidgetRef ref);

  /// Puts one item on a list for the "Auf welche Liste?" card.
  Future<AvoListChange> addItem(
    WidgetRef ref, {
    required String listId,
    required String name,
    double quantity = 1,
    String? unit,
  });
}

/// The assistant behind the Avo tab (Claude through the edge function).
final avoBackendProvider = Provider<AvoBackend>(
  (ref) => const AssistantAvoBackend(),
);

/// [AvoBackend] on [AvoAssistantService].
class AssistantAvoBackend implements AvoBackend {
  const AssistantAvoBackend();

  AvoAssistantService get _service => AvoAssistantService.instance;

  @override
  Future<AvoResponse> ask(
    String question,
    WidgetRef ref, {
    required void Function(String delta) onText,
    required void Function(String name, Map<String, Object?> input) onTool,
    required void Function(AvoWidgetPayload payload) onPayload,
  }) async {
    if (!_service.isInitialized) await _service.initialize();
    final context = await buildAvoContext(ref);
    return _service.chat(
      question,
      ref: ref,
      context: context,
      onText: onText,
      onTool: onTool,
      onPayload: onPayload,
    );
  }

  @override
  void stop() => _service.stop();

  @override
  void reset() => _service.resetChat();

  @override
  Future<AvoDeleteOutcome> confirmDelete(String token, WidgetRef ref) async {
    try {
      final ok = await _service.confirmPendingDelete(token, ref);
      return ok ? AvoDeleteOutcome.deleted : AvoDeleteOutcome.expired;
    } catch (e) {
      debugPrint('❌ [AVO_TAB] Delete failed: $e');
      return AvoDeleteOutcome.failed;
    }
  }

  @override
  Future<AvoListChange> addItem(
    WidgetRef ref, {
    required String listId,
    required String name,
    double quantity = 1,
    String? unit,
  }) => _service.addItemForAvo(
    ref,
    listId: listId,
    name: name,
    quantity: quantity,
    unit: unit,
  );
}

/// Lists, the items of the first three and the profile for the assistant
/// prompt. Reads a running items notifier or the offline cache when there is
/// one and otherwise does a one-shot fetch, so asking Avo never creates an
/// `itemsNotifierProvider` (which would keep a realtime channel open).
Future<AvoContext> buildAvoContext(WidgetRef ref) async {
  final lists = ref.read(listsNotifierProvider).valueOrNull ?? const [];
  final repo = ref.read(itemRepositoryProvider);
  final allItems = <String, List<ShoppingItemModel>>{};

  await Future.wait(
    lists.take(3).map((list) async {
      if (ref.exists(itemsNotifierProvider(list.id))) {
        final live = ref.read(itemsNotifierProvider(list.id)).valueOrNull;
        if (live != null) {
          allItems[list.id] = live;
          return;
        }
      }
      final cached = OfflineCacheService.instance.getCachedListItemsSync(
        list.id,
      );
      if (cached != null) {
        allItems[list.id] = cached;
        return;
      }
      try {
        allItems[list.id] = await repo.getListItems(list.id);
      } catch (e) {
        debugPrint('⚠️ [AVO_TAB] Could not load items for context: $e');
      }
    }),
  );

  final user = ref.read(currentUserProvider).valueOrNull;
  return AvoContext(
    lists: lists,
    currentListId: lists.isNotEmpty ? lists.first.id : null,
    allListItems: allItems,
    dietPreferences: user?.dietPreferences,
    allergies: user?.allergies,
    userName: user?.displayName,
    appPriorities: user?.appPriorities,
  );
}
