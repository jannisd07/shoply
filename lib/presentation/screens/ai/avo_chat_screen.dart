import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shoply/core/constants/paper_colors.dart';
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
import 'package:shoply/data/services/avo_settings_bridge.dart';
import 'package:shoply/presentation/providers/subscription_provider.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';

// ════════════════════════════════════════════════════════
// CHAT MESSAGE MODEL
// ════════════════════════════════════════════════════════

class ChatMessage {
  final String text;
  final bool isUser;
  final AvoExpressionType? avoExpression;
  final List<AvoWidgetPayload> payloads;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.avoExpression,
    this.payloads = const [],
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
    _chips = s.take(2).toList();
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

    final ctx = _buildContext();
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

  AvoContext _buildContext() {
    final listsAsync = ref.read(listsNotifierProvider);
    final lists = listsAsync.hasValue ? listsAsync.value! : <ShoppingListModel>[];

    final allItems = <String, List<ShoppingItemModel>>{};
    for (final list in lists.take(3)) {
      final itemsAsync = ref.read(itemsNotifierProvider(list.id));
      if (itemsAsync.hasValue) allItems[list.id] = itemsAsync.value!;
    }

    final userAsync = ref.read(currentUserProvider);
    final user = userAsync.hasValue ? userAsync.value : null;

    return AvoContext(
      lists: lists,
      currentListId: lists.isNotEmpty ? lists.first.id : null,
      allListItems: allItems,
      dietPreferences: user?.dietPreferences,
      allergies: user?.allergies,
      userName: user?.displayName,
    );
  }

  // ── Callbacks used by rich widgets ──────────────────────────

