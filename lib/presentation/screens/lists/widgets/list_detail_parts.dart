import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/app_localizations.dart';
import 'package:shoply/core/localization/localization_helper.dart';

// Small building blocks of the list detail screen's chrome.

class RenameListDialog extends StatefulWidget {
  final String initialName;

  const RenameListDialog({super.key, required this.initialName});

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

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text(context.tr('rename_list_title')),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CupertinoTextField(
          controller: _controller,
          autofocus: true,
          placeholder: context.tr('list_name'),
          textCapitalization: TextCapitalization.sentences,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).cancel),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(context.tr('save')),
        ),
      ],
    );
  }
}

class ListDetailBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ListDetailBackButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    if (!PlatformInfo.isIOS26OrHigher()) {
      return IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: onPressed,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Center(
        // Messages-metric nav button: 40pt glass circle inside a >=44pt hit
        // target.
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AdaptiveButton.icon(
              icon: Icons.chevron_left,
              style: AdaptiveButtonStyle.glass,
              size: AdaptiveButtonSize.small,
              minSize: const Size(40, 40),
              padding: EdgeInsets.zero,
              useSmoothRectangleBorder: false,
              onPressed: onPressed,
            ),
          ),
        ),
      ),
    );
  }
}

class ListDetailShareButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ListDetailShareButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    if (!PlatformInfo.isIOS26OrHigher()) {
      return IconButton(
        icon: Icon(
          Icons.ios_share,
          size: 22,
          color: Theme.of(context).colorScheme.primary,
        ),
        onPressed: onPressed,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      // 36pt visual inside a 44pt hit target, matching the back button.
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: AdaptiveButton.icon(
            icon: Icons.ios_share,
            style: AdaptiveButtonStyle.glass,
            size: AdaptiveButtonSize.small,
            minSize: const Size(36, 36),
            padding: EdgeInsets.zero,
            useSmoothRectangleBorder: false,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}

class ListProgressHairline extends StatelessWidget {
  final int total;
  final int done;

  const ListProgressHairline({
    super.key,
    required this.total,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? done / total : 0.0;
    return Container(
      height: 3,
      color: AppColors.divider(context),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: progress.clamp(0.0, 1.0),
        heightFactor: 1,
        child: ColoredBox(color: AppColors.accentColor(context)),
      ),
    );
  }
}

/// "Complete shopping" — Paper ink pill at the end of the list.
class CompleteShoppingButton extends StatelessWidget {
  final VoidCallback onPressed;

  const CompleteShoppingButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 24),
      child: SizedBox(
        height: 54,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? PaperColors.paper : PaperColors.ink,
            foregroundColor: isDark ? PaperColors.ink : PaperColors.paper,
            elevation: 0,
            shape: const StadiumBorder(),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context).completeShopping,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
