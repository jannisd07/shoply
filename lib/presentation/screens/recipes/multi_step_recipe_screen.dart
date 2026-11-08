import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_editor_backend.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_editor_form.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_editor_frame.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_editor_steps.dart';
import 'package:shoply/presentation/state/recipes_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/confirm_dialog.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';
import 'package:shoply/routes/route_paths.dart';

/// A page spring has landed within half a point.
const Tolerance _pageTolerance = Tolerance(distance: 0.5, velocity: 10);

/// A draft is saved this long after the last change (Konzept 13 §17.1).
const Duration _draftDelay = Duration(seconds: 1);

/// The recipe editor (R-15, Konzept 13 §17): four steps (photo and name,
/// times and servings, ingredients, preparation and visibility), full
/// screen in the [FullScreenEditor] style.
///
/// New recipes and drafts are saved as a draft automatically 1 s after
/// each change; X closes at once ("Als Entwurf gespeichert"), "Entwurf
/// verwerfen" sits in the "Mehr" menu with a confirmation. Editing a
/// published recipe ([recipeId]) saves nothing until "Änderungen
/// speichern"; closing with changes asks first. In edit mode the screen
/// pops with `true` after saving so the caller can reload.
class MultiStepRecipeScreen extends ConsumerStatefulWidget {
  final String? draftId;
  final String? recipeId;

  const MultiStepRecipeScreen({super.key, this.draftId, this.recipeId});

  @override
  ConsumerState<MultiStepRecipeScreen> createState() =>
      _MultiStepRecipeScreenState();
}

enum _Status { none, offline, publishFailed, draftFailed, loadFailed }

