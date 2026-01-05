// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Boofer Chat';

  @override
  String get settings => 'Paramètres';

  @override
  String get appearance => 'Apparence';

  @override
  String get theme => 'Thème';

  @override
  String get language => 'Langue';

  @override
  String get light => 'Clair';

  @override
  String get dark => 'Sombre';

  @override
  String get systemDefault => 'Par Défaut du Système';

  @override
  String get followSystemTheme => 'Suivre le thème du système';

  @override
  String get chooseTheme => 'Choisir le Thème';

  @override
  String get chooseLanguage => 'Choisir la Langue';

  @override
  String get cancel => 'Annuler';

  @override
  String get privacyAndSecurity => 'Confidentialité et Sécurité';

  @override
  String get privacySettings => 'Paramètres de Confidentialité';

  @override
  String get managePrivacyPreferences =>
      'Gérer vos préférences de confidentialité';

  @override
  String get blockedUsers => 'Utilisateurs Bloqués';

  @override
  String get manageBlockedContacts => 'Gérer les contacts bloqués';

  @override
  String get twoFactorAuthentication => 'Authentification à Deux Facteurs';

  @override
  String get addExtraSecurityToAccount =>
      'Ajouter une sécurité supplémentaire à votre compte';

  @override
  String get notifications => 'Notifications';

  @override
  String get messageNotifications => 'Notifications de Messages';

  @override
  String get receiveNotificationsForNewMessages =>
      'Recevoir des notifications pour les nouveaux messages';

  @override
  String get soundAndVibration => 'Son et Vibration';

  @override
  String get customizeNotificationSounds =>
      'Personnaliser les sons de notification';

  @override
  String get storage => 'Stockage';

  @override
  String get storageUsage => 'Utilisation du Stockage';

  @override
  String get manageAppStorage => 'Gérer le stockage de l\'application';

  @override
  String get autoDownloadMedia => 'Téléchargement Automatique des Médias';

  @override
  String get configureMediaDownloadSettings =>
      'Configurer les paramètres de téléchargement des médias';

  @override
  String get support => 'Support';

  @override
  String get helpCenter => 'Centre d\'Aide';

  @override
  String get getHelpAndSupport => 'Obtenir de l\'aide et du support';

  @override
  String get contactUs => 'Nous Contacter';

  @override
  String get sendFeedbackOrReportIssues =>
      'Envoyer des commentaires ou signaler des problèmes';

  @override
  String get aboutBoofer => 'À Propos de Boofer';

  @override
  String get appVersionAndInformation =>
      'Version de l\'application et informations';

  @override
  String languageChangedTo(String language) {
    return 'Langue changée en $language';
  }

  @override
  String get english => 'Anglais';

  @override
  String get spanish => 'Espagnol';

  @override
  String get french => 'Français';

  @override
  String get german => 'Allemand';

  @override
  String get italian => 'Italien';

  @override
  String get portuguese => 'Portugais';

  @override
  String get russian => 'Russe';

  @override
  String get chinese => 'Chinois';

  @override
  String get japanese => 'Japonais';

  @override
  String get korean => 'Coréen';

  @override
  String get username => 'Nom d\'utilisateur';

  @override
  String get changeUsername => 'Changer le nom d\'utilisateur';

  @override
  String usernameCannotBeChanged(int days) {
    return 'Le nom d\'utilisateur peut être changé dans $days jours';
  }

  @override
  String get enterNewUsername => 'Entrez un nouveau nom d\'utilisateur';

  @override
  String get usernameRules =>
      'Règles du nom d\'utilisateur:\n• 3-20 caractères\n• Lettres, chiffres et underscores uniquement\n• Doit commencer par une lettre\n• Ne peut pas finir par un underscore';

  @override
  String get usernameChangedSuccessfully =>
      'Nom d\'utilisateur changé avec succès!';

  @override
  String get usernameChangeError =>
      'Échec du changement de nom d\'utilisateur. Veuillez réessayer.';

  @override
  String get save => 'Enregistrer';

  @override
  String get archived => 'Archivé';

  @override
  String get archiveChat => 'Archiver la Discussion';

  @override
  String get unarchiveChat => 'Désarchiver la Discussion';

  @override
  String get archivedChats => 'Discussions Archivées';

  @override
  String get noArchivedChats => 'Aucune discussion archivée';

  @override
  String get chatArchived => 'Discussion archivée';

  @override
  String get chatUnarchived => 'Discussion désarchivée';

  @override
  String get darkMode => 'Mode Sombre';

  @override
  String get lightMode => 'Mode Clair';

  @override
  String get themeToggle => 'Basculer le Thème';
}
