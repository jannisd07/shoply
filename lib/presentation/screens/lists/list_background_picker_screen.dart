import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/constants/app_text_styles.dart';
import 'package:shoply/core/constants/list_background_gradients.dart';
import 'package:shoply/presentation/state/lists_provider.dart';

class ListBackgroundPickerScreen extends ConsumerStatefulWidget {
  final String listId;
  
  const ListBackgroundPickerScreen({
    super.key,
    required this.listId,
  });

  @override
  ConsumerState<ListBackgroundPickerScreen> createState() =>
      _ListBackgroundPickerScreenState();
}

class _ListBackgroundPickerScreenState
    extends ConsumerState<ListBackgroundPickerScreen> {
  
  String? selectedBackground;

  List<_BackgroundOption> get backgrounds {
    return ListBackgroundGradients.gradients.entries.map((entry) {
      return _BackgroundOption(
        id: entry.key,
        name: ListBackgroundGradients.getGradientName(entry.key) ?? entry.key,
        gradient: entry.value,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hintergrund wählen', style: AppTextStyles.h2),
        actions: [
          if (selectedBackground != null)
            TextButton(
              onPressed: _saveBackground,
              child: const Text(
                'Speichern',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1C1C1E)
                  : Colors.grey.shade50,
              Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2C2C2E)
                  : Colors.white,
            ],
          ),
        ),
        child: GridView.builder(
          padding: const EdgeInsets.all(AppDimensions.paddingMedium),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.75,
          ),
          itemCount: backgrounds.length,
          itemBuilder: (context, index) {
            final background = backgrounds[index];
            final isSelected = selectedBackground == background.id;
            
            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedBackground = background.id;
                });
              },
              child: Stack(
                children: [
                  // Background Preview
                  Container(
                    decoration: BoxDecoration(
                      gradient: background.gradient,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected 
                            ? Colors.white 
                            : Colors.white.withValues(alpha: 0.3),
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.6),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                          child: Text(
                            background.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Selection Checkmark
                  if (isSelected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.green,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _saveBackground() async {
    if (selectedBackground == null) return;
    
    try {
      // Save background using unified method
      await ref
          .read(listsNotifierProvider.notifier)
          .saveBackground(widget.listId, 'gradient', selectedBackground!, null);
      
      if (!mounted) return;
      
      // Navigate back to home
      context.go('/home');
      
      // Success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hintergrund erfolgreich gespeichert!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      // Error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Speichern: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _BackgroundOption {
  final String id;
  final String name;
  final LinearGradient gradient;

  const _BackgroundOption({
    required this.id,
    required this.name,
    required this.gradient,
  });
}
