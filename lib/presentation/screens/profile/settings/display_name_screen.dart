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

      ref.invalidate(currentUserProvider);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showProfilePictureOptions() {
    final user = ref.read(currentUserProvider).value;
    final backgroundColor = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final separatorColor = AppColors.divider(context);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('change_profile_picture'),
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _buildOptionRow(
                  label: context.tr('choose_from_gallery'),
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                Container(height: 0.5, color: separatorColor),
                _buildOptionRow(
                  label: context.tr('take_photo'),
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _pickImage(ImageSource.camera);
                  },
                ),
                if (user?.avatarUrl != null) ...[
                  Container(height: 0.5, color: separatorColor),
                  _buildOptionRow(
                    label: context.tr('remove_photo'),
                    textColor: CupertinoColors.systemRed,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    onTap: () {
                      Navigator.pop(dialogContext);
                      _deleteProfilePicture();
                    },
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(dialogContext),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Text(
                        context.tr('cancel'),
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionRow({
    required String label,
    required Color textPrimary,
    required Color textSecondary,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor ?? textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: textColor ?? textSecondary.withOpacity(0.4),
              size: 20,
            ),
          ],
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

      ref.invalidate(currentUserProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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

      ref.invalidate(currentUserProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveName,
            child: _isLoading
                ? CupertinoActivityIndicator(radius: 10, color: textPrimary)
                : Text(
                    context.tr('save'),
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: 100 + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            // Profile Picture
            Center(
              child: GestureDetector(
                onTap: _isUploadingImage ? null : _showProfilePictureOptions,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: inputFill,
                      backgroundImage: user?.avatarUrl != null
                          ? NetworkImage(user!.avatarUrl!)
                          : null,
                      child: _isUploadingImage
                          ? CupertinoActivityIndicator(color: textPrimary)
                          : user?.avatarUrl == null
                              ? Text(
                                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                )
                              : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.tr('change_profile_picture'),
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Name section
            _buildSectionHeader(context.tr('how_to_be_called'), textSecondary),
            Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 4),
              child: Text(
                context.tr('name_shown_to_others'),
                style: TextStyle(color: textSecondary, fontSize: 14),
              ),
            ),

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
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
