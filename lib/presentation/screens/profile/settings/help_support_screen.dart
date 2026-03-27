import 'package:flutter/material.dart';
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
        padding: EdgeInsets.only(bottom: 100 + MediaQuery.of(context).padding.bottom),
        children: [
          // FAQ Section
          _buildSectionHeader('❓ ${context.tr('faq')}'),
          _buildFAQTile(
            question: context.tr('faq_create_list'),
            answer: context.tr('faq_create_list_answer'),
          ),
          _buildFAQTile(
            question: context.tr('faq_share_list'),
            answer: context.tr('faq_share_list_answer'),
          ),
          _buildFAQTile(
            question: context.tr('faq_auto_categorization'),
            answer: context.tr('faq_auto_categorization_answer'),
          ),
          _buildFAQTile(
            question: context.tr('faq_delete_history'),
            answer: context.tr('faq_delete_history_answer'),
          ),

          const Divider(height: 32),

          // Contact Section
          _buildSectionHeader('📧 Kontakt'),
          ListTile(
            leading: const Icon(Icons.email),
            title: Text(context.tr('email_support')),
            subtitle: const Text('support@shoplyai.app'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _launchEmail('support@shoplyai.app'),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: Text(context.tr('report_bug')),
            subtitle: Text(context.tr('help_improve_app')),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showBugReportDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.star),
            title: Text(context.tr('rate_app')),
            subtitle: Text(context.tr('rate_app_desc')),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showRatingDialog(context),
          ),

          const Divider(height: 32),

          // Resources Section
          _buildSectionHeader('📚 Ressourcen'),
          ListTile(
            leading: const Icon(Icons.book),
            title: Text(context.tr('user_guide')),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _launchURL('https://shoplyai.app/guide'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: Text(context.tr('privacy')),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _launchURL('https://shoplyai.app/privacy'),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: Text(context.tr('terms')),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _launchURL('https://shoplyai.app/terms'),
          ),

          const SizedBox(height: 24),

          // App Version
          Center(
            child: Column(
              children: [
                Image.asset(
                  'assets/icon/icon.png',
                  width: 64,
                  height: 64,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.shopping_cart,
                    size: 64,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ShoplyAI',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(color: textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  '© 2025 ShoplyAI. Alle Rechte vorbehalten.',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFAQTile({required String question, required String answer}) {
    return ExpansionTile(
      title: Text(question),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(answer, style: const TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  Future<void> _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=ShoplyAI Support',
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('report_bug')),
        content: Text(
          context.tr('bug_report_desc'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('ok')),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('rate_app')),
        content: Text(
          context.tr('rate_app_dialog_desc'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Launch app store
            },
            child: Text(context.tr('rate')),
          ),
        ],
      ),
    );
  }
}
