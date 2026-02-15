// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'Boofer Chat';

  @override
  String get settings => 'Impostazioni';

  @override
  String get appearance => 'Aspetto';

  @override
  String get theme => 'Tema';

  @override
  String get language => 'Lingua';

  @override
  String get light => 'Chiaro';

  @override
  String get dark => 'Scuro';

  @override
  String get systemDefault => 'Predefinito del sistema';

  @override
  String get followSystemTheme => 'Segui il tema del sistema';

  @override
  String get chooseTheme => 'Scegli tema';

  @override
  String get chooseLanguage => 'Scegli lingua';

  @override
  String get cancel => 'Annulla';

  @override
  String get privacyAndSecurity => 'Privacy e sicurezza';

  @override
  String get privacySettings => 'Impostazioni privacy';

  @override
  String get managePrivacyPreferences => 'Gestisci le tue preferenze sulla privacy';

  @override
  String get blockedUsers => 'Utenti bloccati';

  @override
  String get manageBlockedContacts => 'Gestisci contatti bloccati';

  @override
  String get twoFactorAuthentication => 'Autenticazione a due fattori';

  @override
  String get addExtraSecurityToAccount => 'Aggiungi sicurezza extra al tuo account';

  @override
  String get notifications => 'Notifiche';

  @override
  String get messageNotifications => 'Notifiche messaggi';

  @override
  String get receiveNotificationsForNewMessages => 'Ricevi notifiche per nuovi messaggi';

  @override
  String get soundAndVibration => 'Suono e vibrazione';

  @override
  String get customizeNotificationSounds => 'Personalizza suoni di notifica';

  @override
  String get storage => 'Archiviazione';

  @override
  String get storageUsage => 'Utilizzo archiviazione';

  @override
  String get manageAppStorage => 'Gestisci archiviazione app';

  @override
  String get autoDownloadMedia => 'Download automatico media';

  @override
  String get configureMediaDownloadSettings => 'Configura impostazioni download media';

  @override
  String get support => 'Supporto';

  @override
  String get helpCenter => 'Centro assistenza';

  @override
  String get getHelpAndSupport => 'Ottieni aiuto e supporto';

  @override
  String get contactUs => 'Contattaci';

  @override
  String get sendFeedbackOrReportIssues => 'Invia feedback o segnala problemi';

  @override
  String get aboutBoofer => 'Informazioni su Boofer';

  @override
  String get appVersionAndInformation => 'Versione app e informazioni';

  @override
  String languageChangedTo(String language) {
    return 'Lingua cambiata in $language';
  }

  @override
  String get english => 'Inglese';

  @override
  String get spanish => 'Spagnolo';

  @override
  String get french => 'Francese';

  @override
  String get german => 'Tedesco';

  @override
  String get italian => 'Italiano';

  @override
  String get portuguese => 'Portoghese';

  @override
  String get russian => 'Russo';

  @override
  String get chinese => 'Cinese';

  @override
  String get japanese => 'Giapponese';

  @override
  String get korean => 'Coreano';

  @override
  String get username => 'Nome utente';

  @override
  String get changeUsername => 'Cambia nome utente';

  @override
  String usernameCannotBeChanged(int days) {
    return 'Il nome utente può essere cambiato tra $days giorni';
  }

  @override
  String get enterNewUsername => 'Inserisci nuovo nome utente';

  @override
  String get usernameRules => 'Regole nome utente:\n• 3-20 caratteri\n• Solo lettere, numeri e underscore\n• Deve iniziare con una lettera\n• Non può finire con underscore';

  @override
  String get usernameChangedSuccessfully => 'Nome utente cambiato con successo!';

  @override
  String get usernameChangeError => 'Errore nel cambiare il nome utente. Riprova.';

  @override
  String get save => 'Salva';

  @override
  String get archived => 'Archiviato';

  @override
  String get archiveChat => 'Archivia Chat';

  @override
  String get unarchiveChat => 'Dearchivia Chat';

  @override
  String get archivedChats => 'Chat Archiviate';

  @override
  String get noArchivedChats => 'Nessuna chat archiviata';

  @override
  String get chatArchived => 'Chat archiviata';

  @override
  String get chatUnarchived => 'Chat dearchiviata';

  @override
  String get darkMode => 'Modalità Scura';

  @override
  String get lightMode => 'Modalità Chiara';

  @override
  String get themeToggle => 'Cambia Tema';

  @override
  String get blockUser => 'Blocca Utente';

  @override
  String get unblockUser => 'Sblocca Utente';

  @override
  String get muteChat => 'Silenzia Chat';

  @override
  String get unmuteChat => 'Attiva Audio Chat';

  @override
  String get deleteChat => 'Elimina Chat';

  @override
  String get markAsRead => 'Segna come Letto';

  @override
  String get markAsUnread => 'Segna come Non Letto';

  @override
  String get chatOptions => 'Opzioni Chat';

  @override
  String get userBlocked => 'Utente bloccato';

  @override
  String get userUnblocked => 'Utente sbloccato';

  @override
  String get chatMuted => 'Chat silenziata';

  @override
  String get chatUnmuted => 'Audio chat attivato';

  @override
  String get chatDeleted => 'Chat eliminata';

  @override
  String confirmBlockUser(String name) {
    return 'Sei sicuro di voler bloccare $name? Non riceverai più messaggi da questa persona.';
  }

  @override
  String confirmDeleteChat(String name) {
    return 'Sei sicuro di voler eliminare questa chat con $name? Questa azione non può essere annullata.';
  }
}
