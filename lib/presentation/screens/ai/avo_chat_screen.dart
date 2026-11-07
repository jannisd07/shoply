import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/data/services/offline_cache_service.dart';
import 'package:shoply/presentation/providers/subscription_provider.dart';
import 'package:shoply/presentation/screens/ai/avo_chat_message.dart';
import 'package:shoply/presentation/screens/ai/avo_initial_question.dart';
import 'package:shoply/presentation/screens/ai/widgets/avo_chat_widgets.dart';
import 'package:shoply/presentation/screens/ai/widgets/avo_payload_cards.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/language_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';

// ════════════════════════════════════════════════════════
// SUGGESTIONS
// ════════════════════════════════════════════════════════

const _suggestionKeys = [
  'chip_show_lists',
  'chip_cook_tonight',
  'chip_whats_on_list',
  'chip_add_eggs',
  'chip_healthy_dinner',
  'chip_quick_recipes',
  'chip_whats_missing',
  'chip_shopping_history',
  'chip_vegetarian_recipes',
  'chip_saved_recipes',
];

/// One suggestion key per `AppPriority.id` (`core/constants/app_priorities.dart`)
/// a user can pick during onboarding/Profile → "What matters to you". Lets
/// the chat's empty-state chips lean toward what a user already said
/// matters to them (a real, actionable prompt) without literally reciting
/// their answer back — a light-touch personalization, not a new message.
/// 'discover_recipes' intentionally reuses the recipe-search chip already
/// in the general pool above rather than adding a near-duplicate.
const _priorityChipKeys = {
  'save_money': 'chip_cheapest_store',
  'share_lists': 'chip_split_last_trip',
  'eat_healthier': 'chip_healthy_dinner',
  'discover_recipes': 'chip_quick_recipes',
  'stay_organized': 'chip_whats_missing',
};

/// Picks the 2 translation keys shown as empty-state chips: [priorityKey]
/// first if the caller resolved one (from the user's app priorities), then
/// enough of [shuffledGeneralKeys] to reach 2, skipping any that would
/// duplicate the priority key. Pure/deterministic — the randomness lives in
/// how the caller shuffles [shuffledGeneralKeys] and picks [priorityKey],
/// not in here — so this is unit-testable without mocking `Random`.
@visibleForTesting
List<String> buildSuggestionChipKeys({
  required List<String> shuffledGeneralKeys,
  String? priorityKey,
}) {
  final keys = <String>[];
  if (priorityKey != null) keys.add(priorityKey);
  for (final key in shuffledGeneralKeys) {
    if (keys.length >= 2) break;
    if (!keys.contains(key)) keys.add(key);
  }
  return keys;
}

// ════════════════════════════════════════════════════════
// SCREEN
// ════════════════════════════════════════════════════════

/// Root of the Avo tab (`/avo`). [initialQuestion] is the `q` of the route:
/// sent once as the person's message, e.g. from "Frag Avo …" on Home.
class AvoChatScreen extends ConsumerStatefulWidget {
  const AvoChatScreen({super.key, this.initialQuestion});

  final String? initialQuestion;

  @override
  ConsumerState<AvoChatScreen> createState() => _AvoChatScreenState();
}

