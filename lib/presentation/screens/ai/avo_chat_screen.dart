import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/mascot/avo_mascot.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/presentation/screens/main_scaffold.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/shopping_history_provider.dart';

// ════════════════════════════════════════════════════════
// RICH MESSAGE MODEL
// ════════════════════════════════════════════════════════

/// Attachment types for rich inline content
enum RichContentType { recipes, listItems, lists, history, pickList }

class RichContent {
  final RichContentType type;
  final List<Recipe>? recipes;
  final List<ShoppingItemModel>? items;
  final String? listId;
  final String? listName;
  final List<ShoppingListModel>? lists;
  final List<ShoppingHistory>? history;
  final PickListData? pickListData;

  RichContent({
    required this.type,
    this.recipes,
    this.items,
    this.listId,
    this.listName,
    this.lists,
    this.history,
    this.pickListData,
  });
}

class PickListData {
  final String itemName;
  final double quantity;
  final String? unit;
  PickListData({required this.itemName, this.quantity = 1, this.unit});
}

class ChatMessage {
  final String text;
  final bool isUser;
  final AvoExpressionType? avoExpression;
  final RichContent? richContent;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.avoExpression,
    this.richContent,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ════════════════════════════════════════════════════════
// SUGGESTIONS
// ════════════════════════════════════════════════════════

const _suggestions = [
  'Show my shopping lists',
  'What should I cook tonight?',
  "What's on my list?",
  'Add eggs to my list',
  'Suggest a healthy dinner',
  'Find quick recipes',
  "What's missing from my list?",
  'Show my shopping history',
  'Find vegetarian recipes',
  'Show my saved recipes',
];

// ════════════════════════════════════════════════════════
// SCREEN
// ════════════════════════════════════════════════════════

class AvoChatScreen extends ConsumerStatefulWidget {
  const AvoChatScreen({super.key});
  @override
  ConsumerState<AvoChatScreen> createState() => _AvoChatScreenState();
}

class _AvoChatScreenState extends ConsumerState<AvoChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  List<String> _chips = const [];

  @override
  void initState() {
    super.initState();
    _shuffleChips();
    _initAvo();
  }

  void _shuffleChips() {
    final s = List<String>.from(_suggestions)..shuffle(Random());
    _chips = s.take(3).toList();
  }

  Future<void> _initAvo() async {
    try {
      if (!AvoAssistantService.instance.isInitialized) {
        await AvoAssistantService.instance.initialize();
      }
    } catch (_) {}
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
    final response = await AvoAssistantService.instance.chat(text, context: ctx);
    final richContent = await _processActions(response.actions);

    setState(() {
      _messages.add(ChatMessage(
        text: response.message,
        isUser: false,
        avoExpression: response.expression,
        richContent: richContent,
      ));
      _isTyping = false;
    });
    _scrollToBottom();
  }

  void _sendQuick(String text) {
    _controller.text = text;
    _send();
  }

  // ── Build context ──

  Future<AvoContext> _buildContext() async {
    final listsAsync = ref.read(listsNotifierProvider);
    final lists = listsAsync.hasValue ? listsAsync.value! : <ShoppingListModel>[];

    List<Recipe> recipes = [];
    try { recipes = await RecipeService.instance.getPopularRecipes(limit: 8); }
    catch (_) {}

    List<String> historyItems = [];
    final historyAsync = ref.read(recentHistoryProvider);
    if (historyAsync.hasValue) {
      for (final h in historyAsync.value!) {
        for (final item in h.items.take(5)) {
          if (!historyItems.contains(item.name)) historyItems.add(item.name);
        }
      }
    }

    final allItems = <String, List<ShoppingItemModel>>{};
    for (final list in lists.take(3)) {
      final itemsAsync = ref.read(itemsNotifierProvider(list.id));
      if (itemsAsync.hasValue) allItems[list.id] = itemsAsync.value!;
    }

    return AvoContext(
      lists: lists,
      currentListItems: allItems.isNotEmpty ? allItems.values.first : [],
      currentListId: lists.isNotEmpty ? lists.first.id : null,
      recentRecipes: recipes,
      recentHistoryItems: historyItems.take(10).toList(),
      allListItems: allItems,
    );
  }

  // ── Process actions → return rich content ──

