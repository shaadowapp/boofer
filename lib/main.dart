import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/onboarding_controller.dart';
import 'providers/theme_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/archive_settings_provider.dart';
import 'providers/username_provider.dart';
import 'providers/locale_provider.dart';
import 'services/chat_service.dart';
import 'services/user_service.dart';
import 'core/database/database_manager.dart';
import 'core/error/error_handler.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_screen.dart';
import 'screens/friend_chat_screen.dart';
import 'models/friend_model.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('Starting beautiful Boofer app...');
  
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
        ChangeNotifierProvider(create: (_) => OnboardingController()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider(
          chatService: chatService,
          errorHandler: errorHandler,
        )),
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
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SplashScreen(),
            routes: {
              '/onboarding': (context) => const OnboardingScreen(),
              '/main': (context) => const MainScreen(),
              '/chat': (context) {
                final friend = ModalRoute.of(context)?.settings.arguments as Friend?;
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
  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    await Future.delayed(const Duration(seconds: 2)); // Show splash for 2 seconds
    
    final isOnboarded = await UserService.isOnboarded();
    
    if (mounted) {
      if (isOnboarded) {
        Navigator.pushReplacementNamed(context, '/main');
      } else {
        Navigator.pushReplacementNamed(context, '/onboarding');
      }
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
            colors: [
              Color(0xFF1E3A8A),
              Color(0xFF3B82F6),
              Color(0xFF60A5FA),
            ],
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
                            themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
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
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_rounded,
                        size: 80,
                        color: Colors.white,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Boofer',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Privacy-first messaging',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      SizedBox(height: 40),
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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