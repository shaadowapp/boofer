import 'dart:async';
import '../models/message_model.dart';
import 'database_service.dart';

/// Repository interface for message operations
abstract class IMessageRepository {
  Stream<List<Message>> get messagesStream;
  Future<List<Message>> getMessages({int offset = 0, int limit = 50, bool ascending = false});
  Future<List<Message>> getMessagesByConversation(String conversationId);
  Future<List<Message>> getMessagesByStatus(MessageStatus status);
  Future<List<Message>> getOfflineMessages();
  Future<int> saveMessage(Message message);
  Future<List<int>> saveMessages(List<Message> messages);
  Future<void> updateMessageStatus(int messageId, MessageStatus status);
  Future<void> updateMessageStatuses(List<int> messageIds, MessageStatus status);
  Future<bool> deleteMessage(int messageId);
  Future<int> deleteOldMessages(DateTime cutoffDate);
  Future<int> getMessageCount();
  Future<int> getMessageCountByStatus(MessageStatus status);
  Future<bool> messageExists(String messageHash);
  Future<Message?> findMessageByHash(String messageHash);
  Future<void> clearAllMessages();
}

/// Concrete implementation of message repository using Isar database
class MessageRepository implements IMessageRepository {
  final DatabaseService _databaseService;

  MessageRepository({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService.instance;

  @override
  Stream<List<Message>> get messagesStream => _databaseService.messagesStream;

  @override
  Future<List<Message>> getMessages({
    int offset = 0,
    int limit = 50,
    bool ascending = false,
  }) async {
    try {
      return await _databaseService.getMessages(
        offset: offset,
        limit: limit,
        ascending: ascending,
      );
    } catch (e) {
      print('Error getting messages: $e');
      rethrow;
    }
  }

  @override
  Future<List<Message>> getMessagesByConversation(String conversationId) async {
    try {
      return await _databaseService.getMessagesByConversation(conversationId);
    } catch (e) {
      print('Error getting messages by conversation: $e');
      rethrow;
    }
  }

  @override
  Future<List<Message>> getMessagesByStatus(MessageStatus status) async {
    try {
      return await _databaseService.getMessagesByStatus(status);
    } catch (e) {
      print('Error getting messages by status: $e');
      rethrow;
    }
  }

  @override
  Future<List<Message>> getOfflineMessages() async {
    try {
      return await _databaseService.getOfflineMessages();
    } catch (e) {
      print('Error getting offline messages: $e');
      rethrow;
    }
  }

  @override
  Future<int> saveMessage(Message message) async {
    try {
      // Check for duplicate messages
      if (message.messageHash != null && 
          await _databaseService.messageExists(message.messageHash!)) {
        print('Message already exists, skipping save: ${message.messageHash}');
        final existing = await _databaseService.findMessageByHash(message.messageHash!);
        return existing?.id ?? 0;
      }

      return await _databaseService.saveMessage(message);
    } catch (e) {
      print('Error saving message: $e');
      rethrow;
    }
  }

  @override
  Future<List<int>> saveMessages(List<Message> messages) async {
    try {
      // Filter out duplicate messages
      final uniqueMessages = <Message>[];
      for (final message in messages) {
        if (message.messageHash == null || 
            !await _databaseService.messageExists(message.messageHash!)) {
          uniqueMessages.add(message);
        }
      }

      if (uniqueMessages.isEmpty) {
        print('No new messages to save');
        return [];
      }

      return await _databaseService.saveMessages(uniqueMessages);
    } catch (e) {
      print('Error saving messages: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateMessageStatus(int messageId, MessageStatus status) async {
    try {
      await _databaseService.updateMessageStatus(messageId, status);
    } catch (e) {
      print('Error updating message status: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateMessageStatuses(List<int> messageIds, MessageStatus status) async {
    try {
      await _databaseService.updateMessageStatuses(messageIds, status);
    } catch (e) {
      print('Error updating message statuses: $e');
      rethrow;
    }
  }

  @override
  Future<bool> deleteMessage(int messageId) async {
    try {
      return await _databaseService.deleteMessage(messageId);
    } catch (e) {
      print('Error deleting message: $e');
      rethrow;
    }
  }

  @override
  Future<int> deleteOldMessages(DateTime cutoffDate) async {
    try {
      return await _databaseService.deleteOldMessages(cutoffDate);
    } catch (e) {
      print('Error deleting old messages: $e');
      rethrow;
    }
  }

  @override
  Future<int> getMessageCount() async {
    try {
      return await _databaseService.getMessageCount();
    } catch (e) {
      print('Error getting message count: $e');
      rethrow;
    }
  }

  @override
  Future<int> getMessageCountByStatus(MessageStatus status) async {
    try {
      return await _databaseService.getMessageCountByStatus(status);
    } catch (e) {
      print('Error getting message count by status: $e');
      rethrow;
    }
  }

  @override
  Future<bool> messageExists(String messageHash) async {
    try {
      return await _databaseService.messageExists(messageHash);
    } catch (e) {
      print('Error checking if message exists: $e');
      rethrow;
    }
  }

  @override
  Future<Message?> findMessageByHash(String messageHash) async {
    try {
      return await _databaseService.findMessageByHash(messageHash);
    } catch (e) {
      print('Error finding message by hash: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearAllMessages() async {
    try {
      await _databaseService.clearAllMessages();
    } catch (e) {
      print('Error clearing all messages: $e');
      rethrow;
    }
  }

  /// Additional utility methods for the repository

  /// Get recent messages (last 24 hours)
  Future<List<Message>> getRecentMessages() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    try {
      final allMessages = await getMessages(limit: 100);
      return allMessages.where((m) => m.timestamp.isAfter(yesterday)).toList();
    } catch (e) {
      print('Error getting recent messages: $e');
      rethrow;
    }
  }

  /// Get pending messages that need to be sent
  Future<List<Message>> getPendingMessages() async {
    return await getMessagesByStatus(MessageStatus.pending);
  }

  /// Get failed messages that need retry
  Future<List<Message>> getFailedMessages() async {
    return await getMessagesByStatus(MessageStatus.failed);
  }

  /// Mark messages as delivered
  Future<void> markMessagesAsDelivered(List<int> messageIds) async {
    await updateMessageStatuses(messageIds, MessageStatus.delivered);
  }

  /// Mark messages as failed
  Future<void> markMessagesAsFailed(List<int> messageIds) async {
    await updateMessageStatuses(messageIds, MessageStatus.failed);
  }

  /// Get statistics about messages
  Future<Map<String, int>> getMessageStatistics() async {
    try {
      final total = await getMessageCount();
      final pending = await getMessageCountByStatus(MessageStatus.pending);
      final sent = await getMessageCountByStatus(MessageStatus.sent);
      final delivered = await getMessageCountByStatus(MessageStatus.delivered);
      final failed = await getMessageCountByStatus(MessageStatus.failed);
      
      final offlineMessages = await getOfflineMessages();
      final offline = offlineMessages.length;
      final online = total - offline;

      return {
        'total': total,
        'pending': pending,
        'sent': sent,
        'delivered': delivered,
        'failed': failed,
        'offline': offline,
        'online': online,
      };
    } catch (e) {
      print('Error getting message statistics: $e');
      rethrow;
    }
  }
}