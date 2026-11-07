import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';

/// Asks a yes/no question in a centred iOS alert before something final
/// happens (Konzept 00 §12.34). Resolves to true when [confirmLabel] was
/// chosen, false on cancel.
///
/// Only for actions that cannot be undone: delete or leave a list, remove a
/// member, delete a recipe, discard a draft, delete a category or a trip,
/// cancel a challenge, delete the account, sign out with unsent changes.
/// Never for deleting or checking off items, leaving a mode or closing
/// without changes: those get an undo toast instead.
///
/// The cancel button is the bold default action (left), the confirm button
/// is red when [destructive] (right). [cancelLabel] defaults to the existing
/// `cancel` text. The alert cannot be dismissed by tapping outside.
Future<bool> showAvoConfirm(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = true,
}) async {
  final result = await showCupertinoDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final colors = dialogContext.colors;
      final text = message;
      return CupertinoTheme(
        data: CupertinoTheme.of(dialogContext).copyWith(
          primaryColor: colors.tint,
          brightness: Theme.of(dialogContext).brightness,
        ),
        child: CupertinoAlertDialog(
          title: Text(title),
          content: text == null ? null : Text(text),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(cancelLabel ?? dialogContext.tr('cancel')),
            ),
            CupertinoDialogAction(
              isDestructiveAction: destructive,
              // The Cupertino red is a fixed system colour; use the token so
              // dark mode and Increase Contrast match the rest of the app.
              textStyle: destructive
                  ? TextStyle(color: colors.destructive)
                  : null,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      );
    },
  );
  return result ?? false;
}
