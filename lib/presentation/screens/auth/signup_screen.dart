import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/utils/validators.dart';
import 'package:shoply/core/widgets/paper/paper_widgets.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/data/services/fcm_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _showOtpVerification = false;
  String? _pendingEmail;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = GoRouterState.of(context);
    if (state.extra != null && state.extra is Map) {
      final extra = state.extra as Map<String, dynamic>;
      if (extra.containsKey('email')) {
        _emailController.text = extra['email'] as String;
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      // Add timeout to prevent infinite loading
      await SupabaseService.instance
          .signUpWithEmail(
            email,
            _passwordController.text,
            emailRedirectTo: 'shoply://login',
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception(
                'Request timed out. Please check your internet connection and try again.',
              );
            },
          );

      if (mounted) {
        setState(() {
          _pendingEmail = email;
          _showOtpVerification = true;
        });
      }
    } catch (e) {
      debugPrint('❌ [SIGNUP] Error: $e');
      if (mounted) {
        String errorMessage = 'Failed to create account';
        SnackBarAction? action;
        final errorString = e.toString().toLowerCase();

        if (errorString.contains('user already registered') ||
            errorString.contains('already exists')) {
          errorMessage = 'An account with this email already exists.';
          action = SnackBarAction(
            label: 'Log In',
            textColor: Colors.white,
            onPressed: () => context.go('/welcome'),
          );
        } else if (errorString.contains('weak')) {
          errorMessage =
              'Password is too weak. Use at least 8 characters with uppercase and numbers.';
        } else if (errorString.contains('too many requests') ||
            errorString.contains('rate limit') ||
            errorString.contains('429')) {
          errorMessage =
              'Too many attempts. Please wait a moment and try again.';
        } else if (errorString.contains('network') ||
            errorString.contains('socket') ||
            errorString.contains('connection') ||
            errorString.contains('timed out')) {
          errorMessage =
              'Network error. Please check your internet connection.';
        } else if (errorString.contains('invalid email')) {
          errorMessage = 'Please enter a valid email address.';
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
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
      await SupabaseService.instance.client.auth.verifyOTP(
        email: _pendingEmail!,
        token: otp,
        type: OtpType.signup,
      );
    } catch (e) {
      debugPrint('❌ [VERIFY_OTP] Error: $e');
      if (mounted) {
        String errorMessage = 'Verification failed';
        final errorString = e.toString().toLowerCase();

        if (errorString.contains('invalid') ||
            errorString.contains('expired')) {
          errorMessage = 'Invalid or expired code. Please try again.';
        } else if (errorString.contains('too many')) {
          errorMessage = 'Too many attempts. Please request a new code.';
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

    // Push-token sync is a post-login side effect and must not turn a
    // successful OTP verification into a visible verification error.
    if (Platform.isIOS || Platform.isAndroid) {
      unawaited(
        FCMService.instance.saveTokenForCurrentUser().catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          debugPrint('⚠️ [VERIFY_OTP] FCM token save skipped: $error');
        }),
      );
    }

    _scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Email verified successfully!'),
        backgroundColor: AppColors.success,
      ),
    );
    if (!mounted) return;
    // New accounts choose their display name on the dedicated name screen.
    context.go('/name-prompt?new=1');
  }

  Future<void> _resendOtp() async {
    if (_pendingEmail == null) return;

    setState(() => _isLoading = true);

    try {
      await SupabaseService.instance.client.auth.resend(
        type: OtpType.signup,
        email: _pendingEmail!,
      );

      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('New code sent! Please check your email.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [RESEND_OTP] Error: $e');
      if (mounted) {
        String errorMessage = 'Failed to resend code';
        final errorString = e.toString().toLowerCase();

        if (errorString.contains('too many') ||
            errorString.contains('rate limit')) {
          errorMessage = 'Please wait before requesting another code.';
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
                  : _buildSignUpForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpForm() {
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
          PaperKicker(context.tr('signup_kicker')),
          const SizedBox(height: 10),
          Text(
            context.tr('signup_headline'),
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
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.next,
            validator: Validators.validatePassword,
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
          const SizedBox(height: 22),
          PaperUnderlineField(
            controller: _confirmPasswordController,
            label: context.tr('confirm_password_label'),
            obscureText: _obscureConfirmPassword,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _signUp(),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return context.tr('required');
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
            suffix: GestureDetector(
              onTap: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
              child: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 19,
                color: PaperColors.muted,
              ),
            ),
          ),
          const SizedBox(height: 30),
          PaperPrimaryButton(
            label: context.tr('create_account'),
            loading: _isLoading,
            onPressed: _signUp,
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
              onTap: () => context.go('/login'),
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
        const PaperKicker('Verify email'),
        const SizedBox(height: 10),
        Text('Check your\ninbox.', style: PaperTextStyles.serif(27)),
        const SizedBox(height: 14),
        Text(
          'We sent a 6-digit code to\n$_pendingEmail',
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
          onPressed: _verifyOtp,
        ),
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: _isLoading ? null : _resendOtp,
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
