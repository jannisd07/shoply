import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:shoply/core/constants/legal_links.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/profile/settings/data/profile_settings.dart'
    show recipeAutoAdaptProvider;
import 'package:shoply/presentation/screens/recipes/cooking_mode_screen.dart'
    show cookingProgressProvider;
import 'package:shoply/presentation/screens/recipes/widgets/recipe_detail_action_bar.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_detail_adaptation.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_detail_data.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_detail_header.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_detail_report.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_detail_sections.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_detail_texts.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_browse_actions.dart'
    show kRecipeActionParam, kRecipeActionToList;
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/saved_recipes_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/confirm_dialog.dart';
import 'package:shoply/presentation/widgets/design/full_screen_editor.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/presentation/widgets/recipes/nutrition_info_widget.dart';
import 'package:shoply/presentation/widgets/recipes/star_rating_widget.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

export 'package:shoply/presentation/screens/recipes/widgets/select_list_bottom_sheet.dart'
    show openIngredientsToList;

/// Ratings needed before the average shows (Konzept 13 §12.1 Nr. 3).
const int _minRatingsShown = 3;

/// Licence of imported Wikibooks recipes (shown with the source).
const String _wikibooksLicense = 'CC BY-SA 4.0';

enum _Load { ready, loading, gone, failed }

/// One recipe (Konzept 13 §12, R-10; optics from the D2 components):
///
/// - The photo edge to edge under the glass toolbar (back, "Merken" or
///   "Bearbeiten", "Teilen", "Mehr"); the name shows inline once the photo
///   has scrolled away.
/// - Title, meta line, author; the allergy notice right below when the
///   person's allergies or diet are affected (never hidden for space).
/// - Ingredients with servings stepper and "Für dich angepasst | Original",
///   Teil B's offers card, the steps, nutrition, "Deine Bewertung", source.
/// - The floating bar: "Zutaten auf die Liste" (full screen) and "Kochen"
///   (cooking mode through the Pro gate), both with the adapted recipe.
/// - States: local copy at once (card, loaded lists, device cache), calm
///   placeholders when nothing is known, "gibt es nicht mehr", load error,
///   offline.
/// - Sets the Avo context `recipe` while it is the current screen.
/// - `?action=to-list` (Teil "browse", hero button) starts "Zutaten auf die
///   Liste" once the push has settled and the recipe is there.
class RecipeDetailScreen extends ConsumerStatefulWidget {
  final String recipeId;

  /// The recipe as already loaded by the list the user tapped, if any. It is
  /// shown immediately and refreshed in the background; deep links pass none.
  final Recipe? initialRecipe;

  const RecipeDetailScreen({
    super.key,
    required this.recipeId,
    this.initialRecipe,
  });

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  /// Views count once per recipe and app session (Konzept 13 §2.1).
  static final Set<String> _viewed = {};

  /// The warning haptic plays once per recipe and session (§2.3).
  static final Set<String> _warned = {};

  final _scroll = ScrollController();
  final _overscroll = ValueNotifier<double>(0);
  final _collapsed = ValueNotifier<bool>(false);
  final _shareKey = GlobalKey(debugLabel: 'recipeShare');
  final _moreKey = GlobalKey(debugLabel: 'recipeMore');

  Recipe? _recipe;
  _Load _load = _Load.loading;
  Future<Recipe?>? _deviceLookup;

  /// Version shown (Konzept 13 §2.3): first "Für dich angepasst" or
  /// "Original", as "Rezepte automatisch anpassen" says (Ernährung &
  /// Allergien); the switch changes it after.
  late bool _adapted = ref.read(recipeAutoAdaptProvider);

  /// The person's rating while it is being saved.
  int? _myRating;

  double _photoHeight = 0;

  RecipeAdaptation? _adaptation;
  Recipe? _adaptationRecipe;
  Object? _adaptationUser;

  late final StateController<AvoScreenContext?> _avo;
  bool _avoSet = false;

