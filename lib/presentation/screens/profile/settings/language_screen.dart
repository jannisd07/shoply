import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/presentation/state/language_provider.dart';
import 'package:shoply/core/localization/localization_helper.dart';

class LanguageScreen extends ConsumerStatefulWidget {
  const LanguageScreen({super.key});

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> {
  String _selectedLanguage = 'de';

  final List<Map<String, String>> _languages = [
    {'code': 'de', 'name': 'Deutsch'},
    {'code': 'en', 'name': 'English'},
    {'code': 'es', 'name': 'Español'},
    {'code': 'fr', 'name': 'Français'},
    {'code': 'it', 'name': 'Italiano'},
    {'code': 'tr', 'name': 'Türkçe'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedLanguage = ref.read(languageProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('language')),
      ),
      body: ListView.builder(
        itemCount: _languages.length,
        itemBuilder: (context, index) {
          final language = _languages[index];
          final isSelected = _selectedLanguage == language['code'];

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.1)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: RadioListTile<String>(
              title: Row(
                children: [
                  Icon(
                    Icons.language_rounded,
                    size: 22,
                    color: isSelected
                        ? Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black
                        : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    language['name']!,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black
                          : null,
                    ),
                  ),
                ],
              ),
            value: language['code']!,
            groupValue: _selectedLanguage,
            onChanged: (value) async {
              setState(() => _selectedLanguage = value!);
              await ref.read(languageProvider.notifier).setLanguage(value!);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Sprache auf ${language['name']} geändert')),
                );
              }
            },
              activeColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        },
      ),
    );
  }
}
