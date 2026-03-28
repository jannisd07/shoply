import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';

/// Success confirmation alert using native CupertinoAlertDialog
/// iOS 26+: automatically gets Apple's Liquid Glass design
/// Older iOS: standard Apple frosted alert
class SuccessAlert {
  static Future<void> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    String? buttonText,
    int? itemCount,
    IconData icon = CupertinoIcons.checkmark_circle_fill,
    Color? iconColor,
    VoidCallback? onConfirm,
  }) async {
    HapticFeedback.heavyImpact();

    final btn = buttonText ?? context.tr('great');
    final color = iconColor ?? AppColors.success;

    await showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CupertinoAlertDialog(
        title: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 10),
              Text(title),
            ],
          ),
        ),
        content: subtitle != null
            ? Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(subtitle),
              )
            : null,
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              HapticFeedback.lightImpact();
              onConfirm?.call();
              Navigator.of(ctx).pop();
            },
            child: Text(btn),
          ),
        ],
      ),
    );
  }

  /// Single item added
  static Future<void> showItemAdded(
    BuildContext context, {
    required String listName,
  }) {
    return show(
      context,
      title: context.tr('item_added_success'),
      subtitle: context.tr('added_to', params: {'listName': listName}),
    );
  }

  /// Multiple items added
  static Future<void> showItemsAdded(
    BuildContext context, {
    required int count,
    required String listName,
  }) {
    return show(
      context,
      title: context.tr('items_added_success', params: {'count': count.toString()}),
      subtitle: context.tr('added_to', params: {'listName': listName}),
      itemCount: count,
    );
  }
}
