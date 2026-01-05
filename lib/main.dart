import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/friend_chat_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'services/stub_services.dart';
import 'services/app_state_service.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/username_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/archive_settings_provider.dart';
import 'models/friend_model.dart';
import 'l10n/app_localizations.dart';

// Service Locator for dependency injection
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  final Map<Type, dynamic> _services = {};

  T get<T>() {
    final service = _services[T];
    if (service == null) {
      throw Exception('Service of type $T not found. Make sure it is registered.');
    }
    return service as T;
  }

  void register<T>(T service) {
    _services[T] = service;
  }

  void unregister<T>() {
    _services.remove(T);
  }

  bool isRegistered<T>() {
    return _services.containsKey(T);
  }
}

// Service initialization result tracking
class ServiceInitResult {
  final bool isSuccess;
  final String? error;
  final String serviceName;

  ServiceInitResult.success(this.serviceName) : isSuccess = true, error = null;
  ServiceInitResult.failure(this.serviceName, this.error) : isSuccess = false;
}

class AppInitializationResult {
  final List<ServiceInitResult> results;
  final bool hasCriticalFailures;
  final bool canRunInDegradedMode;

  AppInitializationResult(this.results)
      : hasCriticalFailures = results.any((r) => !r.isSuccess && _isCriticalService(r.serviceName)),
        canRunInDegradedMode = results.where((r) => r.isSuccess && _isCriticalService(r.serviceName)).length >= 2;

  static bool _isCriticalService(String serviceName) {
    return ['DatabaseService', 'MessageRepository', 'NetworkService'].contains(serviceName);
  }

  List<String> get failedServices => results.where((r) => !r.isSuccess).map((r) => r.serviceName).toList();
  List<String> get successfulServices => results.where((r) => r.isSuccess).map((r) => r.serviceName).toList();
}

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize stub services for demo purposes
  final serviceLocator = ServiceLocator();
  
  // Register stub services
  serviceLocator.register<DatabaseService>(DatabaseService.instance);
  serviceLocator.register<MessageRepository>(MessageRepository());
  serviceLocator.register<IMeshService>(MeshService());
  serviceLocator.register<IOnlineService>(OnlineService());
  serviceLocator.register<INetworkService>(NetworkService());

  // Initialize stub services
  await DatabaseService.instance.initialize();
  await serviceLocator.get<INetworkService>().initialize();

  // Create providers
  final usernameProvider = UsernameProvider();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ChangeNotifierProvider(create: (context) => LocaleProvider()),
      ChangeNotifierProvider.value(value: usernameProvider),
      ChangeNotifierProvider(create: (context) => ChatProvider()),
      ChangeNotifierProvider(create: (context) => ArchiveSettingsProvider()),
    ],
    child: const BooferApp(
      isDegradedMode: false,
      failedServices: [],
    ),
  ));
}

