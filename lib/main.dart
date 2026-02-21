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
import 'services/deep_link_service.dart';
import 'services/receive_share_service.dart';
import 'screens/main_screen.dart';
import 'screens/friend_chat_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/legal_acceptance_screen.dart';
import 'models/friend_model.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/appearance_settings_screen.dart';
import 'screens/customization_settings_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/profile_chooser_screen.dart';
import 'l10n/app_localizations.dart';

Future<Map<String, dynamic>> _initializeApp() async {
  try {
    debugPrint('🚀 [INIT] Phase 1: Basic Boot');
    WidgetsFlutterBinding.ensureInitialized();

    // Capture any sharing intent early - non-blocking
    ReceiveShareService.instance.checkInitialShare().catchError((e) {
      debugPrint('⚠️ [INIT] Share capture failed (non-critical): $e');
    });

    debugPrint('🚀 [INIT] Phase 2: Supabase');
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );

    debugPrint('🚀 [INIT] Phase 3: Services');
    SyncService.instance.initialize();
    NotificationService.instance.initialize();
    ProfilePictureService.instance.initialize();

    debugPrint('🚀 [INIT] Phase 4: E2EE');
    await SupabaseService.instance.initialize();

    debugPrint('🚀 [INIT] Phase 5: Routing');
    String initialRoute = '/onboarding';

    // Migration
    try {
      final userJson = await LocalStorageService.getString('current_user');
      if (userJson != null) {
        final Map<String, dynamic> user = jsonDecode(userJson);
        final userId = user['id'] as String? ?? '';
        if (userId.isNotEmpty) {
          final existing = await MultiAccountStorageService.getSavedAccounts();
          if (!existing.any((a) => a['id'] == userId)) {
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
      debugPrint('⚠️ [INIT] Migration error (non-critical): $e');
    }

    final savedAccounts = await MultiAccountStorageService.getSavedAccounts();
    debugPrint('🚀 [INIT] Saved accounts: ${savedAccounts.length}');

    // Auto-login logic
    final lastActiveId =
        await MultiAccountStorageService.getLastActiveAccountId();
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null && !session.isExpired) {
      // Already has a valid session (e.g. from Supabase internal storage)
      final userId = session.user.id;
      final hasAcceptedTerms = await LocalStorageService.hasAcceptedTerms(
        userId,
      );
      initialRoute = hasAcceptedTerms ? '/main' : '/legal-acceptance';
    } else if (lastActiveId != null) {
      // Try to recover session from secure storage
      try {
        final sessionJson = await MultiAccountStorageService.getSession(
          lastActiveId,
        );
        if (sessionJson != null) {
          await Supabase.instance.client.auth.recoverSession(sessionJson);
          final hasAcceptedTerms = await LocalStorageService.hasAcceptedTerms(
            lastActiveId,
          );
          initialRoute = hasAcceptedTerms ? '/main' : '/legal-acceptance';
        } else {
          initialRoute = '/onboarding';
        }
      } catch (e) {
        debugPrint('⚠️ [INIT] Session recovery failed: $e');
        initialRoute = '/onboarding';
      }
    } else if (savedAccounts.length > 1) {
      // Multiple accounts - show chooser
      initialRoute = '/profile-chooser';
    } else if (savedAccounts.length == 1) {
      // Exactly 1 account - pick it
      final userId = savedAccounts.first['id'] as String;
      final sessionJson = await MultiAccountStorageService.getSession(userId);
      if (sessionJson != null) {
        try {
          await Supabase.instance.client.auth.recoverSession(sessionJson);
          final hasAcceptedTerms = await LocalStorageService.hasAcceptedTerms(
            userId,
          );
          initialRoute = hasAcceptedTerms ? '/main' : '/legal-acceptance';
        } catch (e) {
          initialRoute = '/onboarding';
        }
      } else {
        initialRoute = '/onboarding';
      }
    } else {
      initialRoute = '/onboarding';
    }

    debugPrint('🚀 [INIT] Finalizing with route: $initialRoute');
    return {'initialRoute': initialRoute};
  } catch (e, stack) {
    debugPrint('❌ [INIT] CRITICAL FAILURE: $e');
    debugPrint('$stack');
    return {'initialRoute': '/onboarding', 'error': e.toString()};
  }
}

void main() async {
  final initializationFuture = _initializeApp();
  runApp(BooferApp(initializationFuture: initializationFuture));
}

class BooferApp extends StatefulWidget {
  final Future<Map<String, dynamic>> initializationFuture;
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  const BooferApp({super.key, required this.initializationFuture});

  @override
  State<BooferApp> createState() => _BooferAppState();
}

class _BooferAppState extends State<BooferApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkService.instance.initialize();
    });
  }

  @override
  void dispose() {
    DeepLinkService.instance.dispose();
    ReceiveShareService.instance.dispose();
    super.dispose();
  }

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
          create: (_) => AppearanceProvider(),
          update: (_, theme, appearance) =>
              appearance!..setThemeProvider(theme),
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
            navigatorKey: BooferApp.navigatorKey,
            title: 'Boofer',
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            locale: context.watch<LocaleProvider>().locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: FutureBuilder<Map<String, dynamic>>(
              future: widget.initializationFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildErrorScreen(
                    'FutureBuilder error: ${snapshot.error}',
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SplashScreen();
                }
                final data = snapshot.data ?? {};
                if (data.containsKey('error')) {
                  return _buildErrorScreen('Init error: ${data['error']}');
                }

                final route = data['initialRoute'] ?? '/onboarding';
                switch (route) {
                  case '/main':
                    return const MainScreen();
                  case '/profile-chooser':
                    return const ProfileChooserScreen();
                  case '/legal-acceptance':
                    return const LegalAcceptanceScreen();
                  default:
                    return const OnboardingScreen();
                }
              },
            ),
            routes: {
              '/onboarding': (context) => const OnboardingScreen(),
              '/main': (context) => const MainScreen(),
              '/chat': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                if (args is Friend) {
                  return FriendChatScreen(
                    recipientId: args.id,
                    recipientName: args.name,
                    recipientHandle: args.handle,
                    recipientAvatar: args.avatar,
                    recipientProfilePicture: args.profilePicture,
                  );
                } else if (args is Map<String, dynamic>) {
                  return FriendChatScreen(
                    recipientId: args['recipientId'],
                    recipientName: args['recipientName'],
                    recipientHandle: args['recipientHandle'],
                    recipientAvatar: args['recipientAvatar'],
                    recipientProfilePicture: args['recipientProfilePicture'],
                    initialText: args['initialText'],
                  );
                }
                return const MainScreen();
              },
              '/profile': (context) {
                final userId =
                    ModalRoute.of(context)?.settings.arguments as String?;
                return userId != null
                    ? UserProfileScreen(userId: userId)
                    : const MainScreen();
              },
              '/welcome': (context) {
                final data =
                    ModalRoute.of(context)?.settings.arguments
                        as Map<String, dynamic>?;
                return data != null
                    ? WelcomeScreen(draftData: data)
                    : const OnboardingScreen();
              },
              '/notification-settings': (context) =>
                  const NotificationSettingsScreen(),
              '/appearance-settings': (context) =>
                  const AppearanceSettingsScreen(),
              '/customization-settings': (context) =>
                  const CustomizationSettingsScreen(),
              '/legal-acceptance': (context) => const LegalAcceptanceScreen(),
              '/profile-chooser': (context) => const ProfileChooserScreen(),
            },
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }

  Widget _buildErrorScreen(String message) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Oops! Initialization Failed',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => main(),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
