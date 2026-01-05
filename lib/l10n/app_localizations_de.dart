// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Boofer Chat';

  @override
  String get settings => 'Einstellungen';

  @override
  String get appearance => 'Erscheinungsbild';

  @override
  String get theme => 'Design';

  @override
  String get language => 'Sprache';

  @override
  String get light => 'Hell';

  @override
  String get dark => 'Dunkel';

  @override
  String get systemDefault => 'Systemstandard';

  @override
  String get followSystemTheme => 'Systemdesign folgen';

  @override
  String get chooseTheme => 'Design wählen';

  @override
  String get chooseLanguage => 'Sprache wählen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get privacyAndSecurity => 'Datenschutz & Sicherheit';

  @override
  String get privacySettings => 'Datenschutzeinstellungen';

  @override
  String get managePrivacyPreferences => 'Datenschutzeinstellungen verwalten';

  @override
  String get blockedUsers => 'Blockierte Benutzer';

  @override
  String get manageBlockedContacts => 'Blockierte Kontakte verwalten';

  @override
  String get twoFactorAuthentication => 'Zwei-Faktor-Authentifizierung';

  @override
  String get addExtraSecurityToAccount =>
      'Zusätzliche Sicherheit für Ihr Konto';

  @override
  String get notifications => 'Benachrichtigungen';

  @override
  String get messageNotifications => 'Nachrichten-Benachrichtigungen';

  @override
  String get receiveNotificationsForNewMessages =>
      'Benachrichtigungen für neue Nachrichten erhalten';

  @override
  String get soundAndVibration => 'Ton & Vibration';

  @override
  String get customizeNotificationSounds => 'Benachrichtigungstöne anpassen';

  @override
  String get storage => 'Speicher';

  @override
  String get storageUsage => 'Speicherverbrauch';

  @override
  String get manageAppStorage => 'App-Speicher verwalten';

  @override
  String get autoDownloadMedia => 'Medien automatisch herunterladen';

  @override
  String get configureMediaDownloadSettings =>
      'Medien-Download-Einstellungen konfigurieren';

  @override
  String get support => 'Support';

  @override
  String get helpCenter => 'Hilfe-Center';

  @override
  String get getHelpAndSupport => 'Hilfe und Support erhalten';

  @override
  String get contactUs => 'Kontakt';

  @override
  String get sendFeedbackOrReportIssues =>
      'Feedback senden oder Probleme melden';

  @override
  String get aboutBoofer => 'Über Boofer';

  @override
  String get appVersionAndInformation => 'App-Version und Informationen';

  @override
  String languageChangedTo(String language) {
    return 'Sprache geändert zu $language';
  }

  @override
  String get english => 'Englisch';

  @override
  String get spanish => 'Spanisch';

  @override
  String get french => 'Französisch';

  @override
  String get german => 'Deutsch';

  @override
  String get italian => 'Italienisch';

  @override
  String get portuguese => 'Portugiesisch';

  @override
  String get russian => 'Russisch';

  @override
  String get chinese => 'Chinesisch';

  @override
  String get japanese => 'Japanisch';

  @override
  String get korean => 'Koreanisch';

  @override
  String get username => 'Benutzername';

  @override
  String get changeUsername => 'Benutzername ändern';

  @override
  String usernameCannotBeChanged(int days) {
    return 'Benutzername kann in $days Tagen geändert werden';
  }

  @override
  String get enterNewUsername => 'Neuen Benutzernamen eingeben';

  @override
  String get usernameRules =>
      'Benutzername-Regeln:\n• 3-20 Zeichen\n• Nur Buchstaben, Zahlen und Unterstriche\n• Muss mit einem Buchstaben beginnen\n• Kann nicht mit Unterstrich enden';

  @override
  String get usernameChangedSuccessfully =>
      'Benutzername erfolgreich geändert!';

  @override
  String get usernameChangeError =>
      'Fehler beim Ändern des Benutzernamens. Bitte versuchen Sie es erneut.';

  @override
  String get save => 'Speichern';

  @override
  String get archived => 'Archiviert';

  @override
  String get archiveChat => 'Chat Archivieren';

  @override
  String get unarchiveChat => 'Chat Entarchivieren';

  @override
  String get archivedChats => 'Archivierte Chats';

  @override
  String get noArchivedChats => 'Keine archivierten Chats';

  @override
  String get chatArchived => 'Chat archiviert';

  @override
  String get chatUnarchived => 'Chat entarchiviert';

  @override
  String get darkMode => 'Dunkler Modus';

  @override
  String get lightMode => 'Heller Modus';

  @override
  String get themeToggle => 'Design Umschalten';
}
