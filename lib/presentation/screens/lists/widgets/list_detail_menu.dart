import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shoply/core/localization/localization_helper.dart';

enum ListDetailMenuAction { rename, categoryOrder, settings }

class _MenuEntry {
  final ListDetailMenuAction action;
  final String labelKey;
  final String sfSymbol;
  final IconData icon;

  const _MenuEntry(this.action, this.labelKey, this.sfSymbol, this.icon);
}

const _entries = [
  _MenuEntry(
    ListDetailMenuAction.rename,
    'rename_list',
    'pencil',
    CupertinoIcons.pencil,
  ),
  _MenuEntry(
    ListDetailMenuAction.categoryOrder,
    'category_order',
    'arrow.up.arrow.down',
    CupertinoIcons.arrow_up_arrow_down,
  ),
  _MenuEntry(
    ListDetailMenuAction.settings,
    'list_settings',
    'gearshape',
    CupertinoIcons.gear,
  ),
];

/// The "…" menu of the list detail app bar: a native glass popup on iOS 26,
/// a Cupertino action sheet elsewhere.
class ListDetailMenuButton extends StatefulWidget {
  final ValueChanged<ListDetailMenuAction> onSelected;

  const ListDetailMenuButton({super.key, required this.onSelected});

  @override
  State<ListDetailMenuButton> createState() => _ListDetailMenuButtonState();
}

class _ListDetailMenuButtonState extends State<ListDetailMenuButton> {
  // Bumped after each selection to force the native popup to rebuild after
  // navigation.
  int _popupKeyCounter = 0;

  void _showActionSheet() {
    HapticFeedback.selectionClick();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          for (final entry in _entries)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                widget.onSelected(entry.action);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(entry.icon, size: 20),
                  const SizedBox(width: 10),
                  Text(context.tr(entry.labelKey)),
                ],
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.tr('cancel')),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformInfo.isIOS26OrHigher()) {
      return IconButton(
        icon: Icon(
          Icons.more_horiz_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        onPressed: _showActionSheet,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AdaptivePopupMenuButton.icon<ListDetailMenuAction>(
        key: ValueKey('settings_popup_$_popupKeyCounter'),
        icon: 'ellipsis.circle',
        // Messages-metric: 40pt glass circle.
        size: 40,
        buttonStyle: PopupButtonStyle.glass,
        items: [
          for (final entry in _entries)
            AdaptivePopupMenuItem<ListDetailMenuAction>(
              label: context.tr(entry.labelKey),
              icon: entry.sfSymbol,
              value: entry.action,
            ),
        ],
        onSelected: (index, entry) {
          setState(() => _popupKeyCounter++);
          final action = entry.value;
          if (action != null) widget.onSelected(action);
        },
      ),
    );
  }
}
