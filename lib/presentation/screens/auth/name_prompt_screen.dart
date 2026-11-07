import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/mascot/avo_mascot.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

/// Shown once after a new account is created (`/name-prompt?new=1`) so the
/// user can pick the display name shown on shared lists.
class NamePromptScreen extends ConsumerStatefulWidget {
  const NamePromptScreen({super.key});

  @override
  ConsumerState<NamePromptScreen> createState() => _NamePromptScreenState();
}

class _NamePromptScreenState extends ConsumerState<NamePromptScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      final user = SupabaseService.instance.currentUser;
      if (user != null) {
        // Upsert (not update): right after sign-up the users row may not
        // exist yet.
        await SupabaseService.instance.client.from('users').upsert({
          'id': user.id,
          'email': user.email,
          'display_name': name,
          'auth_provider': user.appMetadata['provider'],
          'updated_at': DateTime.now().toIso8601String(),
        });
        ref.invalidate(currentUserProvider);
      }

      if (mounted) context.go('/home');
    } catch (e) {
      debugPrint('❌ [NAME_PROMPT] Failed to save name: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('generic_error'))),
        );
      }
    }
  }

  /// Skipping keeps the provider name (e.g. a Google full name) or leaves it
  /// empty; the router no longer requires a display name, so nothing is
  /// written.
  void _skip() {
    if (_isLoading) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : PaperColors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Avo mascot
              const AvoMascot(
                size: 120,
                expression: AvoExpression.waving,
                animate: true,
              ),

              const SizedBox(height: 32),

              // Speech bubble style greeting
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  context.tr('name_prompt_greeting'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : PaperColors.ink,
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Name input field
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : PaperColors.ink,
                ),
                decoration: InputDecoration(
                  hintText: context.tr('name_prompt_hint'),
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                onSubmitted: (_) => _saveName(),
              ),

              const SizedBox(height: 24),

              // Continue button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveName,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CupertinoActivityIndicator(
                          radius: 10,
                          color: Colors.white,
                        )
                      : Text(
                          context.tr('continue_text'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Skip button
              TextButton(
                onPressed: _skip,
                child: Text(
                  context.tr('skip'),
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 14,
                  ),
                ),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
