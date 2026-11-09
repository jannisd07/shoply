import 'package:shoply/presentation/screens/profile/settings_search_entry.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/routes/route_paths.dart';

/// Row ids of Profil bearbeiten (`?row=`, E18-14).
abstract final class ProfileEditRows {
  static const name = 'profile.name';
  static const photo = 'profile.photo';
  static const email = 'profile.email';
}

/// Row ids of Konto (`?row=`, E18-14).
abstract final class AccountRows {
  static const email = 'account.email';
  static const method = 'account.method';
  static const changeEmail = 'account.change_email';
  static const password = 'account.password';
  static const signOut = 'account.sign_out';
  static const delete = 'account.delete';
}

const List<String> _profilePath = ['acct_edit_title'];
const List<String> _accountPath = ['acct_title'];

/// Search entries of Profil bearbeiten and Konto (Konzept 18 §3.5): both
/// pages and every row, in both languages through translation keys. "löschen"
/// finds Konto › Konto löschen and Profil bearbeiten › Foto entfernen.
const List<SettingsSearchEntry> accountSearchEntries = [
  SettingsSearchEntry(
    route: RoutePaths.settingsProfile,
    titleKey: 'acct_edit_title',
    keywordsKeys: ['acct_kw_profile'],
    icon: AvoIcons.person,
  ),
  SettingsSearchEntry(
    route: RoutePaths.settingsProfile,
    titleKey: 'acct_name_section',
    pathKeys: _profilePath,
    keywordsKeys: ['acct_kw_name'],
    rowId: ProfileEditRows.name,
    icon: AvoIcons.person,
  ),
  SettingsSearchEntry(
    route: RoutePaths.settingsProfile,
    titleKey: 'acct_photo_change',
    pathKeys: _profilePath,
    keywordsKeys: ['acct_kw_photo'],
    rowId: ProfileEditRows.photo,
    icon: AvoIcons.person,
  ),
  SettingsSearchEntry(
    route: RoutePaths.settingsProfile,
    titleKey: 'acct_photo_remove',
    pathKeys: _profilePath,
    keywordsKeys: ['acct_kw_photo_remove'],
    rowId: ProfileEditRows.photo,
    icon: AvoIcons.person,
  ),
  SettingsSearchEntry(
    route: RoutePaths.settingsAccount,
    titleKey: 'acct_title',
    keywordsKeys: ['acct_kw_account'],
    icon: AvoIcons.person,
  ),
  SettingsSearchEntry(
    route: RoutePaths.settingsAccount,
    titleKey: 'acct_email',
    pathKeys: _accountPath,
    keywordsKeys: ['acct_kw_email'],
    rowId: AccountRows.email,
    icon: AvoIcons.person,
  ),
  SettingsSearchEntry(
    route: RoutePaths.settingsAccount,
    titleKey: 'acct_signed_in_with',
    pathKeys: _accountPath,
    keywordsKeys: ['acct_kw_method'],
    rowId: AccountRows.method,
    icon: AvoIcons.person,
  ),
  SettingsSearchEntry(
    route: RoutePaths.settingsAccount,
    titleKey: 'acct_change_email',
    pathKeys: _accountPath,
    keywordsKeys: ['acct_kw_email'],
    rowId: AccountRows.changeEmail,
    icon: AvoIcons.person,
  ),
  SettingsSearchEntry(
    route: RoutePaths.settingsAccount,
    titleKey: 'acct_password',
    pathKeys: _accountPath,
    keywordsKeys: ['acct_kw_password'],
    rowId: AccountRows.password,
    icon: AvoIcons.person,
  ),
  SettingsSearchEntry(
    route: RoutePaths.settingsAccount,
    titleKey: 'acct_sign_out',
    pathKeys: _accountPath,
    keywordsKeys: ['acct_kw_sign_out'],
    rowId: AccountRows.signOut,
    icon: AvoIcons.person,
  ),
  SettingsSearchEntry(
    route: RoutePaths.settingsAccount,
    titleKey: 'acct_delete',
    pathKeys: _accountPath,
    keywordsKeys: ['acct_kw_delete'],
    rowId: AccountRows.delete,
    icon: AvoIcons.person,
  ),
];