  Future<RichContent?> _processActions(List<AvoAction> actions) async {
    for (final action in actions) {
      switch (action.type) {
        case AvoActionType.addItem:
          if (action.params.length >= 2) {
            final listId = action.params[0];
            final itemName = action.params[1];
            final qty = action.params.length > 2 ? double.tryParse(action.params[2]) ?? 1 : 1.0;
            final unit = action.params.length > 3 ? action.params[3] : null;
            try {
              await ref.read(itemsNotifierProvider(listId).notifier)
                  .addItem(name: itemName, quantity: qty, unit: unit);
              HapticFeedback.mediumImpact();
            } catch (_) {}
          }
          break;

        case AvoActionType.showListItems:
          if (action.params.isNotEmpty) {
            final listId = action.params[0];
            final items = await AvoAssistantService.instance.getListItems(listId);
            final listsAsync = ref.read(listsNotifierProvider);
            final lists = listsAsync.hasValue ? listsAsync.value! : <ShoppingListModel>[];
            String name = 'Shopping List';
            for (final l in lists) { if (l.id == listId) { name = l.name; break; } }
            return RichContent(type: RichContentType.listItems, items: items, listId: listId, listName: name);
          }
          break;

        case AvoActionType.showListOverview:
          final listsAsync = ref.read(listsNotifierProvider);
          final lists = listsAsync.hasValue ? listsAsync.value! : <ShoppingListModel>[];
          return RichContent(type: RichContentType.lists, lists: lists);

        case AvoActionType.showRecipes:
        case AvoActionType.searchRecipes:
          if (action.params.isNotEmpty) {
            final query = action.params[0];
            final recipes = await RecipeService.instance.searchRecipes(query);
            if (recipes.isNotEmpty) {
              return RichContent(type: RichContentType.recipes, recipes: recipes.take(5).toList());
            }
          }
          break;

        case AvoActionType.showSavedRecipes:
          try {
            final saved = await RecipeService.instance.getSavedRecipes();
            return RichContent(type: RichContentType.recipes, recipes: saved.take(5).toList());
          } catch (_) {}
          break;

        case AvoActionType.showHistory:
          try {
            final historyService = ref.read(shoppingHistoryServiceProvider);
            final history = await historyService.getRecentHistory(limit: 5);
            return RichContent(type: RichContentType.history, history: history);
          } catch (_) {}
          break;

        case AvoActionType.showRecipe:
          if (action.params.isNotEmpty && mounted) {
            context.push('/recipes/${action.params[0]}');
          }
          break;

        case AvoActionType.navigate:
          if (action.params.isNotEmpty && mounted) {
            final route = action.params[0];
            if (route.startsWith('/')) context.go(route);
          }
          break;

        case AvoActionType.pickList:
          if (action.params.isNotEmpty) {
            final itemName = action.params[0];
            final qty = action.params.length > 1 ? double.tryParse(action.params[1]) ?? 1 : 1.0;
            final unit = action.params.length > 2 ? action.params[2] : null;
            return RichContent(
              type: RichContentType.pickList,
              pickListData: PickListData(itemName: itemName, quantity: qty, unit: unit),
            );
          }
          break;

        case AvoActionType.checkItem:
          if (action.params.length >= 2) {
            final itemId = action.params[0];
            final listId = action.params[1];
            try {
              await ref.read(itemsNotifierProvider(listId).notifier)
                  .toggleItemChecked(itemId, true);
              HapticFeedback.lightImpact();
            } catch (_) {}
          }
          break;

        case AvoActionType.deleteItem:
          if (action.params.length >= 2) {
            final itemId = action.params[0];
            final listId = action.params[1];
            try {
              await ref.read(itemsNotifierProvider(listId).notifier).deleteItem(itemId);
              HapticFeedback.lightImpact();
            } catch (_) {}
          }
          break;

        default:
          break;
      }
    }
    return null;
  }

  Future<void> _addItemToList(String listId, PickListData data) async {
    try {
      await ref.read(itemsNotifierProvider(listId).notifier)
          .addItem(name: data.itemName, quantity: data.quantity, unit: data.unit);
      HapticFeedback.mediumImpact();
      final listsAsync = ref.read(listsNotifierProvider);
      final lists = listsAsync.hasValue ? listsAsync.value! : <ShoppingListModel>[];
      String name = 'your list';
      for (final l in lists) { if (l.id == listId) { name = l.name; break; } }
      setState(() {
        _messages.add(ChatMessage(
          text: 'Added "${data.itemName}" to "$name"!',
          isUser: false,
          avoExpression: AvoExpressionType.celebrating,
        ));
      });
      _scrollToBottom();
    } catch (_) {
      setState(() {
        _messages.add(ChatMessage(text: 'Failed to add item. Try again!', isUser: false, avoExpression: AvoExpressionType.confused));
      });
    }
  }

