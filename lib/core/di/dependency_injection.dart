import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_manager.dart';
import '../network/api_client.dart';
import '../error/error_handler.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/chat_service.dart';
import '../../services/notification_service.dart';
import '../../services/connection_service.dart';
import '../../providers/chat_provider.dart';
import '../../providers/user_provider.dart';

final GetIt getIt = GetIt.instance;

class DependencyInjection {
  static Future<void> init() async {
    try {
      // Core services
      final sharedPrefs = await SharedPreferences.getInstance();
      getIt.registerSingleton<SharedPreferences>(sharedPrefs);
      
      // Register database manager as lazy singleton
      getIt.registerLazySingleton<DatabaseManager>(() => DatabaseManager.instance);
      getIt.registerLazySingleton<ApiClient>(() => ApiClient.instance);
      getIt.registerLazySingleton<ErrorHandler>(() => ErrorHandler());
      
      // Business services - also lazy to avoid immediate database access
      getIt.registerLazySingleton<AuthService>(() => AuthService(
        database: getIt<DatabaseManager>(),
        storage: getIt<SharedPreferences>(),
        errorHandler: getIt<ErrorHandler>(),
      ));
      
      getIt.registerLazySingleton<UserService>(() => UserService(
        database: getIt<DatabaseManager>(),
        errorHandler: getIt<ErrorHandler>(),
      ));
      
      getIt.registerLazySingleton<ChatService>(() => ChatService(
        database: getIt<DatabaseManager>(),
        errorHandler: getIt<ErrorHandler>(),
      ));
      
      getIt.registerLazySingleton<NotificationService>(() => NotificationService.instance);
      getIt.registerLazySingleton<ConnectionService>(() => ConnectionService.instance);
      
      // Providers
      getIt.registerFactory<ChatProvider>(() => ChatProvider(
        chatService: getIt<ChatService>(),
        errorHandler: getIt<ErrorHandler>(),
      ));
      
      getIt.registerFactory<UserProvider>(() => UserProvider(
        userService: getIt<UserService>(),
        authService: getIt<AuthService>(),
        errorHandler: getIt<ErrorHandler>(),
      ));
      
      print('Dependency injection initialized successfully');
    } catch (e, stackTrace) {
      print('Error initializing dependencies: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
}