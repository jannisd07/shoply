import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';

/// Tells the user that a module is switched off when they reach one of its
/// routes or actions, and offers to switch it on (Konzept 00 §13
/// "Modul aus", digest 3): a centred alert with `common_module_off_title`,
/// `common_module_off_body` and the buttons `common_not_now` and
/// `common_module_turn_on` (bold default).
///
/// "Turn on" closes the alert at once, then awaits [onEnable] and resolves to
/// true, so the caller can continue to the target. "Not now" resolves to
/// false. An error thrown by [onEnable] reaches the caller.
Future<bool> showModuleOffAlert(
  BuildContext context, {
  required String moduleName,
  required Future<void> Function() onEnable,
}) async {
  final turnOn = await showCupertinoDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return CupertinoTheme(
        data: CupertinoTheme.of(dialogContext).copyWith(
          primaryColor: dialogContext.colors.tint,
          brightness: Theme.of(dialogContext).brightness,
        ),
        child: CupertinoAlertDialog(
          title: Text(
            dialogContext.tr(
              'common_module_off_title',
              params: {'module': moduleName},
            ),
          ),
          content: Text(dialogContext.tr('common_module_off_body')),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.tr('common_not_now')),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dialogContext.tr('common_module_turn_on')),
            ),
          ],
        ),
      );
    },
  );
  if (turnOn != true) return false;
  await onEnable();
  return true;
}