/*
Future<AppInitializationResult> _initializeServicesWithFallback() async {
  final serviceLocator = ServiceLocator();
  final results = <ServiceInitResult>[];

  // Initialize Error Service first (other services may need it)
  try {
    final errorService = ErrorService();
    serviceLocator.register<ErrorService>(errorService);
    results.add(ServiceInitResult.success('ErrorService'));
  } catch (e) {
    results.add(ServiceInitResult.failure('ErrorService', e.toString()));
    debugPrint('Warning: Error service failed to initialize: $e');
  }

  // Initialize Database Service (critical)
  try {
    final databaseService = DatabaseService();
    await databaseService.initialize();
    serviceLocator.register<DatabaseService>(databaseService);
    results.add(ServiceInitResult.success('DatabaseService'));
  } catch (e) {
    results.add(ServiceInitResult.failure('DatabaseService', e.toString()));
    debugPrint('Critical: Database service failed to initialize: $e');
    
    // Log error if ErrorService is available
    if (serviceLocator.isRegistered<ErrorService>()) {
      serviceLocator.get<ErrorService>().logError(
        ChatError.initializationError(
          message: 'Database service initialization failed: $e',
          stackTrace: StackTrace.current.toString(),
          context: {'service': 'DatabaseService'},
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
    }
  }

  // Initialize Message Repository (critical, depends on database)
  if (serviceLocator.isRegistered<DatabaseService>()) {
    try {
      final messageRepository = MessageRepository(serviceLocator.get<DatabaseService>());
      serviceLocator.register<MessageRepository>(messageRepository);
      results.add(ServiceInitResult.success('MessageRepository'));
    } catch (e) {
      results.add(ServiceInitResult.failure('MessageRepository', e.toString()));
      debugPrint('Critical: Message repository failed to initialize: $e');
    }
  } else {
    results.add(ServiceInitResult.failure('MessageRepository', 'Database service not available'));
  }

  // Initialize Network Service (critical)
  try {
    final networkService = NetworkService();
    await networkService.initialize();
    serviceLocator.register<NetworkService>(networkService);
    results.add(ServiceInitResult.success('NetworkService'));
  } catch (e) {
    results.add(ServiceInitResult.failure('NetworkService', e.toString()));
    debugPrint('Critical: Network service failed to initialize: $e');
  }

  // Initialize Mesh Service (non-critical)
  try {
    final meshService = MeshService();
    await meshService.initialize();
    serviceLocator.register<MeshService>(meshService);
    results.add(ServiceInitResult.success('MeshService'));
  } catch (e) {
    results.add(ServiceInitResult.failure('MeshService', e.toString()));
    debugPrint('Warning: Mesh service failed to initialize: $e');
  }

  // Initialize Online Service (non-critical)
  try {
    final onlineService = OnlineService();
    await onlineService.initialize();
    serviceLocator.register<OnlineService>(onlineService);
    results.add(ServiceInitResult.success('OnlineService'));
  } catch (e) {
    results.add(ServiceInitResult.failure('OnlineService', e.toString()));
    debugPrint('Warning: Online service failed to initialize: $e');
  }

  // Initialize Message Handlers (depends on services)
  if (serviceLocator.isRegistered<MeshService>() && serviceLocator.isRegistered<MessageRepository>()) {
    try {
      final meshMessageHandler = MeshMessageHandler(
        serviceLocator.get<MeshService>(),
        serviceLocator.get<MessageRepository>(),
      );
      serviceLocator.register<MeshMessageHandler>(meshMessageHandler);
      results.add(ServiceInitResult.success('MeshMessageHandler'));
    } catch (e) {
      results.add(ServiceInitResult.failure('MeshMessageHandler', e.toString()));
    }

    try {
      final meshReceptionHandler = MeshReceptionHandler(
        serviceLocator.get<MeshService>(),
        serviceLocator.get<MessageRepository>(),
      );
      serviceLocator.register<MeshReceptionHandler>(meshReceptionHandler);
      results.add(ServiceInitResult.success('MeshReceptionHandler'));
    } catch (e) {
      results.add(ServiceInitResult.failure('MeshReceptionHandler', e.toString()));
    }
  }

  if (serviceLocator.isRegistered<OnlineService>() && serviceLocator.isRegistered<MessageRepository>()) {
    try {
      final onlineMessageHandler = OnlineMessageHandler(
        serviceLocator.get<OnlineService>(),
        serviceLocator.get<MessageRepository>(),
      );
      serviceLocator.register<OnlineMessageHandler>(onlineMessageHandler);
      results.add(ServiceInitResult.success('OnlineMessageHandler'));
    } catch (e) {
      results.add(ServiceInitResult.failure('OnlineMessageHandler', e.toString()));
    }
  }

  // Initialize Sync Service (depends on multiple services)
  if (serviceLocator.isRegistered<MessageRepository>()) {
    try {
      final syncService = SyncService(
        serviceLocator.get<MessageRepository>(),
        serviceLocator.isRegistered<MeshService>() ? serviceLocator.get<MeshService>() : null,
        serviceLocator.isRegistered<OnlineService>() ? serviceLocator.get<OnlineService>() : null,
      );
      serviceLocator.register<SyncService>(syncService);
      results.add(ServiceInitResult.success('SyncService'));
    } catch (e) {
      results.add(ServiceInitResult.failure('SyncService', e.toString()));
    }
  }

  // Initialize Mode Manager (depends on network services)
  if (serviceLocator.isRegistered<NetworkService>()) {
    try {
      final modeManager = ModeManager(
        serviceLocator.get<NetworkService>(),
        serviceLocator.isRegistered<MeshService>() ? serviceLocator.get<MeshService>() : null,
        serviceLocator.isRegistered<OnlineService>() ? serviceLocator.get<OnlineService>() : null,
      );
      await modeManager.initialize();
      serviceLocator.register<ModeManager>(modeManager);
      results.add(ServiceInitResult.success('ModeManager'));
    } catch (e) {
      results.add(ServiceInitResult.failure('ModeManager', e.toString()));
    }
  }

  // Initialize Message Stream Manager
  if (serviceLocator.isRegistered<MessageRepository>()) {
    try {
      final messageStreamManager = MessageStreamManager(serviceLocator.get<MessageRepository>());
      serviceLocator.register<MessageStreamManager>(messageStreamManager);
      results.add(ServiceInitResult.success('MessageStreamManager'));
    } catch (e) {
      results.add(ServiceInitResult.failure('MessageStreamManager', e.toString()));
    }
  }

  // Initialize Chat Service (main orchestrator)
  if (serviceLocator.isRegistered<MessageRepository>() && serviceLocator.isRegistered<MessageStreamManager>()) {
    try {
      final chatService = ChatService(
        serviceLocator.get<MessageRepository>(),
        serviceLocator.isRegistered<MeshMessageHandler>() ? serviceLocator.get<MeshMessageHandler>() : null,
        serviceLocator.isRegistered<OnlineMessageHandler>() ? serviceLocator.get<OnlineMessageHandler>() : null,
        serviceLocator.isRegistered<SyncService>() ? serviceLocator.get<SyncService>() : null,
        serviceLocator.isRegistered<ModeManager>() ? serviceLocator.get<ModeManager>() : null,
        serviceLocator.get<MessageStreamManager>(),
      );
      await chatService.initialize();
      serviceLocator.register<ChatService>(chatService);
      results.add(ServiceInitResult.success('ChatService'));
    } catch (e) {
      results.add(ServiceInitResult.failure('ChatService', e.toString()));
    }
  }

  return AppInitializationResult(results);
}
*/

