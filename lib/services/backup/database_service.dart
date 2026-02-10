import 'dart:async';
import '../../models/message_model.dart';

/// Stub database service for backup architecture
class DatabaseService {
  static DatabaseService? _instance;
  
  final StreamController<List<Message>> _messagesController = 
      StreamController<List<Message>>.broadcast();
  
  final List<Message> _messages = [];
  
  static DatabaseService get instance {
    _instance ??= DatabaseService();
    return _instance!;
  }

  Future<void> initialize() async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Stream<List<Message>> get messagesStream => _messagesController.stream;

  Future<List<Message>> getMessages({
    int offset = 0,
    int limit = 50,
    bool ascending = false,
  }) async {
    return _messages.skip(offset).take(limit).toList();
  }

  Future<List<Message>> getMessagesByConversation(String conversationId) async {
    return _messages.where((m) => m.conversationId == conversationId).toList();
  }

  Future<List<Message>> getMessagesByStatus(MessageStatus status) async {
    return _messages.where((m) => m.status == status).toList();
  }

  Future<List<Message>> getOfflineMessages() async {
    return _messages.where((m) => m.isOffline).toList();
  }

  Future<int> saveMessage(Message message) async {
    _messages.add(message);
    _messagesController.add(_messages);
    return _messages.length;
  }

  Future<List<int>> saveMessages(List<Message> messages) async {
    _messages.addAll(messages);
    _messagesController.add(_messages);
    return List.generate(messages.length, (i) => _messages.length - messages.length + i);
  }

  Future<void> updateMessageStatus(String messageId, MessageStatus status) async {
    // Stub implementation
  }

  Future<void> updateMessageStatuses(List<String> messageIds, MessageStatus status) async {
    // Stub implementation
  }

  Future<bool> deleteMessage(String messageId) async {
    return true;
  }

  Future<int> deleteOldMessages(DateTime cutoffDate) async {
    return 0;
  }

  Future<int> getMessageCount() async {
    return _messages.length;
  }

  Future<int> getMessageCountByStatus(MessageStatus status) async {
    return _messages.where((m) => m.status == status).length;
  }

  Future<bool> messageExists(String messageHash) async {
    return _messages.any((m) => m.messageHash == messageHash);
  }

  Future<Message?> findMessageByHash(String messageHash) async {
    try {
      return _messages.firstWhere((m) => m.messageHash == messageHash);
    } catch (e) {
      return null;
    }
  }

  Future<void> clearAllMessages() async {
    _messages.clear();
    _messagesController.add(_messages);
  }

  void dispose() {
    _messagesController.close();
  }
}
