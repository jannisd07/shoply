import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/data/services/profile_picture_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/core/localization/localization_helper.dart';

class DisplayNameScreen extends ConsumerStatefulWidget {
  const DisplayNameScreen({super.key});

  @override
  ConsumerState<DisplayNameScreen> createState() => _DisplayNameScreenState();
}

class _DisplayNameScreenState extends ConsumerState<DisplayNameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider).value;
    _nameController.text = user?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.updateDisplayName(_nameController.text.trim());
      
      // Refresh user data
      ref.invalidate(currentUserProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('name_updated')),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showProfilePictureOptions() {
    final user = ref.read(currentUserProvider).value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: Text(context.tr('choose_from_gallery')),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: Text(context.tr('take_photo')),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              if (user?.avatarUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete_rounded, color: Colors.red),
                  title: Text(
                    context.tr('remove_photo'),
                    style: const TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteProfilePicture();
                  },
                ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: isDark 
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      context.tr('cancel'),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, maxWidth: 512, maxHeight: 512);
    
    if (image != null) {
      await _uploadProfilePicture(image.path);
    }
  }

  Future<void> _uploadProfilePicture(String filePath) async {
    setState(() => _isUploadingImage = true);
    
    try {
      final service = ProfilePictureService();
      await service.uploadProfilePicture(filePath);
      
      // Refresh user data
      ref.invalidate(currentUserProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('profile_picture_updated')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _deleteProfilePicture() async {
    setState(() => _isUploadingImage = true);
    
    try {
      final service = ProfilePictureService();
      await service.deleteProfilePicture();
      
      // Refresh user data
      ref.invalidate(currentUserProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('profile_picture_removed')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final displayName = user?.displayName ?? 'User';
    final backgroundColor = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final inputFill = AppColors.inputFill(context);
    final borderColor = AppColors.border(context);
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.tr('profile'),
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 100 + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            // Profile Picture Section
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _isUploadingImage ? null : _showProfilePictureOptions,
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: inputFill,
                      backgroundImage: user?.avatarUrl != null
                          ? NetworkImage(user!.avatarUrl!)
                          : null,
                      child: _isUploadingImage
                          ? CupertinoActivityIndicator(color: AppColors.accent)
                          : user?.avatarUrl == null
                              ? Text(
                                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                )
                              : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _isUploadingImage ? null : _showProfilePictureOptions,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: backgroundColor,
                            width: 3,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Tap to change text
            Center(
              child: TextButton(
                onPressed: _isUploadingImage ? null : _showProfilePictureOptions,
                child: Text(
                  context.tr('change_profile_picture'),
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Divider
            Divider(color: borderColor),
            
            const SizedBox(height: 16),
            
            Text(
              context.tr('how_to_be_called'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('name_shown_to_others'),
              style: TextStyle(color: textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            
            // Name input field
            Container(
              decoration: BoxDecoration(
                color: inputFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: TextFormField(
                controller: _nameController,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  hintText: context.tr('display_name'),
                  hintStyle: TextStyle(color: textSecondary),
                  prefixIcon: Icon(Icons.person_rounded, color: textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.tr('enter_name');
                  }
                  if (value.trim().length < 2) {
                    return context.tr('name_too_short');
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 24),
            
            // Save button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveName,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? CupertinoActivityIndicator(radius: 10, color: Colors.white)
                    : Text(
                        context.tr('save'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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
