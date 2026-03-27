import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/utils/validators.dart';
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
      await SupabaseService.instance.signUpWithEmail(
        email,
        _passwordController.text,
        emailRedirectTo: 'shoply://login',
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timed out. Please check your internet connection and try again.');
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
        
        if (errorString.contains('user already registered') || errorString.contains('already exists')) {
          errorMessage = 'An account with this email already exists.';
          action = SnackBarAction(
            label: 'Log In',
            textColor: Colors.white,
            onPressed: () => context.go('/welcome'),
          );
        } else if (errorString.contains('weak')) {
          errorMessage = 'Password is too weak. Use at least 8 characters with uppercase and numbers.';
        } else if (errorString.contains('too many requests') || errorString.contains('rate limit') || errorString.contains('429')) {
          errorMessage = 'Too many attempts. Please wait a moment and try again.';
        } else if (errorString.contains('network') || errorString.contains('socket') || errorString.contains('connection') || errorString.contains('timed out')) {
          errorMessage = 'Network error. Please check your internet connection.';
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

      if (mounted) {
        // Save FCM token for push notifications
        if (Platform.isIOS || Platform.isAndroid) {
          await FCMService.instance.saveTokenForCurrentUser();
        }
        
        _scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Email verified successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        // Navigate to name prompt for new users
        context.go('/name-prompt');
      }
    } catch (e) {
      debugPrint('❌ [VERIFY_OTP] Error: $e');
      if (mounted) {
        String errorMessage = 'Verification failed';
        final errorString = e.toString().toLowerCase();
        
        if (errorString.contains('invalid') || errorString.contains('expired')) {
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
        
        if (errorString.contains('too many') || errorString.contains('rate limit')) {
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
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.screenHorizontalPadding,
              ),
              child: _showOtpVerification
                  ? _buildOtpVerificationView(context, inputFillColor, inputBorderColor)
                  : _buildSignUpForm(context, inputFillColor, inputBorderColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpForm(BuildContext context, Color inputFillColor, Color inputBorderColor) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_add_outlined,
            size: 64,
            color: textPrimary,
          ),
          
          const SizedBox(height: 32),
          
          Text(
            'Create your account',
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
              labelText: 'Email',
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
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.next,
            style: TextStyle(color: textPrimary),
            decoration: InputDecoration(
              labelText: 'Password',
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
            validator: Validators.validatePassword,
          ),

          const SizedBox(height: 16),

          // Confirm Password Field
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.done,
            style: TextStyle(color: textPrimary),
            decoration: InputDecoration(
              labelText: 'Confirm Password',
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
                  _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: textSecondary,
                ),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please confirm password';
              if (value != _passwordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          
          const SizedBox(height: 32),
          
          // Sign Up Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _signUp,
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
                      'Create Account',
                      style: TextStyle(
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
          
          // Login Link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Already have an account? ", style: TextStyle(color: textSecondary)),
              GestureDetector(
                onTap: () => context.go('/welcome'),
                child: Text(
                  "Log In",
                  style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOtpVerificationView(BuildContext context, Color inputFillColor, Color inputBorderColor) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    
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
          'Verify your email',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 12),
        
        Text(
          'We sent a 6-digit code to\n$_pendingEmail',
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
            onPressed: _isLoading ? null : _verifyOtp,
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
                    'Verify',
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
              onTap: _isLoading ? null : _resendOtp,
              child: Text(
                "Resend",
                style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Back to signup
        TextButton(
          onPressed: () {
            setState(() {
              _showOtpVerification = false;
              _otpController.clear();
            });
          },
          child: Text(
            'Back to Sign Up',
            style: TextStyle(color: textSecondary),
          ),
        ),
      ],
    );
  }
}
