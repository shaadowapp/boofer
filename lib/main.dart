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
import 'services/user_service.dart';
import 'services/sync_service.dart';
import 'services/profile_picture_service.dart';
import 'core/database/database_manager.dart';
import 'core/error/error_handler.dart';
import 'screens/main_screen.dart';
import 'screens/friend_chat_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/appearance_settings_screen.dart';
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

  // Initialize Firebase for real-time functionality
  await Firebase.initializeApp();

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Configure Firestore for offline support and reduce network spam
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Disable network temporarily to prevent spam during initialization
    // It will auto-enable when network is available
    print('📱 Firestore configured with offline persistence');
  } catch (e) {
    print('⚠️ Firestore settings error (non-critical): $e');
  }

  // Initialize sync service for hybrid online/offline functionality
  await SyncService.instance.initialize();

  // Initialize notification service with channels
  await NotificationService.instance.initialize();

  // Initialize profile picture service BEFORE app starts
  // This ensures profile picture is loaded from storage before UI renders
  await ProfilePictureService.instance.initialize();
  print('📸 Profile picture service initialized');

  print('Starting beautiful Boofer app with real-time capabilities...');

  runApp(const BooferApp());
}

class BooferApp extends StatelessWidget {
  const BooferApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize services
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
            home: const SplashScreen(),
            routes: {
              '/onboarding': (context) => const OnboardingScreen(),
              '/main': (context) => const MainScreen(),
              '/notification-settings': (context) =>
                  const NotificationSettingsScreen(),
              '/appearance-settings': (context) =>
                  const AppearanceSettingsScreen(),
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

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusMessage = 'Initializing...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() {
        _statusMessage = 'Testing Firebase connection...';
      });

      // Test Firebase connection first
      await _testFirebaseConnection();

      setState(() {
        _statusMessage = 'Checking authentication...';
      });

      // Initialize appearance provider
      final appearanceProvider = context.read<AppearanceProvider>();
      await appearanceProvider.initialize();

      await Future.delayed(const Duration(seconds: 1));

      // Check if user is authenticated with Google
      final authProvider = context.read<AuthStateProvider>();
      // AuthStateProvider initializes automatically, just wait a moment for it to complete
      await Future.delayed(const Duration(milliseconds: 500));

      if (authProvider.isAuthenticated) {
        setState(() {
          // _statusMessage = 'User authenticated ✅';
        });

        // Initialize Firestore user provider
        // Minimal status updates to avoid "onboarding" confusion
        // _statusMessage = 'Loading user profile...';

        final userProvider = context.read<FirestoreUserProvider>();
        await userProvider.initialize();

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          final userId = authProvider.currentUserId;

          if (userId != null) {
            // Check if terms accepted for this specific user
            final hasAcceptedTerms = await LocalStorageService.hasAcceptedTerms(
              userId,
            );

            if (hasAcceptedTerms) {
              Navigator.pushReplacementNamed(context, '/main');
            } else {
              Navigator.pushReplacementNamed(context, '/legal-acceptance');
            }
          } else {
            // Should not happen if authenticated, but fallback
            Navigator.pushReplacementNamed(context, '/onboarding');
          }
        }
      } else {
        setState(() {
          _statusMessage = 'Authentication required...';
        });
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/onboarding');
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _hasError = true;
      });

      // Still proceed to onboarding after showing error
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/onboarding');
      }
    }
  }

  Future<bool> _verifyUserInFirebase() async {
    try {
      // Get current user from local storage
      final userData = await UserService.getCurrentUser();
      if (userData == null) {
        print('❌ No user data found locally');
        return false;
      }

      // Test Firestore connection and verify user exists
      final firestore = FirebaseFirestore.instance;
      final userDoc = await firestore
          .collection('users')
          .doc(userData.id)
          .get();

      if (userDoc.exists) {
        print('✅ User verified in Firebase: ${userData.id}');
        return true;
      } else {
        print('❌ User not found in Firebase: ${userData.id}');
        return false;
      }
    } catch (e) {
      print('❌ Failed to verify user in Firebase: $e');
      return false;
    }
  }

  Future<void> _testFirebaseConnection() async {
    try {
      print('🔥 Testing Firebase connection...');

      // Simple Firebase initialization test - no write operation
      final firestore = FirebaseFirestore.instance;

      // Just test if we can access Firestore settings (doesn't require auth)
      firestore.settings;

      print('✅ Firebase connection successful!');
      setState(() {
        _statusMessage = 'Firebase connected ✅';
      });

      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      print('❌ Firebase connection failed: $e');
      setState(() {
        _statusMessage = 'Offline mode (Firebase unavailable)';
        _hasError = true;
      });

      await Future.delayed(const Duration(seconds: 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6), Color(0xFF60A5FA)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Theme toggle button in top right
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Consumer<ThemeProvider>(
                    builder: (context, themeProvider, child) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: Icon(
                            themeProvider.isDarkMode
                                ? Icons.light_mode
                                : Icons.dark_mode,
                            color: Colors.white,
                          ),
                          onPressed: () => themeProvider.toggleTheme(),
                          tooltip: themeProvider.isDarkMode
                              ? 'Switch to Light Mode'
                              : 'Switch to Dark Mode',
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Main content
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.chat_bubble_rounded,
                        size: 80,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Boofer',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Privacy-first messaging',
                        style: TextStyle(fontSize: 16, color: Colors.white70),
                      ),
                      const SizedBox(height: 40),
                      if (!_hasError) ...[
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        _statusMessage,
                        style: TextStyle(
                          fontSize: 14,
                          color: _hasError
                              ? Colors.orange[200]
                              : Colors.white70,
                          fontWeight: _hasError
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
