import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:shoply/core/constants/app_brand.dart';
import 'package:shoply/core/constants/legal_links.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/providers/avo_screen_context_provider.dart';
import 'package:shoply/presentation/providers/subscription_provider.dart';
import 'package:shoply/presentation/screens/avo/avo_chat.dart';
import 'package:shoply/presentation/screens/avo/avo_initial_question.dart';
import 'package:shoply/presentation/screens/avo/avo_suggestions.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_composer.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_context_chip.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_glyphs.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_large_title.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_suggestion_views.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_turn_view.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/widgets/design/add_item_accessory.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

// D2 X-Avo layout (Kap. 3.1).
const double _titleGap = 11; // D2: toolbar ends at 98, the title at 109
const double _topFade = 104; // D2 scroll edge under the head
const double _bottomFade = 40; // Kap. 2.11: fade behind composer and tab bar
const double _historyStart = 18; // D2: the history starts 18 under the title
const double _roundGap = AvoSpacing.xxl; // D2: 24 between two rounds
const double _contextChipGap = AvoSpacing.s; // D2: 8 above the composer

/// Root of the Avo tab (`/avo`, Kap. 3): the large title with the one Avo
/// figure, the conversation (or the empty chat with suggestions), the
/// context capsule and the glass composer above the tab bar.
///
/// [initialQuestion] is the route's `q` (the "Frag Avo …" field on Home):
/// sent exactly once. [prompt] is the route's `prompt` (deep links): it only
/// fills the composer and never sends, so no other app can make Avo act.
class AvoTabScreen extends ConsumerStatefulWidget {
  const AvoTabScreen({super.key, this.initialQuestion, this.prompt});

  final String? initialQuestion;
  final String? prompt;

  @override
  ConsumerState<AvoTabScreen> createState() => _AvoTabScreenState();
}

