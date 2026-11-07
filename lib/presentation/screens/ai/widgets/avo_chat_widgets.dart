import 'package:flutter/material.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/mascot/avo_mascot.dart';

// ════════════════════════════════════════════════════════
// EMPTY STATE — centered Avo + suggestion pills
// ════════════════════════════════════════════════════════

class AvoChatEmptyState extends StatelessWidget {
  final List<String> chips;
  final void Function(String) onTap;
  const AvoChatEmptyState({
    super.key,
    required this.chips,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AvoMascot(size: 64, expression: AvoExpression.waving),
            const SizedBox(height: 14),
            Text(
              context.tr('how_can_i_help'),
              style: PaperTextStyles.serif(
                24,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 28),
            // Quick actions + shuffled suggestions as pills
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final text in [
                  context.tr('chip_analyze_list'),
                  context.tr('chip_find_recipe'),
                  ...chips,
                ])
                  _SuggestionPill(text: text, onTap: onTap, isDark: isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionPill extends StatelessWidget {
  final String text;
  final void Function(String) onTap;
  final bool isDark;
  const _SuggestionPill({
    required this.text,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : PaperColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isDark ? const Color(0xFF2C2C2E) : PaperColors.hairline,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary(context),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// USER BUBBLE — subtle, right-aligned
// ════════════════════════════════════════════════════════

class AvoUserBubble extends StatelessWidget {
  final String text;
  const AvoUserBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.accentColor(context)
              : PaperColors.ink,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            color: PaperColors.paper,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// COMPOSER — tall "Brief" composer: text on top, send button below
// ════════════════════════════════════════════════════════

class AvoComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final double bottomPadding;

  const AvoComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(
        left: 10,
        right: 10,
        top: 6,
        bottom: bottomPadding,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : PaperColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isDark ? const Color(0xFF2C2C2E) : PaperColors.hairline,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(18, 8, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              focusNode: focusNode,
              maxLines: 4,
              minLines: 2,
              textInputAction: TextInputAction.newline,
              onSubmitted: (_) => onSend(),
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary(context),
                height: 1.45,
              ),
              decoration: InputDecoration(
                hintText: context.tr('ask_avo_anything'),
                hintStyle: PaperTextStyles.serif(
                  15,
                  color: isDark ? const Color(0xFF5A5A5E) : PaperColors.faint,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              // Only the send button depends on the text, so only it
              // rebuilds per keystroke.
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final hasText = value.text.trim().isNotEmpty;
                  return GestureDetector(
                    onTap: onSend,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeInOut,
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: hasText
                            ? PaperColors.terracotta
                            : (isDark
                                  ? const Color(0xFF2C2C2E)
                                  : PaperColors.cream),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        size: 19,
                        color: hasText
                            ? PaperColors.paper
                            : isDark
                            ? const Color(0xFF48484A)
                            : PaperColors.faint,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// TYPING DOTS
// ════════════════════════════════════════════════════════

class AvoTypingDots extends StatefulWidget {
  const AvoTypingDots({super.key});
  @override
  State<AvoTypingDots> createState() => _AvoTypingDotsState();
}

class _AvoTypingDotsState extends State<AvoTypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, left: 4),
      child: AnimatedBuilder(
        animation: _c,
        builder: (ctx, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final d = i * 0.2;
            final t = ((_c.value - d) % 1.0).clamp(0.0, 1.0);
            final o = 0.3 + 0.5 * (t < 0.5 ? t * 2 : (1 - t) * 2);
            return Container(
              margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: AppColors.textTertiary(context).withValues(alpha: o),
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// HEADER — Avo avatar + status, premium badge, new chat (tab root, no back)
// ════════════════════════════════════════════════════════

class AvoChatHeader extends StatelessWidget {
  final bool isTyping;
  final bool isSubscribed;
  final bool keyboardOpen;
  final VoidCallback onNewChat;

  const AvoChatHeader({
    super.key,
    required this.isTyping,
    required this.isSubscribed,
    required this.keyboardOpen,
    required this.onNewChat,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final circleColor = isDark ? const Color(0xFF2C2C2E) : PaperColors.cream;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: PaperColors.sage,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: AvoMascot(size: 26, expression: AvoExpression.happy),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Avo',
                  style: PaperTextStyles.serif(
                    19,
                    color: AppColors.textPrimary(context),
                    height: 1.1,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    isTyping
                        ? context.tr('thinking_label')
                        : context.tr('your_shopping_assistant'),
                    key: ValueKey(isTyping),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isSubscribed) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: PaperColors.hairline),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                context.tr('premium_label'),
                style: const TextStyle(
                  fontSize: 11,
                  color: PaperColors.creamInk,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (keyboardOpen) ...[
            GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: _CircleIcon(
                color: circleColor,
                icon: Icons.keyboard_hide_rounded,
                size: 17,
              ),
            ),
            const SizedBox(width: 8),
          ],
          GestureDetector(
            onTap: onNewChat,
            child: _CircleIcon(
              color: circleColor,
              icon: Icons.add_rounded,
              size: 19,
            ),
          ),
        ],
      ),
    );
  }
}

/// 34pt round header button.
class _CircleIcon extends StatelessWidget {
  final Color color;
  final IconData icon;
  final double size;
  const _CircleIcon({
    required this.color,
    required this.icon,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, size: size, color: AppColors.textSecondary(context)),
    );
  }
}
