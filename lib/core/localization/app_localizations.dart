import 'package:flutter/material.dart';
import 'package:shoply/core/localization/app_translations.dart';

/// Localizations delegate plus a few typed getters still used by the list
/// detail and home screens. New code should use `context.tr(...)` from
/// localization_helper.dart instead of adding getters here.
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en', ''), // English (default)
    Locale('de', ''), // German
  ];

  String _get(String key) => AppTranslations.get(key, locale.languageCode);
  String _getWithParams(String key, Map<String, String> params) =>
      AppTranslations.get(key, locale.languageCode, params: params);

  // Common
  String get cancel => _get('cancel');
  String get save => _get('save');

  // Lists
  String get emptyList => _get('empty_list');

  // Items
  String get itemName => _get('item_name');
  String get quantity => _get('quantity');
  String get notes => _get('notes');
  String get addItem => _get('add_item');
  String get editItem => _get('edit_item');
  String get completeShopping => _get('complete_shopping');

  // Delete confirmation
  String get deleteListTitle => _get('delete_list_title');
  String deleteListMessage(String listName) =>
      _getWithParams('delete_list_message', {'listName': listName});
  String get deleteConfirm => _get('delete_confirm');

  // Sharing
  String get share => _get('share');
  String get copy => _get('copy');
  String get copyAndContinue => _get('copy_and_continue');
  String get shareDialogTitle => _get('share_dialog_title');
  String shareDialogMessage(String code) =>
      _getWithParams('share_dialog_message', {'code': code});
  String get shareCodeTitle => _get('share_code_title');
  String get shareCodeMessage => _get('share_code_message');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'de'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
