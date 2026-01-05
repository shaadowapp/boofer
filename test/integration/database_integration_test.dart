import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:boofer/services/database_service.dart';
import 'package:boofer/models/message_model.dart';
import 'dart:io';

void main() {
  group('Database Integration Tests', () {
    late DatabaseService databaseService;
    late Directory tempDir;

    setUp(() async {
      // Create temporary directory for test database
      tempDir = await Directory.systemTemp.createTemp('test_db');
      databaseService = DatabaseService();
      await databaseService.initialize(directory: tempDir.path);
    });

    tearDown(() async {
      await databaseService.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('should initialize database successfully', () async {
      expect(databaseService.isInitialized, isTrue);
    });

    test('should save and retrieve a message', () async {
      final message = Message()
        ..text = 'Test message'
        ..senderId = 'user123'
        ..timestamp = DateTime.now()
        ..isOffline = false
        ..status = MessageStatus.sent;

      await databaseService.saveMessage(message);
      expect(message.id, isNotNull);

      final messages = await databaseService.getMessages();
      expect(messages.length, equals(1));
      expect(messages.first.text, equals('Test message'));
      expect(messages.first.senderId, equals('user123'));
    });

    test('should save multiple messages and retrieve in correct order', () async {
      final now = DateTime.now();
      final messages = [
        Message()
          ..text = 'First message'
          ..senderId = 'user1'
          ..timestamp = now.subtract(Duration(minutes: 2))
          ..isOffline = false
          ..status = MessageStatus.sent,
        Message()
          ..text = 'Second message'
          ..senderId = 'user2'
          ..timestamp = now.subtract(Duration(minutes: 1))
          ..isOffline = true
          ..status = MessageStatus.delivered,
        Message()
          ..text = 'Third message'
          ..senderId = 'user1'
          ..timestamp = now
          ..isOffline = false
          ..status = MessageStatus.pending,
      ];

      for (final message in messages) {
        await databaseService.saveMessage(message);
      }

      final retrievedMessages = await databaseService.getMessages();
      expect(retrievedMessages.length, equals(3));
      
      // Should be ordered by timestamp (oldest first)
      expect(retrievedMessages[0].text, equals('First message'));
      expect(retrievedMessages[1].text, equals('Second message'));
      expect(retrievedMessages[2].text, equals('Third message'));
    });

    test('should update message status', () async {
      final message = Message()
        ..text = 'Test message'
        ..senderId = 'user123'
        ..timestamp = DateTime.now()
        ..isOffline = false
        ..status = MessageStatus.pending;

      await databaseService.saveMessage(message);
      expect(message.status, equals(MessageStatus.pending));

      await databaseService.updateMessageStatus(message.id!, MessageStatus.sent);

      final messages = await databaseService.getMessages();
      expect(messages.first.status, equals(MessageStatus.sent));
    });

    test('should filter messages by status', () async {
      final messages = [
        Message()
          ..text = 'Sent message'
          ..senderId = 'user1'
          ..timestamp = DateTime.now()
          ..isOffline = false
          ..status = MessageStatus.sent,
        Message()
          ..text = 'Pending message'
          ..senderId = 'user2'
          ..timestamp = DateTime.now()
          ..isOffline = false
          ..status = MessageStatus.pending,
        Message()
          ..text = 'Failed message'
          ..senderId = 'user3'
          ..timestamp = DateTime.now()
          ..isOffline = false
          ..status = MessageStatus.failed,
      ];

      for (final message in messages) {
        await databaseService.saveMessage(message);
      }

      final pendingMessages = await databaseService.getMessagesByStatus(MessageStatus.pending);
      expect(pendingMessages.length, equals(1));
      expect(pendingMessages.first.text, equals('Pending message'));

      final failedMessages = await databaseService.getMessagesByStatus(MessageStatus.failed);
      expect(failedMessages.length, equals(1));
      expect(failedMessages.first.text, equals('Failed message'));
    });

    test('should filter messages by offline mode', () async {
      final messages = [
        Message()
          ..text = 'Online message'
          ..senderId = 'user1'
          ..timestamp = DateTime.now()
          ..isOffline = false
          ..status = MessageStatus.sent,
        Message()
          ..text = 'Offline message'
          ..senderId = 'user2'
          ..timestamp = DateTime.now()
          ..isOffline = true
          ..status = MessageStatus.sent,
      ];

      for (final message in messages) {
        await databaseService.saveMessage(message);
      }

      final offlineMessages = await databaseService.getOfflineMessages();
      expect(offlineMessages.length, equals(1));
      expect(offlineMessages.first.text, equals('Offline message'));
      expect(offlineMessages.first.isOffline, isTrue);
    });

    test('should provide real-time message stream', () async {
      final messageStream = databaseService.watchMessages();
      
      final message = Message()
        ..text = 'Stream test message'
        ..senderId = 'user123'
        ..timestamp = DateTime.now()
        ..isOffline = false
        ..status = MessageStatus.sent;

      // Listen to stream
      final streamFuture = messageStream.first;
      
      // Save message
      await databaseService.saveMessage(message);
      
      // Stream should emit the new message
      final messages = await streamFuture;
      expect(messages.length, equals(1));
      expect(messages.first.text, equals('Stream test message'));
    });

    test('should handle concurrent message saves', () async {
      final futures = <Future>[];
      
      for (int i = 0; i < 10; i++) {
        final message = Message()
          ..text = 'Concurrent message $i'
          ..senderId = 'user$i'
          ..timestamp = DateTime.now()
          ..isOffline = false
          ..status = MessageStatus.sent;
        
        futures.add(databaseService.saveMessage(message));
      }

      await Future.wait(futures);

      final messages = await databaseService.getMessages();
      expect(messages.length, equals(10));
    });

    test('should delete message', () async {
      final message = Message()
        ..text = 'Message to delete'
        ..senderId = 'user123'
        ..timestamp = DateTime.now()
        ..isOffline = false
        ..status = MessageStatus.sent;

      await databaseService.saveMessage(message);
      expect(message.id, isNotNull);

      final messagesBefore = await databaseService.getMessages();
      expect(messagesBefore.length, equals(1));

      await databaseService.deleteMessage(message.id!);

      final messagesAfter = await databaseService.getMessages();
      expect(messagesAfter.length, equals(0));
    });

    test('should handle database schema correctly', () async {
      final message = Message()
        ..text = 'Schema test message'
        ..senderId = 'user123'
        ..timestamp = DateTime.now()
        ..isOffline = false
        ..status = MessageStatus.sent;

      await databaseService.saveMessage(message);

      // Verify all fields are persisted correctly
      final messages = await databaseService.getMessages();
      final savedMessage = messages.first;
      
      expect(savedMessage.id, isNotNull);
      expect(savedMessage.text, equals('Schema test message'));
      expect(savedMessage.senderId, equals('user123'));
      expect(savedMessage.timestamp, isNotNull);
      expect(savedMessage.isOffline, isFalse);
      expect(savedMessage.status, equals(MessageStatus.sent));
    });

    test('should handle large number of messages efficiently', () async {
      final stopwatch = Stopwatch()..start();
      
      // Save 1000 messages
      for (int i = 0; i < 1000; i++) {
        final message = Message()
          ..text = 'Message $i'
          ..senderId = 'user${i % 10}'
          ..timestamp = DateTime.now().add(Duration(seconds: i))
          ..isOffline = i % 2 == 0
          ..status = MessageStatus.sent;
        
        await databaseService.saveMessage(message);
      }

      stopwatch.stop();
      print('Time to save 1000 messages: ${stopwatch.elapsedMilliseconds}ms');

      final messages = await databaseService.getMessages();
      expect(messages.length, equals(1000));
      
      // Test query performance
      stopwatch.reset();
      stopwatch.start();
      
      final offlineMessages = await databaseService.getOfflineMessages();
      
      stopwatch.stop();
      print('Time to query offline messages: ${stopwatch.elapsedMilliseconds}ms');
      
      expect(offlineMessages.length, equals(500)); // Half should be offline
    });
  });
}