  // ════════════════════════════════════════════════════════
  // BUILD — Gemini-style minimal layout
  // ════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final kbdOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final navClearance = MainScaffold.getNavbarClearance(context);
    final inputPad = kbdOpen ? 2.0 : navClearance;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          bottom: false,
          child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const AvoMascot(size: 32, expression: AvoExpression.happy),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Avo', style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        )),
                        if (_isTyping)
                          Text('thinking...', style: TextStyle(
                            fontSize: 12, color: AppColors.textTertiary(context),
                          )),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      AvoAssistantService.instance.resetChat();
                      setState(() { _messages.clear(); _shuffleChips(); });
                    },
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.04),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add_rounded, size: 20, color: AppColors.textSecondary(context)),
                    ),
                  ),
                  if (kbdOpen) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => FocusScope.of(context).unfocus(),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.07)
                              : Colors.black.withValues(alpha: 0.04),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.keyboard_hide_rounded,
                          size: 18,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),

            // ── Messages ──
            Expanded(
              child: _messages.isEmpty
                  ? _EmptyState(chips: _chips, onTap: _sendQuick)
                  : ListView.builder(
                      controller: _scrollController,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      itemCount: _messages.length + (_isTyping ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (_isTyping && i == _messages.length) return const _TypingDots();
                        final msg = _messages[i];
                        if (msg.isUser) return _UserBubble(text: msg.text);
                        return _AvoMessage(
                          msg: msg,
                          onListTap: (listId) => context.push('/lists/$listId?name=List'),
                          onRecipeTap: (recipeId) => context.push('/recipes/$recipeId'),
                          onPickList: _addItemToList,
                          onCheckItem: (itemId, listId, checked) async {
                            try {
                              await ref.read(itemsNotifierProvider(listId).notifier)
                                  .toggleItemChecked(itemId, !checked);
                              HapticFeedback.lightImpact();
                              setState(() {}); // refresh
                            } catch (_) {}
                          },
                        );
                      },
                    ),
            ),

            // ── Input ──
            Container(
              padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: inputPad),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE5E5E5),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        maxLines: 5, minLines: 1,
                        textInputAction: TextInputAction.newline,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _send(),
                        style: TextStyle(fontSize: 15, color: AppColors.textPrimary(context), height: 1.4),
                        decoration: InputDecoration(
                          hintText: context.tr('ask_avo_anything'),
                          hintStyle: TextStyle(color: AppColors.textTertiary(context), fontSize: 15),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 5, bottom: 5),
                      child: GestureDetector(
                        onTap: _send,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: _controller.text.trim().isNotEmpty
                                ? AppColors.accentColor(context)
                                : isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_upward_rounded, size: 20,
                            color: _controller.text.trim().isNotEmpty
                                ? Colors.white : AppColors.textTertiary(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// EMPTY STATE — centered Avo + chips
// ════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final List<String> chips;
  final void Function(String) onTap;
  const _EmptyState({required this.chips, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AvoMascot(size: 72, expression: AvoExpression.waving),
            const SizedBox(height: 16),
            Text('How can I help?', style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            )),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8, runSpacing: 8,
              alignment: WrapAlignment.center,
              children: chips.map((c) => GestureDetector(
                onTap: () => onTap(c),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Text(c, style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary(context),
                  )),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// USER BUBBLE — subtle, right-aligned
// ════════════════════════════════════════════════════════

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.accentColor(context),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20), topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20), bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(text, style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.4)),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// AVO MESSAGE — Gemini style, no bubble, with rich content
// ════════════════════════════════════════════════════════

class _AvoMessage extends StatelessWidget {
  final ChatMessage msg;
  final void Function(String listId) onListTap;
  final void Function(String recipeId) onRecipeTap;
  final Future<void> Function(String listId, PickListData data) onPickList;
  final Future<void> Function(String itemId, String listId, bool isChecked) onCheckItem;

  const _AvoMessage({
    required this.msg, required this.onListTap, required this.onRecipeTap,
    required this.onPickList, required this.onCheckItem,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text
          if (msg.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 32),
              child: SelectableText(msg.text, style: TextStyle(
                fontSize: 15, color: AppColors.textPrimary(context), height: 1.55,
              )),
            ),

          // Rich content
          if (msg.richContent != null) ...[
            if (msg.text.isNotEmpty) const SizedBox(height: 12),
            _buildRichContent(context, msg.richContent!),
          ],
        ],
      ),
    );
  }

  Widget _buildRichContent(BuildContext context, RichContent rc) {
    switch (rc.type) {
      case RichContentType.recipes:
        return _RecipeCards(recipes: rc.recipes ?? [], onTap: onRecipeTap);
      case RichContentType.listItems:
        return _ListItemsView(items: rc.items ?? [], listName: rc.listName ?? '', listId: rc.listId ?? '', onCheck: onCheckItem);
      case RichContentType.lists:
        return _ListOverview(lists: rc.lists ?? [], onTap: onListTap);
      case RichContentType.history:
        return _HistoryView(history: rc.history ?? []);
      case RichContentType.pickList:
        return _PickListView(data: rc.pickListData!, onPick: onPickList);
    }
  }
}

