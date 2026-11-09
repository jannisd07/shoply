import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';

/// Native destructive confirmation ("Delete X?" with Cancel / [confirmLabel]).
/// Resolves to true only when the destructive action was tapped.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  double? iconSize,
}) async {
  var confirmed = false;
  await AdaptiveAlertDialog.show(
    context: context,
    title: title,
    message: message,
    icon: PlatformInfo.isIOS26OrHigher()
        ? 'trash.fill'
        : Icons.delete, // design-check: ok Android-Fallback des nativen Alerts
    iconSize: iconSize,
    iconColor: context.colors.destructive,
    actions: [
      AlertAction(
        title: context.tr('cancel'),
        style: AlertActionStyle.cancel,
        onPressed: () {},
      ),
      AlertAction(
        title: confirmLabel,
        style: AlertActionStyle.destructive,
        onPressed: () => confirmed = true,
      ),
    ],
  );
  return confirmed;
}
