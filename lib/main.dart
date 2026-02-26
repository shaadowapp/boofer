import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

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
import 'models/user_model.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/appearance_settings_screen.dart';
import 'screens/customization_settings_screen.dart';
import 'screens/welcome_screen.dart';
import 'l10n/app_localizations.dart';
import 'services/code_push_service.dart';

/// The initialization logic for the application.
/// This handles services that depend on Supabase and Firebase being ready.
Future<Map<String, dynamic>> _initializeApp() async {
  debugPrint('🚀 [BOOT] _initializeApp() invoked');
  try {
    debugPrint('🚀 [BOOT] Phase 2: Services Initialization Started');

    // Ensure we have a valid client before proceeding
    final client = Supabase.instance.client;
    debugPrint('🚀 [BOOT] Supabase client obtained: ${client.hashCode}');

    // Early Share Check (Fire and forget, but with safety)
    debugPrint('🚀 [BOOT] Checking for initial share...');
    ReceiveShareService.instance
        .checkInitialShare()
        .timeout(const Duration(seconds: 3))
        .then((_) {
          debugPrint('✅ [BOOT] Share check completed');
        })
        .catchError((e) {
          debugPrint('⚠️ [BOOT] Share check timed out or failed: $e');
        });

    // Await core services with timeouts
    debugPrint('🚀 [BOOT] Initializing NotificationService...');
    await NotificationService.instance.initialize().timeout(
      const Duration(seconds: 5),
      onTimeout: () => debugPrint('⚠️ [BOOT] NotificationService init timeout'),
    );
    debugPrint('✅ [BOOT] NotificationService Initialized');

    debugPrint('🚀 [BOOT] Initializing ProfilePictureService...');
    try {
      await ProfilePictureService.instance.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () =>
            debugPrint('⚠️ [BOOT] ProfilePictureService init timeout'),
      );
      debugPrint('✅ [BOOT] ProfilePictureService Initialized');
    } catch (e) {
      debugPrint('⚠️ [BOOT] ProfilePictureService initialization failed: $e');
    }

    debugPrint('🚀 [BOOT] Phase 3: SupabaseService initialization');
    await SupabaseService.instance.initialize().timeout(
      const Duration(seconds: 10),
      onTimeout: () => debugPrint('⚠️ [BOOT] SupabaseService init timeout'),
    );
    debugPrint('✅ [BOOT] SupabaseService Initialized');

    debugPrint('🚀 [BOOT] Phase 4: Route Determination');
    String initialRoute = '/onboarding';

    // Account migration and discovery logic
    debugPrint('🚀 [BOOT] Checking local storage for current_user...');
    try {
      final userJson = await LocalStorageService.getString('current_user');
      if (userJson != null) {
        debugPrint('🚀 [BOOT] Found current_user in local storage');
        final Map<String, dynamic> userMap = jsonDecode(userJson);
        final userId = userMap['id'] as String? ?? '';
        if (userId.isNotEmpty) {
          debugPrint('🚀 [BOOT] User ID: $userId');
          final existing = await MultiAccountStorageService.getSavedAccounts();
          debugPrint('🚀 [BOOT] Saved accounts found: ${existing.length}');
          if (!existing.any((a) => a['id'] == userId)) {
            debugPrint(
              '🚀 [BOOT] Migrating current user to multi-account storage',
            );
            await MultiAccountStorageService.upsertAccount(
              id: userId,
              handle: userMap['handle'] as String? ?? '',
              fullName: userMap['fullName'] as String? ?? '',
              avatar: userMap['avatar'] as String?,
            );
          }
          await MultiAccountStorageService.setLastActiveAccountId(userId);
        }
      } else {
        debugPrint('🚀 [BOOT] No current_user in local storage');
      }
    } catch (e) {
      debugPrint('⚠️ [BOOT] Migration error (non-critical): $e');
    }

    final savedAccounts = await MultiAccountStorageService.getSavedAccounts();
    debugPrint('🚀 [BOOT] Total Saved accounts: ${savedAccounts.length}');

    // Session logic
    debugPrint('🚀 [BOOT] Checking active session...');
    final lastActiveId =
        await MultiAccountStorageService.getLastActiveAccountId();
    final session = client.auth.currentSession;

    if (session != null && !session.isExpired) {
      final userId = session.user.id;
      debugPrint('✅ [BOOT] Valid session found for user: $userId');
      final hasAcceptedTerms = await LocalStorageService.hasAcceptedTerms(
        userId,
      );
      initialRoute = hasAcceptedTerms ? '/main' : '/legal-acceptance';
    } else if (lastActiveId != null && lastActiveId.isNotEmpty) {
      debugPrint(
        '🚀 [BOOT] No current session, attempting recovery for: $lastActiveId',
      );
      try {
        final sessionJson = await MultiAccountStorageService.getSession(
          lastActiveId,
        );
        if (sessionJson != null) {
          await client.auth.recoverSession(sessionJson);
          debugPrint('✅ [BOOT] Session recovered successfully');
          final hasAcceptedTerms = await LocalStorageService.hasAcceptedTerms(
            lastActiveId,
          );
          initialRoute = hasAcceptedTerms ? '/main' : '/legal-acceptance';
        } else {
          debugPrint('🚀 [BOOT] No session JSON found for recovery');
          initialRoute = '/onboarding';
        }
      } catch (e) {
        debugPrint('⚠️ [BOOT] Session recovery failed: $e');
        initialRoute = '/onboarding';
      }
    } else {
      debugPrint(
        '🚀 [BOOT] No session and no last active ID, going to onboarding',
      );
      initialRoute = '/onboarding';
    }

    debugPrint('🚀 [BOOT] Finalizing boot with route: $initialRoute');
    return {'initialRoute': initialRoute, 'accounts': savedAccounts};
  } catch (e, stack) {
    debugPrint('❌ [BOOT] CRITICAL FAILURE: $e');
    debugPrint('❌ [BOOT] STACKTRACE: $stack');
    return {
      'initialRoute': '/onboarding',
      'accounts': [],
      'error': e.toString(),
    };
  }
}

