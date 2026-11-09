// Texte des Bereichs "profile" (Teil A), Teil "Konto" (Profil bearbeiten, Konto, Abmelden, Konto löschen), Deutsch und Englisch.
// Eigene Datei während A8, damit parallele Arbeiten nicht dieselbe Datei
// ändern; wird nach A8 zusammengeführt. Präfix: acct_. Neue Texte sagen "Avo", nie "Shoply".

const Map<String, String> settingsAccountEn = {
  // Profil bearbeiten (Konzept 18 §4)
  'acct_edit_title': 'Edit profile',
  'acct_photo_label': 'Profile photo',
  'acct_photo_change': 'Change photo',
  'acct_photo_choose': 'Choose photo',
  'acct_photo_take': 'Take photo',
  'acct_photo_take_hint': 'Asks once for the camera',
  'acct_photo_remove': 'Remove photo',
  'acct_photo_removed': 'Photo removed',
  'acct_photo_uploading': 'Uploading',
  'acct_photo_upload_failed': 'Photo not uploaded.',
  'acct_photo_remove_failed': 'Photo not removed.',
  'acct_camera_off': 'Camera is off.',
  'acct_allow_in_settings': 'Allow in Settings',
  'acct_name_section': 'Name',
  'acct_name_placeholder': 'Your name',
  'acct_name_footer':
      'This is how others see you in shared lists and on your recipes.',
  'acct_name_too_short': 'At least 2 characters.',
  'acct_name_not_changed': 'Name not changed: too short',
  'acct_name_waiting': 'Saved on this iPhone, sent once you are online',
  'acct_email_section': 'Email',
  'acct_email_footer': 'You can change it under Account.',

  // Konto (§7.1)
  'acct_title': 'Account',
  'acct_email': 'Email',
  'acct_signed_in_with': 'Signed in with',
  'acct_method_apple': 'Apple',
  'acct_method_google': 'Google',
  'acct_method_email': 'Email',
  'acct_change_email': 'Change email',
  'acct_password': 'Password',
  'acct_password_set': 'Set',
  'acct_password_not_set': 'Not set',
  'acct_delete': 'Delete account',
  'acct_delete_footer': 'Deletes your account and your data for good.',

  // Abmelden (§7.2)
  'acct_sign_out': 'Sign out',
  'acct_signing_out': 'Signing out',
  'acct_sign_out_title': 'Sign out?',
  'acct_sign_out_unsent':
      '{n} changes haven’t been sent yet and will be lost if you sign out now.',
  'acct_sign_out_unsent_one':
      '1 change hasn’t been sent yet and will be lost if you sign out now.',

  // Konto löschen (§7.3)
  'acct_delete_intro':
      'Your account and everything that only belongs to you will be deleted for good. This can’t be undone.',
  'acct_delete_what': 'What gets deleted',
  'acct_delete_lists': '{n} lists that only belong to you',
  'acct_delete_lists_one': '1 list that only belongs to you',
  'acct_delete_recipes': '{n} of your own recipes',
  'acct_delete_recipes_one': '1 of your own recipes',
  'acct_delete_recipes_unknown': 'Your recipes',
  'acct_delete_history': 'History with {n} shopping trips',
  'acct_delete_history_one': 'History with 1 shopping trip',
  'acct_delete_history_unknown': 'Your history',
  'acct_delete_profile': 'Profile, photo and settings',
  'acct_delete_calories': 'Calorie diary',
  'acct_delete_calories_off': 'Calorie diary (turned off)',
  'acct_delete_health_footer': 'Data in Apple Health stays in Health.',
  'acct_delete_shared': 'Shared lists',
  'acct_delete_handover': '{list} goes to {name}.',
  'acct_delete_handover_someone': '{list} goes to another member.',
  'acct_delete_leave':
      'You leave {n} shared lists. What you added there stays for the others, without your name.',
  'acct_delete_leave_one':
      'You leave 1 shared list. What you added there stays for the others, without your name.',
  'acct_delete_pro':
      'Your Avo Pro subscription keeps running until you cancel it with Apple.',
  'acct_delete_pro_renews':
      'Your Avo Pro subscription keeps running until you cancel it with Apple. It renews on {date}.',
  'acct_manage_subscription': 'Manage subscription',
  'acct_delete_balances':
      '{n} open amounts will be marked as settled for the others.',
  'acct_delete_balances_one':
      '1 open amount will be marked as settled for the others.',
  'acct_deleting': 'Deleting',
  'acct_needs_connection': 'Needs a connection.',
  'acct_delete_failed': 'Deleting didn’t work. Nothing was deleted.',
  'acct_confirm_failed': 'Confirming didn’t work. Nothing was deleted.',
  'acct_other_account': 'That was a different account. Nothing was deleted.',
  'acct_delete_confirm_title': 'Delete account for good?',
  'acct_delete_confirm_named':
      '{name}, your account and your data will be deleted.',
  'acct_delete_confirm_plain': 'Your account and your data will be deleted.',
  'acct_delete_confirm_action': 'Delete',
  'acct_deleted': 'Your account has been deleted.',
  'acct_reauth_title': 'Confirm it’s you',
  'acct_reauth_message': 'We sent a code to {email}.',

  // E-Mail ändern, Passwort (§7.1, Konzept 17 §3.7, §4.4)
  'acct_new_email_title': 'New email address',
  'acct_new_email_message':
      'We’ll send a code to the new address. From then on you sign in with it.',
  'acct_email_same': 'That’s already your address.',
  'acct_email_taken': 'This address already belongs to another account.',
  'acct_email_changed': 'Email changed.',
  'acct_password_title_set': 'Set a password',
  'acct_password_title_change': 'Change password',
  'acct_password_message':
      'Then you can also sign in with your email and password, without a code.',
  'acct_password_saved': 'Password saved.',

  // Suche (Konzept 18 §3.5)
  'acct_kw_profile': 'name, photo, picture, profile picture, avatar',
  'acct_kw_name': 'name, display name, nickname',
  'acct_kw_photo': 'photo, picture, profile picture, avatar, camera',
  'acct_kw_photo_remove': 'delete, remove, remove photo',
  'acct_kw_account': 'account, login, sign in',
  'acct_kw_email': 'email, address, mail',
  'acct_kw_method': 'Apple, Google, sign in, login',
  'acct_kw_password': 'password',
  'acct_kw_sign_out': 'sign out, log out, logout',
  'acct_kw_delete': 'delete, delete account, delete data, GDPR',
};

