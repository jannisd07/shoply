import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/common/paper_settings.dart';
import 'package:shoply/presentation/state/language_provider.dart';

class LanguageScreen extends ConsumerStatefulWidget {
  const LanguageScreen({super.key});

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> {
  String _selectedLanguage = 'system';

  final List<Map<String, String>> _languages = [
    {'code': 'system', 'name': 'System'},
    {'code': 'de', 'name': 'Deutsch'},
    {'code': 'en', 'name': 'English'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedLanguage = ref.read(languageProvider.notifier).savedSetting;
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final separatorColor = AppColors.divider(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: PaperSettingsAppBar(title: context.tr('language')),
      body: ListView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 8,
          bottom: 60 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 24, left: 2),
            child: Text(
              context.tr('language_description'),
              style: TextStyle(
                color: textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),

          PaperSectionHeader(context.tr('language')),

          ...List.generate(_languages.length, (index) {
            final language = _languages[index];
            final isSelected = _selectedLanguage == language['code'];
            return Column(
              children: [
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedLanguage = language['code']!);
                    await ref.read(languageProvider.notifier).setLanguage(language['code']!);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                language['name']!,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  color: textPrimary,
                                ),
                              ),
                              if (language['code'] == 'system')
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    context.tr('follows_system_language'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: textSecondary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_rounded,
                            color: AppColors.accentColor(context),
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
                if (index < _languages.length - 1)
                  Container(height: 0.5, color: separatorColor),
              ],
            );
          }),
        ],
      ),
    );
  }
}
