import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/widgets/paper/paper_widgets.dart';
import 'package:shoply/presentation/screens/auth/social_auth.dart';
import 'package:shoply/presentation/screens/auth/widgets/google_logo.dart';

/// Welcome Screen — paper-style auth entry point with social login
/// and email signup/login.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _signIn(BuildContext context, SocialAuthProvider provider) {
    return signInWithSocialProvider(
      context,
      provider,
      onError: (message) => _showErrorDialog(context, message),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('notice_title')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('ok')),
          ),
        ],
      ),
    );
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
                  onPressed: () => _signIn(context, SocialAuthProvider.apple),
                ),
                const SizedBox(height: 10),
              ],
              PaperOutlineButton(
                label: context.tr('continue_with_google'),
                leading: const GoogleLogo(),
                onPressed: () => _signIn(context, SocialAuthProvider.google),
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