void main() async {
  // if (kReleaseMode) {
  //   debugPrint = (String? message, {int? wrapWidth}) {};
  // }
  debugPrint('🚩 [BOOT] --- APP STARTING ---');
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 [BOOT] Phase 1: Global Infrastructure (Blocking)');
  bool isInfraReady = false;

  // Move validation and Supabase setup into a guarded future to avoid black screen on crash
  final initializationFuture = _performInfrastructureSetup();

  debugPrint('🚀 [BOOT] Calling runApp...');
  runApp(BooferApp(initializationFuture: initializationFuture));
}

Future<Map<String, dynamic>> _performInfrastructureSetup() async {
  try {
    debugPrint('🔒 [BOOT] Validating Supabase configuration...');
    SupabaseConfig.validate();

    debugPrint('🚀 [BOOT] Initializing Supabase...');
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );

    debugPrint('✅ [BOOT] Infrahstucture Ready');
    return await _initializeApp();
  } catch (e) {
    debugPrint('❌ [BOOT] Infrastructure failure: $e');
    return {
      'initialRoute': '/onboarding',
      'error':
          'Configuration Error: $e\n\nEnsure you built with --dart-define flags for Supabase.',
    };
  }
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
  late final ErrorHandler _errorHandler;
  late final DatabaseManager _databaseManager;
  late final ChatService _chatService;

  late Future<Map<String, dynamic>> _initFuture;

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 [APP] initState triggered');
    _initFuture = widget.initializationFuture;
    _errorHandler = ErrorHandler();
    _databaseManager = DatabaseManager.instance;
    _chatService = ChatService(
      database: _databaseManager,
      errorHandler: _errorHandler,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('🚀 [APP] Post-frame callback: Initializing DeepLinkService');
      DeepLinkService.instance.init(BooferApp.navigatorKey);

      // Check for code push updates (Shorebird Shadow Manager)
      CodePushService.instance.checkForUpdates(context);

      // Perform database health check
      _performDatabaseHealthCheck();
    });
  }

  /// Perform periodic database health check
  Future<void> _performDatabaseHealthCheck() async {
    try {
      // Check if we should run health check (once per 24 hours)
      final lastCheckStr = await LocalStorageService.getString(
        'last_db_health_check',
      );
      final now = DateTime.now();

      if (lastCheckStr != null) {
        final lastCheck = DateTime.parse(lastCheckStr);
        final hoursSinceLastCheck = now.difference(lastCheck).inHours;

        if (hoursSinceLastCheck < 24) {
          debugPrint(
            '⏭️ [DB_HEALTH] Skipping health check (last check: $hoursSinceLastCheck hours ago)',
          );
          return;
        }
      }

      debugPrint('🏥 [DB_HEALTH] Starting periodic health check...');
      final results = await _databaseManager.performHealthCheck();

      // Store last check timestamp
      await LocalStorageService.setString(
        'last_db_health_check',
        now.toIso8601String(),
      );

      final allPassed = results.values.every((v) => v == true);
      if (allPassed) {
        debugPrint('✅ [DB_HEALTH] All checks passed');
      } else {
        debugPrint('⚠️ [DB_HEALTH] Some checks failed: $results');
      }
    } catch (e) {
      debugPrint('⚠️ [DB_HEALTH] Health check failed (non-critical): $e');
      // Don't block app startup on health check failure
    }
  }

  void _retryInit() {
    debugPrint('🔄 [APP] Retrying initialization...');
    setState(() {
      _initFuture = _initializeApp();
    });
  }

  @override
  void dispose() {
    debugPrint('🚀 [APP] dispose triggered');
    // DeepLinkService handles its own lifecycle
    ReceiveShareService.instance.dispose();
    _chatService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🚀 [APP] build triggered');
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
            chatService: _chatService,
            errorHandler: _errorHandler,
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
            debugShowCheckedModeBanner: false,
            routes: {
              '/onboarding': (context) => const OnboardingScreen(),
              '/main': (context) => const MainScreen(),
            },
            themeMode: themeProvider.themeMode == AppThemeMode.system
                ? ThemeMode.system
                : (themeProvider.themeMode == AppThemeMode.dark
                      ? ThemeMode.dark
                      : ThemeMode.light),
            darkTheme: themeProvider.darkTheme,
            theme: themeProvider.lightTheme,
            locale: Provider.of<LocaleProvider>(context).locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: FutureBuilder<Map<String, dynamic>>(
              future: _initFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    backgroundColor: Color(0xFF0F172A),
                    body: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.cyanAccent),
                          SizedBox(height: 24),
                          Text(
                            'Initializing Boofer OS...',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.hasError ||
                    (snapshot.data != null &&
                        snapshot.data!['error'] != null)) {
                  return _ErrorScreen(
                    message: snapshot.data?['error'] ?? 'Unknown Error',
                    onRetry: _retryInit,
                  );
                }

                final initialRoute =
                    snapshot.data?['initialRoute'] ?? '/onboarding';
                final List<Map<String, dynamic>> initialAccounts =
                    List<Map<String, dynamic>>.from(
                      snapshot.data?['accounts'] ?? [],
                    );

                // Return appropriate initial screen
                switch (initialRoute) {
                  case '/main':
                    return const MainScreen();
                  case '/legal-acceptance':
                    return const LegalAcceptanceScreen();
                  case '/welcome':
                    // Map empty data for welcome screen if accessed without draft
                    return const WelcomeScreen(draftData: {});
                  case '/onboarding':
                  default:
                    return OnboardingScreen(initialAccounts: initialAccounts);
                }
              },
            ),
            onGenerateRoute: (settings) {
              if (settings.name == '/profile') {
                // Support both String (userId) and Friend/User objects
                if (settings.arguments is String) {
                  return MaterialPageRoute(
                    builder: (context) =>
                        UserProfileScreen(userId: settings.arguments as String),
                  );
                } else if (settings.arguments is Friend) {
                  return MaterialPageRoute(
                    builder: (context) => UserProfileScreen(
                      userId: (settings.arguments as Friend).id,
                    ),
                  );
                } else if (settings.arguments is User) {
                  return MaterialPageRoute(
                    builder: (context) => UserProfileScreen(
                      userId: (settings.arguments as User).id,
                    ),
                  );
                }
              }

              if (settings.name == '/chat') {
                final args = settings.arguments;
                String? rId, rName, rHandle, rAvatar, rPic, vNum;

                if (args is Map<String, dynamic>) {
                  rId = args['recipientId'] ?? args['friend']?.id;
                  rName = args['recipientName'] ?? args['friend']?.name;
                  rHandle = args['recipientHandle'] ?? args['friend']?.handle;
                  rAvatar = args['recipientAvatar'] ?? args['friend']?.avatar;
                  rPic =
                      args['recipientProfilePicture'] ??
                      args['friend']?.profilePicture;
                  vNum = args['virtualNumber'] ?? args['friend']?.virtualNumber;
                } else if (args is Friend) {
                  rId = args.id;
                  rName = args.name;
                  rHandle = args.handle;
                  rAvatar = args.avatar;
                  rPic = args.profilePicture;
                  vNum = args.virtualNumber;
                } else if (args is User) {
                  rId = args.id;
                  rName = args.fullName;
                  rHandle = args.handle;
                  rAvatar = args.avatar;
                  rPic = args.profilePicture;
                  vNum = args.virtualNumber;
                }

                if (rId != null) {
                  return MaterialPageRoute(
                    builder: (context) => FriendChatScreen(
                      recipientId: rId!,
                      recipientName: rName ?? 'User',
                      recipientHandle: rHandle,
                      recipientAvatar: rAvatar,
                      recipientProfilePicture: rPic,
                      virtualNumber: vNum,
                    ),
                  );
                }
              }

              if (settings.name == '/notification-settings') {
                return MaterialPageRoute(
                  builder: (context) => const NotificationSettingsScreen(),
                );
              }
              if (settings.name == '/appearance-settings') {
                return MaterialPageRoute(
                  builder: (context) => const AppearanceSettingsScreen(),
                );
              }
              if (settings.name == '/customization-settings') {
                return MaterialPageRoute(
                  builder: (context) => const CustomizationSettingsScreen(),
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorScreen({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 24),
              const Text(
                'Oops! Boofer couldn\'t connect',
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
                  color: Colors.white.withAlpha(180),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Retry Connection'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