class BooferApp extends StatelessWidget {
  final bool isDegradedMode;
  final List<String> failedServices;

  const BooferApp({
    super.key,
    this.isDegradedMode = false,
    this.failedServices = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LocaleProvider>(
      builder: (context, themeProvider, localeProvider, child) {
        return MaterialApp(
          title: 'Boofer Chat',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.themeMode == AppThemeMode.system 
              ? ThemeMode.system 
              : (themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light),
          locale: localeProvider.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SplashScreen(),
          routes: {
            '/onboarding': (context) => const OnboardingScreen(),
            '/main': (context) => const MainScreen(),
            '/profile': (context) => const ProfileScreen(),
          },
          builder: (context, child) {
            // Global error handling wrapper
            ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
              return _buildErrorWidget(errorDetails);
            };
            return child!;
          },
          // Navigation configuration
          onGenerateRoute: _generateRoute,
          initialRoute: '/',
        );
      },
    );
  }

  Widget _buildErrorWidget(FlutterErrorDetails errorDetails) {
    return Material(
      color: Colors.red.shade900,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                errorDetails.exception.toString(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // In a real app, this could restart the app or navigate to a safe screen
                  debugPrint('Error widget button pressed');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red.shade900,
                ),
                child: const Text('Restart App'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(
          builder: (context) => const SplashScreen(),
          settings: settings,
        );
      case '/onboarding':
        return MaterialPageRoute(
          builder: (context) => const OnboardingScreen(),
          settings: settings,
        );
      case '/main':
        return MaterialPageRoute(
          builder: (context) => const MainScreen(),
          settings: settings,
        );
      case '/profile':
        return MaterialPageRoute(
          builder: (context) => const ProfileScreen(),
          settings: settings,
        );
      case '/settings':
        return MaterialPageRoute(
          builder: (context) => const SettingsScreen(),
          settings: settings,
        );
      case '/chat':
        final args = settings.arguments;
        if (args is Friend) {
          return MaterialPageRoute(
            builder: (context) => FriendChatScreen(friend: args),
            settings: settings,
          );
        } else {
          // If no friend is provided, redirect to main screen
          return MaterialPageRoute(
            builder: (context) => const MainScreen(),
            settings: settings,
          );
        }
      case '/error':
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (context) => ErrorScreen(
            error: args?['error'] ?? 'Unknown error',
            stackTrace: args?['stackTrace'],
            failedServices: args?['failedServices'] ?? [],
            canRetry: args?['canRetry'] ?? false,
          ),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Page Not Found')),
            body: const Center(
              child: Text(
                '404 - Page Not Found',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
          settings: settings,
        );
    }
  }
}

class DegradedModeWrapper extends StatelessWidget {
  final List<String> failedServices;
  final Widget child;

  const DegradedModeWrapper({
    super.key,
    required this.failedServices,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8.0),
            color: Colors.orange.shade800,
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Running in degraded mode. Some features unavailable.',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showDegradedModeDetails(context),
                    child: const Text('Details', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  void _showDegradedModeDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Degraded Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('The following services failed to initialize:'),
            const SizedBox(height: 8),
            ...failedServices.map((service) => Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Text('• $service', style: const TextStyle(fontFamily: 'monospace')),
            )),
            const SizedBox(height: 16),
            const Text('Available features may be limited. You can still:'),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• View and send messages'),
                  Text('• Access local message history'),
                  Text('• Use basic chat functionality'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _retryInitialization(context);
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _retryInitialization(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Retrying initialization...'),
          ],
        ),
      ),
    );

    // Simulate retry (in real app, this would restart the initialization)
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Retry completed. Please restart the app to see changes.'),
          duration: Duration(seconds: 3),
        ),
      );
    });
  }
}

