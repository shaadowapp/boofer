// Stub implementations for services that depend on missing packages
// This allows the app to run without the actual dependencies

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../models/chat_error.dart';

// Stub Database Service
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

// Stub Message Repository
class MessageRepository {
  Future<List<Message>> getMessages() async {
    return [];
  }

  Future<List<Message>> getConversationMessages(String conversationId) async {
    return [];
  }

  Future<void> saveMessage(Message message) async {
    // Stub implementation
  }

  Future<void> updateMessage(Message message) async {
    // Stub implementation
  }

  Future<void> deleteMessage(String messageId) async {
    // Stub implementation
  }

  Future<List<Message>> getFailedMessages() async {
    return [];
  }

  Future<List<Message>> getRecentMessages() async {
    return [];
  }

  Future<Map<String, dynamic>> getMessageStatistics() async {
    return {
      'total': 0,
      'sent': 0,
      'received': 0,
      'failed': 0,
    };
  }
}

// Stub Mesh Service
abstract class IMeshService {
  Future<void> initialize(String apiKey);
  Future<void> start();
  Future<void> stop();
  Future<void> sendMessage(String message, String recipientId);
  Future<void> sendBroadcastMessage(String message);
  Stream<String> get messageStream;
  Stream<String> get deviceConnectionStream;
  bool get isConnected;
  void dispose() {}
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

// Stub Online Service
abstract class IOnlineService {
  Future<void> initialize(String supabaseUrl, String supabaseKey);
  Future<void> connect();
  Future<void> disconnect();
  Future<void> sendMessage(Message message);
  Stream<Message> get messageStream;
  bool get isConnected;
  void dispose() {}
}

class OnlineService implements IOnlineService {
  final StreamController<Message> _messageController = StreamController<Message>.broadcast();
  bool _isConnected = false;

  @override
  Future<void> initialize(String supabaseUrl, String supabaseKey) async {
    await Future.delayed(Duration(milliseconds: 100));
  }

  @override
  Future<void> connect() async {
    _isConnected = true;
    await Future.delayed(Duration(milliseconds: 100));
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
    await Future.delayed(Duration(milliseconds: 100));
  }

  @override
  Future<void> sendMessage(Message message) async {
    await Future.delayed(Duration(milliseconds: 100));
  }

  @override
  Stream<Message> get messageStream => _messageController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  void dispose() {
    _messageController.close();
  }
}

// Stub Network Service
abstract class INetworkService {
  Future<void> initialize();
  Stream<bool> get connectivityStream;
  bool get isConnected;
  void dispose() {}
}

class NetworkService implements INetworkService {
  final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();
  bool _isConnected = true;

  @override
  Future<void> initialize() async {
    await Future.delayed(Duration(milliseconds: 100));
  }

  @override
  Stream<bool> get connectivityStream => _connectivityController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  void dispose() {
    _connectivityController.close();
  }
}