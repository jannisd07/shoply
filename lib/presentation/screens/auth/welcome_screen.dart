import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/widgets/paper/paper_widgets.dart';
import 'package:shoply/data/services/supabase_service.dart';

/// Welcome Screen — paper-style auth entry point with social login
/// and email signup/login.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _handleAppleLogin(BuildContext context) async {
    try {
      debugPrint('🍎 Apple Sign In tapped');
      final success = await SupabaseService.instance.signInWithApple();
      if (success && context.mounted) {
        // OAuth flow completed successfully - user is now logged in
        // Navigation will be handled by auth state listener
        debugPrint('✅ Apple Sign In success!');
      }
    } catch (e) {
      debugPrint('❌ Apple Sign In error: $e');
      if (context.mounted) {
        String errorMessage = 'Apple Sign In fehlgeschlagen';

        if (e.toString().contains('validation_failed') ||
            e.toString().contains('OAuth secret') ||
            e.toString().contains('Unsupported provider')) {
          errorMessage =
              'Apple Sign In ist noch nicht konfiguriert.\nBitte verwenden Sie Email/Passwort.';
        } else if (e.toString().contains('nicht verfügbar') ||
            e.toString().contains('error 1000') ||
            e.toString().contains('AuthorizationErrorCode.unknown')) {
          errorMessage =
              'Apple Sign In ist im Simulator nicht verfügbar.\nBitte auf einem echten Gerät testen.';
        } else if (e.toString().contains('canceled')) {
          return;
        }

        _showErrorDialog(context, errorMessage);
      }
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hinweis'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleGoogleLogin(BuildContext context) async {
    try {
      debugPrint('🔵 Google Sign In tapped');
      final success = await SupabaseService.instance.signInWithGoogle();
      if (success && context.mounted) {
        debugPrint('✅ Google Sign In success!');
        // Navigation will be handled by auth state listener
      }
    } catch (e) {
      debugPrint('❌ Google Sign In error: $e');
      if (context.mounted) {
        String errorMessage = 'Google Sign In fehlgeschlagen';

        if (e.toString().contains('validation_failed') ||
            e.toString().contains('OAuth') ||
            e.toString().contains('konfiguriert')) {
          errorMessage =
              'Google Sign In ist noch nicht konfiguriert.\nBitte verwenden Sie Email/Passwort.';
        } else if (e.toString().contains('canceled') ||
            e.toString().contains('cancelled')) {
          return;
        }

        _showErrorDialog(context, errorMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PaperColors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 190,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: PaperColors.sage,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(
                                color: PaperColors.paper,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.eco_outlined,
                                size: 34,
                                color: PaperColors.sageInk,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        PaperKicker(
                          context.tr('welcome_kicker'),
                          color: PaperColors.terracotta,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          context.tr('welcome_headline'),
                          style: PaperTextStyles.serif(28),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.tr('welcome_sub'),
                          style: PaperTextStyles.body(color: PaperColors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (Platform.isIOS) ...[
                PaperOutlineButton(
                  label: context.tr('continue_with_apple'),
                  strong: true,
                  leading: const Icon(
                    Icons.apple,
                    size: 20,
                    color: PaperColors.ink,
                  ),
                  onPressed: () => _handleAppleLogin(context),
                ),
                const SizedBox(height: 10),
              ],
              PaperOutlineButton(
                label: context.tr('continue_with_google'),
                leading: Image.network(
                  'https://www.google.com/favicon.ico',
                  height: 18,
                  width: 18,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.g_mobiledata,
                    size: 22,
                    color: PaperColors.creamInk,
                  ),
                ),
                onPressed: () => _handleGoogleLogin(context),
              ),
              const SizedBox(height: 14),
              PaperPrimaryButton(
                label: context.tr('create_account'),
                onPressed: () => context.push('/signup'),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: () => context.push('/login'),
                  child: Text.rich(
                    TextSpan(
                      text: '${context.tr('already_have_account')} ',
                      style: const TextStyle(
                        fontSize: 13,
                        color: PaperColors.muted,
                      ),
                      children: [
                        TextSpan(
                          text: context.tr('log_in_paper'),
                          style: const TextStyle(
                            color: PaperColors.terracotta,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
