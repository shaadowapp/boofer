// Stub database service for demo purposes

class DatabaseService {
  static DatabaseService? _instance;
  static DatabaseService get instance => _instance ??= DatabaseService._();
  DatabaseService._();

  Future<void> initialize() async {
    // Stub implementation
    await Future.delayed(Duration(milliseconds: 100));
  }

  Future<void> dispose() async {
    // Stub implementation
  }
}