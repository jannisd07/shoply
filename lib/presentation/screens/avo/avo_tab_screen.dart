import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:shoply/core/constants/app_brand.dart';
import 'package:shoply/core/constants/legal_links.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/tip_service.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/providers/avo_screen_context_provider.dart';
import 'package:shoply/presentation/providers/subscription_provider.dart';
import 'package:shoply/presentation/screens/avo/avo_chat.dart';
import 'package:shoply/presentation/screens/avo/avo_hand_over.dart';
import 'package:shoply/presentation/screens/avo/avo_initial_question.dart';
import 'package:shoply/presentation/screens/avo/avo_photo_source.dart';
import 'package:shoply/presentation/screens/avo/avo_suggestions.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_composer.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_context_chip.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_glyphs.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_large_title.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_list_sections.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_record_sections.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_status_sections.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_suggestion_views.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_turn_view.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/widgets/design/add_item_accessory.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/confirm_dialog.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/presentation/widgets/tips/tip_slot.dart';

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
/// [prompt] comes from the URL (`?prompt=`, `?q=`, deep links): it only
/// fills the composer and never sends, so no other app or web page can make
/// Avo act. [ask] is an in-app hand-over (`openAvoWithQuestion`): sent once.
class AvoTabScreen extends ConsumerStatefulWidget {
  const AvoTabScreen({super.key, this.prompt, this.ask});

  final String? prompt;
  final AvoAsk? ask;

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

  final _prefill = AvoInitialQuestion();
  int? _lastAsk;

  AvoChat? _chat;
  int _turnCount = -1;

  /// The one status row (offline, AI off, weak connection): it moves between
  /// the conversation (below the large title) and the pinned band under the
  /// head without losing its state, so it is announced once.
  final _statusKey = GlobalKey(debugLabel: 'avo-status');
  String? _announcedStatus;

  /// The composer, to place the photo menu at its camera button.
  final _composerKey = GlobalKey(debugLabel: 'avo-composer');

