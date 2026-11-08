import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/routes/route_paths.dart';

/// Root of the "Listen" tab (D2-Home): every list of the user.
///
/// Version 0 from S2: title, count line, one row per list, "New list" in the
/// top-right corner. The full D2 screen (large card, quick re-add, shared
/// avatars, offers badge) follows in A5.
class AllListsScreen extends ConsumerWidget {
  const AllListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(listsNotifierProvider);
    final colors = context.colors;
    final topInset = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: colors.background,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AvoSpacing.screen,
              topInset + AvoSizes.toolbarButton + AvoSpacing.m,
              AvoSpacing.screen,
              AvoSpacing.m,
            ),
            sliver: SliverToBoxAdapter(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        context.tr('common_tab_lists'),
                        style: context.text(AvoTextStyle.largeTitle),
                      ),
                    ),
                  ),
                  AvoMenuButton(
                    floating: false,
                    items: [
                      AvoMenuItem(
                        label: context.tr('join_list'),
                        icon: AvoIcons.people,
                        onSelected: () => _joinList(context, ref),
                      ),
                    ],
                  ),
                  _NewListButton(onTap: () => _createList(context, ref)),
                ],
              ),
            ),
          ),
          ...lists.when(
            data: (items) => [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AvoSpacing.screen,
                  0,
                  AvoSpacing.screen,
                  ShellInsets.bottom(context),
                ),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AvoSpacing.m),
                  itemBuilder: (context, i) => _ListTile(list: items[i]),
                ),
              ),
            ],
            loading: () => const [
              SliverToBoxAdapter(child: SizedBox.shrink()),
            ],
            error: (_, _) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AvoSpacing.screen),
                  child: Text(
                    context.tr('common_section_error'),
                    style: context.text(AvoTextStyle.subhead,
                        color: colors.secondaryLabel),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _createList(BuildContext context, WidgetRef ref) async {
    final name = await AdaptiveAlertDialog.inputShow(
      context: context,
      title: context.tr('create_new_list'),
      message: context.tr('enter_list_name_prompt'),
      icon: PlatformInfo.isIOS26OrHigher() ? 'list.bullet.circle.fill' : null,
      input: AdaptiveAlertDialogInput(
        placeholder: context.tr('enter_list_name'),
        initialValue: '',
        keyboardType: TextInputType.text,
      ),
      actions: [
        AlertAction(
          title: context.tr('cancel'),
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: context.tr('create'),
          style: AlertActionStyle.primary,
          onPressed: () {},
        ),
      ],
    );
    if (name == null || name.trim().isEmpty) return;
    final list =
        await ref.read(listsNotifierProvider.notifier).createList(name.trim());
    if (context.mounted) {
      context.push(RoutePaths.list(list.id, name: list.name));
    }
  }
}

/// "Liste beitreten" with a share code (moved here from the old Home).
Future<void> _joinList(BuildContext context, WidgetRef ref) async {
  final code = await AdaptiveAlertDialog.inputShow(
    context: context,
    title: context.tr('join_list'),
    message: context.tr('enter_share_code'),
    icon: PlatformInfo.isIOS26OrHigher() ? 'person.2.fill' : null,
    input: AdaptiveAlertDialogInput(
      placeholder: context.tr('share_code'),
      initialValue: '',
      keyboardType: TextInputType.text,
    ),
    actions: [
      AlertAction(
        title: context.tr('cancel'),
        style: AlertActionStyle.cancel,
        onPressed: () {},
      ),
      AlertAction(
        title: context.tr('join'),
        style: AlertActionStyle.primary,
        onPressed: () {},
      ),
    ],
  );
  if (code == null || code.trim().isEmpty || !context.mounted) return;

  String? message;
  try {
    final list = await ref
        .read(listsNotifierProvider.notifier)
        .joinListWithCode(code.trim().toUpperCase());
    if (!context.mounted) return;
    if (list != null) {
      context.push(RoutePaths.list(list.id, name: list.name));
      return;
    }
    message = context.tr('invalid_share_code');
  } catch (_) {
    if (!context.mounted) return;
    message = context.tr('join_error');
  }
  await AdaptiveAlertDialog.show(
    context: context,
    title: context.tr('join_list'),
    message: message,
    actions: [
      AlertAction(
        title: context.tr('ok'),
        style: AlertActionStyle.primary,
        onPressed: () {},
      ),
    ],
  );
}

class _NewListButton extends StatelessWidget {
  const _NewListButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: context.tr('create_new_list'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: AvoSizes.hitTarget,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.tintFill,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AvoSpacing.s + 2),
                child: Icon(CupertinoIcons.add, color: colors.onTint, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ListTile extends StatelessWidget {
  const _ListTile({required this.list});

  final ShoppingListModel list;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final total = list.itemCount ?? 0;
    final open = list.uncheckedCount ?? 0;
    final meta = context.tr('items_left', params: {'n': '$open'});
    return Semantics(
      button: true,
      label: '${list.name}, $meta',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push(RoutePaths.list(list.id, name: list.name)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AvoRadii.group),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AvoSpacing.l,
                vertical: AvoSpacing.m,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(list.name,
                            style: context.text(AvoTextStyle.headline)),
                        Text(
                          total == 0 ? context.tr('list_empty_label') : meta,
                          style: context.text(AvoTextStyle.subhead,
                              color: colors.secondaryLabel),
                        ),
                      ],
                    ),
                  ),
                  Icon(CupertinoIcons.chevron_right,
                      size: 14, color: colors.secondaryLabel),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