const Map<String, String> settingsAccountDe = {
  // Profil bearbeiten (Konzept 18 §4)
  'acct_edit_title': 'Profil bearbeiten',
  'acct_photo_label': 'Profilfoto',
  'acct_photo_change': 'Foto ändern',
  'acct_photo_choose': 'Foto auswählen',
  'acct_photo_take': 'Foto aufnehmen',
  'acct_photo_take_hint': 'Fragt einmal nach der Kamera',
  'acct_photo_remove': 'Foto entfernen',
  'acct_photo_removed': 'Foto entfernt',
  'acct_photo_uploading': 'Wird hochgeladen',
  'acct_photo_upload_failed': 'Foto nicht hochgeladen.',
  'acct_photo_remove_failed': 'Foto nicht entfernt.',
  'acct_camera_off': 'Kamera ist aus.',
  'acct_allow_in_settings': 'In Einstellungen erlauben',
  'acct_name_section': 'Name',
  'acct_name_placeholder': 'Dein Name',
  'acct_name_footer':
      'So sehen dich andere in geteilten Listen und bei deinen Rezepten.',
  'acct_name_too_short': 'Mindestens 2 Zeichen.',
  'acct_name_not_changed': 'Name nicht geändert: zu kurz',
  'acct_name_waiting':
      'Auf diesem iPhone gespeichert, wird gesendet, sobald du online bist',
  'acct_email_section': 'E-Mail',
  'acct_email_footer': 'Ändern kannst du sie unter Konto.',

  // Konto (§7.1)
  'acct_title': 'Konto',
  'acct_email': 'E-Mail',
  'acct_signed_in_with': 'Angemeldet mit',
  'acct_method_apple': 'Apple',
  'acct_method_google': 'Google',
  'acct_method_email': 'E-Mail',
  'acct_change_email': 'E-Mail ändern',
  'acct_password': 'Passwort',
  'acct_password_set': 'Festgelegt',
  'acct_password_not_set': 'Nicht festgelegt',
  'acct_delete': 'Konto löschen',
  'acct_delete_footer': 'Löscht dein Konto und deine Daten endgültig.',

  // Abmelden (§7.2)
  'acct_sign_out': 'Abmelden',
  'acct_signing_out': 'Wird abgemeldet',
  'acct_sign_out_title': 'Abmelden?',
  'acct_sign_out_unsent':
      '{n} Änderungen sind noch nicht gesendet und gehen verloren, wenn du dich jetzt abmeldest.',
  'acct_sign_out_unsent_one':
      '1 Änderung ist noch nicht gesendet und geht verloren, wenn du dich jetzt abmeldest.',

  // Konto löschen (§7.3)
  'acct_delete_intro':
      'Dein Konto und alles, was nur dir gehört, wird endgültig gelöscht. Das lässt sich nicht rückgängig machen.',
  'acct_delete_what': 'Was gelöscht wird',
  'acct_delete_lists': '{n} Listen, die nur dir gehören',
  'acct_delete_lists_one': '1 Liste, die nur dir gehört',
  'acct_delete_recipes': '{n} eigene Rezepte',
  'acct_delete_recipes_one': '1 eigenes Rezept',
  'acct_delete_recipes_unknown': 'Deine Rezepte',
  'acct_delete_history': 'Verlauf mit {n} Einkäufen',
  'acct_delete_history_one': 'Verlauf mit 1 Einkauf',
  'acct_delete_history_unknown': 'Dein Verlauf',
  'acct_delete_profile': 'Profil, Foto und Einstellungen',
  'acct_delete_calories': 'Kalorien-Tagebuch',
  'acct_delete_calories_off': 'Kalorien-Tagebuch (ausgeschaltet)',
  'acct_delete_health_footer': 'Daten in Apple Health bleiben in Health.',
  'acct_delete_shared': 'Geteilte Listen',
  'acct_delete_handover': '{list} geht an {name} über.',
  'acct_delete_handover_someone': '{list} geht an ein anderes Mitglied über.',
  'acct_delete_leave':
      'Du verlässt {n} geteilte Listen. Was du dort hinzugefügt hast, bleibt für die anderen ohne deinen Namen.',
  'acct_delete_leave_one':
      'Du verlässt 1 geteilte Liste. Was du dort hinzugefügt hast, bleibt für die anderen ohne deinen Namen.',
  'acct_delete_pro':
      'Dein Avo-Pro-Abo läuft weiter, bis du es bei Apple kündigst.',
  'acct_delete_pro_renews':
      'Dein Avo-Pro-Abo läuft weiter, bis du es bei Apple kündigst. Es verlängert sich am {date}.',
  'acct_manage_subscription': 'Abo verwalten',
  'acct_delete_balances':
      '{n} offene Beträge werden für die anderen als beglichen markiert.',
  'acct_delete_balances_one':
      '1 offener Betrag wird für die anderen als beglichen markiert.',
  'acct_deleting': 'Wird gelöscht',
  'acct_needs_connection': 'Braucht eine Verbindung.',
  'acct_delete_failed':
      'Das Löschen hat nicht geklappt. Es wurde nichts gelöscht.',
  'acct_confirm_failed':
      'Die Bestätigung hat nicht geklappt. Es wurde nichts gelöscht.',
  'acct_other_account': 'Das war ein anderes Konto. Es wurde nichts gelöscht.',
  'acct_delete_confirm_title': 'Konto endgültig löschen?',
  'acct_delete_confirm_named':
      '{name}, dein Konto und deine Daten werden gelöscht.',
  'acct_delete_confirm_plain': 'Dein Konto und deine Daten werden gelöscht.',
  'acct_delete_confirm_action': 'Löschen',
  'acct_deleted': 'Dein Konto wurde gelöscht.',
  'acct_reauth_title': 'Bestätige, dass du es bist',
  'acct_reauth_message': 'Wir haben dir einen Code an {email} geschickt.',

  // E-Mail ändern, Passwort (§7.1, Konzept 17 §3.7, §4.4)
  'acct_new_email_title': 'Neue E-Mail-Adresse',
  'acct_new_email_message':
      'Wir schicken einen Code an die neue Adresse. Danach meldest du dich mit ihr an.',
  'acct_email_same': 'Das ist schon deine Adresse.',
  'acct_email_taken': 'Diese Adresse gehört schon zu einem anderen Konto.',
  'acct_email_changed': 'E-Mail geändert.',
  'acct_password_title_set': 'Passwort festlegen',
  'acct_password_title_change': 'Passwort ändern',
  'acct_password_message':
      'Dann kannst du dich auch mit E-Mail und Passwort anmelden, ohne Code.',
  'acct_password_saved': 'Passwort gespeichert.',

  // Suche (Konzept 18 §3.5)
  'acct_kw_profile': 'Name, Foto, Bild, Profilbild, Avatar',
  'acct_kw_name': 'Name, Anzeigename, Spitzname',
  'acct_kw_photo': 'Foto, Bild, Profilbild, Avatar, Kamera',
  'acct_kw_photo_remove': 'löschen, entfernen, Foto entfernen',
  'acct_kw_account': 'Konto, Account, Anmeldung, Login',
  'acct_kw_email': 'E-Mail, Adresse, Mail',
  'acct_kw_method': 'Apple, Google, Anmeldung, Login',
  'acct_kw_password': 'Passwort, Kennwort',
  'acct_kw_sign_out': 'abmelden, ausloggen, Logout',
  'acct_kw_delete': 'löschen, Konto löschen, Daten löschen, DSGVO',
};
