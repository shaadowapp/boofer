// Stub mesh service for demo purposes
import 'dart:async';

abstract class IMeshService {
  Future<void> initialize(String apiKey);
  Future<void> start();
  Future<void> stop();
  Future<void> sendMessage(String message, String recipientId);
  Future<void> sendBroadcastMessage(String message);
  Future<void> sendMeshMessage(String text, String senderId);
  Stream<String> get messageStream;
  Stream<dynamic> get incomingMessages;
  Stream<String> get deviceConnectionStream;
  bool get isConnected;
  bool get isInitialized;
  bool get isStarted;
  bool get isActive;
  int get peersCount;
  int get connectedPeersCount;
  void dispose();
}

class MeshService implements IMeshService {
  static MeshService? _instance;
  
  final StreamController<String> _messageController = StreamController<String>.broadcast();
  final StreamController<dynamic> _incomingController = StreamController<dynamic>.broadcast();
  final StreamController<String> _deviceController = StreamController<String>.broadcast();
  bool _isConnected = false;
  bool _isInitialized = false;
  bool _isStarted = false;
  final int _peersCount = 0;

  static MeshService getInstance({dynamic messageRepository}) {
    _instance ??= MeshService();
    return _instance!;
  }

  @override
  Future<void> initialize(String apiKey) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _isInitialized = true;
  }

  @override
  Future<void> start() async {
    _isConnected = true;
    _isStarted = true;
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<void> stop() async {
    _isConnected = false;
    _isStarted = false;
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<void> sendMessage(String message, String recipientId) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<void> sendBroadcastMessage(String message) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<void> sendMeshMessage(String text, String senderId) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Stream<String> get messageStream => _messageController.stream;

  @override
  Stream<dynamic> get incomingMessages => _incomingController.stream;

  @override
  Stream<String> get deviceConnectionStream => _deviceController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isStarted => _isStarted;

  @override
  bool get isActive => _isStarted;

  @override
  int get peersCount => _peersCount;

  @override
  int get connectedPeersCount => _peersCount;

  @override
  void dispose() {
    _messageController.close();
    _incomingController.close();
    _deviceController.close();
  }
}