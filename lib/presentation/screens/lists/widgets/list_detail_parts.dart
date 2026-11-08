import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/presentation/widgets/design/avatar.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/check_circle.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';
import 'package:shoply/presentation/widgets/design/progress.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

// Building blocks of the list screen (D2-Liste): toolbar, header, the
// "Erledigt" section and the rename alert.

/// Title to meta line (D2 margin-top 6).
const double _metaTop = 6; // D2

/// Meta line to progress bar (D2 margin-top 12).
const double _progressTop = AvoSpacing.m; // D2

/// Chevron of the "Erledigt" heading (D2 12 pt, stroke 1.8).
const double _chevronSize = 12; // D2

/// Gap between count and chevron in the "Erledigt" heading (D2 gap 6).
const double _chevronGap = 6; // D2

/// Collapsed "Erledigt" row (D2 min-height 56, padding 10 16).
const double _summaryMinHeight = 56; // D2
const double _summaryVertical = 10; // D2

/// Lines of the collapsed "Erledigt" row before it ends in "…".
const int _summaryLines = 1;
const int _summaryLinesAx = 3;

/// The floating top row of the list (D2-Liste toolbar): back on the left;
/// on the right one glass group with "Teilen" and "Mehr", then the tinted
/// cart that starts shopping mode while open items exist (owner 07.11.2026).
class ListDetailToolbar extends StatelessWidget {
  const ListDetailToolbar({
    super.key,
    required this.onBack,
    required this.onShare,
    required this.onMore,
    required this.moreKey,
    this.onShop,
    this.title,
  });

  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onMore;

  /// On the "Mehr" glyph, so the menu grows out of it.
  final GlobalKey moreKey;

  /// Starts shopping mode; null hides the cart (no open items).
  final VoidCallback? onShop;

  /// Inline title once the large title has scrolled away.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final shop = onShop;
    return GlassToolbar(
      leading: GlassIconButton(
        icon: const AvoIcon(AvoIcons.chevronBack),
        semanticLabel: context.tr('back'),
        onPressed: onBack,
      ),
      title: title,
      trailing: [
        GlassButtonGroup(
          items: [
            GlassGroupItem(
              icon: const AvoIcon(AvoIcons.people),
              semanticLabel: context.tr('list_detail_share'),
              onPressed: onShare,
            ),
            GlassGroupItem(
              icon: KeyedSubtree(
                key: moreKey,
                child: const AvoIcon(AvoIcons.more),
              ),
              semanticLabel: context.tr('common_more'),
              onPressed: onMore,
            ),
          ],
        ),
        if (shop != null)
          GlassIconButton(
            icon: AvoIcon(AvoIcons.cart, color: context.colors.onTint),
            semanticLabel: context.tr('list_detail_shop'),
            tinted: true,
            onPressed: shop,
          ),
      ],
    );
  }
}

/// Large title, meta line and progress of the list (D2-Liste header,
/// Konzept 11 §1.1 items 2–3, §11.1).
///
/// The meta line wraps: the other members as an avatar stack with "8 von
/// 12" (one target that opens "Liste teilen"), then Teil B's market chip (it renders nothing until B fills
/// it, so it sits last and leaves no gap). The title wraps to two lines,
/// then ends in "…".
class ListDetailHeader extends StatelessWidget {
  const ListDetailHeader({
    super.key,
    required this.listId,
    required this.title,
    required this.total,
    required this.done,
    this.members = const [],
    this.onMembersTap,
  });

  final String listId;
  final String title;

  /// All items and the checked ones.
  final int total;
  final int done;

  /// Names of the other members (without the signed-in person).
  final List<String> members;
  final VoidCallback? onMembersTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final progress = context.tr(
      'common_progress',
      params: {'done': '$done', 'total': '$total'},
    );
    final names = members.join(', ');
    final progressText = total > 0
        ? Text(
            progress,
            style: context.text(
              AvoTextStyle.subhead,
              color: colors.secondaryLabel,
              tabular: true,
            ),
          )
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text(AvoTextStyle.largeTitle),
            ),
          ),
          const SizedBox(height: _metaTop),
          Wrap(
            spacing: AvoSpacing.s,
            runSpacing: AvoSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (members.isNotEmpty)
                // Avatars and progress are one target (at least 44 pt) that
                // opens "Liste teilen".
                Semantics(
                  button: onMembersTap != null,
                  label: context.tr(
                    'common_shared_with',
                    params: {'names': names},
                  ),
                  excludeSemantics: true,
                  onTap: onMembersTap,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onMembersTap,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: AvoSizes.hitTarget,
                        minHeight: AvoSizes.hitTarget,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AvatarStack(
                            names: members,
                            ringColor: colors.background,
                          ),
                          if (progressText != null) ...[
                            const SizedBox(width: AvoSpacing.s),
                            Flexible(child: progressText),
                          ],
                        ],
                      ),
                    ),
                  ),
                )
              else if (progressText != null)
                progressText,
              StoreChip(listId: listId),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: _progressTop),
            ProgressLine(
              value: done / total,
              semanticLabel: context.tr('list_detail_progress'),
              semanticValue: progress,
            ),
          ],
        ],
      ),
    );
  }
}