  Future<void> _addItemToListFromPicker(String listId, AvoPickListData data) async {
    try {
      await ref
          .read(itemsNotifierProvider(listId).notifier)
          .addItem(name: data.itemName, quantity: data.quantity, unit: data.unit);
      HapticFeedback.mediumImpact();
      final listsAsync = ref.read(listsNotifierProvider);
      final lists = listsAsync.hasValue ? listsAsync.value! : <ShoppingListModel>[];
      String name = 'your list';
      for (final l in lists) {
        if (l.id == listId) {
          name = l.name;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          text: 'Added "${data.itemName}" to "$name".',
          isUser: false,
          avoExpression: AvoExpressionType.celebrating,
        ));
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          text: 'Failed to add item. Try again!',
          isUser: false,
          avoExpression: AvoExpressionType.confused,
        ));
      });
    }
  }

  Future<void> _onCheckItem(String itemId, String listId, bool currentlyChecked) async {
    try {
      await ref
          .read(itemsNotifierProvider(listId).notifier)
          .toggleItemChecked(itemId, !currentlyChecked);
      HapticFeedback.lightImpact();
      setState(() {});
    } catch (_) {}
  }

  Future<void> _onAddHistoryItem(ShoppingHistory entry, ShoppingHistoryItem? item) async {
    final listsAsync = ref.read(listsNotifierProvider);
    final lists = listsAsync.hasValue ? listsAsync.value! : <ShoppingListModel>[];
    if (lists.isEmpty) return;
    // Add to the first list by default — keeps the interaction one-tap.
    final targetList = lists.first;
    final notifier = ref.read(itemsNotifierProvider(targetList.id).notifier);
    try {
      if (item == null) {
        for (final i in entry.items) {
          await notifier.addItem(name: i.name, quantity: i.quantity, unit: i.unit, category: i.category);
        }
        HapticFeedback.mediumImpact();
      } else {
        await notifier.addItem(name: item.name, quantity: item.quantity, unit: item.unit, category: item.category);
        HapticFeedback.lightImpact();
      }
      if (!mounted) return;
      final label = item == null
          ? 'Added ${entry.items.length} items to "${targetList.name}".'
          : 'Added "${item.name}" to "${targetList.name}".';
      setState(() {
        _messages.add(ChatMessage(
          text: label,
          isUser: false,
          avoExpression: AvoExpressionType.celebrating,
        ));
      });
      _scrollToBottom();
    } catch (_) {}
  }

  // ════════════════════════════════════════════════════════
  // BUILD — Gemini-style minimal layout
  // ════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Raw window insets — Scaffold resizes the body on keyboard open so
    // MediaQuery.viewInsets.bottom reads 0. View.of(context) gives the
    // untouched platform inset.
    final view = View.of(context);
    final rawKbd = view.viewInsets.bottom / view.devicePixelRatio;
    final kbdOpen = rawKbd > 0;
    // Full-screen route (no navbar). Closed: hug the bottom edge so the
    // composer corners run concentric with the iPhone display corners.
    final inputPad =
        kbdOpen ? 6.0 : max(MediaQuery.of(context).padding.bottom - 8.0, 12.0);

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
              padding: const EdgeInsets.fromLTRB(20, 10, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2C2C2E)
                            : PaperColors.cream,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: PaperColors.sage,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: AvoMascot(
                        size: 26,
                        expression: AvoExpression.happy,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Avo', style: PaperTextStyles.serif(
                          19,
                          color: AppColors.textPrimary(context),
                          height: 1.1,
                        )),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            _isTyping
                                ? context.tr('thinking_label')
                                : context.tr('your_shopping_assistant'),
                            key: ValueKey(_isTyping),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (ref.watch(isSubscribedProvider)) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: PaperColors.hairline),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Premium',
                        style: TextStyle(
                          fontSize: 11,
                          color: PaperColors.creamInk,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (kbdOpen) ...[
                    GestureDetector(
                      onTap: () => FocusScope.of(context).unfocus(),
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2E) : PaperColors.cream,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.keyboard_hide_rounded,
                          size: 17,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      AvoAssistantService.instance.resetChat();
                      setState(() { _messages.clear(); _shuffleChips(); });
                    },
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C2C2E) : PaperColors.cream,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add_rounded, size: 19, color: AppColors.textSecondary(context)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 2),

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
                          onPickList: _addItemToListFromPicker,
                          onCheckItem: _onCheckItem,
                          onAddHistoryItem: _onAddHistoryItem,
                        );
                      },
                    ),
            ),

            // ── Input — tall "Brief" composer: text on top, toolbar below ──
            Container(
              padding: EdgeInsets.only(left: 10, right: 10, top: 6, bottom: inputPad),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : PaperColors.surface,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2C2C2E) : PaperColors.hairline,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(18, 8, 14, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLines: 4, minLines: 2,
                      textInputAction: TextInputAction.newline,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _send(),
                      style: TextStyle(fontSize: 15, color: AppColors.textPrimary(context), height: 1.45),
                      decoration: InputDecoration(
                        hintText: context.tr('ask_avo_anything'),
                        hintStyle: PaperTextStyles.serif(
                          15,
                          color: isDark ? const Color(0xFF5A5A5E) : PaperColors.faint,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.add_rounded, size: 21, color: AppColors.textSecondary(context)),
                        const SizedBox(width: 14),
                        Icon(Icons.photo_camera_outlined, size: 19, color: AppColors.textSecondary(context)),
                        const SizedBox(width: 14),
                        Icon(Icons.mic_none_rounded, size: 20, color: AppColors.textSecondary(context)),
                        const Spacer(),
                        GestureDetector(
                          onTap: _send,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeInOut,
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                              color: _controller.text.trim().isNotEmpty
                                  ? PaperColors.terracotta
                                  : (isDark ? const Color(0xFF2C2C2E) : PaperColors.cream),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_upward_rounded, size: 19,
                              color: _controller.text.trim().isNotEmpty
                                  ? PaperColors.paper
                                  : isDark ? const Color(0xFF48484A) : PaperColors.faint,
                            ),
                          ),
                        ),
                      ],
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
// EMPTY STATE — centered Avo + suggestion cards
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
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AvoMascot(size: 64, expression: AvoExpression.waving),
            const SizedBox(height: 14),
            Text(
              context.tr('how_can_i_help'),
              style: PaperTextStyles.serif(
                24,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 28),
            // Quick actions + shuffled suggestions as pills
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _SuggestionPill(
                  text: context.tr('chip_analyze_list'),
                  onTap: onTap,
                  isDark: isDark,
                ),
                _SuggestionPill(
                  text: context.tr('chip_find_recipe'),
                  onTap: onTap,
                  isDark: isDark,
                ),
                for (final chip in chips)
                  _SuggestionPill(text: chip, onTap: onTap, isDark: isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionPill extends StatelessWidget {
  final String text;
  final void Function(String) onTap;
  final bool isDark;
  const _SuggestionPill({
    required this.text,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : PaperColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isDark ? const Color(0xFF2C2C2E) : PaperColors.hairline,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary(context),
          ),
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
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.accentColor(context)
              : PaperColors.ink,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16), topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16), bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            color: PaperColors.paper,
            height: 1.4,
          ),
        ),
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
  final Future<void> Function(String listId, AvoPickListData data) onPickList;
  final Future<void> Function(String itemId, String listId, bool isChecked) onCheckItem;
  final Future<void> Function(ShoppingHistory entry, ShoppingHistoryItem? item) onAddHistoryItem;

  const _AvoMessage({
    required this.msg,
    required this.onListTap,
    required this.onRecipeTap,
    required this.onPickList,
    required this.onCheckItem,
    required this.onAddHistoryItem,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (msg.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 32),
              child: SelectableText(
                msg.text,
                style: PaperTextStyles.serif(
                  15,
                  color: AppColors.textPrimary(context),
                  height: 1.55,
                ),
              ),
            ),
          for (var i = 0; i < msg.payloads.length; i++) ...[
            if (msg.text.isNotEmpty || i > 0) const SizedBox(height: 12),
            _buildPayload(context, msg.payloads[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildPayload(BuildContext context, AvoWidgetPayload p) {
    switch (p.kind) {
      case AvoPayloadKind.recipes:
        return _RecipeCards(recipes: p.recipes ?? [], onTap: onRecipeTap);
      case AvoPayloadKind.listItems:
        return _ListItemsView(
          items: p.items ?? [],
          listName: p.listName ?? '',
          listId: p.listId ?? '',
          onCheck: onCheckItem,
        );
      case AvoPayloadKind.lists:
        return _ListOverview(lists: p.lists ?? [], onTap: onListTap);
      case AvoPayloadKind.history:
        return _HistoryView(
          history: p.history ?? [],
          onAddAll: (entry) => onAddHistoryItem(entry, null),
          onAddOne: (entry, item) => onAddHistoryItem(entry, item),
        );
      case AvoPayloadKind.pickList:
        return _PickListView(data: p.pickListData!, onPick: onPickList);
      case AvoPayloadKind.nutrition:
        return _NutritionCard(data: p.nutrition!);
      case AvoPayloadKind.settingChange:
        return _SettingChangeCard(result: p.settingChange!);
      case AvoPayloadKind.appInfo:
        return _AppInfoCard(data: p.appInfo!);
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
                color: isDark ? Colors.white.withValues(alpha: 0.06) : PaperColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : PaperColors.hairline),
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
        color: isDark ? Colors.white.withValues(alpha: 0.04) : PaperColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : PaperColors.hairline),
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
            color: isDark ? Colors.white.withValues(alpha: 0.04) : PaperColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : PaperColors.hairline),
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
  final Future<void> Function(ShoppingHistory entry) onAddAll;
  final Future<void> Function(ShoppingHistory entry, ShoppingHistoryItem item) onAddOne;
  const _HistoryView({
    required this.history,
    required this.onAddAll,
    required this.onAddOne,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (history.isEmpty) {
      return Text(
        'No shopping history yet.',
        style: TextStyle(color: AppColors.textTertiary(context), fontSize: 14),
      );
    }
    return Column(
      children: history.take(5).map((h) {
        final date = '${h.completedAt.day}/${h.completedAt.month}/${h.completedAt.year}';
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : PaperColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFEEEEEE),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.accentColor(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    h.listName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ),
                Text(date,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textTertiary(context))),
              ]),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: h.items.take(12).map((item) {
                  return GestureDetector(
                    onTap: () => onAddOne(h, item),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.10)
                              : const Color(0xFFE5E5E5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded,
                              size: 12,
                              color: AppColors.accentColor(context)),
                          const SizedBox(width: 4),
                          Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (h.items.length > 12)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('+ ${h.items.length - 12} more',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textTertiary(context))),
                ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => onAddAll(h),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.accentColor(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.playlist_add_rounded,
                          size: 16, color: AppColors.accentColor(context)),
                      const SizedBox(width: 6),
                      Text(
                        'Add all ${h.items.length} items',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
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
  final AvoPickListData data;
  final Future<void> Function(String, AvoPickListData) onPick;
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
// RICH: Nutrition Card
// ════════════════════════════════════════════════════════

class _NutritionCard extends StatelessWidget {
  final AvoNutritionData data;
  const _NutritionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : PaperColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFEEEEEE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.local_fire_department_rounded,
                size: 16, color: AppColors.accentColor(context)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                data.recipeName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text('per serving',
                style: TextStyle(
                    fontSize: 11, color: AppColors.textTertiary(context))),
          ]),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _macro(context, 'kcal',
                  data.calories != null ? '${data.calories}' : '—'),
              _macro(context, 'protein',
                  data.proteinG != null ? '${data.proteinG!.round()}g' : '—'),
              _macro(context, 'carbs',
                  data.carbsG != null ? '${data.carbsG!.round()}g' : '—'),
              _macro(context, 'fat',
                  data.fatG != null ? '${data.fatG!.round()}g' : '—'),
            ],
          ),
          if (data.estimated) ...[
            const SizedBox(height: 10),
            Text(
              'Estimated from ingredients',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary(context),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _macro(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppColors.textTertiary(context)),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════
// RICH: Setting Change Confirmation
// ════════════════════════════════════════════════════════

class _SettingChangeCard extends StatelessWidget {
  final SettingChangeResult result;
  const _SettingChangeCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = result.success
        ? AppColors.accentColor(context)
        : Colors.red.shade400;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? accent.withValues(alpha: 0.08)
            : accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            result.success
                ? Icons.check_circle_rounded
                : Icons.error_outline_rounded,
            size: 18,
            color: accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.success
                      ? '${result.displayName} updated'
                      : "Couldn't change ${result.displayName}",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  result.success
                      ? (result.oldValue != null
                          ? '${result.oldValue}  →  ${result.newValue}'
                          : result.newValue)
                      : (result.error ?? 'Unknown error'),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// RICH: App Info Card
// ════════════════════════════════════════════════════════

class _AppInfoCard extends StatelessWidget {
  final AvoAppInfoData data;
  const _AppInfoCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : PaperColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFEEEEEE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline_rounded,
                size: 14, color: AppColors.accentColor(context)),
            const SizedBox(width: 6),
            Text(
              data.topic,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: AppColors.accentColor(context),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            data.answer,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
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