  /// `?action=to-list` is waiting for the push to settle and the recipe.
  bool _toListPending = false;
  bool _actionRead = false;
  bool _settled = false;
  Animation<double>? _routeAnimation;

  RecipeDetailActions get _actions => ref.read(recipeDetailActionsProvider);
  String get _id => widget.recipeId;

  @override
  void initState() {
    super.initState();
    _avo = ref.read(avoScreenContextProvider.notifier);
    _scroll.addListener(_onScroll);
    final initial = widget.initialRecipe;
    final known = initial != null && initial.id == _id
        ? initial
        : _actions.known(ref, _id);
    if (known != null) {
      _recipe = known;
      _load = _Load.ready;
    } else {
      _deviceLookup = _fromDevice();
    }
    unawaited(_refresh());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final animation = ModalRoute.of(context)?.animation;
      if (animation == null || animation.status == AnimationStatus.completed) {
        _onSettled();
      } else {
        _routeAnimation = animation;
        animation.addStatusListener(_onRouteStatus);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_actionRead) return;
    _actionRead = true;
    _toListPending = _routeAction() == kRecipeActionToList;
  }

  /// `?action=…` on the route; null outside the router (tests, a push).
  String? _routeAction() {
    try {
      return GoRouterState.of(context).uri.queryParameters[kRecipeActionParam];
    } catch (_) {
      return null;
    }
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _routeAnimation = null;
    _onSettled();
  }

  void _onSettled() {
    if (!mounted || _settled) return;
    _settled = true;
    _startPendingAction();
  }

  /// Runs `?action=to-list` once, when the push is done and the recipe is
  /// known (a deep link waits for the load).
  void _startPendingAction() {
    final recipe = _recipe;
    if (!_toListPending || !_settled || recipe == null || !mounted) return;
    _toListPending = false;
    if (recipe.ingredients.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = _recipe ?? recipe;
      final base = current.defaultServings > 0 ? current.defaultServings : 1;
      final servings = (ref.read(recipeServingsProvider(current.id)) ?? base)
          .clamp(1, 20);
      unawaited(
        _actions.openToList(context, current, servings, adapted: _adapted),
      );
    });
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _resetAvoContext();
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _overscroll.dispose();
    _collapsed.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- loading

  Future<Recipe?> _fromDevice() async {
    try {
      final r = await _actions.onDevice(_id);
      if (r != null && mounted && _recipe == null) {
        setState(() {
          _recipe = r;
          _load = _Load.ready;
        });
        _startPendingAction();
      }
      return r;
    } catch (e) {
      debugPrint('⚠️ [RECIPE_DETAIL] No device copy: $e');
      return null;
    }
  }

  /// Loads the full recipe; a failure keeps what is shown (Konzept 13 §2.1).
  Future<void> _refresh() async {
    try {
      final recipe = await _actions.load(_id);
      if (!mounted) return;
      setState(() {
        _recipe = recipe;
        _load = _Load.ready;
      });
      _startPendingAction();
      _trackView(recipe);
    } catch (e) {
      debugPrint('❌ [RECIPE_DETAIL] Load $_id failed: $e');
      if (!mounted) return;
      if (_actions.isNotFound(e)) {
        setState(() {
          _recipe = null;
          _load = _Load.gone;
        });
        return;
      }
      await _deviceLookup;
      if (!mounted || _recipe != null) return;
      setState(() => _load = _Load.failed);
    }
  }

  void _retry() {
    setState(() => _load = _Load.loading);
    unawaited(_refresh());
  }

  void _trackView(Recipe recipe) {
    final me = ref.read(currentUserProvider).valueOrNull?.id;
    if (me != null && me == recipe.authorId) return;
    if (!_viewed.add(recipe.id)) return;
    unawaited(
      _actions.trackView(recipe.id).catchError((Object e) {
        debugPrint('⚠️ [RECIPE_DETAIL] View not counted: $e');
      }),
    );
  }

  // ----------------------------------------------------------------- Avo

