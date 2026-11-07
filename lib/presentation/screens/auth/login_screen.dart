import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/utils/validators.dart';
import 'package:shoply/core/widgets/paper/paper_widgets.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/presentation/screens/auth/auth_errors.dart';
import 'package:shoply/presentation/screens/auth/social_auth.dart';
import 'package:shoply/presentation/screens/auth/widgets/google_logo.dart';
import 'package:shoply/presentation/screens/auth/widgets/otp_verification_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  void _showSnack(String message, {Color? color, SnackBarAction? action}) {
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color ?? AppColors.error,
        duration: Duration(seconds: action != null ? 5 : 4),
        action: action,
      ),
    );
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    AuthResponse response;
    try {
      debugPrint('🔐 [LOGIN] Attempting login');
      response = await SupabaseService.instance.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } catch (e) {
      debugPrint('❌ [LOGIN] Error: $e');
      if (mounted) _showSignInError(e);
      return;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    // Push-token sync happens in main.dart's signedIn listener.
    if (response.user != null && mounted) {
      debugPrint('✅ [LOGIN] Login successful');
      context.go('/home');
    }
  }

  void _showSignInError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('invalid login credentials') ||
        s.contains('invalid_credentials')) {
      _showSnack(
        context.tr('invalid_email_password'),
        action: SnackBarAction(
          label: context.tr('sign_up_instead'),
          textColor: Colors.white,
          onPressed: () => context.push('/signup'),
        ),
      );
    } else if (s.contains('email not confirmed') ||
        s.contains('email_not_confirmed')) {
      _showSnack(
        context.tr('verify_email_first'),
        action: SnackBarAction(
          label: context.tr('resend'),
          textColor: Colors.white,
          onPressed: _resendConfirmationEmail,
        ),
      );
    } else if (s.contains('user not found')) {
      _showSnack(
        context.tr('no_account_found'),
        action: SnackBarAction(
          label: context.tr('sign_up'),
          textColor: Colors.white,
          onPressed: () => context.push('/signup'),
        ),
      );
    } else {
      _showSnack(commonAuthError(context, e) ?? context.tr('login_failed'));
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
        _showSnack(context.tr('confirmation_email_sent'), color: AppColors.success);
      }
    } catch (e) {
      debugPrint('❌ [RESEND] Error: $e');
      if (mounted) {
        _showSnack(commonAuthError(context, e) ?? context.tr('otp_resend_failed'));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    await signInWithSocialProvider(
      context,
      SocialAuthProvider.google,
      onError: _showSnack,
    );
    if (mounted) setState(() => _isGoogleLoading = false);
  }

  Future<void> _onForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack(context.tr('enter_email_first'), color: AppColors.warning);
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('📧 [FORGOT_PASSWORD] Sending reset OTP');
      await SupabaseService.instance.resetPassword(email);
      debugPrint('✅ [FORGOT_PASSWORD] Reset OTP sent successfully');

      if (mounted) {
        setState(() {
          _pendingResetEmail = email;
          _showOtpVerification = true;
        });
        _showSnack(
          context.tr('reset_code_sent', params: {'email': email}),
          color: AppColors.success,
        );
      }
    } catch (e) {
      debugPrint('❌ [FORGOT_PASSWORD] Error: $e');
      if (mounted) {
        final s = e.toString().toLowerCase();
        _showSnack(
          s.contains('user not found') || s.contains('no user')
              ? context.tr('no_account_found')
              : commonAuthError(context, e) ?? context.tr('reset_code_send_failed'),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyResetOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      _showSnack(context.tr('otp_enter_code'));
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
      if (mounted) _showSnack(otpErrorMessage(context, e));
      return;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (!mounted) return;
    // The reset screen shows its own "set a new password" instructions; a
    // snackbar here would be disposed with this route immediately.
    context.go('/reset-password');
  }

  Future<void> _resendResetOtp() async {
    if (_pendingResetEmail == null) return;

    setState(() => _isLoading = true);

    try {
      await SupabaseService.instance.resetPassword(_pendingResetEmail!);
      if (mounted) {
        _showSnack(context.tr('otp_new_code_sent'), color: AppColors.success);
      }
    } catch (e) {
      debugPrint('❌ [RESEND_RESET_OTP] Error: $e');
      if (mounted) {
        _showSnack(commonAuthError(context, e) ?? context.tr('otp_resend_failed'));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                  ? OtpVerificationView(
                      kicker: context.tr('otp_kicker_reset_password'),
                      email: _pendingResetEmail,
                      controller: _otpController,
                      loading: _isLoading,
                      onVerify: _verifyResetOtp,
                      onResend: _resendResetOtp,
                      onBack: () => setState(() {
                        _showOtpVerification = false;
                        _otpController.clear();
                      }),
                    )
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
            leading: const GoogleLogo(),
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
}