// ════════════════════════════════════════════════════════
// RICH: Recipe Cards (horizontal scroll)
// ════════════════════════════════════════════════════════

class _RecipeCards extends StatelessWidget {
  final List<Recipe> recipes;
  final void Function(String) onTap;
  const _RecipeCards({required this.recipes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recipes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final r = recipes[i];
          return GestureDetector(
            onTap: () => onTap(r.id),
            child: Container(
              width: 200,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFEEEEEE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: r.imageUrl != null && r.imageUrl!.isNotEmpty
                        ? Image.network(r.imageUrl!, height: 80, width: 200, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder())
                        : _placeholder(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                    child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(children: [
                      Icon(Icons.timer_outlined, size: 12, color: AppColors.textTertiary(context)),
                      const SizedBox(width: 3),
                      Text('${r.totalTimeMinutes}m', style: TextStyle(fontSize: 11, color: AppColors.textTertiary(context))),
                      if (r.averageRating > 0) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(r.averageRating.toStringAsFixed(1), style: TextStyle(fontSize: 11, color: AppColors.textTertiary(context))),
                      ],
                    ]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _placeholder() => Container(
    height: 80, width: 200,
    color: AppColors.freshGreen.withValues(alpha: 0.15),
    child: const Icon(Icons.restaurant_rounded, color: AppColors.freshGreen, size: 28),
  );
}

// ════════════════════════════════════════════════════════
// RICH: List Items with check toggles
// ════════════════════════════════════════════════════════

class _ListItemsView extends StatelessWidget {
  final List<ShoppingItemModel> items;
  final String listName;
  final String listId;
  final Future<void> Function(String, String, bool) onCheck;
  const _ListItemsView({required this.items, required this.listName, required this.listId, required this.onCheck});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unchecked = items.where((i) => !i.isChecked).toList();
    final checked = items.where((i) => i.isChecked).toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(children: [
              Icon(Icons.checklist_rounded, size: 16, color: AppColors.accentColor(context)),
              const SizedBox(width: 8),
              Text(listName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
              const Spacer(),
              Text('${unchecked.length} left', style: TextStyle(fontSize: 12, color: AppColors.textTertiary(context))),
            ]),
          ),
          Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFEEEEEE)),
          // Unchecked items
          ...unchecked.take(10).map((item) => _itemRow(context, item, false, isDark)),
          // Checked items (collapsed)
          if (checked.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              child: Text('${checked.length} checked', style: TextStyle(fontSize: 12, color: AppColors.textTertiary(context))),
            ),
        ],
      ),
    );
  }

  Widget _itemRow(BuildContext context, ShoppingItemModel item, bool isChecked, bool isDark) {
    return GestureDetector(
      onTap: () => onCheck(item.id, listId, item.isChecked),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: item.isChecked ? AppColors.freshGreen : AppColors.textTertiary(context),
                width: 1.5,
              ),
              color: item.isChecked ? AppColors.freshGreen : Colors.transparent,
            ),
            child: item.isChecked ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(
            item.name,
            style: TextStyle(
              fontSize: 14, color: item.isChecked ? AppColors.textTertiary(context) : AppColors.textPrimary(context),
              decoration: item.isChecked ? TextDecoration.lineThrough : null,
            ),
          )),
          if (item.quantity > 1 || (item.unit != null && item.unit!.isNotEmpty))
            Text(
              '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity}${item.unit != null ? ' ${item.unit}' : ''}',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary(context)),
            ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// RICH: List Overview cards
