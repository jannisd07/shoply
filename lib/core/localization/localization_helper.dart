import 'package:flutter/material.dart';
import 'package:shoply/core/localization/app_translations.dart';

extension LocalizationExtension on BuildContext {
  String tr(String key, {Map<String, String>? params}) {
    // Get language from device locale
    final locale = Localizations.localeOf(this);
    final languageCode = locale.languageCode;
    return AppTranslations.get(key, languageCode, params: params);
  }
}