/// The "Erledigt" section at the end of the list (D2-Liste, Konzept 11 §1.1
/// item 10): collapsed by default to one row with the names struck
/// through; the heading or that row expands it to the checked rows.
class ListDoneSection extends StatelessWidget {
  const ListDoneSection({
    super.key,
    required this.items,
    required this.expanded,
    required this.onExpandedChanged,
    required this.rowBuilder,
    this.withThumbs = true,
  });

  /// The checked items, newest first.
  final List<ShoppingItemModel> items;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  /// Builds the row of one checked item (a `ListItemTile`).
  final Widget Function(ShoppingItemModel item) rowBuilder;

  /// Whether the rows show pictures (for the hairline inset).
  final bool withThumbs;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    final title = context.tr('list_detail_done');
    final count = items.length;
    void toggle() => onExpandedChanged(!expanded);

    final heading = Semantics(
      button: true,
      expanded: expanded,
      label: '$title, $count',
      excludeSemantics: true,
      onTap: toggle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: toggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
          child: SectionCaps(
            title,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$count'),
                const SizedBox(width: _chevronGap),
                AvoIcon(
                  expanded ? AvoIcons.chevronDown : AvoIcons.chevronRight,
                  size: _chevronSize,
                  color: colors.secondaryLabel,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final Widget body;
    if (expanded) {
      body = InsetSection(
        separatorIndent: ItemRow.separatorIndentOf(
          context,
          withThumb: withThumbs,
        ),
        children: [for (final item in items) rowBuilder(item)],
      );
    } else {
      body = InsetSection(
        children: [
          _DoneSummaryRow(
            names: [for (final item in items) item.name],
            onTap: toggle,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [heading, body],
    );
  }
}

/// "Nudeln, Olivenöl, Eier, Kaffee" behind a filled circle, struck through
/// (D2-Liste, collapsed "Erledigt").
class _DoneSummaryRow extends StatelessWidget {
  const _DoneSummaryRow({required this.names, required this.onTap});

  final List<String> names;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = names.join(', ');
    final ax = context.isAccessibilityText;
    final style = context
        .text(AvoTextStyle.body, color: colors.secondaryLabel)
        .copyWith(
          decoration: TextDecoration.lineThrough,
          decorationColor: colors.secondaryLabel,
        );
    return Semantics(
      button: true,
      label: context.tr(
        'list_detail_done_summary',
        params: {'count': '${names.length}', 'names': text},
      ),
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _summaryMinHeight),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AvoSpacing.l - (AvoSizes.hitTarget - AvoSizes.checkCircle) / 2,
              _summaryVertical,
              AvoSpacing.l,
              _summaryVertical,
            ),
            child: Row(
              crossAxisAlignment: ax
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                // Decorative: the row is the button, the circle only shows
                // that these are done.
                IgnorePointer(
                  child: CheckCircle(
                    checked: true,
                    itemName: text,
                    onChanged: (_) {},
                  ),
                ),
                const SizedBox(
                  width:
                      AvoSpacing.m -
                      (AvoSizes.hitTarget - AvoSizes.checkCircle) / 2,
                ),
                Expanded(
                  child: Text(
                    text,
                    maxLines: ax ? _summaryLinesAx : _summaryLines,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Renames the list: a centred alert with one text field (Konzept 00
/// §12.34; no sheet). Pops with the trimmed name, or null on cancel.
class RenameListDialog extends StatefulWidget {
  const RenameListDialog({super.key, required this.initialName});

  final String initialName;

  @override
  State<RenameListDialog> createState() => _RenameListDialogState();
}

class _RenameListDialogState extends State<RenameListDialog> {
  late final _controller = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CupertinoTheme(
      data: CupertinoTheme.of(context).copyWith(
        primaryColor: colors.tint,
        brightness: Theme.of(context).brightness,
      ),
      child: CupertinoAlertDialog(
        title: Text(context.tr('rename_list_title')),
        content: Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.m),
          child: CupertinoTextField(
            controller: _controller,
            autofocus: true,
            placeholder: context.tr('list_name'),
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            style: context.text(AvoTextStyle.body),
            cursorColor: colors.tint,
            padding: const EdgeInsets.all(AvoSpacing.m),
            decoration: BoxDecoration(
              color: colors.fill,
              borderRadius: BorderRadius.circular(AvoRadii.imageSmall),
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel')),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: _save,
            child: Text(context.tr('save')),
          ),
        ],
      ),
    );
  }
}
