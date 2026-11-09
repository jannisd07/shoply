import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe_draft.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_data.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_mine.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_scaffold.dart';
import 'package:shoply/presentation/state/recipes_provider.dart';
import 'package:shoply/presentation/widgets/design/confirm_dialog.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

/// R-09 "Entwürfe" (Konzept 13 §11, §19.5): where did I stop writing?
///
/// Drafts come from this device (they are not synced yet). Tapping a row
/// is "Weiterschreiben"; discarding asks first, because it deletes the
/// draft and its photo for good.
class RecipeDraftsScreen extends ConsumerStatefulWidget {
  const RecipeDraftsScreen({super.key});

  @override
  ConsumerState<RecipeDraftsScreen> createState() => _RecipeDraftsScreenState();
}

class _RecipeDraftsScreenState extends ConsumerState<RecipeDraftsScreen>
    with LibraryAvoContext {
  List<RecipeDraft>? _drafts;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final drafts = await ref.read(recipeLibraryActionsProvider).drafts();
      if (mounted) {
        setState(() {
          _drafts = drafts;
          _failed = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [RECIPE_DRAFTS] Load failed: $e');
      if (mounted) {
        setState(() {
          _drafts ??= const [];
          _failed = true;
        });
      }
    }
  }

  Future<void> _continue(RecipeDraft d) async {
    await context.push(continueDraftPath(d.id), extra: {'draftId': d.id});
    if (mounted) unawaited(_load());
  }

  Future<void> _write() async {
    await context.push('/recipes/add');
    if (mounted) unawaited(_load());
  }

  Future<bool> _confirmDiscard(RecipeDraft d) => showAvoConfirm(
    context,
    title: context.tr('recipe_lib_discard_title'),
    message: context.tr(
      'recipe_lib_discard_message',
      params: {'name': draftTitle(context, d)},
    ),
    confirmLabel: context.tr('common_discard'),
  );

  Future<void> _discard(RecipeDraft d) async {
    final before = _drafts ?? const <RecipeDraft>[];
    final index = before.indexWhere((x) => x.id == d.id);
    setState(
      () => _drafts = [
        for (final x in before)
          if (x.id != d.id) x,
      ],
    );
    // Let the row leave the tree first: a swiped row that came back in the
    // same frame would still be dismissed.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final toastContext = context;
    final done = context.tr('recipe_lib_discarded');
    final failed = context.tr('action_failed');
    try {
      await ref.read(recipeLibraryActionsProvider).deleteDraft(d);
      if (toastContext.mounted) AvoToast.show(toastContext, message: done);
    } catch (e) {
      debugPrint('❌ [RECIPE_DRAFTS] Discard failed: $e');
      unawaited(AvoHaptics.error());
      if (!mounted) return;
      setState(() {
        final list = [...?_drafts];
        list.insert(index.clamp(0, list.length), d);
        _drafts = list;
      });
      if (toastContext.mounted) AvoToast.show(toastContext, message: failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    syncAvoContext(context);
    // A draft saved or published in the editor changes this list.
    ref.listen<int>(recipeRefreshTriggerProvider, (_, _) => _load());
    final drafts = _drafts;

    return RecipesLibraryPage(
      title: context.tr('recipe_lib_drafts_title'),
      onRefresh: _load,
      slivers: [
        SliverToBoxAdapter(
          child: RecipeDraftsContent(
            phase: drafts == null
                ? LibraryPhase.loading
                : _failed
                ? LibraryPhase.error
                : LibraryPhase.ready,
            drafts: drafts ?? const [],
            now: DateTime.now(),
            onContinue: _continue,
            confirmDiscard: _confirmDiscard,
            onDiscard: _discard,
            onWrite: _write,
            onRetry: _load,
          ),
        ),
      ],
    );
  }
}
