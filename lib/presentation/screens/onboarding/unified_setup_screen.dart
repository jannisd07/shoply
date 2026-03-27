import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/mascot/avo_mascot.dart';
import 'package:shoply/data/services/supabase_service.dart';

class UnifiedSetupScreen extends StatefulWidget {
  const UnifiedSetupScreen({super.key});

  @override
  State<UnifiedSetupScreen> createState() => _UnifiedSetupScreenState();
}

class _UnifiedSetupScreenState extends State<UnifiedSetupScreen> {
  bool _isLoading = false;
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canContinue {
    return _nameController.text.trim().length >= 2;
  }

  Future<void> _saveAndComplete() async {
    if (!_canContinue) return;

    setState(() => _isLoading = true);

    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Save only the display name - no demographic data
      await SupabaseService.instance.client.from('users').upsert({
        'id': user.id,
        'email': user.email,
        'display_name': _nameController.text.trim(),
        'onboarding_completed': true,
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ [SETUP] Onboarding completed, navigating to home');
      
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      debugPrint('❌ [SETUP] Error saving: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
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

  // Design constants matching login screen
  static const _backgroundColor = Color(0xFF121212);
  static const _inputFillColor = Color(0xFF2C2C2E);
  static const _inputBorderColor = Color(0xFF3A3A3C);
  static const _buttonColor = Color(0xFF4A4A4A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: _inputFillColor,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/welcome');
                  }
                },
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Content
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.screenHorizontalPadding,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),

                    // Mascot greeting
                    Center(
                      child: AvoMascot(
                        size: 100,
                        expression: AvoExpression.waving,
                        message: 'Hey there! I\'m $avoName! 🥑',
                        animate: true,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Title
                    const Text(
                      'What should we call you?',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 48),

                    // Name Field
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: InputDecoration(
                        labelText: 'Your Name',
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        hintText: 'e.g. John',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        filled: true,
                        fillColor: _inputFillColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: _inputBorderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: _inputBorderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.white54),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                      onFieldSubmitted: (_) {
                        if (_canContinue) _saveAndComplete();
                      },
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'This helps personalize your experience',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            // Continue button
            Padding(
              padding: const EdgeInsets.all(AppDimensions.screenHorizontalPadding),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (_canContinue && !_isLoading) ? _saveAndComplete : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _buttonColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _buttonColor.withOpacity(0.5),
                    disabledForegroundColor: Colors.white.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? CupertinoActivityIndicator(radius: 10, color: Colors.white)
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
