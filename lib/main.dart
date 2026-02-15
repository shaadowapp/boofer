import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/network/supabase_config.dart';
import 'providers/theme_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/archive_settings_provider.dart';
import 'providers/username_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/auth_state_provider.dart';
import 'providers/supabase_user_provider.dart';
import 'providers/follow_provider.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

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
    debugPrint('Error checking initial auth state: $e');
    // Fallback to onboarding on error
  }

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
        ChangeNotifierProvider(create: (_) => SupabaseUserProvider()),
        ChangeNotifierProvider(create: (_) => FollowProvider()),
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
            // Wrap with Consumer to make locale reactive
            locale: context.watch<LocaleProvider>().locale,
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
