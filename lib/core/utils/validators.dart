import 'package:shoply/core/localization/app_localizations.dart';
import 'package:shoply/core/localization/app_translations.dart';

/// Form validators. Messages follow the app language (the locale the
/// AppLocalizations delegate last loaded), so they can be used as plain
/// `validator:` tear-offs without a BuildContext.
class Validators {
  static String _tr(String key) =>
      AppTranslations.get(key, AppLocalizations.currentLanguageCode);

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// Validates email format. Surrounding whitespace (e.g. the trailing space
  /// iOS autocomplete inserts) is ignored; the auth calls trim as well.
  static String? validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return _tr('validation_email_required');
    if (!_emailRegex.hasMatch(email)) return _tr('validation_email_invalid');
    return null;
  }

  /// Validates password strength
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return _tr('validation_password_required');
    }
    if (value.length < 8) return _tr('validation_password_min_length');
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return _tr('validation_password_uppercase');
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return _tr('validation_password_number');
    }
    return null;
  }
}