class DegradedModeApp extends StatelessWidget {
  final List<String> failedServices;
  final List<String> successfulServices;

  const DegradedModeApp({
    super.key,
    required this.failedServices,
    required this.successfulServices,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LocaleProvider>(
      builder: (context, themeProvider, localeProvider, child) {
        return MaterialApp(
          title: 'Boofer Chat - Degraded Mode',
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.themeMode == AppThemeMode.system 
              ? ThemeMode.system 
              : (themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light),
          locale: localeProvider.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DegradedModeScreen(
            failedServices: failedServices,
            successfulServices: successfulServices,
          ),
        );
      },
    );
  }
}

class DegradedModeScreen extends StatelessWidget {
  final List<String> failedServices;
  final List<String> successfulServices;

  const DegradedModeScreen({
    super.key,
    required this.failedServices,
    required this.successfulServices,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Degraded Mode'),
        backgroundColor: Colors.orange.shade800,
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return IconButton(
                icon: Icon(
                  themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                ),
                onPressed: () => themeProvider.toggleTheme(),
                tooltip: themeProvider.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.warning_amber,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            const Text(
              'App running in degraded mode',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Some services failed to initialize, but the app can still run with limited functionality.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            const Text(
              'Failed Services:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade700),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: failedServices.map((service) => 
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $service', style: const TextStyle(fontFamily: 'monospace')),
                  )
                ).toList(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Working Services:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade900.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade700),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: successfulServices.map((service) => 
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $service', style: const TextStyle(fontFamily: 'monospace')),
                  )
                ).toList(),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Continue with limited functionality
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const BooferApp(
                            isDegradedMode: true,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Continue Anyway'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      SystemNavigator.pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade700,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Exit App'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String error;
  final List<String> failedServices;
  final bool canRetry;

  const ErrorApp({
    super.key,
    required this.error,
    this.failedServices = const [],
    this.canRetry = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LocaleProvider>(
      builder: (context, themeProvider, localeProvider, child) {
        return MaterialApp(
          title: 'Boofer Chat - Error',
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.themeMode == AppThemeMode.system 
              ? ThemeMode.system 
              : (themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light),
          locale: localeProvider.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ErrorScreen(
            error: error,
            failedServices: failedServices,
            canRetry: canRetry,
          ),
        );
      },
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final String error;
  final String? stackTrace;
  final List<String> failedServices;
  final bool canRetry;

  const ErrorScreen({
    super.key,
    required this.error,
    this.stackTrace,
    this.failedServices = const [],
    this.canRetry = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Initialization Error'),
        backgroundColor: Colors.red.shade800,
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return IconButton(
                icon: Icon(
                  themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                ),
                onPressed: () => themeProvider.toggleTheme(),
                tooltip: themeProvider.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to initialize the application',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (failedServices.isNotEmpty) ...[
              const Text(
                'Failed Services:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade700),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: failedServices.map((service) => 
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $service', style: const TextStyle(fontFamily: 'monospace')),
                    )
                  ).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Error Details:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                error,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            if (stackTrace != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Stack Trace:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      stackTrace!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (canRetry) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _retryInitialization(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        SystemNavigator.pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Exit App'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    SystemNavigator.pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Exit App'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _retryInitialization(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Retrying initialization...'),
          ],
        ),
      ),
    );

    // Simulate retry (in real app, this would restart the initialization)
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Retry failed. Please check your device and try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    });
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Reduce splash time for better UX
      await Future.delayed(const Duration(milliseconds: 300));
      
      setState(() {
        _statusMessage = 'Initializing app state...';
      });

      // Initialize app state service
      final appState = AppStateService.instance;
      final isOnboardingCompleted = await appState.initialize();
      
      if (isOnboardingCompleted && appState.isUserLoggedIn) {
        // Load user preferences and data for returning users
        await _loadUserPreferences();
        
        if (mounted) {
          setState(() {
            _statusMessage = 'Welcome back, ${appState.userDisplayName}!';
          });
          
          // Small delay to show welcome message
          await Future.delayed(const Duration(milliseconds: 200));
          
          // User has completed onboarding, go to main screen
          Navigator.pushReplacementNamed(context, '/main');
        }
      } else {
        if (mounted) {
          setState(() {
            _statusMessage = 'Setting up your account...';
          });
          
          // Small delay for smooth transition
          await Future.delayed(const Duration(milliseconds: 200));
          
          // User needs to complete onboarding
          Navigator.pushReplacementNamed(context, '/onboarding');
        }
      }
    } catch (e) {
      // Handle errors gracefully
      debugPrint('Error during app initialization: $e');
      
      setState(() {
        _statusMessage = 'Initialization failed, starting fresh...';
      });

      // Small delay to show error message
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        // On error, default to showing onboarding
        // This ensures new users can still access the app
        Navigator.pushReplacementNamed(context, '/onboarding');
      }
    }
  }

  Future<void> _loadUserPreferences() async {
    try {
      setState(() {
        _statusMessage = 'Loading your preferences...';
      });

      final appState = AppStateService.instance;
      
      if (appState.currentUser != null) {
        // Log app state summary for debugging (remove in production)
        final summary = appState.getAppSummary();
        debugPrint('App state summary: $summary');
        
        // Here you could initialize user-specific services or preferences
        // For example:
        // - Setting up user-specific chat rooms
        // - Loading message history
        // - Configuring user preferences
        // - Initializing notification settings
        
        // Reduce loading time for better UX
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      debugPrint('Error loading user preferences: $e');
      // Continue anyway - user can still use the app
      setState(() {
        _statusMessage = 'Using default settings...';
      });
    }
  }

  // Keep the old method for backward compatibility during transition
  Future<void> _checkOnboardingStatus() async {
    await _initializeApp();
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
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 40),
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _statusMessage,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
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