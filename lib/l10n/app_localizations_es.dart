// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Boofer Chat';

  @override
  String get settings => 'Configuración';

  @override
  String get appearance => 'Apariencia';

  @override
  String get theme => 'Tema';

  @override
  String get language => 'Idioma';

  @override
  String get light => 'Claro';

  @override
  String get dark => 'Oscuro';

  @override
  String get systemDefault => 'Predeterminado del Sistema';

  @override
  String get followSystemTheme => 'Seguir tema del sistema';

  @override
  String get chooseTheme => 'Elegir Tema';

  @override
  String get chooseLanguage => 'Elegir Idioma';

  @override
  String get cancel => 'Cancelar';

  @override
  String get privacyAndSecurity => 'Privacidad y Seguridad';

  @override
  String get privacySettings => 'Configuración de Privacidad';

  @override
  String get managePrivacyPreferences => 'Gestiona tus preferencias de privacidad';

  @override
  String get blockedUsers => 'Usuarios Bloqueados';

  @override
  String get manageBlockedContacts => 'Gestionar contactos bloqueados';

  @override
  String get twoFactorAuthentication => 'Autenticación de Dos Factores';

  @override
  String get addExtraSecurityToAccount => 'Añade seguridad extra a tu cuenta';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get messageNotifications => 'Notificaciones de Mensajes';

  @override
  String get receiveNotificationsForNewMessages => 'Recibir notificaciones de nuevos mensajes';

  @override
  String get soundAndVibration => 'Sonido y Vibración';

  @override
  String get customizeNotificationSounds => 'Personalizar sonidos de notificación';

  @override
  String get storage => 'Almacenamiento';

  @override
  String get storageUsage => 'Uso de Almacenamiento';

  @override
  String get manageAppStorage => 'Gestionar almacenamiento de la app';

  @override
  String get autoDownloadMedia => 'Descarga Automática de Medios';

  @override
  String get configureMediaDownloadSettings => 'Configurar ajustes de descarga de medios';

  @override
  String get support => 'Soporte';

  @override
  String get helpCenter => 'Centro de Ayuda';

  @override
  String get getHelpAndSupport => 'Obtener ayuda y soporte';

  @override
  String get contactUs => 'Contáctanos';

  @override
  String get sendFeedbackOrReportIssues => 'Enviar comentarios o reportar problemas';

  @override
  String get aboutBoofer => 'Acerca de Boofer';

  @override
  String get appVersionAndInformation => 'Versión de la app e información';

  @override
  String languageChangedTo(String language) {
    return 'Idioma cambiado a $language';
  }

  @override
  String get english => 'Inglés';

  @override
  String get spanish => 'Español';

  @override
  String get french => 'Francés';

  @override
  String get german => 'Alemán';

  @override
  String get italian => 'Italiano';

  @override
  String get portuguese => 'Portugués';

  @override
  String get russian => 'Ruso';

  @override
  String get chinese => 'Chino';

  @override
  String get japanese => 'Japonés';

  @override
  String get korean => 'Coreano';

  @override
  String get username => 'Nombre de usuario';

  @override
  String get changeUsername => 'Cambiar nombre de usuario';

  @override
  String usernameCannotBeChanged(int days) {
    return 'El nombre de usuario se puede cambiar en $days días';
  }

  @override
  String get enterNewUsername => 'Ingresa nuevo nombre de usuario';

  @override
  String get usernameRules => 'Reglas del nombre de usuario:\n• 3-20 caracteres\n• Solo letras, números y guiones bajos\n• Debe comenzar con una letra\n• No puede terminar con guión bajo';

  @override
  String get usernameChangedSuccessfully => '¡Nombre de usuario cambiado exitosamente!';

  @override
  String get usernameChangeError => 'Error al cambiar el nombre de usuario. Inténtalo de nuevo.';

  @override
  String get save => 'Guardar';

  @override
  String get archived => 'Archivado';

  @override
  String get archiveChat => 'Archivar Chat';

  @override
  String get unarchiveChat => 'Desarchivar Chat';

  @override
  String get archivedChats => 'Chats Archivados';

  @override
  String get noArchivedChats => 'No hay chats archivados';

  @override
  String get chatArchived => 'Chat archivado';

  @override
  String get chatUnarchived => 'Chat desarchivado';

  @override
  String get darkMode => 'Modo Oscuro';

  @override
  String get lightMode => 'Modo Claro';

  @override
  String get themeToggle => 'Alternar Tema';

  @override
  String get blockUser => 'Bloquear Usuario';

  @override
  String get unblockUser => 'Desbloquear Usuario';

  @override
  String get muteChat => 'Silenciar Chat';

  @override
  String get unmuteChat => 'Activar Sonido del Chat';

  @override
  String get deleteChat => 'Eliminar Chat';

  @override
  String get markAsRead => 'Marcar como Leído';

  @override
  String get markAsUnread => 'Marcar como No Leído';

  @override
  String get chatOptions => 'Opciones del Chat';

  @override
  String get userBlocked => 'Usuario bloqueado';

  @override
  String get userUnblocked => 'Usuario desbloqueado';

  @override
  String get chatMuted => 'Chat silenciado';

  @override
  String get chatUnmuted => 'Sonido del chat activado';

  @override
  String get chatDeleted => 'Chat eliminado';

  @override
  String confirmBlockUser(String name) {
    return '¿Estás seguro de que quieres bloquear a $name? No recibirás mensajes de esta persona.';
  }

  @override
  String confirmDeleteChat(String name) {
    return '¿Estás seguro de que quieres eliminar este chat con $name? Esta acción no se puede deshacer.';
  }
}
