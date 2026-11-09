// Texte des Bereichs "auth" (Teil A), Teil "Konto" (Konto, E-Mail, Code, Name, Anmelden, Passwort, Fehler), Deutsch und Englisch.
// Eigene Datei während A7, damit parallele Arbeiten nicht dieselbe Datei
// ändern; wird nach A7 zusammengeführt. Präfix: auth_. Neue Texte sagen "Avo", nie "Shoply".
// Konzept 17 §3.5–3.8, §4.1–4.6. Vorhandene Schlüssel, die hier benutzt
// werden: back, cancel, continue_text, retry, skip.

const Map<String, String> authFlowEn = {
  // Konto (3.5) und Anmelden (4.1)
  'auth_account_title': 'Create an account',
  'auth_account_message':
      'So your lists are on all your devices and you can share them with others. If you already have an account, you sign in here the same way.',
  'auth_login_title': 'Sign in',
  'auth_login_message': 'Use the same method as the first time.',
  'auth_continue_apple': 'Continue with Apple',
  'auth_continue_google': 'Continue with Google',
  'auth_continue_email': 'Continue with email',
  'auth_use_password': 'Sign in with password',
  'auth_legal_notice':
      'By continuing you accept the terms of use and the privacy notice.',
  'auth_terms': 'Terms of use',
  'auth_privacy': 'Privacy notice',
  'auth_signing_in': 'Signing in',
  'auth_offline_keeps_choice':
      'Offline. You need a connection to sign in. Your choices stay saved.',

  // E-Mail (3.6)
  'auth_email_title': 'Your email address',
  'auth_email_message':
      'We’ll send you a 6-digit code. You don’t need a password for it.',
  'auth_email_placeholder': 'name@example.com',
  'auth_email_label': 'Email address',
  'auth_send_code': 'Send code',
  'auth_sending': 'Sending',
  'auth_offline_send_code':
      'Offline. You need a connection to send the code.',

  // Code (3.7)
  'auth_code_title': 'Enter the code',
  'auth_code_title_reset': 'Code to reset',
  'auth_code_sent_to': 'We sent it to {email}.',
  'auth_code_sent_if_account':
      'If there’s an account for {email}, the code is on its way.',
  'auth_code_label': 'Code from the email',
  'auth_code_spam': 'No email? Check your spam folder.',
  'auth_code_resend': 'Send a new code',
  'auth_code_resend_in': 'New code in {time}',
  'auth_code_resent': 'A new code is on its way.',
  'auth_code_change_email': 'Change address',
  'auth_code_confirm': 'Confirm',
  'auth_code_checking': 'Checking',
  'auth_offline_code_waits':
      'Offline. The code is checked as soon as you’re back online.',

  // Name (3.8)
  'auth_name_title': 'What’s your name?',
  'auth_name_message': 'This is how others see you in shared lists.',
  'auth_name_placeholder': 'First name',
  'auth_name_not_saved': 'Your name isn’t saved yet.',

  // Mit Passwort anmelden (4.2)
  'auth_email_field': 'Email',
  'auth_password_field': 'Password',
  'auth_password_placeholder': 'Required',
  'auth_show_password': 'Show password',
  'auth_hide_password': 'Hide password',
  'auth_forgot_password': 'Forgot password?',
  'auth_use_code_instead': 'Get a code by email instead',

  // Passwort vergessen (4.3)
  'auth_reset_title': 'Reset password',
  'auth_reset_message':
      'We’ll send you a code. Then you set a new password.',

  // Neues Passwort (4.4)
  'auth_new_password_title': 'New password',
  'auth_rule_length': 'At least 8 characters',
  'auth_rule_upper': 'One capital letter',
  'auth_rule_digit': 'One number',
  'auth_rule_met': 'met',
  'auth_rule_open': 'missing',
  'auth_save_password': 'Save password',
  'auth_saving': 'Saving',
  'auth_password_changed': 'Password changed.',
  'auth_reset_cancel_title': 'Stop resetting?',
  'auth_reset_cancel_message':
      'You’ll be signed out and can try again later.',
  'auth_reset_keep_going': 'Keep setting it',
  'auth_sign_out': 'Sign out',
  'auth_offline_save': 'Offline. You need a connection to save.',

  // Fehler (4.6)
  'auth_err_offline': 'Offline. You need a connection to sign in.',
  'auth_err_rate_limit': 'Too many attempts. Please wait a minute.',
  'auth_err_invalid_credentials': 'Email or password is wrong.',
  'auth_err_email_not_confirmed': 'Confirm your email address first.',
  'auth_err_otp_invalid':
      'The code isn’t right. Check it or get a new one.',
  'auth_err_otp_expired': 'The code has expired.',
  'auth_err_email_invalid': 'This email address doesn’t look right.',
  'auth_err_uses_google': 'This address belongs to an account with Google.',
  'auth_err_uses_apple': 'This address belongs to an account with Apple.',
  'auth_err_apple_failed': 'Signing in with Apple didn’t work.',
  'auth_err_google_failed': 'Signing in with Google didn’t work.',
  'auth_err_apple_unavailable':
      'Signing in with Apple isn’t working right now. Use Google or email.',
  'auth_err_google_unavailable':
      'Signing in with Google isn’t working right now. Use Apple or email.',
  'auth_err_google_unavailable_email':
      'Signing in with Google isn’t working right now. Use email.',
  'auth_err_account_deleted': 'This account no longer exists.',
  'auth_err_weak_password':
      'This password is too easy to guess. Choose another one.',
  'auth_err_same_password':
      'That’s your current password. Choose a new one.',
  'auth_err_unknown': 'That didn’t work.',
};

