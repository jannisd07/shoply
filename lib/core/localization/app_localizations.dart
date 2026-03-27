import 'package:flutter/material.dart';
import 'package:shoply/core/localization/app_translations.dart';

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

  // Helper to get string from AppTranslations
  String _get(String key) => AppTranslations.get(key, locale.languageCode);
  String _getWithParams(String key, Map<String, String> params) => 
      AppTranslations.get(key, locale.languageCode, params: params);

  // Common
  String get appName => 'Shoply';
  String get cancel => _get('cancel');
  String get save => _get('save');
  String get delete => _get('delete');
  String get edit => _get('edit');
  String get add => _get('add');
  String get search => _get('search');
  String get loading => _get('loading');
  String get error => _get('error');
  String get yes => _get('yes');
  String get no => _get('no');

  // Lists
  String get myLists => _get('my_lists');
  String get createList => _get('create_list');
  String get listName => _get('list_name');
  String get shareList => _get('share_list');
  String get deleteList => _get('delete_list');
  String get emptyList => _get('empty_list');

  // Items
  String get itemName => _get('item_name');
  String get quantity => _get('quantity');
  String get unit => _get('unit');
  String get notes => _get('notes');
  String get addItem => _get('add_item');
  String get editItem => _get('edit_item');
  String get deleteItem => _get('delete_item');
  String get completeShopping => _get('complete_shopping');

  // Categories
  String get category => _get('category');
  String get sortByCategory => _get('sort_by_category');
  String get sortAlphabetically => _get('sort_alphabetically');
  String get sortByQuantity => _get('sort_by_quantity');
  String get customSort => _get('custom_sort');

  // What's New
  String get whatsNewTitle => _get('whats_new_title');
  String get whatsNewSubtitle => _get('whats_new_subtitle');
  String get getStarted => _get('get_started');
  String get forInternalTesters => _get('for_internal_testers');

  // Delete confirmation
  String get deleteListTitle => _get('delete_list_title');
  String deleteListMessage(String listName) => _getWithParams('delete_list_message', {'listName': listName});
  String get deleteConfirm => _get('delete_confirm');

  // Sharing
  String get share => _get('share');
  String get showCode => _get('show_code');
  String get copy => _get('copy');
  String get copyAndContinue => _get('copy_and_continue');
  String get shareDialogTitle => _get('share_dialog_title');
  String shareDialogMessage(String code) => _getWithParams('share_dialog_message', {'code': code});
  String get shareCodeTitle => _get('share_code_title');
  String get shareCodeMessage => _get('share_code_message');
  
  // Home Screen
  String get selectList => _get('select_list');
  String addItemsCount(int count) => _getWithParams('add_items_count', {'count': count.toString()});
  String get noListsAvailable => _get('no_lists_available');
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
