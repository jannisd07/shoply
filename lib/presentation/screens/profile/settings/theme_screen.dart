import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/state/theme_provider.dart';

class ThemeScreen extends ConsumerStatefulWidget {
  const ThemeScreen({super.key});

  @override
  ConsumerState<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends ConsumerState<ThemeScreen> {
  ThemeMode _selectedTheme = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _selectedTheme = ref.read(themeModeProvider);
  }

  List<Map<String, dynamic>> _getThemes(BuildContext context) => [
    {'name': context.tr('light'), 'icon': Icons.light_mode, 'value': 'light'},
    {'name': context.tr('dark'), 'icon': Icons.dark_mode, 'value': 'dark'},
    {'name': context.tr('system'), 'icon': Icons.settings_brightness, 'value': 'system'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('theme')),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _getThemes(context).length,
        itemBuilder: (context, index) {
          final theme = _getThemes(context)[index];
          final themeValue = theme['value'] as String;
          final themeMode = themeValue == 'light' ? ThemeMode.light : 
                           themeValue == 'dark' ? ThemeMode.dark : ThemeMode.system;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: RadioListTile<ThemeMode>(
              title: Row(
                children: [
                  Icon(theme['icon'] as IconData, size: 24),
                  const SizedBox(width: 12),
                  Text(theme['name'] as String),
                ],
              ),
              subtitle: Text(_getThemeDescription(themeValue)),
              value: themeMode,
              groupValue: _selectedTheme,
              onChanged: (value) async {
                if (value != null) {
                  setState(() => _selectedTheme = value);
                  await ref.read(themeModeProvider.notifier).setThemeMode(value);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${context.tr('theme_changed_to')} "${theme['name']}"')),
                    );
                  }
                }
              },
              activeColor: Colors.blue,
            ),
          );
        },
      ),
    );
  }

  String _getThemeDescription(String value) {
    switch (value) {
      case 'light':
        return context.tr('light_mode');
      case 'dark':
        return context.tr('dark_mode');
      case 'system':
        return context.tr('follows_system');
      default:
        return '';
    }
  }
}