class _AvoTabScreenState extends ConsumerState<AvoTabScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _collapsed = ValueNotifier<bool>(false);
  late final AnimationController _scrollSpring = AnimationController.unbounded(
    vsync: this,
  )..addListener(_onSpring);

  final _question = AvoInitialQuestion();
  final _prefill = AvoInitialQuestion();

  AvoChat? _chat;
  int _turnCount = -1;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _handOver(widget.initialQuestion);
    _prefillWith(widget.prompt);
  }

  @override
  void didUpdateWidget(covariant AvoTabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuestion != oldWidget.initialQuestion) {
      _handOver(widget.initialQuestion);
    }
    if (widget.prompt != oldWidget.prompt) _prefillWith(widget.prompt);
  }

  @override
  void dispose() {
    _chat?.onTurnFinished = null;
    _scroll.removeListener(_onScroll);
    _scrollSpring.dispose();
    _scroll.dispose();
    _collapsed.dispose();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ hand-overs

  /// `?q=`: sends the question once, after the first frame.
  void _handOver(String? question) {
    final q = _question.take(question);
    if (q == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ref.read(aiRemoteEnabledProvider)) {
        _controller.text = q;
        return;
      }
      _send(q, clearField: false);
    });
  }

  /// `?prompt=`: fills the composer, never sends.
  void _prefillWith(String? prompt) {
    final p = _prefill.take(prompt);
    if (p == null) return;
    final text = p.length > avoMaxQuestionLength
        ? p.substring(0, avoMaxQuestionLength)
        : p;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  // --------------------------------------------------------------- actions

  void _send(String text, {bool clearField = true}) {
    final turn = ref
        .read(avoChatProvider)
        .send(
          text,
          ref,
          offline: ref.read(isOfflineProvider),
          isFree: !ref.read(isSubscribedProvider),
        );
    if (turn != null && clearField) _controller.clear();
  }

  void _newConversation() {
    final chat = ref.read(avoChatProvider);
    if (chat.isEmpty) return;
    chat.newConversation();
    _controller.clear();
    AvoToast.show(
      context,
      message: context.tr('avo_new_conversation_toast'),
      actionLabel: context.tr('avo_undo'),
      onAction: chat.undoNewConversation,
    );
  }

  void _edit(String question) {
    _controller.value = TextEditingValue(
      text: question,
      selection: TextSelection.collapsed(offset: question.length),
    );
    _focus.requestFocus();
  }

  Future<void> _openPrivacy() async {
    final uri = Uri.parse(LegalLinks.privacy);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('⚠️ [AVO_TAB] Privacy page not opened: $e');
    }
  }

  void _removeContext() {
    ref.read(avoScreenContextProvider.notifier).state = null;
  }

  // ------------------------------------------------------------- scrolling

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final threshold = context.typography.lineHeightOf(AvoTextStyle.largeTitle);
    _collapsed.value = _scroll.offset > threshold;
  }

  void _onSpring() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    _scroll.jumpTo(_scrollSpring.value.clamp(0.0, max));
  }

  /// A new round: its bubble glides under the collapsed head (the last round
  /// is at least a screen tall, so the end of the list puts it there). Later
  /// growth of the answer never scrolls by itself.
  void _scrollToNewest({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (!animate || context.reduceMotion) {
        _scroll.jumpTo(target);
        return;
      }
      _scrollSpring.value = _scroll.offset;
      _scrollSpring.animateWith(
        SpringSimulation(AvoMotion.standard, _scroll.offset, target, 0),
      );
    });
  }

  // ------------------------------------------------------------- VoiceOver

  /// Announces an answer once it is complete, politely and not while the
  /// person types (Kap. 3.6).
  void _announce(AvoTurn turn) {
    if (!mounted || _focus.hasFocus) return;
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    final view = View.maybeOf(context);
    if (view == null) return;
    final text = turn.refused
        ? context.tr('avo_err_refused')
        : turn.phase == AvoTurnPhase.failed
        ? context.tr('avo_err_title')
        : turn.text.value.trim();
    if (text.isEmpty) return;
    final undo = turn.payloads.any((p) => p.listChange?.undo != null);
    SemanticsService.sendAnnouncement(
      view,
      [
        '${context.tr('avo_a11y_prefix')} $text',
        if (undo) context.tr('avo_a11y_undo_available'),
      ].join(' '),
      Directionality.of(context),
    );
  }

  // ----------------------------------------------------------------- build

  ShoppingListModel? _contextList(
    AvoScreenContext? screen,
    List<ShoppingListModel> lists,
  ) {
    final id = screen?.listId;
    if (id != null) {
      final match = lists.where((l) => l.id == id).firstOrNull;
      if (match != null) return match;
    }
    if (lists.isEmpty) return null;
    return lists.reduce((a, b) => b.updatedAt.isAfter(a.updatedAt) ? b : a);
  }

  List<String> _openNames(String? listId) {
    if (listId == null || !ref.exists(itemsNotifierProvider(listId))) {
      return const [];
    }
    final items = ref.read(itemsNotifierProvider(listId)).valueOrNull;
    return [
      for (final i in items ?? const [])
        if (!i.isChecked) i.name,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(avoChatProvider);
    if (!identical(chat, _chat)) {
      _chat?.onTurnFinished = null;
      _chat = chat;
      chat.onTurnFinished = _announce;
      _turnCount = -1;
    }
    final offline = ref.watch(isOfflineProvider);
    final aiOn = ref.watch(aiRemoteEnabledProvider);
    final screenContext = ref.watch(avoScreenContextProvider);
    final lists = ref.watch(avoListsProvider);
    final colors = context.colors;

    // A new round scrolls into place; opening the tab starts at the newest.
    final turns = chat.turns;
    if (_turnCount != turns.length) {
      final grew = _turnCount >= 0 && turns.length > _turnCount;
      if (turns.isNotEmpty && (grew || _turnCount < 0)) {
        _scrollToNewest(animate: grew);
      }
      _turnCount = turns.length;
    }

    final contextList = _contextList(screenContext, lists);
    final contextName = screenContext?.listName?.trim();
    final showChip =
        aiOn &&
        screenContext != null &&
        (screenContext.screen == 'list' ||
            screenContext.screen == 'shopping') &&
        contextName != null &&
        contextName.isNotEmpty &&
        screenContext != chat.askedContext;
    final canAsk = aiOn && !offline;

    final media = MediaQuery.of(context);
    final toolbarTop = GlassToolbar.topOffset(context);
    final top = toolbarTop + AvoSizes.toolbarButton + _titleGap;
    final turnTop = toolbarTop + AvoSizes.toolbarButton + AvoSpacing.s;
    final dockBottom = AccessoryDock.bottomOffset(context);
    final chipSpace = showChip ? AvoSizes.hitTarget + _contextChipGap : 0.0;
    final bottom =
        dockBottom + AvoSizes.accessoryHeight + chipSpace + AvoSpacing.l;
    final lastMinHeight = (media.size.height - turnTop - bottom).clamp(
      0.0,
      double.infinity,
    );

    final pose = chat.isWorking ? AvoPose.thinking : AvoPose.waving;
    final status = !aiOn
        ? StatusRow(
            kind: StatusKind.sectionError,
            text: context.tr('avo_unavailable'),
          )
        : offline
        ? StatusRow(kind: StatusKind.offline, text: context.tr('avo_offline'))
        : null;

    final followUpTarget = contextName ?? contextList?.name;
    final body = <Widget>[
      AvoLargeTitle(pose: pose),
      if (status != null) ...[const SizedBox(height: AvoSpacing.s), status],
      const SizedBox(height: _historyStart),
      if (turns.isEmpty)
        AvoEmptyChat(
          suggestions: avoEmptySuggestions(
            context: screenContext,
            list: contextList,
            openItemNames: screenContext?.screen == 'shopping'
                ? _openNames(screenContext?.listId)
                : const [],
          ),
          enabled: canAsk,
          onSend: _send,
          onPrivacy: _openPrivacy,
        )
      else
        for (var i = 0; i < turns.length; i++) ...[
          if (i > 0) const SizedBox(height: _roundGap),
          _turn(
            chat,
            turns[i],
            last: i == turns.length - 1,
            minHeight: lastMinHeight,
            offline: offline,
            aiOn: aiOn,
            followUps: chat.isLatestDone(turns[i])
                ? avoFollowUps(turns[i].payloads, targetList: followUpTarget)
                : const [],
          ),
        ],
    ];

    return ColoredBox(
      color: colors.background,
      child: Stack(
        children: [
          Positioned.fill(
            // VoiceOver: toolbar, then title and conversation, then the
            // composer (Kap. 3.6), whatever scrolls under what.
            child: Semantics(
              container: true,
              sortKey: const OrdinalSortKey(1),
              child: CustomScrollView(
                controller: _scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.only(top: top, bottom: bottom),
                    sliver: SliverList(delegate: SliverChildListDelegate(body)),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ScrollEdgeFade(height: _topFade),
          ),
          Positioned(
            top: toolbarTop,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<bool>(
              valueListenable: _collapsed,
              builder: (context, collapsed, _) => Semantics(
                container: true,
                sortKey: const OrdinalSortKey(0),
                child: GlassToolbar(
                  title: collapsed ? AppBrand.name : null,
                  trailing: [
                    GlassIconButton(
                      icon: const AvoIcon(avoNewConversationIcon),
                      semanticLabel: context.tr('avo_new_conversation'),
                      onPressed: turns.isEmpty ? null : _newConversation,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bottom - AvoSpacing.l + _bottomFade,
            child: _BottomEdgeFade(fade: _bottomFade),
          ),
          AccessoryDock(
            child: Semantics(
              container: true,
              sortKey: const OrdinalSortKey(2),
              child: AvoComposer(
                controller: _controller,
                focusNode: _focus,
                enabled: aiOn,
                onSend: _send,
                above: showChip
                    ? AvoContextChip(
                        name: contextName,
                        onRemove: _removeContext,
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _turn(
    AvoChat chat,
    AvoTurn turn, {
    required bool last,
    required double minHeight,
    required bool offline,
    required bool aiOn,
    required List<AvoSuggestion> followUps,
  }) {
    final view = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: AvoTurnView(
        key: ValueKey(turn.id),
        chat: chat,
        turn: turn,
        offline: offline,
        aiEnabled: aiOn,
        followUps: followUps,
        onSend: _send,
        onEdit: _edit,
      ),
    );
    if (!last) return view;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Align(alignment: Alignment.topCenter, child: view),
    );
  }
}

/// Kap. 2.11: behind the composer and the tab bar the background fades in
/// over [fade] points and stays, so dark content never sits right under the
/// placeholder (contrast, Kap. 12.1).
class _BottomEdgeFade extends StatelessWidget {
  const _BottomEdgeFade({required this.fade});

  final double fade;

  @override
  Widget build(BuildContext context) {
    final base = context.colors.background;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            final stop = h <= 0 ? 1.0 : (fade / h).clamp(0.0, 1.0);
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [base.withValues(alpha: 0), base, base],
                  stops: [0, stop, 1],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
