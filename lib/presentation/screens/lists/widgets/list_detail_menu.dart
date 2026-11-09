import 'package:flutter/widgets.dart';

import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';

/// What the "Mehr" menu of the list can do (Konzept 11 §1.3).
enum ListDetailMenuAction {
  shop,
  checkout,
  share,
  info,
  rename,
  storeOrder,
  offers,
  toggleOffers,
  importNote,
  delete,
  leave,
}

/// The rows of the "Mehr" menu, in groups. Entries without meaning are left
/// out rather than dimmed (Konzept 11 §1.3): "Einkaufen" only with open
/// items, "Einkauf abschließen" only with done ones, the offers entry only
/// with the offers module ("Angebote dieser Liste" only while they show),
/// delete for the creator and leave for members.
List<AvoMenuEntry> listDetailMenuEntries(
  BuildContext context, {
  required bool hasOpen,
  required bool hasDone,
  required bool offersAvailable,
  required bool offersHidden,
  required bool? isOwner,
  required ValueChanged<ListDetailMenuAction> onSelected,
}) {
  AvoMenuItem item(
    ListDetailMenuAction action,
    String key, {
    AvoIconData? icon,
    bool destructive = false,
  }) => AvoMenuItem(
    label: context.tr(key),
    icon: icon,
    destructive: destructive,
    onSelected: () => onSelected(action),
  );

  return [
    if (hasOpen)
      item(
        ListDetailMenuAction.shop,
        'list_detail_menu_shop',
        icon: AvoIcons.cart,
      ),
    if (hasDone)
      item(
        ListDetailMenuAction.checkout,
        'list_detail_menu_checkout',
        icon: AvoIcons.check,
      ),
    const AvoMenuDivider(),
    item(
      ListDetailMenuAction.share,
      'list_detail_share',
      icon: AvoIcons.people,
    ),
    item(ListDetailMenuAction.info, 'list_detail_menu_info'),
    item(ListDetailMenuAction.rename, 'list_detail_menu_rename'),
    item(ListDetailMenuAction.storeOrder, 'list_detail_menu_order'),
    if (offersAvailable) ...[
      const AvoMenuDivider(),
      if (!offersHidden)
        item(
          ListDetailMenuAction.offers,
          'list_detail_menu_offers',
          icon: AvoIcons.tag,
        ),
      item(
        ListDetailMenuAction.toggleOffers,
        offersHidden
            ? 'list_detail_menu_show_offers'
            : 'list_detail_menu_hide_offers',
      ),
    ],
    const AvoMenuDivider(),
    item(ListDetailMenuAction.importNote, 'list_detail_menu_import'),
    if (isOwner != null) ...[
      const AvoMenuDivider(),
      if (isOwner)
        item(
          ListDetailMenuAction.delete,
          'list_detail_menu_delete',
          icon: AvoIcons.trash,
          destructive: true,
        )
      else
        item(
          ListDetailMenuAction.leave,
          'list_detail_menu_leave',
          destructive: true,
        ),
    ],
  ];
}
