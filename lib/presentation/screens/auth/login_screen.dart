import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/utils/validators.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/data/services/fcm_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/utils/display_name_helper.dart';

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

    try {
      debugPrint('🔐 [LOGIN] Attempting login for: ${_emailController.text.trim()}');
      
      final response = await SupabaseService.instance.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (response.user != null && mounted) {
        debugPrint('🔐 [LOGIN] Login successful');
        
        // Save FCM token for push notifications
        if (Platform.isIOS || Platform.isAndroid) {
          await FCMService.instance.saveTokenForCurrentUser();
        }
        
        // Check if user needs to set their display name
        final userData = await SupabaseService.instance.client
            .from('users')
            .select('display_name')
            .eq('id', response.user!.id)
            .maybeSingle();
        
        final displayName = userData?['display_name'] as String?;
        
        if (DisplayNameHelper.needsNamePrompt(displayName)) {
          context.go('/name-prompt');
        } else {
          context.go('/home');
        }
      }
    } catch (e) {
      debugPrint('❌ [LOGIN] Error: $e');
      
      if (mounted) {
        final errorString = e.toString().toLowerCase();
        String errorMessage;
        SnackBarAction? action;
        
        if (errorString.contains('invalid login credentials') || errorString.contains('invalid_credentials')) {
          errorMessage = context.tr('invalid_email_password');
          action = SnackBarAction(
            label: context.tr('sign_up_instead'),
            textColor: Colors.white,
            onPressed: () => context.push('/signup'),
          );
        } else if (errorString.contains('email not confirmed') || errorString.contains('email_not_confirmed')) {
          errorMessage = context.tr('verify_email_first');
          action = SnackBarAction(
            label: context.tr('resend'),
            textColor: Colors.white,
            onPressed: () => _resendConfirmationEmail(),
          );
        } else if (errorString.contains('too many requests') || errorString.contains('rate limit') || errorString.contains('429')) {
          errorMessage = context.tr('too_many_attempts');
        } else if (errorString.contains('network') || errorString.contains('socket') || errorString.contains('connection')) {
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        // Navigation will happen automatically via auth state listener
      }
    } catch (e) {
      debugPrint('❌ [GOOGLE_SIGNIN] Error: $e');
      if (mounted) {
        String errorMessage = 'Google Sign-In failed';
        final errorString = e.toString().toLowerCase();
        
        if (errorString.contains('nicht konfiguriert') || errorString.contains('not configured')) {
          errorMessage = 'Google Sign-In is not available. Please use email/password.';
        } else if (errorString.contains('timeout') || errorString.contains('timed out')) {
          errorMessage = 'Connection timed out. Please try again.';
        } else if (errorString.contains('network') || errorString.contains('connection')) {
          errorMessage = 'Network error. Please check your internet connection.';
        } else if (errorString.contains('cancelled') || errorString.contains('canceled')) {
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
        
        if (errorString.contains('user not found') || errorString.contains('no user')) {
          errorMessage = 'No account found with this email';
        } else if (errorString.contains('rate limit') || errorString.contains('too many')) {
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

      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Code verified! Set your new password.'),
            backgroundColor: AppColors.success,
          ),
        );
        // Navigate to reset password screen
        context.go('/reset-password');
      }
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
    final backgroundColor = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final inputFillColor = AppColors.inputFill(context);
    final inputBorderColor = AppColors.border(context);

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: inputFillColor,
              child: IconButton(
                icon: Icon(Icons.arrow_back_ios_rounded, color: textPrimary, size: 18),
                onPressed: () => context.go('/welcome'),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollStartNotification) {
                  FocusScope.of(context).unfocus();
                }
                return false;
              },
              child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.screenHorizontalPadding,
              ),
              child: _showOtpVerification
                  ? _buildOtpVerificationView(textPrimary, textSecondary, inputFillColor, inputBorderColor)
                  : Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.login_outlined,
                      size: 64,
                      color: textPrimary,
                    ),
                    
                    const SizedBox(height: 32),
                    
                    Text(
                      context.tr('welcome_back'),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        labelText: context.tr('email'),
                        labelStyle: TextStyle(color: textSecondary),
                        hintText: 'name@example.com',
                        hintStyle: TextStyle(color: textSecondary.withOpacity(0.6)),
                        filled: true,
                        fillColor: inputFillColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: inputBorderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: inputBorderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppColors.accent),
                        ),
                      ),
                      validator: Validators.validateEmail,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _signIn(),
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        labelText: context.tr('password'),
                        labelStyle: TextStyle(color: textSecondary),
                        filled: true,
                        fillColor: inputFillColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: inputBorderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: inputBorderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppColors.accent),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: textSecondary,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return context.tr('required');
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _onForgotPassword,
                        child: Text(
                          context.tr('forgot_password'),
                          style: TextStyle(
                            color: textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Login Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? CupertinoActivityIndicator(radius: 10, color: Colors.white)
                            : Text(
                                context.tr('sign_in'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Divider with "or"
                    Row(
                      children: [
                        Expanded(child: Divider(color: inputBorderColor)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('or', style: TextStyle(color: textSecondary)),
                        ),
                        Expanded(child: Divider(color: inputBorderColor)),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Google Sign-In Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: _isGoogleLoading ? null : _signInWithGoogle,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textPrimary,
                          side: BorderSide(color: inputBorderColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        icon: _isGoogleLoading
                            ? CupertinoActivityIndicator(radius: 10, color: textPrimary)
                            : Image.network(
                                'https://www.google.com/favicon.ico',
                                height: 20,
                                width: 20,
                                errorBuilder: (_, __, ___) => Icon(Icons.g_mobiledata, size: 24, color: textPrimary),
                              ),
                        label: Text(
                          _isGoogleLoading ? 'Signing in...' : 'Continue with Google',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Sign up link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          context.tr('dont_have_account'),
                          style: TextStyle(color: textSecondary),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => context.go('/signup'),
                          child: Text(
                            context.tr('sign_up'),
                            style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpVerificationView(Color textPrimary, Color textSecondary, Color inputFillColor, Color inputBorderColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.mark_email_read_outlined,
          size: 64,
          color: textPrimary,
        ),
        
        const SizedBox(height: 32),
        
        Text(
          'Reset Password',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 12),
        
        Text(
          'We sent a 6-digit code to\n$_pendingResetEmail',
          style: TextStyle(
            fontSize: 15,
            color: textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 8),
        
        Text(
          'Please also check your spam folder.',
          style: TextStyle(
            fontSize: 13,
            color: textSecondary.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 40),
        
        // OTP Input Field
        TextFormField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: TextStyle(
            color: textPrimary,
            fontSize: 24,
            letterSpacing: 8,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: '000000',
            hintStyle: TextStyle(
              color: textSecondary.withOpacity(0.5),
              fontSize: 24,
              letterSpacing: 8,
            ),
            counterText: '',
            filled: true,
            fillColor: inputFillColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: inputBorderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: inputBorderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.accent),
            ),
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Verify Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyResetOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? CupertinoActivityIndicator(radius: 10, color: Colors.white)
                : const Text(
                    'Verify Code',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Resend Code Link
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Didn't receive the code? ", style: TextStyle(color: textSecondary)),
            GestureDetector(
              onTap: _isLoading ? null : _resendResetOtp,
              child: Text(
                "Resend",
                style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Back to login
        TextButton(
          onPressed: () {
            setState(() {
              _showOtpVerification = false;
              _otpController.clear();
            });
          },
          child: Text(
            'Back to Login',
            style: TextStyle(color: textSecondary),
          ),
        ),
      ],
    );
  }
}
