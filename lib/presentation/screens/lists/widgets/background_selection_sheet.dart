import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/list_background_gradients.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/state/lists_provider.dart';

class BackgroundSelectionSheet extends ConsumerStatefulWidget {
  final String listId;

  const BackgroundSelectionSheet({super.key, required this.listId});

  @override
  ConsumerState<BackgroundSelectionSheet> createState() =>
      _BackgroundSelectionSheetState();
}

class _BackgroundSelectionSheetState
    extends ConsumerState<BackgroundSelectionSheet> {
  String? selectedBackground;
  bool _isSaving = false;

  List<_BackgroundOption> get backgrounds {
    return ListBackgroundGradients.gradients.entries.map((entry) {
      return _BackgroundOption(
        id: entry.key,
        name: ListBackgroundGradients.getGradientName(entry.key) ?? entry.key,
        gradient: entry.value,
      );
    }).toList();
  }

  Future<void> _saveBackground(String bgId, String bgName) async {
    if (_isSaving) return;
    setState(() {
      selectedBackground = bgId;
      _isSaving = true;
    });
    HapticFeedback.selectionClick();

    try {
      await ref
          .read(listsNotifierProvider.notifier)
          .saveBackground(widget.listId, 'gradient', bgId, null);

      if (mounted) {
        HapticFeedback.mediumImpact();
        ref.invalidate(listsNotifierProvider);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('select_background'),
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: GridView.builder(
        padding: EdgeInsets.fromLTRB(24, 8, 24, 60 + MediaQuery.of(context).padding.bottom),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.75,
        ),
        itemCount: backgrounds.length,
        itemBuilder: (context, index) {
          final bg = backgrounds[index];
          final isSelected = selectedBackground == bg.id;

          return GestureDetector(
            onTap: () => _saveBackground(bg.id, bg.name),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                gradient: bg.gradient,
                borderRadius: BorderRadius.circular(16),
                border: isSelected
                    ? Border.all(
                        color: isDark ? Colors.white : Colors.black,
                        width: 2.5,
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  if (isSelected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white : Colors.black,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: isDark ? Colors.black : Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.45),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Text(
                        bg.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BackgroundOption {
  final String id;
  final String name;
  final Gradient gradient;

  const _BackgroundOption({
    required this.id,
    required this.name,
    required this.gradient,
  });
}
