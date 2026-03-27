import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/mascot/avo_mascot.dart';
import 'package:shoply/presentation/screens/auth/widgets/primary_button.dart';
import 'package:shoply/presentation/screens/auth/widgets/social_button.dart';
import 'package:shoply/data/services/supabase_service.dart';

/// Welcome Screen - ChatGPT-Style Login Entry Point
/// 
/// Shows "Let's brainstorm" branding with bottom sheet containing
/// social login options and email signup/login buttons.
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
        
        // Check for specific error types
        if (e.toString().contains('validation_failed') || 
            e.toString().contains('OAuth secret') ||
            e.toString().contains('Unsupported provider')) {
          errorMessage = 'Apple Sign In ist noch nicht konfiguriert.\nBitte verwenden Sie Email/Passwort.';
        } else if (e.toString().contains('nicht verfügbar') ||
                   e.toString().contains('error 1000') ||
                   e.toString().contains('AuthorizationErrorCode.unknown')) {
          errorMessage = 'Apple Sign In ist im Simulator nicht verfügbar.\nBitte auf einem echten Gerät testen.';
        } else if (e.toString().contains('canceled')) {
          // User cancelled - no error message needed
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
          errorMessage = 'Google Sign In ist noch nicht konfiguriert.\nBitte verwenden Sie Email/Passwort.';
        } else if (e.toString().contains('canceled') || e.toString().contains('cancelled')) {
          // User cancelled - no error message needed
          return;
        }
        
        _showErrorDialog(context, errorMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Colors - main background is theme-aware (white in light, dark in dark)
    // Bottom sheet keeps dark style for contrast
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = AppColors.background(context);
    final bottomSheetColor = AppColors.darkSurface; // Always dark
    final buttonSecondaryBg = AppColors.darkInputFill; // Always dark
    final buttonSecondaryText = AppColors.darkTextPrimary; // Always white
    final borderColor = AppColors.darkBorder; // Always dark
    
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Avo mascot with greeting
          Align(
            alignment: const Alignment(0, -0.35),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AvoMascot(
                  size: 140,
                  expression: AvoExpression.waving,
                ),
                const SizedBox(height: 16),
                Text(
                  'Hi, I\'m $avoName! 🥑',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your shopping buddy',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),

          // Bottom: Welcome Actions Sheet - extends to bottom edge
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: bottomSheetColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              padding: const EdgeInsets.only(
                left: 24,
                right: 24,
                top: 32,
                bottom: 24,
              ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Continue with Apple (iOS only)
                    if (Platform.isIOS) ...[
                      SocialButton(
                        text: 'Continue with Apple',
                        icon: Icons.apple,
                        backgroundColor: Colors.white,
                        textColor: Colors.black,
                        iconColor: Colors.black,
                        onPressed: () => _handleAppleLogin(context),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Continue with Google
                    SocialButton(
                      text: 'Continue with Google',
                      customIcon: Image.network(
                        'https://www.google.com/favicon.ico',
                        height: 22,
                        width: 22,
                        errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 24),
                      ),
                      backgroundColor: buttonSecondaryBg,
                      textColor: buttonSecondaryText,
                      iconColor: buttonSecondaryText,
                      onPressed: () => _handleGoogleLogin(context),
                    ),
                    const SizedBox(height: 12),

                    // Sign up
                    PrimaryButton(
                      text: 'Sign up',
                      backgroundColor: buttonSecondaryBg,
                      textColor: buttonSecondaryText,
                      onPressed: () {
                        debugPrint('📝 Sign up button pressed');
                        context.push('/signup');
                      },
                    ),
                    const SizedBox(height: 12),

                    // Log in
                    PrimaryButton(
                      text: 'Log in',
                      backgroundColor: Colors.transparent,
                      textColor: buttonSecondaryText,
                      borderColor: borderColor,
                      onPressed: () => context.push('/login'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
