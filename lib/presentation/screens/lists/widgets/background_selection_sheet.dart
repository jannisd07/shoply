import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        children: [
          // iOS-style drag handle
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          // Navigation bar style header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(
              children: [
                const Spacer(),
                Text(
                  context.tr('select_background'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                const Spacer(),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 30,
                  onPressed: () => Navigator.pop(context),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.xmark,
                      size: 14,
                      color: isDark ? Colors.white60 : const Color(0xFF8E8E93),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.8,
              ),
              itemCount: backgrounds.length,
              itemBuilder: (context, index) {
                final bg = backgrounds[index];
                final isSelected = selectedBackground == bg.id;

                return GestureDetector(
                  onTap: () => _saveBackground(bg.id, bg.name),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      gradient: bg.gradient,
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? Border.all(color: isDark ? Colors.white : CupertinoColors.systemBlue, width: 3)
                          : null,
                    ),
                    child: Stack(
                      children: [
                        // Checkmark
                        if (isSelected)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white : CupertinoColors.systemBlue,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                CupertinoIcons.checkmark,
                                color: isDark ? Colors.black : Colors.white,
                                size: 15,
                              ),
                            ),
                          ),
                        // Name at bottom
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
                                  Colors.black.withValues(alpha: 0.5),
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
          ),
          const SizedBox(height: 0),
        ],
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