class _AvoChatScreenState extends ConsumerState<AvoChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _addingFromHistory = false;
  List<String> _chips = const [];

  /// Items checked from a list-items card (id → checked). The payload is a
  /// frozen snapshot, so the card reads this to reflect taps.
  final Map<String, bool> _checkedOverrides = {};

  final _initialQuestion = AvoInitialQuestion();
  late final Future<void> _ready;

  @override
  void initState() {
    super.initState();
    _shuffleChips();
    _ready = _initAvo();
    _handOver(widget.initialQuestion);
  }

  @override
  void didUpdateWidget(AvoChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuestion != oldWidget.initialQuestion) {
      _handOver(widget.initialQuestion);
    }
  }

  /// Sends a question handed over through the route, once, after Avo is
  /// ready and the first frame is on screen.
  void _handOver(String? question) {
    final q = _initialQuestion.take(question);
    if (q == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ready;
      if (!mounted) return;
      _controller.text = q;
      await _send();
    });
  }

  void _shuffleChips() {
    final languageCode = ref.read(languageProvider);
    final priorities =
        ref.read(currentUserProvider).valueOrNull?.appPriorities ?? const [];

    String? priorityKey;
    if (priorities.isNotEmpty) {
      final shuffledPriorities = List<String>.from(priorities)..shuffle(Random());
      priorityKey = _priorityChipKeys[shuffledPriorities.first];
    }
    final generalKeys = List<String>.from(_suggestionKeys)..shuffle(Random());
    final keys = buildSuggestionChipKeys(
      shuffledGeneralKeys: generalKeys,
      priorityKey: priorityKey,
    );

    _chips = keys.map((k) => AppTranslations.get(k, languageCode)).toList();
  }

  Future<void> _initAvo() async {
    try {
      if (!AvoAssistantService.instance.isInitialized) {
        await AvoAssistantService.instance.initialize();
      }
    } catch (e) {
      debugPrint('❌ [AVO_CHAT] Failed to initialize assistant: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addAvoMessage(String text, AvoExpressionType expression) {
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: false, avoExpression: expression));
    });
    _scrollToBottom();
  }

  List<ShoppingListModel> get _lists =>
      ref.read(listsNotifierProvider).valueOrNull ?? const <ShoppingListModel>[];

  // ── Send message ──

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isTyping) return;
    _controller.clear();
    HapticFeedback.lightImpact();

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isTyping = true;
    });
    _scrollToBottom();

    final ctx = await _buildContext();
    final response = await AvoAssistantService.instance.chat(
      text,
      ref: ref,
      context: ctx,
    );

    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(
        text: response.message,
        isUser: false,
        avoExpression: response.expression,
        payloads: response.payloads,
      ));
      _isTyping = false;
    });
    _scrollToBottom();
  }

  void _sendQuick(String text) {
    _controller.text = text;
    _send();
  }

  // ── Build context (profile + lists) ─────────────────────────

  /// Items of the first 3 lists for the assistant prompt. Reads a running
  /// items notifier or the offline cache when available and otherwise does a
  /// one-shot fetch, so asking Avo never instantiates `itemsNotifierProvider`
  /// (which would open a realtime channel for the rest of the session).
  Future<AvoContext> _buildContext() async {
    final lists = _lists;
    final repo = ref.read(itemRepositoryProvider);
    final allItems = <String, List<ShoppingItemModel>>{};

    await Future.wait(lists.take(3).map((list) async {
      if (ref.exists(itemsNotifierProvider(list.id))) {
        final live = ref.read(itemsNotifierProvider(list.id)).valueOrNull;
        if (live != null) {
          allItems[list.id] = live;
          return;
        }
      }
      final cached = OfflineCacheService.instance.getCachedListItemsSync(list.id);
      if (cached != null) {
        allItems[list.id] = cached;
        return;
      }
      try {
        allItems[list.id] = await repo.getListItems(list.id);
      } catch (e) {
        debugPrint('⚠️ [AVO_CHAT] Could not load items for context: $e');
      }
    }));

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

  // ── Callbacks used by rich widgets ──────────────────────────

  Future<void> _addItemToListFromPicker(String listId, AvoPickListData data) async {
    try {
      await ref
          .read(itemsNotifierProvider(listId).notifier)
          .addItem(name: data.itemName, quantity: data.quantity, unit: data.unit);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      final name = _lists.where((l) => l.id == listId).firstOrNull?.name ??
          context.tr('avo_your_list');
      _addAvoMessage(
        context.tr('avo_added_item', params: {'item': data.itemName, 'list': name}),
        AvoExpressionType.celebrating,
      );
    } catch (e) {
      debugPrint('❌ [AVO_CHAT] Add from picker failed: $e');
      if (mounted) {
        _addAvoMessage(context.tr('avo_add_failed'), AvoExpressionType.confused);
      }
    }
  }

  Future<void> _onCheckItem(String itemId, String listId, bool currentlyChecked) async {
    final checked = !currentlyChecked;
    try {
      await ref.read(itemRepositoryProvider).toggleItemChecked(itemId, checked);
      HapticFeedback.lightImpact();
      if (!mounted) return;
      setState(() => _checkedOverrides[itemId] = checked);
      // Refresh an open list screen, without creating a notifier for lists
      // that are not open.
      if (ref.exists(itemsNotifierProvider(listId))) {
        unawaited(ref.read(itemsNotifierProvider(listId).notifier).loadItems());
      }
    } catch (e) {
      debugPrint('❌ [AVO_CHAT] Toggle item failed: $e');
      if (mounted) {
        _addAvoMessage(context.tr('avo_update_failed'), AvoExpressionType.confused);
      }
    }
  }

  Future<void> _onAddHistoryItem(ShoppingHistory entry, ShoppingHistoryItem? item) async {
    final lists = _lists;
    if (lists.isEmpty || _addingFromHistory) return;
    // Add to the first list by default — keeps the interaction one-tap.
    final targetList = lists.first;
    setState(() => _addingFromHistory = true);
    try {
      if (item == null) {
        // Batch path: category is known from the trip, so skip the name
        // parser / Gemini categorization and the per-item push + reload that
        // ItemsNotifier.addItem does; reload once at the end.
        final repo = ref.read(itemRepositoryProvider);
        for (final i in entry.items) {
          await repo.addItem(
            listId: targetList.id,
            name: i.name,
            quantity: i.quantity,
            unit: i.unit,
            category: i.category,
            autoParse: false,
          );
        }
        if (ref.exists(itemsNotifierProvider(targetList.id))) {
          await ref.read(itemsNotifierProvider(targetList.id).notifier).loadItems();
        }
        HapticFeedback.mediumImpact();
      } else {
        await ref
            .read(itemsNotifierProvider(targetList.id).notifier)
            .addItem(name: item.name, quantity: item.quantity, unit: item.unit, category: item.category);
        HapticFeedback.lightImpact();
      }
      if (!mounted) return;
      _addAvoMessage(
        item == null
            ? context.tr('avo_added_items',
                params: {'count': '${entry.items.length}', 'list': targetList.name})
            : context.tr('avo_added_item', params: {'item': item.name, 'list': targetList.name}),
        AvoExpressionType.celebrating,
      );
    } catch (e) {
      debugPrint('❌ [AVO_CHAT] Add from history failed: $e');
      if (mounted) {
        _addAvoMessage(context.tr('avo_add_failed'), AvoExpressionType.confused);
      }
    } finally {
      if (mounted) setState(() => _addingFromHistory = false);
    }
  }

  void _openList(ShoppingListModel list) {
    context.push('/lists/${list.id}?name=${Uri.encodeComponent(list.name)}');
  }

  // ════════════════════════════════════════════════════════
  // BUILD — Gemini-style minimal layout
  // ════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // Raw window insets — Scaffold resizes the body on keyboard open so
    // MediaQuery.viewInsets.bottom reads 0. View.of(context) gives the
    // untouched platform inset.
    final view = View.of(context);
    final rawKbd = view.viewInsets.bottom / view.devicePixelRatio;
    final kbdOpen = rawKbd > 0;
    // Root of the Avo tab: closed, the composer floats above the tab bar.
    final inputPad = kbdOpen ? 6.0 : ShellInsets.aboveTabBar(context);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          bottom: false,
          child: Column(
          children: [
            AvoChatHeader(
              isTyping: _isTyping,
              isSubscribed: ref.watch(isSubscribedProvider),
              keyboardOpen: kbdOpen,
              onNewChat: () {
                HapticFeedback.mediumImpact();
                AvoAssistantService.instance.resetChat();
                setState(() {
                  _messages.clear();
                  _checkedOverrides.clear();
                  _shuffleChips();
                });
              },
            ),

            const SizedBox(height: 2),

            // ── Messages ──
            Expanded(
              child: _messages.isEmpty
                  ? AvoChatEmptyState(chips: _chips, onTap: _sendQuick)
                  : ListView.builder(
                      controller: _scrollController,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      itemCount: _messages.length + (_isTyping ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (_isTyping && i == _messages.length) return const AvoTypingDots();
                        final msg = _messages[i];
                        if (msg.isUser) return AvoUserBubble(text: msg.text);
                        return AvoMessage(
                          msg: msg,
                          checkedOverrides: _checkedOverrides,
                          onListTap: _openList,
                          onRecipeTap: (recipeId) => context.push('/recipes/$recipeId'),
                          onPickList: _addItemToListFromPicker,
                          onCheckItem: _onCheckItem,
                          onAddHistoryItem: _onAddHistoryItem,
                        );
                      },
                    ),
            ),

            AvoComposer(
              controller: _controller,
              focusNode: _focusNode,
              onSend: _send,
              bottomPadding: inputPad,
            ),
          ],
        ),
      ),
      ),
    );
  }
}
