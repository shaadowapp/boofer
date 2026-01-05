// Stub mesh service for demo purposes
import 'dart:async';

abstract class IMeshService {
  Future<void> initialize(String apiKey);
  Future<void> start();
  Future<void> stop();
  Future<void> sendMessage(String message, String recipientId);
  Future<void> sendBroadcastMessage(String message);
  Stream<String> get messageStream;
  Stream<String> get deviceConnectionStream;
  bool get isConnected;
  void dispose();
}

class MeshService implements IMeshService {
  final StreamController<String> _messageController = StreamController<String>.broadcast();
  final StreamController<String> _deviceController = StreamController<String>.broadcast();
  bool _isConnected = false;

  @override
  Future<void> initialize(String apiKey) async {
    await Future.delayed(Duration(milliseconds: 100));
  }

  @override
  Future<void> start() async {
    _isConnected = true;
    await Future.delayed(Duration(milliseconds: 100));
  }

  @override
  Future<void> stop() async {
    _isConnected = false;
    await Future.delayed(Duration(milliseconds: 100));
  }

  @override
  Future<void> sendMessage(String message, String recipientId) async {
    await Future.delayed(Duration(milliseconds: 100));
  }

  @override
  Future<void> sendBroadcastMessage(String message) async {
    await Future.delayed(Duration(milliseconds: 100));
  }

  @override
  Stream<String> get messageStream => _messageController.stream;

  @override
  Stream<String> get deviceConnectionStream => _deviceController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  void dispose() {
    _messageController.close();
    _deviceController.close();
  }
}