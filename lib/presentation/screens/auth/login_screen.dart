import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/utils/validators.dart';
import 'package:shoply/core/widgets/paper/paper_widgets.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/data/services/fcm_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shoply/core/localization/localization_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  bool _showOtpVerification = false;
  String? _pendingResetEmail;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    AuthResponse? response;
    try {
      debugPrint(
        '🔐 [LOGIN] Attempting login for: ${_emailController.text.trim()}',
      );

      response = await SupabaseService.instance.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } catch (e) {
      debugPrint('❌ [LOGIN] Error: $e');

      if (mounted) {
        final errorString = e.toString().toLowerCase();
        String errorMessage;
        SnackBarAction? action;

        if (errorString.contains('invalid login credentials') ||
            errorString.contains('invalid_credentials')) {
          errorMessage = context.tr('invalid_email_password');
          action = SnackBarAction(
            label: context.tr('sign_up_instead'),
            textColor: Colors.white,
            onPressed: () => context.push('/signup'),
          );
        } else if (errorString.contains('email not confirmed') ||
            errorString.contains('email_not_confirmed')) {
          errorMessage = context.tr('verify_email_first');
          action = SnackBarAction(
            label: context.tr('resend'),
            textColor: Colors.white,
            onPressed: () => _resendConfirmationEmail(),
          );
        } else if (errorString.contains('too many requests') ||
            errorString.contains('rate limit') ||
            errorString.contains('429')) {
          errorMessage = context.tr('too_many_attempts');
        } else if (errorString.contains('network') ||
            errorString.contains('socket') ||
            errorString.contains('connection')) {
          errorMessage = context.tr('network_error');
        } else if (errorString.contains('user not found')) {
          errorMessage = context.tr('no_account_found');
          action = SnackBarAction(
            label: context.tr('sign_up'),
            textColor: Colors.white,
            onPressed: () => context.push('/signup'),
          );
        } else {
          errorMessage = context.tr('login_failed');
        }

        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
            action: action,
          ),
        );
      }
      return;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }

    if (response.user != null && mounted) {
      debugPrint('🔐 [LOGIN] Login successful');

      // Push-token sync is a post-login side effect and should never surface
      // as a login failure after Supabase accepted the credentials.
      if (Platform.isIOS || Platform.isAndroid) {
        unawaited(
          FCMService.instance.saveTokenForCurrentUser().catchError((
            Object error,
            StackTrace stackTrace,
          ) {
            debugPrint('⚠️ [LOGIN] FCM token save skipped: $error');
          }),
        );
      }

      if (!mounted) return;
      context.go('/home');
    }
  }

  Future<void> _resendConfirmationEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await SupabaseService.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
      );

      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(context.tr('confirmation_email_sent')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [RESEND] Error: $e');
      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Failed to resend: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);

    try {
      // Use native Google Sign-In for better reliability on Android
      final success = await SupabaseService.instance.signInWithGoogle();

      if (success && mounted) {
        // Save FCM token for push notifications
        if (Platform.isIOS || Platform.isAndroid) {
          await FCMService.instance.saveTokenForCurrentUser();
        }
        _routeAfterSocialSignIn();
      }
    } catch (e) {
      debugPrint('❌ [GOOGLE_SIGNIN] Error: $e');
      if (mounted) {
        String errorMessage = 'Google Sign-In failed';
        final errorString = e.toString().toLowerCase();

        if (errorString.contains('nicht konfiguriert') ||
            errorString.contains('not configured')) {
          errorMessage =
              'Google Sign-In is not available. Please use email/password.';
        } else if (errorString.contains('timeout') ||
            errorString.contains('timed out')) {
          errorMessage = 'Connection timed out. Please try again.';
        } else if (errorString.contains('network') ||
            errorString.contains('connection')) {
          errorMessage =
              'Network error. Please check your internet connection.';
        } else if (errorString.contains('cancelled') ||
            errorString.contains('canceled')) {
          // User cancelled - don't show error
          return;
        }

        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  void _routeAfterSocialSignIn() {
    final user = SupabaseService.instance.currentUser;
    final createdAt = user != null ? DateTime.tryParse(user.createdAt) : null;
    final isNewAuthUser =
        createdAt != null &&
        DateTime.now().difference(createdAt.toLocal()).inMinutes < 3;

    if (isNewAuthUser) {
      context.go('/name-prompt?new=1');
    } else {
      context.go('/home');
    }
  }

  Future<void> _onForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(context.tr('enter_email_first')),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('📧 [FORGOT_PASSWORD] Sending reset OTP to: $email');

      await SupabaseService.instance.resetPassword(email);

      debugPrint('✅ [FORGOT_PASSWORD] Reset OTP sent successfully');

      if (mounted) {
        setState(() {
          _pendingResetEmail = email;
          _showOtpVerification = true;
        });
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Verification code sent to $email'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [FORGOT_PASSWORD] Error: $e');
      if (mounted) {
        String errorMessage = 'Failed to send reset code';
        final errorString = e.toString().toLowerCase();

        if (errorString.contains('user not found') ||
            errorString.contains('no user')) {
          errorMessage = 'No account found with this email';
        } else if (errorString.contains('rate limit') ||
            errorString.contains('too many')) {
          errorMessage = 'Too many attempts. Please wait a moment.';
        }

        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyResetOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || otp.length != 6) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Please enter the 6-digit code'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await SupabaseService.instance.verifyPasswordResetOtp(
        _pendingResetEmail!,
        otp,
      );
    } catch (e) {
      debugPrint('❌ [VERIFY_RESET_OTP] Error: $e');
      if (mounted) {
        String errorMessage = 'Invalid or expired code';
        final errorString = e.toString().toLowerCase();

        if (errorString.contains('expired')) {
          errorMessage = 'Code expired. Please request a new one.';
        } else if (errorString.contains('invalid')) {
          errorMessage = 'Invalid code. Please try again.';
        }

        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }

    if (!mounted) return;

    _scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Code verified! Set your new password.'),
        backgroundColor: AppColors.success,
      ),
    );
    // Navigate to reset password screen
    context.go('/reset-password');
  }

  Future<void> _resendResetOtp() async {
    if (_pendingResetEmail == null) return;

    setState(() => _isLoading = true);

    try {
      await SupabaseService.instance.resetPassword(_pendingResetEmail!);

      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('New code sent! Check your email.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [RESEND_RESET_OTP] Error: $e');
      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Failed to resend code: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        backgroundColor: PaperColors.paper,
        body: SafeArea(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                FocusScope.of(context).unfocus();
              }
              return false;
            },
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: _showOtpVerification
                  ? _buildOtpVerificationView()
                  : _buildLoginForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          IconButton(
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
            icon: const Icon(
              Icons.arrow_back,
              size: 22,
              color: PaperColors.ink,
            ),
            onPressed: () => context.go('/welcome'),
          ),
          const SizedBox(height: 20),
          PaperKicker(context.tr('sign_in_kicker')),
          const SizedBox(height: 10),
          Text(
            context.tr('welcome_back_paper'),
            style: PaperTextStyles.serif(27),
          ),
          const SizedBox(height: 34),
          PaperUnderlineField(
            controller: _emailController,
            label: context.tr('email'),
            hint: 'name@example.com',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            validator: Validators.validateEmail,
          ),
          const SizedBox(height: 22),
          PaperUnderlineField(
            controller: _passwordController,
            label: context.tr('password'),
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _signIn(),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return context.tr('required');
              }
              return null;
            },
            suffix: GestureDetector(
              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
              child: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 19,
                color: PaperColors.muted,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _onForgotPassword,
              child: Text(
                context.tr('forgot_password'),
                style: const TextStyle(
                  fontSize: 13,
                  color: PaperColors.terracotta,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          PaperPrimaryButton(
            label: context.tr('sign_in'),
            loading: _isLoading,
            onPressed: _signIn,
          ),
          const SizedBox(height: 22),
          PaperOrDivider(context.tr('or')),
          const SizedBox(height: 22),
          PaperOutlineButton(
            label: context.tr('continue_with_google'),
            loading: _isGoogleLoading,
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
            onPressed: _signInWithGoogle,
          ),
          const SizedBox(height: 24),
          Center(
            child: GestureDetector(
              onTap: () => context.go('/signup'),
              child: Text.rich(
                TextSpan(
                  text: '${context.tr('dont_have_account')} ',
                  style: const TextStyle(
                    fontSize: 13,
                    color: PaperColors.muted,
                  ),
                  children: [
                    TextSpan(
                      text: context.tr('sign_up'),
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
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildOtpVerificationView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        IconButton(
          padding: EdgeInsets.zero,
          alignment: Alignment.centerLeft,
          icon: const Icon(Icons.arrow_back, size: 22, color: PaperColors.ink),
          onPressed: () {
            setState(() {
              _showOtpVerification = false;
              _otpController.clear();
            });
          },
        ),
        const SizedBox(height: 20),
        const PaperKicker('Reset password'),
        const SizedBox(height: 10),
        Text('Check your\ninbox.', style: PaperTextStyles.serif(27)),
        const SizedBox(height: 14),
        Text(
          'We sent a 6-digit code to\n$_pendingResetEmail',
          style: PaperTextStyles.body(color: PaperColors.muted),
        ),
        const SizedBox(height: 6),
        Text(
          'Please also check your spam folder.',
          style: PaperTextStyles.body(size: 12, color: PaperColors.faint),
        ),
        const SizedBox(height: 34),
        PaperUnderlineField(
          controller: _otpController,
          label: 'Code',
          hint: '000000',
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: PaperColors.ink,
            fontSize: 24,
            letterSpacing: 8,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 30),
        PaperPrimaryButton(
          label: 'Verify code',
          loading: _isLoading,
          onPressed: _verifyResetOtp,
        ),
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: _isLoading ? null : _resendResetOtp,
            child: Text.rich(
              TextSpan(
                text: "Didn't receive the code? ",
                style: const TextStyle(fontSize: 13, color: PaperColors.muted),
                children: const [
                  TextSpan(
                    text: 'Resend',
                    style: TextStyle(
                      color: PaperColors.terracotta,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
