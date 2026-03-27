import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/constants/app_text_styles.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/core/utils/category_detector.dart';

class ListBackgroundSelectionScreen extends ConsumerWidget {
  const ListBackgroundSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(listsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste auswählen', style: AppTextStyles.h2),
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
        child: listsAsync.when(
          data: (lists) {
            if (lists.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Keine Listen vorhanden',
                      style: AppTextStyles.h3.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Erstelle zuerst eine Liste',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(AppDimensions.paddingMedium),
              children: [
                Text(
                  'Wähle eine Liste aus, um einen Hintergrund festzulegen',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ...lists.map((list) => _buildListItem(
                      context,
                      list.name,
                      list.id,
                      CategoryDetector.getCategoryIcon(list.name),
                      CategoryDetector.getCategoryColor(list.name),
                    )),
              ],
            );
          },
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, stack) => Center(
            child: Text('Fehler: $error'),
          ),
        ),
      ),
    );
  }

  Widget _buildListItem(
    BuildContext context,
    String name,
    String listId,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(name, style: AppTextStyles.h3),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
        onTap: () {
          context.push('/background-picker/$listId');
        },
      ),
    );
  }
}
