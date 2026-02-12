import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'providers/theme_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/archive_settings_provider.dart';
import 'providers/username_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/auth_state_provider.dart';
import 'providers/firestore_user_provider.dart';
import 'providers/friend_request_provider.dart';
import 'providers/appearance_provider.dart';
import 'services/chat_service.dart';

import 'services/sync_service.dart';
import 'services/profile_picture_service.dart';
import 'core/database/database_manager.dart';
import 'core/error/error_handler.dart';
import 'screens/main_screen.dart';
import 'screens/friend_chat_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/appearance_settings_screen.dart';
import 'screens/customization_settings_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/legal_acceptance_screen.dart';
import 'models/friend_model.dart';
import 'l10n/app_localizations.dart';
import 'services/notification_service.dart';
import 'services/local_storage_service.dart';

/// Background message handler for Firebase Messaging
/// This must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if not already initialized
  await Firebase.initializeApp();

  print('📬 Background message received: ${message.notification?.title}');

  // Handle the message (notification is automatically shown by the system)
  // You can add custom logic here if needed
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Configure Firestore
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    print('⚠️ Firestore settings error: $e');
  }

  // Fire-and-forget background service initializations
  // We don't await these to speed up app launch
  SyncService.instance.initialize();
  NotificationService.instance.initialize();
  ProfilePictureService.instance.initialize();

  // Determine initial route based on cached auth state
  // This allows us to skip the splash screen completely for logged-in users
  String initialRoute = '/onboarding';

  try {
    final userJson = await LocalStorageService.getString('current_user');
    if (userJson != null) {
      final Map<String, dynamic> user = jsonDecode(userJson);
      if (user.containsKey('id')) {
        final userId = user['id'];
        final hasAcceptedTerms = await LocalStorageService.hasAcceptedTerms(
          userId,
        );

        if (hasAcceptedTerms) {
          initialRoute = '/main';
        } else {
          initialRoute = '/legal-acceptance';
        }
      }
    }
  } catch (e) {
    print('Error checking initial auth state: $e');
    // Fallback to onboarding on error
  }

  print('🚀 Starting Boofer directly to: $initialRoute');

  runApp(BooferApp(initialRoute: initialRoute));
}

class BooferApp extends StatelessWidget {
  final String initialRoute;

  const BooferApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    // Initialize services that need context or lifecycle
    final errorHandler = ErrorHandler();
    final databaseManager = DatabaseManager.instance;
    final chatService = ChatService(
      database: databaseManager,
      errorHandler: errorHandler,
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProxyProvider<ThemeProvider, AppearanceProvider>(
          create: (context) => AppearanceProvider(),
          update: (context, themeProvider, appearanceProvider) {
            appearanceProvider?.setThemeProvider(themeProvider);
            return appearanceProvider!;
          },
        ),
        ChangeNotifierProvider(create: (_) => AuthStateProvider()),
        ChangeNotifierProvider(create: (_) => FirestoreUserProvider()),
        ChangeNotifierProvider(create: (_) => FriendRequestProvider()),
        ChangeNotifierProvider(
          create: (_) => ChatProvider(
            chatService: chatService,
            errorHandler: errorHandler,
          ),
        ),
        ChangeNotifierProvider(create: (_) => ArchiveSettingsProvider()),
        ChangeNotifierProvider(create: (_) => UsernameProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Boofer - Privacy First Chat',
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            initialRoute: initialRoute,
            routes: {
              '/onboarding': (context) => const OnboardingScreen(),
              '/main': (context) => const MainScreen(),
              '/notification-settings': (context) =>
                  const NotificationSettingsScreen(),
              '/appearance-settings': (context) =>
                  const AppearanceSettingsScreen(),
              '/customization-settings': (context) =>
                  const CustomizationSettingsScreen(),
              '/chat': (context) {
                final friend =
                    ModalRoute.of(context)?.settings.arguments as Friend?;
                if (friend != null) {
                  return FriendChatScreen(
                    recipientId: friend.id,
                    recipientName: friend.name,
                    recipientHandle: friend.handle,
                    recipientAvatar: friend.avatar,
                  );
                }
                return const MainScreen(); // Fallback if no friend provided
              },
              '/profile': (context) {
                final userId =
                    ModalRoute.of(context)?.settings.arguments as String?;
                if (userId != null) {
                  return UserProfileScreen(userId: userId);
                }
                return const MainScreen(); // Fallback if no userId provided
              },
              '/legal-acceptance': (context) => const LegalAcceptanceScreen(),
            },
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
