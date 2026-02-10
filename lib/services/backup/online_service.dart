// Stub online service for demo purposes
import 'dart:async';
import '../../models/message_model.dart';

abstract class IOnlineService {
  Future<void> initialize(String supabaseUrl, String supabaseKey);
  Future<void> connect();
  Future<void> disconnect();
  Future<void> sendMessage(Message message);
  Future<void> sendOnlineMessage(String text, String senderId);
  Future<void> syncOfflineMessages(List<Message> messages);
  Future<List<Message>> getRecentMessages({int limit = 100});
  Future<List<Message>> getConversationMessages(String conversationId);
  void setCurrentUserId(String userId);
  Stream<Message> get messageStream;
  Stream<dynamic> get incomingMessages;
  bool get isConnected;
  bool get isOnline;
  Map<String, dynamic> getConnectionStatus();
  void dispose();
}

class OnlineService implements IOnlineService {
  static OnlineService? _instance;
  
  final StreamController<Message> _messageController = StreamController<Message>.broadcast();
  final StreamController<dynamic> _incomingController = StreamController<dynamic>.broadcast();
  bool _isConnected = false;
  String? _currentUserId;

  static OnlineService getInstance({dynamic messageRepository}) {
    _instance ??= OnlineService();
    return _instance!;
  }

  @override
  Future<void> initialize(String supabaseUrl, String supabaseKey) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<void> connect() async {
    _isConnected = true;
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<void> sendMessage(Message message) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<void> sendOnlineMessage(String text, String senderId) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<void> syncOfflineMessages(List<Message> messages) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<List<Message>> getRecentMessages({int limit = 100}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return [];
  }

  @override
  Future<List<Message>> getConversationMessages(String conversationId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return [];
  }

  @override
  void setCurrentUserId(String userId) {
    _currentUserId = userId;
  }

  @override
  Stream<Message> get messageStream => _messageController.stream;

  @override
  Stream<dynamic> get incomingMessages => _incomingController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  bool get isOnline => _isConnected;

  @override
  Map<String, dynamic> getConnectionStatus() {
    return {
      'isConnected': _isConnected,
      'userId': _currentUserId,
    };
  }

  @override
  void dispose() {
    _messageController.close();
    _incomingController.close();
  }
}