// ════════════════════════════════════════════════════════

class _ListOverview extends StatelessWidget {
  final List<ShoppingListModel> lists;
  final void Function(String) onTap;
  const _ListOverview({required this.lists, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (lists.isEmpty) {
      return Text('No lists yet!', style: TextStyle(color: AppColors.textTertiary(context), fontSize: 14));
    }
    return Column(
      children: lists.take(5).map((list) => GestureDetector(
        onTap: () => onTap(list.id),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFEEEEEE)),
          ),
          child: Row(children: [
            Icon(Icons.list_rounded, size: 18, color: AppColors.accentColor(context)),
            const SizedBox(width: 10),
            Expanded(child: Text(list.name, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary(context),
            ))),
            Text('${list.itemCount ?? 0}', style: TextStyle(fontSize: 13, color: AppColors.textTertiary(context))),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textTertiary(context)),
          ]),
        ),
      )).toList(),
    );
  }
}

// ════════════════════════════════════════════════════════
// RICH: Shopping History
// ════════════════════════════════════════════════════════

class _HistoryView extends StatelessWidget {
  final List<ShoppingHistory> history;
  const _HistoryView({required this.history});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (history.isEmpty) {
      return Text('No shopping history yet.', style: TextStyle(color: AppColors.textTertiary(context), fontSize: 14));
    }
    return Column(
      children: history.take(5).map((h) {
        final date = '${h.completedAt.day}/${h.completedAt.month}/${h.completedAt.year}';
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFEEEEEE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.accentColor(context)),
                const SizedBox(width: 8),
                Expanded(child: Text(h.listName, style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary(context),
                ))),
                Text(date, style: TextStyle(fontSize: 11, color: AppColors.textTertiary(context))),
              ]),
              const SizedBox(height: 6),
              Text(
                h.items.take(5).map((i) => i.name).join(', ') + (h.items.length > 5 ? ' +${h.items.length - 5} more' : ''),
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ════════════════════════════════════════════════════════
// RICH: Pick List (for add item)
// ════════════════════════════════════════════════════════

class _PickListView extends ConsumerWidget {
  final PickListData data;
  final Future<void> Function(String, PickListData) onPick;
  const _PickListView({required this.data, required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final listsAsync = ref.watch(listsNotifierProvider);
    final lists = listsAsync.hasValue ? listsAsync.value! : <ShoppingListModel>[];

    if (lists.isEmpty) {
      return Text('No lists available.', style: TextStyle(color: AppColors.textTertiary(context)));
    }

    return Column(
      children: lists.take(3).map((list) => GestureDetector(
        onTap: () => onPick(list.id, data),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.accentColor(context).withValues(alpha: 0.08)
                : AppColors.accentColor(context).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accentColor(context).withValues(alpha: 0.20)),
          ),
          child: Row(children: [
            Icon(Icons.add_rounded, size: 18, color: AppColors.accentColor(context)),
            const SizedBox(width: 10),
            Expanded(child: Text(list.name, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary(context),
            ))),
            Text('${list.itemCount ?? 0} items', style: TextStyle(fontSize: 12, color: AppColors.textTertiary(context))),
          ]),
        ),
      )).toList(),
    );
  }
}

// ════════════════════════════════════════════════════════
// TYPING DOTS
// ════════════════════════════════════════════════════════

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, left: 4),
      child: AnimatedBuilder(
        animation: _c,
        builder: (ctx, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final d = i * 0.2;
            final t = ((_c.value - d) % 1.0).clamp(0.0, 1.0);
            final o = 0.3 + 0.5 * (t < 0.5 ? t * 2 : (1 - t) * 2);
            return Container(
              margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
              width: 7, height: 7,
              decoration: BoxDecoration(
                color: AppColors.textTertiary(context).withValues(alpha: o),
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      ),
    );
  }
}