class _MultiStepRecipeScreenState extends ConsumerState<MultiStepRecipeScreen>
    with SingleTickerProviderStateMixin {
  final RecipeEditorForm _form = RecipeEditorForm();
  int _step = 0;

  late bool _loading = widget.draftId != null || widget.recipeId != null;
  String? _draftId;
  DateTime? _draftCreatedAt;
  String? _draftImagePath;

  /// The photo file [_draftImagePath] was made from.
  String? _keptPhotoSource;

  String? _editingId;
  Recipe? _original;
  String? _baseline;

  Timer? _saveTimer;
  Future<void>? _saving;
  bool _publishing = false;
  bool _discarded = false;
  _Status _status = _Status.none;
  String? _authorName;

  /// Issues shown since the last "Weiter" / "Veröffentlichen".
  final Set<RecipeEditorIssue> _shown = {};

  late PageController _pages = PageController();
  late final AnimationController _pageSpring = AnimationController.unbounded(
    vsync: this,
  );
  bool _springing = false;

  late final StateController<AvoScreenContext?> _avoContext;
  AvoScreenContext? _previousContext;
  static const _ownContext = AvoScreenContext(screen: 'recipes');

  bool get _editing => _editingId != null || widget.recipeId != null;

  String get _lang => Localizations.localeOf(context).languageCode;

  @override
  void initState() {
    super.initState();
    _form.addListener(_onFormChanged);
    _pageSpring.addListener(() {
      if (_pages.hasClients) _pages.jumpTo(_pageSpring.value);
    });
    _avoContext = ref.read(avoScreenContextProvider.notifier);
    _previousContext = _avoContext.state;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _avoContext.state = _ownContext;
      if (!_loading && mounted) _form.nameFocus.requestFocus();
    });
    if (widget.recipeId != null) {
      unawaited(_loadRecipe(widget.recipeId!));
    } else if (widget.draftId != null) {
      unawaited(_loadDraft(widget.draftId!));
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _form
      ..removeListener(_onFormChanged)
      ..dispose();
    _pageSpring.dispose();
    _pages.dispose();
    final controller = _avoContext;
    final previous = _previousContext;
    scheduleMicrotask(() {
      if (controller.mounted && controller.state == _ownContext) {
        controller.state = previous;
      }
    });
    super.dispose();
  }

  // ---------------------------------------------------------------- loading

  Future<void> _loadDraft(String id) async {
    final drafts = ref.read(recipeEditorDraftsProvider);
    try {
      final draft = await drafts.get(id);
      final photo = await drafts.photo(draft?.localImagePath);
      if (!mounted) return;
      if (draft != null) {
        _draftId = draft.id;
        _draftCreatedAt = draft.createdAt;
        _draftImagePath = photo?.path;
        _keptPhotoSource = photo?.path;
        _form.fillFromDraft(draft, photo: photo);
      }
    } catch (e) {
      debugPrint('❌ [RECIPE_EDITOR] Draft $id not loaded: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadRecipe(String id) async {
    setState(() {
      _loading = true;
      _status = _Status.none;
    });
    try {
      final recipe = await ref.read(recipeEditorBackendProvider).load(id);
      if (!mounted) return;
      _editingId = recipe.id;
      _original = recipe;
      _form.fillFromRecipe(recipe, languageCode: _lang);
      _baseline = _form.signature();
      setState(() => _loading = false);
    } catch (e) {
      debugPrint('❌ [RECIPE_EDITOR] Recipe $id not loaded: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = _Status.loadFailed;
      });
    }
  }

  // ------------------------------------------------------------ the draft

  void _onFormChanged() {
    if (!mounted) return;
    setState(() {
      _shown.removeWhere(
        (issue) => !_currentIssues(issue.step).contains(issue),
      );
      if (_status == _Status.publishFailed || _status == _Status.offline) {
        _status = _Status.none;
      }
    });
    if (_loading || _editing || _discarded) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(_draftDelay, () => unawaited(_saveDraft()));
  }

  /// Saves the draft now (waits for a save already running).
  Future<void> _saveDraft() async {
    _saveTimer?.cancel();
    final running = _saving;
    if (running != null) await running;
    if (_editing || _discarded) return;
    final future = _writeDraft();
    _saving = future;
    try {
      await future;
    } finally {
      if (identical(_saving, future)) _saving = null;
    }
  }

  Future<void> _writeDraft() async {
    final drafts = ref.read(recipeEditorDraftsProvider);
    final lang = _lang;
    try {
      if (!_form.hasContent) {
        // Everything emptied again: no draft.
        final id = _draftId;
        if (id != null) {
          await drafts.delete(id);
          await drafts.deletePhoto(_draftImagePath);
          _draftId = null;
          _draftImagePath = null;
          _keptPhotoSource = null;
        }
        return;
      }
      final id = _draftId ??= 'draft_${DateTime.now().millisecondsSinceEpoch}';
      _draftCreatedAt ??= DateTime.now();
      final photo = _form.photo;
      if (photo == null) {
        if (_draftImagePath != null) {
          await drafts.deletePhoto(_draftImagePath);
          _draftImagePath = null;
          _keptPhotoSource = null;
        }
      } else if (photo.path != _keptPhotoSource) {
        // The picker's file lives in tmp, which iOS purges.
        _draftImagePath = await drafts.keepPhoto(id, photo);
        _keptPhotoSource = photo.path;
      }
      await drafts.save(
        _form.toDraft(
          id: id,
          languageCode: lang,
          imagePath: _draftImagePath,
          createdAt: _draftCreatedAt,
        ),
      );
      if (mounted && _status == _Status.draftFailed) {
        setState(() => _status = _Status.none);
      }
    } catch (e) {
      debugPrint('❌ [RECIPE_EDITOR] Draft not saved: $e');
      if (mounted) setState(() => _status = _Status.draftFailed);
    }
  }

  // ------------------------------------------------------------ validation

  bool get _needsAuthorName =>
      !_editing && ref.read(recipeEditorAuthorNameProvider) == null;

  List<RecipeEditorIssue> _currentIssues(int step) => _form.issuesFor(
    step,
    languageCode: _lang,
    needsAuthorName: step == 3 && _needsAuthorName,
  );

  String? _messageFor(RecipeEditorIssue issue) =>
      _shown.contains(issue) ? context.tr(issue.messageKey) : null;

  void _focusIssue(RecipeEditorIssue issue) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (issue) {
        case RecipeEditorIssue.name:
          _form.nameFocus.requestFocus();
        case RecipeEditorIssue.ingredients:
          _form.ingredients.first.focus.requestFocus();
        case RecipeEditorIssue.steps:
          _form.steps.first.focus.requestFocus();
        case RecipeEditorIssue.authorName:
          FocusScope.of(context).unfocus();
      }
    });
  }

  /// Shows what blocks [steps]; returns false when something does.
  bool _check(Iterable<int> steps) {
    final issues = [for (final s in steps) ..._currentIssues(s)];
    if (issues.isEmpty) return true;
    unawaited(AvoHaptics.error());
    setState(() {
      _shown
        ..clear()
        ..addAll(issues);
    });
    final first = issues.first;
    if (first.step != _step) _goTo(first.step);
    _focusIssue(first);
    return false;
  }

  // ------------------------------------------------------------ navigation

  void _goTo(int step) {
    final target = step.clamp(0, kEditorStepCount - 1);
    if (target == _step) return;
    FocusScope.of(context).unfocus();
    setState(() => _step = target);
    if (context.reduceMotion || !_pages.hasClients) return;
    final position = _pages.position;
    final to = target * position.viewportDimension;
    _springing = true;
    _pageSpring.value = position.pixels;
    // Completes only when it lands (an interrupted spring never does).
    _pageSpring
        .animateWith(
          SpringSimulation(
            AvoMotion.standard,
            position.pixels,
            to,
            0,
            tolerance: _pageTolerance,
            snapToEnd: true,
          ),
        )
        .then((_) {
          _springing = false;
          if (mounted && _pages.hasClients) _pages.jumpTo(to);
        });
  }

  void _next() {
    if (_step < kEditorStepCount - 1) {
      if (_check([_step])) _goTo(_step + 1);
      return;
    }
    unawaited(_publish());
  }

  void _back() => _goTo(_step - 1);

  Future<void> _openStepMenu(BuildContext anchor) => showAvoMenu(
    anchor,
    semanticLabel: context.tr('recipe_editor_switch_step'),
    items: [
      for (var i = 0; i < kEditorStepCount; i++)
        AvoMenuItem(
          label: _stepTitle(i),
          checked: i == _step,
          subtitle: _form.stepComplete(i, languageCode: _lang)
              ? null
              : context.tr('recipe_editor_step_incomplete'),
          onSelected: () => _goTo(i),
        ),
    ],
  );

  // --------------------------------------------------------------- actions

  Future<void> _close() async {
    if (_publishing) return;
    final navigator = Navigator.of(context);
    if (_editing) {
      final dirty = _baseline != null && _form.signature() != _baseline;
      if (dirty) {
        final discard = await showAvoConfirm(
          context,
          title: context.tr('recipe_editor_discard_changes_title'),
          message: context.tr('recipe_editor_discard_changes_message'),
          confirmLabel: context.tr('recipe_editor_discard'),
          cancelLabel: context.tr('common_keep_editing'),
        );
        if (!discard || !mounted) return;
      }
      navigator.pop();
      return;
    }
    final hadContent = _form.hasContent;
    await _saveDraft();
    if (!mounted) return;
    if (hadContent && _status != _Status.draftFailed) {
      AvoToast.show(context, message: context.tr('recipe_editor_saved_draft'));
    }
    navigator.pop();
  }

  Future<void> _discard() async {
    final discard = await showAvoConfirm(
      context,
      title: context.tr(
        _editing
            ? 'recipe_editor_discard_changes_title'
            : 'recipe_editor_discard_title',
      ),
      message: context.tr(
        _editing
            ? 'recipe_editor_discard_changes_message'
            : 'recipe_editor_discard_message',
      ),
      confirmLabel: context.tr('recipe_editor_discard'),
    );
    if (!discard || !mounted) return;
    _discarded = true;
    _saveTimer?.cancel();
    final navigator = Navigator.of(context);
    final id = _draftId;
    if (id != null) {
      final running = _saving;
      if (running != null) await running;
      final drafts = ref.read(recipeEditorDraftsProvider);
      await drafts.delete(id);
      await drafts.deletePhoto(_draftImagePath);
    }
    navigator.pop();
  }

  Future<void> _pickPhoto(RecipePhotoSource source) async {
    try {
      final file = await ref.read(recipeEditorPhotoPickerProvider)(source);
      if (file != null && mounted) _form.setPhoto(file);
    } catch (e) {
      debugPrint('❌ [RECIPE_EDITOR] Photo not picked: $e');
      if (mounted) {
        AvoToast.show(
          context,
          message: context.tr('recipe_editor_photo_failed'),
        );
      }
    }
  }

  void _removePhoto() {
    final undo = _form.removePhoto();
    AvoToast.show(
      context,
      message: context.tr('recipe_editor_photo_removed'),
      actionLabel: context.tr('common_undo'),
      onAction: undo,
    );
  }

  Future<void> _openPhotoMenu(BuildContext anchor) => showAvoMenu(
    anchor,
    items: [
      AvoMenuItem(
        label: context.tr(
          _form.hasPhoto
              ? 'recipe_editor_photo_retake'
              : 'recipe_editor_photo_camera',
        ),
        onSelected: () => unawaited(_pickPhoto(RecipePhotoSource.camera)),
      ),
      AvoMenuItem(
        label: context.tr(
          _form.hasPhoto
              ? 'recipe_editor_photo_replace'
              : 'recipe_editor_photo_library',
        ),
        onSelected: () => unawaited(_pickPhoto(RecipePhotoSource.library)),
      ),
      if (_form.hasPhoto) ...[
        const AvoMenuDivider(),
        AvoMenuItem(
          label: context.tr('recipe_editor_photo_remove'),
          icon: AvoIcons.trash,
          destructive: true,
          onSelected: _removePhoto,
        ),
      ],
    ],
  );

  void _focusLater(RecipeEditorLine line) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) line.focus.requestFocus();
    });
  }

  void _ingredientSubmitted(RecipeEditorLine line) {
    final lines = _form.ingredients;
    final isLast = lines.last == line;
    if (line.text.trim().isEmpty && isLast) {
      FocusScope.of(context).unfocus();
      return;
    }
    _focusLater(_form.insertLine(lines, after: line));
  }

  void _ingredientChanged(RecipeEditorLine line) {
    if (!line.text.contains('\n')) return;
    _focusLater(_form.splitPastedIngredient(line));
  }

  void _deleteLine(List<RecipeEditorLine> lines, RecipeEditorLine line) {
    final text = line.text.trim();
    final lang = _lang;
    final undo = _form.removeLine(lines, line);
    if (text.isEmpty) return;
    final parsed = identical(lines, _form.ingredients)
        ? parseIngredientLine(text, lang)
        : null;
    final label = parsed != null && parsed.hasName
        ? context.tr('recipe_editor_removed', params: {'name': parsed.name})
        : context.tr('recipe_editor_removed_step');
    AvoToast.show(
      context,
      message: label,
      actionLabel: context.tr('common_undo'),
      onAction: undo,
    );
  }

  Future<void> _publish() async {
    if (_publishing) return;
    if (!_check(List.generate(kEditorStepCount, (i) => i))) return;
    if (ref.read(isOfflineProvider)) {
      unawaited(AvoHaptics.error());
      setState(() => _status = _Status.offline);
      unawaited(_saveDraft());
      return;
    }
    FocusScope.of(context).unfocus();
    _saveTimer?.cancel();
    setState(() {
      _publishing = true;
      _status = _Status.none;
    });
    final backend = ref.read(recipeEditorBackendProvider);
    final drafts = ref.read(recipeEditorDraftsProvider);
    final lang = _lang;
    try {
      final photo = _form.photo;
      final imageUrl = photo != null
          ? await backend.uploadPhoto(photo)
          : (_form.photoUrl ?? '');
      final base = _original;
      final recipe = Recipe(
        id: _editingId ?? '',
        name: _form.name.text.trim(),
        description: _form.description.text.trim(),
        imageUrl: imageUrl,
        prepTimeMinutes: _form.prepMinutes,
        cookTimeMinutes: _form.cookMinutes,
        defaultServings: _form.servings,
        ingredients: _form.toIngredients(lang),
        instructions: _form.stepTexts,
        authorId: base?.authorId ?? '',
        authorName: base?.authorName ?? '',
        createdAt: base?.createdAt ?? DateTime.now(),
      );
      final String recipeId;
      if (_editing) {
        await backend.update(recipe);
        recipeId = recipe.id;
      } else {
        recipeId = await backend.create(recipe, difficulty: _form.difficulty);
      }
      final draftId = _draftId;
      if (draftId != null) {
        _discarded = true;
        final running = _saving;
        if (running != null) await running;
        await drafts.delete(draftId);
        await drafts.deletePhoto(_draftImagePath);
      }
      if (!mounted) return;
      refreshRecipeData(ref);
      unawaited(AvoHaptics.success());
      AvoToast.show(
        context,
        message: context.tr(
          _editing ? 'recipe_editor_saved_changes' : 'recipe_editor_published',
        ),
      );
      final router = GoRouter.maybeOf(context);
      if (_editing) {
        Navigator.of(context).pop(true);
      } else if (router != null) {
        router.pushReplacement(RoutePaths.recipe(recipeId));
      } else {
        Navigator.of(context).pop(recipeId);
      }
    } catch (e) {
      debugPrint('❌ [RECIPE_EDITOR] Publishing failed: $e');
      if (!mounted) return;
      unawaited(AvoHaptics.error());
      setState(() {
        _publishing = false;
        _status = _Status.publishFailed;
      });
      if (!_editing) unawaited(_saveDraft());
    }
  }

  // ----------------------------------------------------------------- build

  String _stepTitle(int step) => context.tr(switch (step) {
    0 => 'recipe_editor_step_photo',
    1 => 'recipe_editor_step_times',
    2 => 'recipe_editor_step_ingredients',
    _ => 'recipe_editor_step_preparation',
  });

  String _subtitle(int step) {
    final mode = context.tr(
      _editing ? 'recipe_editor_mode_edit' : 'recipe_editor_mode_new',
    );
    final where = context.tr(
      'recipe_editor_step_of',
      params: {'n': '${step + 1}', 'total': '$kEditorStepCount'},
    );
    return '$mode · $where';
  }

  String _nextLabel() {
    if (_step < kEditorStepCount - 1) return context.tr('recipe_editor_next');
    return context.tr(
      _editing ? 'recipe_editor_save_changes' : 'recipe_editor_publish',
    );
  }

  Widget? _statusRow() {
    return switch (_status) {
      _Status.none => null,
      _Status.offline => StatusRow(
        kind: StatusKind.offline,
        text: context.tr('recipe_editor_offline'),
      ),
      _Status.publishFailed => StatusRow(
        kind: StatusKind.failed,
        text: context.tr(
          _editing
              ? 'recipe_editor_save_failed'
              : 'recipe_editor_publish_failed',
        ),
        actionLabel: context.tr('common_try_again'),
        onAction: () => unawaited(_publish()),
      ),
      _Status.draftFailed => StatusRow(
        kind: StatusKind.failed,
        text: context.tr('recipe_editor_draft_failed'),
        actionLabel: context.tr('common_try_again'),
        onAction: () => unawaited(_saveDraft()),
      ),
      _Status.loadFailed => StatusRow(
        kind: StatusKind.sectionError,
        text: context.tr('recipe_editor_load_failed'),
        actionLabel: context.tr('common_try_again'),
        onAction: () => unawaited(_loadRecipe(widget.recipeId!)),
      ),
    };
  }

  Widget _stepBody(int step) {
    switch (step) {
      case 0:
        return RecipeEditorPhotoNameStep(
          form: _form,
          onPhotoTap: (anchor) => unawaited(_openPhotoMenu(anchor)),
          nameError: _messageFor(RecipeEditorIssue.name),
        );
      case 1:
        return RecipeEditorTimesStep(form: _form);
      case 2:
        return RecipeEditorIngredientsStep(
          form: _form,
          onSubmitted: _ingredientSubmitted,
          onChanged: _ingredientChanged,
          onDelete: (line) => _deleteLine(_form.ingredients, line),
          onAdd: () => _focusLater(_form.insertLine(_form.ingredients)),
          error: _messageFor(RecipeEditorIssue.ingredients),
        );
      default:
        return RecipeEditorInstructionsStep(
          form: _form,
          onDelete: (line) => _deleteLine(_form.steps, line),
          onAdd: () => _focusLater(_form.insertLine(_form.steps)),
          authorName: _authorName,
          onSetName: () => unawaited(context.push(RoutePaths.profile)),
          stepsError: _messageFor(RecipeEditorIssue.steps),
          authorError: _messageFor(RecipeEditorIssue.authorName),
        );
    }
  }

  Widget _page(BuildContext context, int step) => RecipeEditorStepPage(
    title: _stepTitle(step),
    subtitle: _subtitle(step),
    onTitleTap: (anchor) => unawaited(_openStepMenu(anchor)),
    child: _stepBody(step),
  );

  Widget _body(BuildContext context) {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.only(top: AvoSpacing.l),
        children: const [SkeletonSection(rows: 4, withImage: false)],
      );
    }
    if (_status == _Status.loadFailed) return const SizedBox.expand();
    if (context.reduceMotion) {
      return AnimatedSwitcher(
        duration: AvoMotion.fadeReduced,
        child: KeyedSubtree(key: ValueKey(_step), child: _page(context, _step)),
      );
    }
    if (!_pages.hasClients && _pages.initialPage != _step) {
      final old = _pages;
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      _pages = PageController(initialPage: _step);
    }
    return PageView.builder(
      controller: _pages,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: kEditorStepCount,
      onPageChanged: (page) {
        if (!_springing && page != _step) setState(() => _step = page);
      },
      itemBuilder: _page,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watched here, not in the page builder (which runs during layout).
    _authorName = ref.watch(recipeEditorAuthorNameProvider);
    final blocked = _loading || _status == _Status.loadFailed;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_step > 0) {
          _back();
        } else {
          unawaited(_close());
        }
      },
      child: RecipeEditorFrame(
        step: _step,
        stepCount: kEditorStepCount,
        onClose: () => unawaited(_close()),
        nextLabel: _nextLabel(),
        onNext: blocked ? null : _next,
        working: _publishing,
        status: _statusRow(),
        onSwipeBack: _step > 0 && !blocked ? _back : null,
        menuItems: [
          if (!blocked)
            AvoMenuItem(
              label: context.tr(
                _editing
                    ? 'recipe_editor_discard_changes'
                    : 'recipe_editor_discard_draft',
              ),
              icon: AvoIcons.trash,
              destructive: true,
              enabled: _editing || _form.hasContent || _draftId != null,
              onSelected: () => unawaited(_discard()),
            ),
        ],
        body: _body(context),
      ),
    );
  }
}
