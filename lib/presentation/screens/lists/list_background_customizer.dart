import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shoply/core/constants/list_background_gradients.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/data/services/supabase_service.dart';

/// Background Customizer Modal for Shopping Lists (Prompt 5)
/// Supports: Colors, Gradients, and Images - all available to all users
class ListBackgroundCustomizer extends ConsumerStatefulWidget {
  final String listId;
  final String currentBackgroundType;
  final String? currentBackgroundValue;

  const ListBackgroundCustomizer({
    Key? key,
    required this.listId,
    required this.currentBackgroundType,
    this.currentBackgroundValue,
  }) : super(key: key);

  @override
  ConsumerState<ListBackgroundCustomizer> createState() =>
      _ListBackgroundCustomizerState();
}

class _ListBackgroundCustomizerState
    extends ConsumerState<ListBackgroundCustomizer>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  // Free color palette (10 colors)
  final List<Color> _freeColors = [
    Colors.black,
    Colors.white,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.pink,
    Colors.teal,
    Colors.amber,
  ];

  String? _selectedBackgroundType;
  String? _selectedBackgroundValue;
  File? _selectedImageFile;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedBackgroundType = widget.currentBackgroundType;
    _selectedBackgroundValue = widget.currentBackgroundValue;

    // Navigate to correct tab based on current type
    if (widget.currentBackgroundType == 'gradient') {
      _tabController.index = 1;
    } else if (widget.currentBackgroundType == 'image') {
      _tabController.index = 2;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Abbrechen'),
                ),
                const Text(
                  'Hintergrund anpassen',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: _isUploading ? null : _saveBackground,
                  child: const Text(
                    'Fertig',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Tab Bar
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).primaryColor,
            tabs: const [
              Tab(text: 'Farben', icon: Icon(Icons.palette)),
              Tab(text: 'Verläufe', icon: Icon(Icons.gradient)),
              Tab(text: 'Bilder', icon: Icon(Icons.image)),
            ],
          ),

          // Upload Progress
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  LinearProgressIndicator(value: _uploadProgress),
                  const SizedBox(height: 8),
                  Text(
                    'Wird hochgeladen... ${(_uploadProgress * 100).toInt()}%',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildColorsTab(),
                _buildGradientsTab(),
                _buildImagesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Colors Tab (FREE)
  Widget _buildColorsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Einfarbige Hintergründe',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Kostenlos verfügbar',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: _freeColors.length,
            itemBuilder: (context, index) {
              final color = _freeColors[index];
              final colorHex = '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
              final isSelected = _selectedBackgroundType == 'color' &&
                  _selectedBackgroundValue == colorHex;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedBackgroundType = 'color';
                    _selectedBackgroundValue = colorHex;
                    _selectedImageFile = null;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade300,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          // Color Picker (Advanced - could add flutter_colorpicker package)
          const Text(
            'Eigene Farbe auswählen',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Für eine größere Farbauswahl, verwende die Premium-Version.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // Gradients Tab (Available to all users)
  Widget _buildGradientsTab() {
    return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text(
                    'Premium-Verläufe',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.workspace_premium, color: Colors.amber, size: 20),
                ],
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.75,
                ),
                itemCount: ListBackgroundGradients.gradients.length,
                itemBuilder: (context, index) {
                  final entry =
                      ListBackgroundGradients.gradients.entries.elementAt(index);
                  final gradientId = entry.key;
                  final gradient = entry.value;
                  final gradientName = ListBackgroundGradients.getGradientName(gradientId);
                  final isSelected = _selectedBackgroundType == 'gradient' &&
                      _selectedBackgroundValue == gradientId;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedBackgroundType = 'gradient';
                        _selectedBackgroundValue = gradientId;
                        _selectedImageFile = null;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.transparent,
                          width: isSelected ? 3 : 0,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: Theme.of(context).primaryColor.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Gradient name overlay
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                              ),
                              child: Text(
                                gradientName ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          // Check icon for selected
                          if (isSelected)
                            const Center(
                              child: Icon(Icons.check_circle,
                                  color: Colors.white, size: 32),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
  }

  // Images Tab (Available to all users)
  Widget _buildImagesTab() {
    return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text(
                    'Eigenes Bild hochladen',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.workspace_premium, color: Colors.amber, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Maximale Dateigröße: 5 MB',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // Image Preview
              if (_selectedImageFile != null)
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: FileImage(_selectedImageFile!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

              if (_selectedImageFile != null) const SizedBox(height: 16),

              // Upload Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Kamera'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Galerie'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Text(
                'Hinweis:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Das Bild wird automatisch komprimiert\n'
                '• Unterstützte Formate: JPG, PNG\n'
                '• Das Bild wird auf allen Geräten synchronisiert',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        );
  }

  // Pick Image
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      final File imageFile = File(pickedFile.path);

      // Check file size
      final fileSize = await imageFile.length();
      if (fileSize > 5 * 1024 * 1024) {
        // 5 MB
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bild ist zu groß. Maximale Größe: 5 MB'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Compress image
      final compressedFile = await _compressImage(imageFile);

      setState(() {
        _selectedImageFile = compressedFile;
        _selectedBackgroundType = 'image';
        _selectedBackgroundValue = null; // Will be set after upload
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Laden des Bildes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Compress Image
  Future<File> _compressImage(File file) async {
    // Read image
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) return file;

    // Resize if too large
    img.Image resized = image;
    if (image.width > 1920 || image.height > 1920) {
      resized = img.copyResize(
        image,
        width: image.width > image.height ? 1920 : null,
        height: image.height > image.width ? 1920 : null,
      );
    }

    // Compress as JPEG
    final compressedBytes = img.encodeJpg(resized, quality: 85);

    // Write to new file
    final compressedFile = File('${file.path}_compressed.jpg');
    await compressedFile.writeAsBytes(compressedBytes);

    return compressedFile;
  }

  // Save Background
  Future<void> _saveBackground() async {
    if (_selectedBackgroundType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte wähle einen Hintergrund aus'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      String? imageUrl;

      // Upload image if selected
      if (_selectedBackgroundType == 'image' && _selectedImageFile != null) {
        imageUrl = await _uploadImageToSupabase(_selectedImageFile!);
      }

      // Save to database
      await ref.read(listsNotifierProvider.notifier).saveBackground(
            widget.listId,
            _selectedBackgroundType!,
            _selectedBackgroundValue,
            imageUrl,
          );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hintergrund gespeichert'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  // Upload Image to Supabase Storage
  Future<String> _uploadImageToSupabase(File imageFile) async {
    final supabase = SupabaseService.instance.client;
    final userId = SupabaseService.instance.currentUser?.id;

    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Generate unique filename
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${userId}_${widget.listId}_$timestamp.jpg';

    // Upload to storage bucket 'list-backgrounds'
    await supabase.storage.from('list-backgrounds').uploadBinary(
          fileName,
          await imageFile.readAsBytes(),
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    // Update progress
    setState(() {
      _uploadProgress = 0.9;
    });

    // Get public URL
    final publicUrl =
        supabase.storage.from('list-backgrounds').getPublicUrl(fileName);

    setState(() {
      _uploadProgress = 1.0;
    });

    return publicUrl;
  }
}