const Map<String, String> authFlowDe = {
  // Konto (3.5) und Anmelden (4.1)
  'auth_account_title': 'Konto anlegen',
  'auth_account_message':
      'Damit deine Listen auf allen Geräten da sind und du sie mit anderen teilen kannst. Hast du schon ein Konto, meldest du dich hier genauso an.',
  'auth_login_title': 'Anmelden',
  'auth_login_message': 'Mit derselben Methode wie beim ersten Mal.',
  'auth_continue_apple': 'Mit Apple fortfahren',
  'auth_continue_google': 'Mit Google fortfahren',
  'auth_continue_email': 'Mit E-Mail fortfahren',
  'auth_use_password': 'Mit Passwort anmelden',
  'auth_legal_notice':
      'Mit dem Fortfahren akzeptierst du die Nutzungsbedingungen und die Datenschutzhinweise.',
  'auth_terms': 'Nutzungsbedingungen',
  'auth_privacy': 'Datenschutzhinweise',
  'auth_signing_in': 'Wird angemeldet',
  'auth_offline_keeps_choice':
      'Offline. Zum Anmelden brauchst du eine Verbindung. Deine Auswahl bleibt gespeichert.',

  // E-Mail (3.6)
  'auth_email_title': 'Deine E-Mail-Adresse',
  'auth_email_message':
      'Wir schicken dir einen 6-stelligen Code. Ein Passwort brauchst du dafür nicht.',
  'auth_email_placeholder': 'name@beispiel.de',
  'auth_email_label': 'E-Mail-Adresse',
  'auth_send_code': 'Code senden',
  'auth_sending': 'Wird gesendet',
  'auth_offline_send_code':
      'Offline. Zum Senden des Codes brauchst du eine Verbindung.',

  // Code (3.7)
  'auth_code_title': 'Code eingeben',
  'auth_code_title_reset': 'Code zum Zurücksetzen',
  'auth_code_sent_to': 'Wir haben ihn an {email} geschickt.',
  'auth_code_sent_if_account':
      'Wenn es ein Konto mit {email} gibt, ist der Code unterwegs.',
  'auth_code_label': 'Code aus der E-Mail',
  'auth_code_spam': 'Keine E-Mail da? Schau im Spam-Ordner nach.',
  'auth_code_resend': 'Neuen Code senden',
  'auth_code_resend_in': 'Neuer Code in {time}',
  'auth_code_resent': 'Ein neuer Code ist unterwegs.',
  'auth_code_change_email': 'Adresse ändern',
  'auth_code_confirm': 'Bestätigen',
  'auth_code_checking': 'Wird geprüft',
  'auth_offline_code_waits':
      'Offline. Der Code wird geprüft, sobald du wieder online bist.',

  // Name (3.8)
  'auth_name_title': 'Wie heißt du?',
  'auth_name_message': 'So sehen dich andere in geteilten Listen.',
  'auth_name_placeholder': 'Vorname',
  'auth_name_not_saved': 'Dein Name ist noch nicht gespeichert.',

  // Mit Passwort anmelden (4.2)
  'auth_email_field': 'E-Mail',
  'auth_password_field': 'Passwort',
  'auth_password_placeholder': 'Erforderlich',
  'auth_show_password': 'Passwort anzeigen',
  'auth_hide_password': 'Passwort verbergen',
  'auth_forgot_password': 'Passwort vergessen?',
  'auth_use_code_instead': 'Stattdessen Code per E-Mail',

  // Passwort vergessen (4.3)
  'auth_reset_title': 'Passwort zurücksetzen',
  'auth_reset_message':
      'Wir schicken dir einen Code. Danach legst du ein neues Passwort fest.',

  // Neues Passwort (4.4)
  'auth_new_password_title': 'Neues Passwort',
  'auth_rule_length': 'Mindestens 8 Zeichen',
  'auth_rule_upper': 'Ein Großbuchstabe',
  'auth_rule_digit': 'Eine Ziffer',
  'auth_rule_met': 'erfüllt',
  'auth_rule_open': 'fehlt',
  'auth_save_password': 'Passwort speichern',
  'auth_saving': 'Wird gespeichert',
  'auth_password_changed': 'Passwort geändert.',
  'auth_reset_cancel_title': 'Zurücksetzen abbrechen?',
  'auth_reset_cancel_message':
      'Du wirst abgemeldet und kannst es später erneut versuchen.',
  'auth_reset_keep_going': 'Weiter festlegen',
  'auth_sign_out': 'Abmelden',
  'auth_offline_save': 'Offline. Zum Speichern brauchst du eine Verbindung.',

  // Fehler (4.6)
  'auth_err_offline': 'Offline. Zum Anmelden brauchst du eine Verbindung.',
  'auth_err_rate_limit': 'Zu viele Versuche. Bitte warte eine Minute.',
  'auth_err_invalid_credentials': 'E-Mail oder Passwort stimmt nicht.',
  'auth_err_email_not_confirmed': 'Bestätige zuerst deine E-Mail-Adresse.',
  'auth_err_otp_invalid':
      'Der Code stimmt nicht. Prüfe ihn oder lass dir einen neuen schicken.',
  'auth_err_otp_expired': 'Der Code ist abgelaufen.',
  'auth_err_email_invalid': 'Diese E-Mail-Adresse sieht nicht richtig aus.',
  'auth_err_uses_google': 'Diese Adresse gehört zu einem Konto mit Google.',
  'auth_err_uses_apple': 'Diese Adresse gehört zu einem Konto mit Apple.',
  'auth_err_apple_failed': 'Anmelden mit Apple hat nicht geklappt.',
  'auth_err_google_failed': 'Anmelden mit Google hat nicht geklappt.',
  'auth_err_apple_unavailable':
      'Anmelden mit Apple klappt gerade nicht. Nimm Google oder E-Mail.',
  'auth_err_google_unavailable':
      'Anmelden mit Google klappt gerade nicht. Nimm Apple oder E-Mail.',
  'auth_err_google_unavailable_email':
      'Anmelden mit Google klappt gerade nicht. Nimm E-Mail.',
  'auth_err_account_deleted': 'Dieses Konto gibt es nicht mehr.',
  'auth_err_weak_password':
      'Dieses Passwort ist zu leicht zu erraten. Nimm ein anderes.',
  'auth_err_same_password': 'Das ist dein bisheriges Passwort. Nimm ein neues.',
  'auth_err_unknown': 'Das hat nicht geklappt.',
};