  void _syncAvoContext({required bool current}) {
    if (!current || _avoSet) return;
    _avoSet = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _avo.state = const AvoScreenContext(screen: 'recipe');
    });
  }

  /// Leaving clears the context, unless another screen already set its own.
  void _resetAvoContext() {
    final avo = _avo;
    Future.microtask(() {
      try {
        if (avo.state?.screen == 'recipe') avo.state = null;
      } catch (_) {
        // The provider scope is gone (app or test shut down).
      }
    });
  }

  // -------------------------------------------------------------- scroll

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final offset = _scroll.offset;
    _overscroll.value = math.max(0, -offset);
    final collapseAt =
        _photoHeight - GlassToolbar.topOffset(context) - AvoSizes.toolbarButton;
    final collapsed = _photoHeight > 0 && offset > collapseAt;
    if (_collapsed.value != collapsed) _collapsed.value = collapsed;
  }

  // ------------------------------------------------------------- derived

  RecipeAdaptation _adaptationFor(Recipe recipe, Object? user) {
    final known = _adaptation;
    if (known != null &&
        identical(recipe, _adaptationRecipe) &&
        identical(user, _adaptationUser)) {
      return known;
    }
    _adaptationRecipe = recipe;
    _adaptationUser = user;
    return _adaptation = RecipeAdaptation.of(
      recipe,
      RecipeDietProfile.ofUser(ref.read(currentUserProvider).valueOrNull),
    );
  }

  int _servingsFor(Recipe recipe) {
    final chosen = ref.watch(recipeServingsProvider(recipe.id));
    final base = recipe.defaultServings > 0 ? recipe.defaultServings : 1;
    return (chosen ?? base).clamp(1, 20);
  }

  String _rating(Recipe recipe, String language) =>
      NumberFormat('0.0', language).format(recipe.averageRating);

  List<String> _metaParts(Recipe recipe, String language) {
    String tr(String key, Map<String, String> params) =>
        context.tr(key, params: params);
    final diet = recipeShownDiet(recipe);
    return [
      if (recipe.totalTimeMinutes > 0)
        formatRecipeTime(recipe.totalTimeMinutes, tr),
      if (recipe.ratingCount >= _minRatingsShown)
        context.tr(
          'recipe_detail_rating',
          params: {
            'rating': _rating(recipe, language),
            'count': '${recipe.ratingCount}',
          },
        ),
      if (diet == RecipeDiet.vegan)
        context.tr('recipe_detail_vegan')
      else if (diet == RecipeDiet.vegetarian)
        context.tr('recipe_detail_vegetarian'),
    ];
  }

  /// The meta line with the rating spelled out for VoiceOver.
  String? _metaSemantics(Recipe recipe, List<String> parts, String language) {
    if (recipe.ratingCount < _minRatingsShown) return null;
    final shown = context.tr(
      'recipe_detail_rating',
      params: {
        'rating': _rating(recipe, language),
        'count': '${recipe.ratingCount}',
      },
    );
    final spoken = context.tr(
      'recipe_detail_rating_semantics',
      params: {
        'rating': _rating(recipe, language),
        'count': '${recipe.ratingCount}',
      },
    );
    return [for (final p in parts) p == shown ? spoken : p].join(', ');
  }

  // ------------------------------------------------------------- actions

  Rect? _originOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _share(Recipe recipe) =>
      _actions.share(context, recipe, _originOf(_shareKey));

  Future<void> _edit() async {
    final saved = await _actions.edit(context, _id);
    if (saved && mounted) unawaited(_refresh());
  }

  void _openMenu(Recipe recipe, {required bool own, required bool canLog}) {
    unawaited(
      showAvoMenu(
        context,
        anchorKey: _moreKey,
        items: [
          if (canLog)
            AvoMenuItem(
              label: context.tr('recipe_detail_log'),
              onSelected: () => unawaited(_actions.logRecipe(context, recipe)),
            ),
          if (own)
            AvoMenuItem(
              label: context.tr('recipe_detail_edit'),
              onSelected: () => unawaited(_edit()),
            )
          else
            AvoMenuItem(
              label: context.tr('recipe_detail_report'),
              onSelected: () => unawaited(_report(recipe)),
            ),
          if (own) ...[
            const AvoMenuDivider(),
            AvoMenuItem(
              label: context.tr('recipe_detail_delete'),
              icon: AvoIcons.trash,
              destructive: true,
              onSelected: () => unawaited(_delete(recipe)),
            ),
          ],
        ],
      ),
    );
  }

  /// Konzept 13 §18.2: confirm, back at once, delete behind it; a failure
  /// says so with "Erneut versuchen".
  Future<void> _delete(Recipe recipe) async {
    final confirmed = await showAvoConfirm(
      context,
      title: context.tr(
        'recipe_detail_delete_title',
        params: {'name': recipe.name},
      ),
      message: context.tr('recipe_detail_delete_message'),
      confirmLabel: context.tr('recipe_detail_delete'),
    );
    if (!confirmed || !mounted) return;
    final actions = _actions;
    final container = ProviderScope.containerOf(context, listen: false);
    final toastContext = Navigator.of(context, rootNavigator: true).context;
    final deleted = context.tr('recipe_detail_deleted');
    final failed = context.tr('recipe_detail_delete_failed');
    final retry = context.tr('common_try_again');
    actions.back(context);

    Future<void> run() async {
      try {
        await actions.delete(recipe.id);
        actions.refreshRecipes(container);
        if (toastContext.mounted) {
          AvoToast.show(toastContext, message: deleted);
        }
      } catch (e) {
        debugPrint('❌ [RECIPE_DETAIL] Delete failed: $e');
        unawaited(AvoHaptics.error());
        if (toastContext.mounted) {
          AvoToast.show(
            toastContext,
            message: failed,
            actionLabel: retry,
            onAction: () => unawaited(run()),
          );
        }
      }
    }

    unawaited(run());
  }

  /// "Melden" (Konzept 13 §18.4) as a full screen; the report goes out as
  /// a prepared mail until a server table for reports exists (E-09).
  Future<void> _report(Recipe recipe) async {
    final report = await pushFullScreenEditor<RecipeReport>(
      context,
      (_) => const RecipeReportScreen(),
    );
    if (report == null || !mounted) return;
    final opened = await _actions.report(
      subject: context.tr(
        'recipe_detail_report_subject',
        params: {'name': recipe.name},
      ),
      body: context.tr(
        'recipe_detail_report_body',
        params: {
          'name': recipe.name,
          'id': recipe.id,
          'reason': recipeReportReasonText(context, report.reason),
          'note': report.note,
        },
      ),
    );
    if (!mounted) return;
    AvoToast.show(
      context,
      message: opened
          ? context.tr('recipe_detail_report_ready')
          : context.tr(
              'recipe_detail_report_no_mail',
              params: {'email': LegalLinks.supportEmail},
            ),
    );
  }

  /// Optimistic; a failure brings the old stars back (Konzept 13 §12.1).
  Future<void> _rate(Recipe recipe, int stars) async {
    final before = recipe.userRating;
    if (before == stars) return;
    final count = recipe.ratingCount;
    final total = recipe.averageRating * count;
    final updated = recipe.copyWith(
      averageRating: before == null
          ? (total + stars) / (count + 1)
          : (total - before + stars) / math.max(1, count),
      ratingCount: before == null ? count + 1 : count,
      userRating: stars,
    );
    final container = ProviderScope.containerOf(context, listen: false);
    final failed = context.tr('recipe_detail_rating_failed');
    setState(() {
      _myRating = stars;
      _recipe = updated;
    });
    try {
      await _actions.rate(recipe.id, stars);
      _actions.refreshRecipes(container);
      if (mounted) setState(() => _myRating = null);
    } catch (e) {
      debugPrint('❌ [RECIPE_DETAIL] Rating not saved: $e');
      unawaited(AvoHaptics.error());
      if (!mounted) return;
      setState(() {
        _myRating = null;
        _recipe = recipe;
      });
      AvoToast.show(context, message: failed);
    }
  }

  // --------------------------------------------------------------- build

  /// Inside the tab shell the shell raises `padding.bottom` above the
  /// `viewPadding` by the tab bar; outside (deep link) both are equal.
  bool _inShell(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom >
      MediaQuery.viewPaddingOf(context).bottom + 0.5;

  double _barBottom(BuildContext context) => _inShell(context)
      ? ShellInsets.aboveTabBar(context)
      : MediaQuery.viewPaddingOf(context).bottom + AvoSpacing.s;

  double _contentEnd(BuildContext context) => _inShell(context)
      ? ShellInsets.bottom(context, withAccessory: true)
      : _barBottom(context) + AvoSizes.accessoryHeight + AvoSpacing.l;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final background = context.isAccessibilityText
        ? colors.backgroundPlain
        : colors.background;
    _syncAvoContext(current: ModalRoute.isCurrentOf(context) ?? true);
    _photoHeight = recipePhotoHeight(context, MediaQuery.sizeOf(context).width);

    final recipe = _recipe;
    return ColoredBox(
      color: background,
      child: recipe == null
          ? _notReady(context)
          : _ready(context, recipe, background),
    );
  }

  Widget _notReady(BuildContext context) {
    final problem = switch (_load) {
      _Load.gone => RecipeDetailProblem(
        gone: true,
        onAction: () => _actions.openRecipes(context),
      ),
      _Load.failed => RecipeDetailProblem(
        gone: false,
        offline: ref.watch(isOfflineProvider),
        onAction: _retry,
      ),
      _ => null,
    };
    return Stack(
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            child: problem == null
                ? RecipeDetailPlaceholder(photoHeight: _photoHeight)
                : Padding(
                    padding: EdgeInsets.only(
                      top:
                          GlassToolbar.topOffset(context) +
                          AvoSizes.toolbarButton +
                          AvoSpacing.section,
                    ),
                    child: problem,
                  ),
          ),
        ),
        Positioned(
          top: GlassToolbar.topOffset(context),
          left: 0,
          right: 0,
          child: RecipeDetailToolbar(onBack: () => _actions.back(context)),
        ),
      ],
    );
  }

  Widget _ready(BuildContext context, Recipe recipe, Color background) {
    final language = Localizations.localeOf(context).languageCode;
    final user = ref.watch(currentUserProvider).valueOrNull;
    final own = user != null && user.id == recipe.authorId;
    final saved = own ? null : ref.watch(isRecipeSavedProvider(recipe.id));
    final offline = ref.watch(isOfflineProvider);
    final caloriesOn = ref.watch(moduleEnabledProvider(AppModule.calories));
    final offersOn = ref.watch(offersAvailableProvider);
    final nutrition = recipe.nutrition;
    final canLog = caloriesOn && nutrition != null && nutrition.hasData;
    final servings = _servingsFor(recipe);
    final resumeStep = ref
        .watch(cookingProgressProvider(recipe.id))
        .valueOrNull
        ?.stepNumber;

    final adaptation = _adaptationFor(recipe, user);
    final adapted = _adapted && adaptation.hasSubstitutes;
    if (adaptation.hasAllergen && _warned.add(recipe.id)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(AvoHaptics.warning()),
      );
    }

    final target = ref.watch(recipeTargetListProvider(recipe.id));
    final openItems = target == null
        ? null
        : ref.watch(recipeListOpenItemsProvider(target.id));

    // Teil B's offers (S15) for the target list: the pill at each
    // ingredient and the summary as the last row of "Zutaten".
    final offerListId = offersOn && ref.watch(offersRemoteEnabledProvider)
        ? target?.id
        : null;
    final offerRow = offerListId == null
        ? null
        : _offerSummary(recipe, offerListId);

    final lines = [
      for (final info in adaptation.ingredients)
        _line(
          context,
          info,
          recipe: recipe,
          servings: servings,
          adapted: adapted,
          language: language,
          listName: target?.name,
          openItems: openItems,
          offerListId: offerListId,
        ),
    ];
    final stepTexts = adaptation.steps(recipe, adapted: adapted);
    final steps = [
      for (var i = 0; i < stepTexts.length; i++)
        RecipeStepLine(
          text: stepTexts[i],
          note: adapted ? _stepNote(context, adaptation, i) : null,
        ),
    ];
    final notice = recipeNoticeLines(context, adaptation);
    final meta = _metaParts(recipe, language);
    final sourceName = recipe.sourceName == 'wikibooks'
        ? context.tr('recipe_detail_source_wikibooks')
        : context.tr('recipe_detail_source_web');
    final rating = _myRating ?? recipe.userRating;
    final sourceUrl = recipe.sourceUrl;

    final blocks = <Widget>[
      if (offline)
        Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.m),
          child: StatusRow(
            kind: StatusKind.offline,
            text: context.tr('recipe_detail_offline'),
          ),
        ),
      if (notice.isNotEmpty) ...[
        const SizedBox(height: AvoSpacing.l),
        RecipeAllergenNotice(lines: notice),
      ],
      if (recipe.description.trim().isNotEmpty) ...[
        const SizedBox(height: AvoSpacing.section),
        RecipeDescription(text: recipe.description),
      ],
      const SizedBox(height: AvoSpacing.s),
      RecipeIngredientsSection(
        lines: lines,
        servings: servings,
        onServings: (v) => rememberRecipeServings(ref, recipe.id, v),
        adapted: adaptation.hasSubstitutes ? adapted : null,
        onAdapted: adaptation.hasSubstitutes
            ? (v) => setState(() => _adapted = v)
            : null,
        footer: offerRow,
      ),
      const SizedBox(height: AvoSpacing.s),
      RecipeStepsSection(steps: steps),
      if (nutrition != null && nutrition.hasData) ...[
        const SizedBox(height: AvoSpacing.s),
        RecipeNutritionSection(nutrition: nutrition),
      ],
      if (canLog) ...[
        const SizedBox(height: AvoSpacing.section),
        InsetSection(
          children: [
            NavRow(
              title: context.tr('recipe_detail_log'),
              onTap: () => unawaited(_actions.logRecipe(context, recipe)),
            ),
          ],
        ),
      ],
      if (!own && user != null) ...[
        const SizedBox(height: AvoSpacing.section),
        InsetSection(
          children: [
            RecipeRatingRow(
              rating: rating,
              onRate: (stars) => unawaited(_rate(recipe, stars)),
            ),
          ],
        ),
      ],
      if (recipe.isImported && sourceUrl != null) ...[
        const SizedBox(height: AvoSpacing.l),
        RecipeSourceFooter(
          source: sourceName,
          license: recipe.sourceName == 'wikibooks' ? _wikibooksLicense : null,
          onOpen: () => unawaited(_actions.openSource(sourceUrl)),
        ),
      ],
      SizedBox(height: _contentEnd(context)),
    ];

    final hasPhoto = recipe.imageUrl.isNotEmpty;
    final dark = background.computeLuminance() < 0.5;

    return Stack(
      children: [
        Positioned.fill(
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: RecipeDetailPhoto(
                  imageUrl: recipe.imageUrl,
                  title: recipe.name,
                  overscroll: _overscroll,
                ),
              ),
              SliverToBoxAdapter(
                child: RecipeDetailTitle(
                  title: recipe.name,
                  metaParts: meta,
                  metaSemantics: _metaSemantics(recipe, meta, language),
                  authorName: recipe.isImported ? null : recipe.authorName,
                  authorAvatarUrl: recipe.authorAvatarUrl,
                  onAuthor: recipe.isImported || recipe.authorId.isEmpty
                      ? null
                      : () => _actions.openAuthor(context, recipe),
                  sourceLine: recipe.isImported
                      ? context.tr(
                          'recipe_detail_from_source',
                          params: {'source': sourceName},
                        )
                      : null,
                ),
              ),
              SliverList.list(children: blocks),
            ],
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _collapsed,
          builder: (context, collapsed, _) {
            final overPhoto = hasPhoto && !collapsed;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: overPhoto || dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark,
              child: Stack(
                children: [
                  if (!overPhoto)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: ScrollEdgeFade(color: background),
                    ),
                  Positioned(
                    top: GlassToolbar.topOffset(context),
                    left: 0,
                    right: 0,
                    child: RecipeDetailToolbar(
                      title: collapsed ? recipe.name : null,
                      onBack: () => _actions.back(context),
                      saved: saved,
                      onSave: saved == null
                          ? null
                          : () =>
                                unawaited(_actions.toggleSave(ref, recipe.id)),
                      onEdit: own ? () => unawaited(_edit()) : null,
                      shareKey: _shareKey,
                      onShare: () => unawaited(_share(recipe)),
                      moreKey: _moreKey,
                      onMore: () => _openMenu(recipe, own: own, canLog: canLog),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Positioned(
          left: AvoSpacing.screen,
          right: AvoSpacing.screen,
          bottom: _barBottom(context),
          child: RecipeDetailActionBar(
            resumeStep: resumeStep,
            onToList: recipe.ingredients.isEmpty
                ? null
                : () => unawaited(
                    _actions.openToList(
                      context,
                      recipe,
                      servings,
                      adapted: _adapted,
                    ),
                  ),
            onCook: () => unawaited(
              _actions.cook(
                context,
                ref,
                adaptation.applyTo(recipe, adapted: adapted),
                servings,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String? _stepNote(BuildContext context, RecipeAdaptation a, int step) {
    if (step >= a.stepSubstitutions.length) return null;
    final notes = [
      for (final s in a.stepSubstitutions[step]) ?recipeInsteadText(context, s),
    ];
    return notes.isEmpty ? null : notes.join('\n');
  }

  /// Teil B's "3 Zutaten diese Woche bei Lidl im Angebot" for [listId], or
  /// null while it would show nothing (then "Zutaten" has no empty row).
  /// The summary hands its offers to the ingredient pills itself.
  Widget? _offerSummary(Recipe recipe, String listId) {
    final shows = ref.watch(
      recipeOfferSummaryShowsProvider(recipeOfferSummaryKey(recipe, listId)),
    );
    return shows ? RecipeOfferSummary(recipe: recipe, listId: listId) : null;
  }

  RecipeIngredientLine _line(
    BuildContext context,
    AdaptedIngredient info, {
    required Recipe recipe,
    required int servings,
    required bool adapted,
    required String language,
    required String? listName,
    required List<ShoppingItemModel>? openItems,
    String? offerListId,
  }) {
    final replaced = adapted && info.isAdapted;
    final scaled = scaleIngredient(
      info.shown(adapted: adapted),
      recipe.defaultServings,
      servings,
    );
    final onList =
        listName != null &&
        openItems != null &&
        openItems.any((i) => sameShoppingName(scaled.name, i.name));
    return RecipeIngredientLine(
      name: scaled.name,
      amount: formatRecipeAmount(scaled, language),
      adapted: replaced,
      allergen: info.allergens.isNotEmpty && !replaced
          ? recipeAllergenName(context, info.allergens.first)
          : null,
      unchecked: info.unchecked,
      // Offers are looked up for the recipe's own ingredients, so a
      // replaced one has none.
      offerBadge: offerListId == null || replaced
          ? null
          : IngredientOfferBadge(
              listId: offerListId,
              ingredient: info.original,
            ),
      sublines: [
        if (replaced) ?recipeInsteadText(context, info),
        if (onList)
          context.tr('recipe_detail_on_list', params: {'list': listName}),
      ],
    );
  }
}
