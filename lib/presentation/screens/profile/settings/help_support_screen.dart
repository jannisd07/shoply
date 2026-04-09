import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final backgroundColor = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final separatorColor = AppColors.divider(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.tr('help_support'),
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 8,
          bottom: 60 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          // FAQ Section
          _buildSectionHeader(context.tr('faq'), textSecondary),
          _buildFAQItem(
            context: context,
            question: context.tr('faq_create_list'),
            answer: context.tr('faq_create_list_answer'),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          _buildDivider(separatorColor),
          _buildFAQItem(
            context: context,
            question: context.tr('faq_share_list'),
            answer: context.tr('faq_share_list_answer'),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          _buildDivider(separatorColor),
          _buildFAQItem(
            context: context,
            question: context.tr('faq_auto_categorization'),
            answer: context.tr('faq_auto_categorization_answer'),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          _buildDivider(separatorColor),
          _buildFAQItem(
            context: context,
            question: context.tr('faq_delete_history'),
            answer: context.tr('faq_delete_history_answer'),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),

          const SizedBox(height: 32),

          // Contact Section
          _buildSectionHeader(context.tr('contact'), textSecondary),
          _buildTapItem(
            title: context.tr('email_support'),
            subtitle: 'support@shoplyai.app',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            onTap: () => _launchEmail('support@shoplyai.app'),
          ),
          _buildDivider(separatorColor),
          _buildTapItem(
            title: context.tr('report_bug'),
            subtitle: context.tr('help_improve_app'),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            onTap: () => _showBugReportDialog(context),
          ),
          _buildDivider(separatorColor),
          _buildTapItem(
            title: context.tr('rate_app'),
            subtitle: context.tr('rate_app_desc'),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            onTap: () => _showRatingDialog(context),
          ),

          const SizedBox(height: 32),

          // Resources Section
          _buildSectionHeader(context.tr('resources'), textSecondary),
          _buildTapItem(
            title: context.tr('user_guide'),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            onTap: () => _launchURL('https://shoplyai.app/guide'),
          ),
          _buildDivider(separatorColor),
          _buildTapItem(
            title: context.tr('privacy'),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            onTap: () => _launchURL('https://shoplyai.app/privacy'),
          ),
          _buildDivider(separatorColor),
          _buildTapItem(
            title: context.tr('terms'),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            onTap: () => _launchURL('https://shoplyai.app/terms'),
          ),

          const SizedBox(height: 40),

          // App Version
          Center(
            child: Text(
              'Avo  v1.0.0',
              style: TextStyle(
                fontSize: 13,
                color: textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFAQItem({
    required BuildContext context,
    required String question,
    required String answer,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return _FAQExpandableItem(
      question: question,
      answer: answer,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
    );
  }

  Widget _buildTapItem({
    required String title,
    String? subtitle,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return Container(
      height: 0.5,
      color: color,
    );
  }

  Future<void> _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Avo Support',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showBugReportDialog(BuildContext context) {
    _showModal(
      context: context,
      title: context.tr('report_bug'),
      body: context.tr('bug_report_desc'),
    );
  }

  void _showRatingDialog(BuildContext context) {
    _showModal(
      context: context,
      title: context.tr('rate_app'),
      body: context.tr('rate_app_dialog_desc'),
      actionLabel: context.tr('rate'),
      onAction: () {
        // TODO: Launch app store
      },
    );
  }

  void _showModal({
    required BuildContext context,
    required String title,
    required String body,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final backgroundColor = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(dialogContext),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        child: Text(
                          context.tr('cancel'),
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    if (actionLabel != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(dialogContext);
                          onAction?.call();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          child: Text(
                            actionLabel,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FAQExpandableItem extends StatefulWidget {
  final String question;
  final String answer;
  final Color textPrimary;
  final Color textSecondary;

  const _FAQExpandableItem({
    required this.question,
    required this.answer,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  State<_FAQExpandableItem> createState() => _FAQExpandableItemState();
}

class _FAQExpandableItemState extends State<_FAQExpandableItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _expanded = !_expanded);
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.question,
                    style: TextStyle(
                      color: widget.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: widget.textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  widget.answer,
                  style: TextStyle(
                    color: widget.textSecondary,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }
}
