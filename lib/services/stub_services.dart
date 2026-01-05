// Stub services for demo purposes

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static DatabaseService get instance => _instance;
  
  DatabaseService._internal();

  Future<void> initialize() async {
    // Stub implementation
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

class MessageRepository {
  Future<void> initialize() async {
    // Stub implementation
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

abstract class IMeshService {
  Future<void> initialize();
}

class MeshService implements IMeshService {
  @override
  Future<void> initialize() async {
    // Stub implementation
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

abstract class IOnlineService {
  Future<void> initialize();
}

class OnlineService implements IOnlineService {
  @override
  Future<void> initialize() async {
    // Stub implementation
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

abstract class INetworkService {
  Future<void> initialize();
}

class NetworkService implements INetworkService {
  @override
  Future<void> initialize() async {
    // Stub implementation
    await Future.delayed(const Duration(milliseconds: 100));
  }
}