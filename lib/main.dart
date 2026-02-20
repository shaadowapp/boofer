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
import 'services/supabase_service.dart';
import 'services/sync_service.dart';
import 'services/profile_picture_service.dart';
import 'services/notification_service.dart';
import 'services/local_storage_service.dart';
import 'services/multi_account_storage_service.dart';
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
import 'screens/welcome_screen.dart';
import 'models/friend_model.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Fire-and-forget background service initializations
  SyncService.instance.initialize();
  NotificationService.instance.initialize();
  ProfilePictureService.instance.initialize();

  // Initialize SupabaseService (handles E2EE initialization if user is logged in)
  await SupabaseService.instance.initialize();

  // ── Determine initial route ──────────────────────────────────────
  // Priority:
  //   1. If there is a valid Supabase session + stored user → /main
  //   2. If stored user but no terms → /legal-acceptance
  //   3. If multiple saved accounts with NO active session → /onboarding
  //      (login flow will auto-select if exactly 1 saved account found)
  //   4. Otherwise → /onboarding
  String initialRoute = '/onboarding';

  try {
    final userJson = await LocalStorageService.getString('current_user');
    if (userJson != null) {
      final Map<String, dynamic> user = jsonDecode(userJson);
      if (user.containsKey('id')) {
        final userId = user['id'] as String;
        final hasAcceptedTerms = await LocalStorageService.hasAcceptedTerms(
          userId,
        );

        if (hasAcceptedTerms) {
          initialRoute = '/main';
        } else {
          initialRoute = '/legal-acceptance';
        }

        // Update the last active account in multi-account storage
        final savedAccounts =
            await MultiAccountStorageService.getSavedAccounts();
        final alreadySaved = savedAccounts.any((a) => a['id'] == userId);
        if (!alreadySaved) {
          // Migrate old single-account to multi-account storage
          await MultiAccountStorageService.upsertAccount(
            id: userId,
            handle: user['handle'] as String? ?? '',
            fullName: user['fullName'] as String? ?? '',
            avatar: user['avatar'] as String?,
          );
        }
        await MultiAccountStorageService.setLastActiveAccountId(userId);
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
            title: 'Boofer - Meet, Chat, Connect',
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            locale: context.watch<LocaleProvider>().locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            initialRoute: initialRoute,
            routes: {
              '/onboarding': (context) => const OnboardingScreen(),
              '/main': (context) => const MainScreen(),
              '/welcome': (context) {
                final name =
                    ModalRoute.of(context)?.settings.arguments as String?;
                return WelcomeScreen(displayName: name);
              },
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
                return const MainScreen();
              },
              '/profile': (context) {
                final userId =
                    ModalRoute.of(context)?.settings.arguments as String?;
                if (userId != null) {
                  return UserProfileScreen(userId: userId);
                }
                return const MainScreen();
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
