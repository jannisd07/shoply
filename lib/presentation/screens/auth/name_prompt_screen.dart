import 'package:flutter/material.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/mascot/avo_mascot.dart';
import 'package:shoply/data/services/supabase_service.dart';

class NamePromptScreen extends StatefulWidget {
  const NamePromptScreen({super.key});

  @override
  State<NamePromptScreen> createState() => _NamePromptScreenState();
}

class _NamePromptScreenState extends State<NamePromptScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final user = SupabaseService.instance.currentUser;
      if (user != null) {
        await SupabaseService.instance.client.from('users').upsert({
          'id': user.id,
          'email': user.email,
          'display_name': name,
          'auth_provider': user.appMetadata['provider'],
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      debugPrint('Error saving name: $e');
      if (mounted) {
        context.go('/home');
      }
    }
  }

  Future<void> _skip() async {
    // Save "User" as display name so router doesn't redirect back
    try {
      final user = SupabaseService.instance.currentUser;
      if (user != null) {
        await SupabaseService.instance.client.from('users').upsert({
          'id': user.id,
          'email': user.email,
          'display_name': 'User',
          'auth_provider': user.appMetadata['provider'],
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Error saving default name: $e');
    }

    if (mounted) {
      context.go('/home');
    }
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
                  'Hey! Ich bin Avo 🥑\nWie darf ich dich nennen?',
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
                  hintText: 'Dein Name',
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
                      ? CupertinoActivityIndicator(
                          radius: 10,
                          color: Colors.white,
                        )
                      : const Text(
                          'Weiter',
                          style: TextStyle(
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
                  'Überspringen',
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