  /// The camera is off in Settings (Kap. 7.4): the status row says so
  /// until a photo or a question goes out.
  bool _cameraDenied = false;
  bool _visible = false;
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () => _chat?.expireIfStale(),
  );

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _lifecycle;
    _handOver(widget.ask);
    _prefillWith(widget.prompt);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The tab root stays mounted: TickerMode is off while another tab shows,
    // and the route is not current while something is pushed on top.
    final visible =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (visible && !_visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(avoChatProvider).expireIfStale();
      });
    }
    _visible = visible;
  }

  @override
  void didUpdateWidget(covariant AvoTabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ask?.id != oldWidget.ask?.id) _handOver(widget.ask);
    if (widget.prompt != oldWidget.prompt) _prefillWith(widget.prompt);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _chat?.onTurnFinished = null;
    _chat?.onChangeMade = null;
    _chat?.onAvoTurnedOff = null;
    _scroll.removeListener(_onScroll);
    _scrollSpring.dispose();
    _scroll.dispose();
    _collapsed.dispose();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ hand-overs

  /// An in-app [AvoAsk]: sent once, after the first frame (with the AI
  /// switched off it only fills the composer).
  void _handOver(AvoAsk? ask) {
    if (ask == null || ask.id == _lastAsk) return;
    _lastAsk = ask.id;
    final q = ask.question.trim();
    if (q.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ref.read(aiRemoteEnabledProvider)) {
        _prefillWith(q);
        return;
      }
      _send(q, clearField: false);
    });
  }

  /// A URL's `?prompt=` / `?q=`: fills the composer, never sends.
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

  /// Free with a known Pro limit: only then may the Pro row show (and use
  /// up the week's one showing).
  bool get _proHintAllowed =>
      !ref.read(isSubscribedProvider) &&
      ref.read(avoProQuestionLimitProvider) != null;

  /// [typed]: the person wrote it in the composer (counts for Teil A's tip
  /// T8); suggestions, chips and in-app hand-overs do not.
  void _send(String text, {bool clearField = true, bool typed = false}) {
    final chat = ref.read(avoChatProvider)..attach(ref);
    final turn = chat.send(
      text,
      offline: ref.read(isOfflineProvider),
      proHintAllowed: _proHintAllowed,
    );
    if (turn == null) return;
    if (clearField) _controller.clear();
    if (_cameraDenied) setState(() => _cameraDenied = false);
    if (typed) ref.read(tipServiceProvider).note(TipEvent.avoTextMessage);
  }

  // ---------------------------------------------------------------- photos

  /// "Foto hinzufügen": the pull-down "Foto aufnehmen / Foto auswählen"
  /// from the camera button of the composer (Kap. 2.11, 7.1).
  void _photoMenu() {
    final box = _composerKey.currentContext?.findRenderObject() as RenderBox?;
    Rect? anchor;
    if (box != null && box.hasSize) {
      final origin = box.localToGlobal(Offset.zero);
      anchor = Rect.fromLTWH(
        origin.dx + AvoSpacing.screen,
        origin.dy + box.size.height - AvoSizes.accessoryHeight,
        AvoSizes.hitTarget,
        AvoSizes.accessoryHeight,
      );
    }
    showAvoMenu(
      context,
      anchorRect: anchor,
      items: [
        AvoMenuItem(
          label: context.tr('avo_photo_take'),
          onSelected: () => unawaited(_takePhoto()),
        ),
        AvoMenuItem(
          label: context.tr('avo_photo_choose'),
          onSelected: () => unawaited(_choosePhoto()),
        ),
      ],
    );
  }

  /// "Neues Foto" on a photo Avo could not read.
  void _photoMenuFromCard() => _photoMenu();

  /// The camera: first the app's own explanation when the system has not
  /// asked yet (dialog 11.3), then the system camera.
  Future<void> _takePhoto() async {
    final source = ref.read(avoPhotoSourceProvider);
    final access = await source.cameraAccess();
    if (!mounted) return;
    if (access == AvoCameraAccess.denied) {
      setState(() => _cameraDenied = true);
      return;
    }
    if (access == AvoCameraAccess.notAsked) {
      final go = await showAvoConfirm(
        context,
        title: context.tr('avo_camera_title'),
        message: context.tr('avo_camera_body'),
        confirmLabel: context.tr('avo_continue'),
        cancelLabel: context.tr('avo_not_now'),
        destructive: false,
      );
      if (!go || !mounted) return;
    }
    final photo = await source.take();
    if (!mounted) return;
    if (photo == null) {
      // Declined in the system prompt: say how to allow it.
      if (await source.cameraAccess() == AvoCameraAccess.denied && mounted) {
        setState(() => _cameraDenied = true);
      }
      return;
    }
    _sendPhoto(photo);
  }

  Future<void> _choosePhoto() async {
    final photo = await ref.read(avoPhotoSourceProvider).choose();
    if (photo == null || !mounted) return;
    _sendPhoto(photo);
  }

  /// The photo goes out with what is in the composer as its note.
  void _sendPhoto(Uint8List photo) {
    final chat = ref.read(avoChatProvider)..attach(ref);
    final turn = chat.sendPhoto(
      photo,
      text: _controller.text,
      offline: ref.read(isOfflineProvider),
    );
    if (turn == null) return;
    _controller.clear();
    setState(() => _cameraDenied = false);
  }

  /// Kap. 3.2: a change made while the tab is not visible also shows as a
  /// toast on the current screen, without Avo's name, with "Widerrufen".
  void _changeMade(AvoWidgetPayload p) {
    if (!mounted || _visible) return;
    final chat = ref.read(avoChatProvider);
    final change = chat.changeOf(p);
    final record = chat.recordOf(p);
    final String message;
    final bool undoable;
    if (change != null) {
      message = avoChangeToast(context, change);
      undoable = change.undo != null;
    } else if (record != null) {
      final head = avoRecordHead(context, record);
      message = '${head.title}: ${head.subtitle}';
      undoable = record.undo != null;
    } else {
      return;
    }
    AvoToast.show(
      context,
      message: message,
      actionLabel: undoable ? context.tr('avo_undo') : null,
      onAction: undoable ? () => chat.undo(p) : null,
    );
  }

  /// Avo switched itself off (Kap. 5.7): the global toast with
  /// "Widerrufen"; the tab goes away with the module.
  void _avoTurnedOff(AvoModuleRecord record) {
    if (!mounted) return;
    // The tab goes away with the module; the container outlives it.
    final container = ProviderScope.containerOf(context, listen: false);
    AvoToast.show(
      context,
      message: context.tr('avo_avo_off_toast'),
      actionLabel: context.tr('avo_undo'),
      onAction: () => container
          .read(appModulesProvider.notifier)
          .setEnabled(AppModule.avo, true),
    );
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

  // ---------------------------------------------------------------- status

  /// The status row is in the conversation but scrolled out of sight (and
  /// maybe never built): say its new text once, politely (Kap. 2.12).
  void _announceIfHidden(String? text, {required bool visible}) {
    if (text == _announcedStatus) return;
    _announcedStatus = text;
    if (text == null || visible) return;
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final view = View.maybeOf(context);
      if (view == null) return;
      SemanticsService.sendAnnouncement(view, text, Directionality.of(context));
    });
  }

  // ------------------------------------------------------------- scrolling

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final threshold = context.typography.lineHeightOf(AvoTextStyle.largeTitle);
    final collapsed = _scroll.offset > threshold;
    if (collapsed == _collapsed.value) return;
    _collapsed.value = collapsed;
    // The status row may move between the conversation and the band.
    setState(() {});
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
        : turn.isPhoto
        ? _photoResult(turn)
        : turn.text.value.trim();
    if (text.isEmpty) return;
    final undo = turn.payloads.any(
      (p) => p.listChange?.undo != null || p.record?.undo != null,
    );
    SemanticsService.sendAnnouncement(
      view,
      [
        '${context.tr('avo_a11y_prefix')} $text',
        if (undo) context.tr('avo_a11y_undo_available'),
      ].join(' '),
      Directionality.of(context),
    );
  }

  /// What a photo round found, for its announcement (Kap. 3.6).
  String _photoResult(AvoTurn turn) {
    for (final p in turn.payloads.reversed) {
      switch (p.card) {
        case AvoEstimateCard(:final name, :final kcal):
          return '$name, ${context.tr('avo_est_about', params: {'kcal': '$kcal'})}';
        case AvoListImportCard(:final items):
          return items.length == 1
              ? context.tr('avo_import_found_one')
              : context.tr('avo_import_found', params: {'n': '${items.length}'});
        case AvoPhotoChoiceCard():
          return context.tr('avo_photo_question');
        case AvoPhotoErrorCard():
          return context.tr('avo_err_title');
        default:
          break;
      }
    }
    return '';
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
    // Everything that runs later works with this long-lived ref, never with
    // the ref of a round that may scroll away.
    chat.attach(ref);
    if (!identical(chat, _chat)) {
      _chat?.onTurnFinished = null;
      _chat?.onChangeMade = null;
      _chat?.onAvoTurnedOff = null;
      _chat = chat;
      chat
        ..onTurnFinished = _announce
        ..onChangeMade = _changeMade
        ..onAvoTurnedOff = _avoTurnedOff;
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

    final status = !aiOn
        ? StatusRow(
            kind: StatusKind.sectionError,
            text: context.tr('avo_unavailable'),
          )
        : offline
        ? StatusRow(kind: StatusKind.offline, text: context.tr('avo_offline'))
        : _cameraDenied
        ? StatusRow(
            kind: StatusKind.permission,
            text: context.tr('avo_camera_denied'),
            actionLabel: context.tr('avo_settings_action'),
            onAction: () => ref.read(avoPhotoSourceProvider).openSettings(),
          )
        : chat.slowConnection
        ? StatusRow(
            kind: StatusKind.pending,
            text: context.tr('avo_slow_connection'),
          )
        : null;
    final cameraRow = aiOn && !offline && _cameraDenied;
    final media = MediaQuery.of(context);
    // The status row sits in the conversation below the large title (as
    // StatusRow wants it). Once the title has collapsed into the head it
    // pins under the head, so it stays in sight, but only while it is small:
    // never at accessibility sizes or above a quarter of the screen, where
    // it would hide the conversation. Its height is measured up front, so
    // nothing jumps and nothing is covered for a frame.
    final statusText = status?.text;
    final statusSpace = statusText == null
        ? 0.0
        : _statusRowHeight(context, statusText, media.size.width) +
              2 * AvoSpacing.xs;
    final mayPin =
        statusText != null &&
        !cameraRow &&
        !context.isAccessibilityText &&
        statusSpace <= media.size.height / 4;
    final pinned = mayPin && _collapsed.value;
    _announceIfHidden(statusText, visible: pinned || !_collapsed.value);

    final toolbarTop = GlassToolbar.topOffset(context);
    final top = toolbarTop + AvoSizes.toolbarButton + _titleGap;
    // The newest round glides below the band, not under it.
    final turnTop =
        toolbarTop +
        AvoSizes.toolbarButton +
        AvoSpacing.s +
        (mayPin ? statusSpace : 0);
    final dockBottom = AccessoryDock.bottomOffset(context);
    final chipSpace = showChip ? AvoSizes.hitTarget + _contextChipGap : 0.0;
    final bottom =
        dockBottom + AvoSizes.accessoryHeight + chipSpace + AvoSpacing.l;
    final lastMinHeight = (media.size.height - turnTop - bottom).clamp(
      0.0,
      double.infinity,
    );

    final pose = chat.isWorking
        ? AvoPose.thinking
        : chat.celebrating
        ? AvoPose.celebrating
        : AvoPose.waving;

    final followUpTarget = contextName ?? contextList?.name;
    final body = <Widget>[
      // VoiceOver reads the title from the head ([_TitleForVoiceOver]), so it
      // comes before "Neues Gespräch" (Kap. 3.6).
      ExcludeSemantics(child: AvoLargeTitle(pose: pose)),
      // The slot is always there (empty without a status), so the rounds
      // below keep their places in the list and their state when the row
      // comes or goes (W1 re-review 3, Minor 2).
      if (status == null)
        const SizedBox.shrink()
      else if (pinned)
        // Holds its place while it is pinned, so nothing moves.
        SizedBox(height: statusSpace)
      else
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: statusSpace),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AvoSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                KeyedSubtree(key: _statusKey, child: status),
                // Kap. 7.4: "Stattdessen Foto auswählen" under the row.
                if (cameraRow)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AvoSpacing.screen,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: AppButton.plain(
                        label: context.tr('avo_photo_choose_instead'),
                        onPressed: () => unawaited(_choosePhoto()),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
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
            // VoiceOver (Kap. 3.6): title, "Neues Gespräch", status row,
            // conversation, then the composer, whatever scrolls under what.
            child: Semantics(
              container: true,
              sortKey: const OrdinalSortKey(2),
              // A finger on the list stops the glide to the newest round at
              // once (interruptible, apple-design §3).
              child: NotificationListener<UserScrollNotification>(
                onNotification: (_) {
                  if (_scrollSpring.isAnimating) _scrollSpring.stop();
                  return false;
                },
                child: CustomScrollView(
                  controller: _scroll,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.only(top: top, bottom: bottom),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(body),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (status != null && pinned)
                  Semantics(
                    container: true,
                    sortKey: const OrdinalSortKey(1.5),
                    child: ColoredBox(
                      color: colors.background,
                      child: Padding(
                        padding: EdgeInsets.only(
                          top:
                              toolbarTop +
                              AvoSizes.toolbarButton +
                              AvoSpacing.xs,
                          bottom: AvoSpacing.xs,
                        ),
                        child: KeyedSubtree(key: _statusKey, child: status),
                      ),
                    ),
                  ),
                ScrollEdgeFade(height: pinned ? _bottomFade : _topFade),
              ],
            ),
          ),
          Positioned(
            top: toolbarTop,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<bool>(
              valueListenable: _collapsed,
              builder: (context, collapsed, _) => Semantics(
                container: true,
                sortKey: const OrdinalSortKey(1),
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
          _TitleForVoiceOver(scroll: _scroll, collapsed: _collapsed, top: top),
          AccessoryDock(
            child: Semantics(
              container: true,
              sortKey: const OrdinalSortKey(3),
              child: AvoComposer(
                key: _composerKey,
                controller: _controller,
                focusNode: _focus,
                enabled: aiOn,
                onPhoto: _photoMenu,
                onSend: (text) => _send(text, typed: true),
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
        onNewPhoto: _photoMenuFromCard,
      ),
    );
    // Keyed by the round, so the list finds it again whatever comes or goes
    // above it; the same wrapper for every round, so the newest one keeps
    // its state when a newer round arrives.
    return KeyedSubtree(
      key: ValueKey('avo-turn-${turn.id}'),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: last ? minHeight : 0),
        child: Align(alignment: Alignment.topCenter, child: view),
      ),
    );
  }
}

// Mirrors StatusRow (Teil A): 16 pt symbol at subhead 15, 8 pt gap, 12 pt
// above and below the text, at least 44 pt, 16 pt side margins.
const double _statusSymbol = 16;
const double _statusSubheadAtLarge = 15;
const double _statusGap = AvoSpacing.s;
const double _statusVertical = AvoSpacing.m;

/// The height a [StatusRow] with [text] takes at [screenWidth], measured
/// with the same text resolution as `Text` (Dynamic Type, Bold Text).
double _statusRowHeight(BuildContext context, String text, double screenWidth) {
  final typography = context.typography;
  final symbol =
      _statusSymbol *
      typography.sizeOf(AvoTextStyle.subhead) /
      _statusSubheadAtLarge;
  final style = context.text(AvoTextStyle.subhead);
  final painter =
      TextPainter(
        text: TextSpan(
          text: text,
          style: MediaQuery.boldTextOf(context)
              ? style.merge(const TextStyle(fontWeight: FontWeight.bold))
              : style,
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(
        maxWidth: math.max(
          0,
          screenWidth - 2 * AvoSpacing.screen - symbol - _statusGap,
        ),
      );
  final height = painter.height + 2 * _statusVertical;
  painter.dispose();
  return math.max(AvoSizes.hitTarget, height);
}

/// The large title "Avo" for VoiceOver, placed over the scrolling title so
/// it is read first (Kap. 3.6). Once the title has collapsed into the
/// toolbar, the toolbar's title takes over.
class _TitleForVoiceOver extends StatelessWidget {
  const _TitleForVoiceOver({
    required this.scroll,
    required this.collapsed,
    required this.top,
  });

  final ScrollController scroll;
  final ValueListenable<bool> collapsed;
  final double top;

  @override
  Widget build(BuildContext context) {
    final height = context.typography.lineHeightOf(AvoTextStyle.largeTitle);
    return ListenableBuilder(
      listenable: Listenable.merge([scroll, collapsed]),
      builder: (context, _) {
        if (collapsed.value) return const SizedBox.shrink();
        final offset = scroll.hasClients ? scroll.offset : 0.0;
        return Positioned(
          top: top - offset,
          left: AvoSpacing.screen,
          right: AvoSpacing.screen,
          height: height,
          child: IgnorePointer(
            child: Semantics(
              container: true,
              header: true,
              label: AppBrand.name,
              sortKey: const OrdinalSortKey(0),
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
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
