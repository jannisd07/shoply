import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  Future<void> _signUp() async {
    // The confirm field's validator already checks that both passwords match.
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      // Timeout so a stalled request can't leave the button spinning.
      await SupabaseService.instance
          .signUpWithEmail(
            email,
            _passwordController.text,
            emailRedirectTo: 'shoply://login',
          )
          .timeout(const Duration(seconds: 30));

      if (mounted) {
        setState(() {
          _pendingEmail = email;
          _showOtpVerification = true;
        });
      }
    } catch (e) {
      debugPrint('❌ [SIGNUP] Error: $e');
      if (mounted) _showSignUpError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSignUpError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('user already registered') || s.contains('already exists')) {
      _showSnack(
        context.tr('auth_error_account_exists'),
        action: SnackBarAction(
          label: context.tr('log_in_paper'),
          textColor: Colors.white,
          onPressed: () => context.go('/login'),
        ),
      );
    } else if (s.contains('weak')) {
      _showSnack(context.tr('auth_error_weak_password'));
    } else if (s.contains('invalid email')) {
      _showSnack(context.tr('auth_error_invalid_email'));
    } else {
      _showSnack(
        commonAuthError(context, e) ?? context.tr('auth_error_signup_failed'),
      );
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      _showSnack(context.tr('otp_enter_code'));
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
      if (mounted) _showSnack(otpErrorMessage(context, e));
      return;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (!mounted) return;
    // Push-token sync happens in main.dart's signedIn listener. New accounts
    // choose their display name on the dedicated name screen.
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
        _showSnack(context.tr('otp_new_code_sent'), color: AppColors.success);
      }
    } catch (e) {
      debugPrint('❌ [RESEND_OTP] Error: $e');
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
                      kicker: context.tr('otp_kicker_verify_email'),
                      email: _pendingEmail,
                      controller: _otpController,
                      loading: _isLoading,
                      onVerify: _verifyOtp,
                      onResend: _resendOtp,
                      onBack: () => setState(() {
                        _showOtpVerification = false;
                        _otpController.clear();
                      }),
                    )
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
                return context.tr('passwords_do_not_match');
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
            leading: const GoogleLogo(),
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
}
