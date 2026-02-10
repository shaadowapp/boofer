import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:isar/isar.dart';
import 'package:boofer/models/message_model.dart';
import 'package:boofer/services/database_service.dart';

// Generate mocks - simplified to avoid conflicts
@GenerateMocks([DatabaseService])
import 'database_service_test.mocks.dart';

void main() {
  group('DatabaseService', () {
    late DatabaseService databaseService;
    late MockIsar mockIsar;
    late MockIsarCollection<Message> mockMessagesCollection;

    setUp(() {
      mockIsar = MockIsar();
      mockMessagesCollection = MockIsarCollection<Message>();

      // Reset singleton for testing
      DatabaseService._instance = null;
      DatabaseService._isar = null;

      databaseService = DatabaseService.instance;
    });

    tearDown(() async {
      await databaseService.close();
    });

    group('Initialization', () {
      test('should initialize database successfully', () async {
        // Note: This test would require mocking Isar.open which involves file system operations
        // In a real implementation, we'd use an in-memory database or mock the file system
        
        // For now, we'll test the singleton pattern
        final instance1 = DatabaseService.instance;
        final instance2 = DatabaseService.instance;
        expect(identical(instance1, instance2), true);
      });

      test('should not reinitialize if already initialized', () async {
        // This would test that multiple calls to initialize() don't create new instances
        // Implementation depends on how we mock the Isar.open call
      });

      test('should handle initialization failure', () async {
        // Test initialization failure scenarios
        // Would require mocking Isar.open to throw an exception
      });
    });

    group('CRUD Operations', () {
      setUp(() {
        // Setup mock Isar instance
        DatabaseService._isar = mockIsar;
        when(mockIsar.messages).thenReturn(mockMessagesCollection);
      });

      group('Create Operations', () {
        test('should save single message successfully', () async {
          // Arrange
          final message = Message.create(
            text: 'Test message',
            senderId: 'user1',
            isOffline: true,
          );

          when(mockIsar.writeTxn(any)).thenAnswer((invocation) async {
            final function = invocation.positionalArguments[0] as Function();
            return await function();
          });
          when(mockMessagesCollection.put(any)).thenAnswer((_) async => 123);

          // Act
          final id = await databaseService.saveMessage(message);

          // Assert
          expect(id, 123);
          verify(mockIsar.writeTxn(any)).called(1);
          verify(mockMessagesCollection.put(message)).called(1);
        });

        test('should save multiple messages successfully', () async {
          // Arrange
          final messages = [
            Message.create(text: 'Message 1', senderId: 'user1', isOffline: true),
            Message.create(text: 'Message 2', senderId: 'user2', isOffline: false),
          ];

          when(mockIsar.writeTxn(any)).thenAnswer((invocation) async {
            final function = invocation.positionalArguments[0] as Function();
            return await function();
          });
          when(mockMessagesCollection.putAll(any)).thenAnswer((_) async => [123, 124]);

          // Act
          final ids = await databaseService.saveMessages(messages);

          // Assert
          expect(ids, [123, 124]);
          verify(mockIsar.writeTxn(any)).called(1);
          verify(mockMessagesCollection.putAll(messages)).called(1);
        });
      });

      group('Read Operations', () {
        test('should get messages with pagination', () async {
          // Arrange
          final mockQueryBuilder = MockQueryBuilder<Message, Message, QWhere>();
          final mockAfterWhere = MockQueryBuilder<Message, Message, QAfterWhere>();
          final mockAfterLimit = MockQueryBuilder<Message, Message, QAfterLimit>();
          final mockAfterSortBy = MockQueryBuilder<Message, Message, QAfterSortBy>();

          when(mockMessagesCollection.where()).thenReturn(mockQueryBuilder);
          when(mockQueryBuilder.offset(any)).thenReturn(mockAfterWhere);
          when(mockAfterWhere.limit(any)).thenReturn(mockAfterLimit);
          when(mockAfterLimit.sortByTimestampDesc()).thenReturn(mockAfterSortBy);
          when(mockAfterSortBy.findAll()).thenAnswer((_) async => [
            Message.create(text: 'Message 1', senderId: 'user1', isOffline: true),
            Message.create(text: 'Message 2', senderId: 'user2', isOffline: false),
          ]);

          // Act
          final messages = await databaseService.getMessages(offset: 0, limit: 2);

          // Assert
          expect(messages.length, 2);
          verify(mockQueryBuilder.offset(0)).called(1);
          verify(mockAfterWhere.limit(2)).called(1);
          verify(mockAfterLimit.sortByTimestampDesc()).called(1);
        });

        test('should get messages in ascending order', () async {
          // Arrange
          final mockQueryBuilder = MockQueryBuilder<Message, Message, QWhere>();
          final mockAfterWhere = MockQueryBuilder<Message, Message, QAfterWhere>();
          final mockAfterLimit = MockQueryBuilder<Message, Message, QAfterLimit>();
          final mockAfterSortBy = MockQueryBuilder<Message, Message, QAfterSortBy>();

          when(mockMessagesCollection.where()).thenReturn(mockQueryBuilder);
          when(mockQueryBuilder.offset(any)).thenReturn(mockAfterWhere);
          when(mockAfterWhere.limit(any)).thenReturn(mockAfterLimit);
          when(mockAfterLimit.sortByTimestamp()).thenReturn(mockAfterSortBy);
          when(mockAfterSortBy.findAll()).thenAnswer((_) async => []);

          // Act
          await databaseService.getMessages(ascending: true);

          // Assert
          verify(mockAfterLimit.sortByTimestamp()).called(1);
        });

        test('should get messages by conversation ID', () async {
          // This would test the conversation filtering logic
          // Implementation depends on how we mock the Isar filter operations
        });

        test('should get messages by status', () async {
          // This would test the status filtering logic
          // Implementation depends on how we mock the Isar filter operations
        });

        test('should get offline messages', () async {
          // This would test the offline filtering logic
          // Implementation depends on how we mock the Isar filter operations
        });

        test('should get message count', () async {
          // Arrange
          when(mockMessagesCollection.count()).thenAnswer((_) async => 42);

          // Act
          final count = await databaseService.getMessageCount();

          // Assert
          expect(count, 42);
          verify(mockMessagesCollection.count()).called(1);
        });

        test('should get message count by status', () async {
          // This would test the status-based counting
          // Implementation depends on how we mock the Isar filter operations
        });
      });

      group('Update Operations', () {
        test('should update message status successfully', () async {
          // Arrange
          final message = Message.create(
            text: 'Test message',
            senderId: 'user1',
            isOffline: true,
          );
          message.id = 123;

          when(mockIsar.writeTxn(any)).thenAnswer((invocation) async {
            final function = invocation.positionalArguments[0] as Function();
            return await function();
          });
          when(mockMessagesCollection.get(123)).thenAnswer((_) async => message);
          when(mockMessagesCollection.put(any)).thenAnswer((_) async => 123);

          // Act
          await databaseService.updateMessageStatus(123, MessageStatus.sent);

          // Assert
          verify(mockIsar.writeTxn(any)).called(1);
          verify(mockMessagesCollection.get(123)).called(1);
          verify(mockMessagesCollection.put(any)).called(1);
          expect(message.status, MessageStatus.sent);
        });

        test('should handle update of non-existent message', () async {
          // Arrange
          when(mockIsar.writeTxn(any)).thenAnswer((invocation) async {
            final function = invocation.positionalArguments[0] as Function();
            return await function();
          });
          when(mockMessagesCollection.get(999)).thenAnswer((_) async => null);

          // Act
          await databaseService.updateMessageStatus(999, MessageStatus.sent);

          // Assert
          verify(mockMessagesCollection.get(999)).called(1);
          verifyNever(mockMessagesCollection.put(any));
        });

        test('should update multiple message statuses', () async {
          // Arrange
          final message1 = Message.create(text: 'Message 1', senderId: 'user1', isOffline: true);
          final message2 = Message.create(text: 'Message 2', senderId: 'user2', isOffline: false);
          message1.id = 1;
          message2.id = 2;

          when(mockIsar.writeTxn(any)).thenAnswer((invocation) async {
            final function = invocation.positionalArguments[0] as Function();
            return await function();
          });
          when(mockMessagesCollection.get(1)).thenAnswer((_) async => message1);
          when(mockMessagesCollection.get(2)).thenAnswer((_) async => message2);
          when(mockMessagesCollection.put(any)).thenAnswer((_) async => 1);

          // Act
          await databaseService.updateMessageStatuses([1, 2], MessageStatus.delivered);

          // Assert
          verify(mockIsar.writeTxn(any)).called(1);
          verify(mockMessagesCollection.get(1)).called(1);
          verify(mockMessagesCollection.get(2)).called(1);
          verify(mockMessagesCollection.put(any)).called(2);
        });
      });

      group('Delete Operations', () {
        test('should delete message successfully', () async {
          // Arrange
          when(mockIsar.writeTxn(any)).thenAnswer((invocation) async {
            final function = invocation.positionalArguments[0] as Function();
            return await function();
          });
          when(mockMessagesCollection.delete(123)).thenAnswer((_) async => true);

          // Act
          final result = await databaseService.deleteMessage(123);

          // Assert
          expect(result, true);
          verify(mockIsar.writeTxn(any)).called(1);
          verify(mockMessagesCollection.delete(123)).called(1);
        });

        test('should handle deletion of non-existent message', () async {
          // Arrange
          when(mockIsar.writeTxn(any)).thenAnswer((invocation) async {
            final function = invocation.positionalArguments[0] as Function();
            return await function();
          });
          when(mockMessagesCollection.delete(999)).thenAnswer((_) async => false);

          // Act
          final result = await databaseService.deleteMessage(999);

          // Assert
          expect(result, false);
          verify(mockMessagesCollection.delete(999)).called(1);
        });

        test('should delete old messages', () async {
          // This would test the date-based deletion logic
          // Implementation depends on how we mock the Isar filter and delete operations
        });

        test('should clear all messages', () async {
          // Arrange
          when(mockIsar.writeTxn(any)).thenAnswer((invocation) async {
            final function = invocation.positionalArguments[0] as Function();
            return await function();
          });
          when(mockMessagesCollection.clear()).thenAnswer((_) async {
            return null;
          });

          // Act
          await databaseService.clearAllMessages();

          // Assert
          verify(mockIsar.writeTxn(any)).called(1);
          verify(mockMessagesCollection.clear()).called(1);
        });
      });
    });

    group('Message Deduplication', () {
      setUp(() {
        DatabaseService._isar = mockIsar;
        when(mockIsar.messages).thenReturn(mockMessagesCollection);
      });

      test('should check if message exists by hash', () async {
        // This would test the messageExists method
        // Implementation depends on how we mock the Isar filter operations
      });

      test('should find message by hash', () async {
        // This would test the findMessageByHash method
        // Implementation depends on how we mock the Isar filter operations
      });
    });

    group('Streaming Operations', () {
      setUp(() {
        DatabaseService._isar = mockIsar;
        when(mockIsar.messages).thenReturn(mockMessagesCollection);
      });

      test('should provide messages stream', () {
        // Arrange
        final mockQueryBuilder = MockQueryBuilder<Message, Message, QWhere>();
        final mockAfterSortBy = MockQueryBuilder<Message, Message, QAfterSortBy>();

        when(mockMessagesCollection.where()).thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.sortByTimestamp()).thenReturn(mockAfterSortBy);
        when(mockAfterSortBy.watch(fireImmediately: true))
            .thenAnswer((_) => Stream.value([]));

        // Act
        final stream = databaseService.messagesStream;

        // Assert
        expect(stream, isA<Stream<List<Message>>>());
        verify(mockAfterSortBy.watch(fireImmediately: true)).called(1);
      });
    });

    group('Error Handling', () {
      setUp(() {
        DatabaseService._isar = mockIsar;
        when(mockIsar.messages).thenReturn(mockMessagesCollection);
      });

      test('should handle database transaction errors', () async {
        // Arrange
        when(mockIsar.writeTxn(any)).thenThrow(Exception('Database error'));

        // Act & Assert
        expect(
          () => databaseService.saveMessage(Message.create(
            text: 'Test',
            senderId: 'user1',
            isOffline: true,
          )),
          throwsException,
        );
      });

      test('should handle query errors', () async {
        // Arrange
        when(mockMessagesCollection.count()).thenThrow(Exception('Query error'));

        // Act & Assert
        expect(
          () => databaseService.getMessageCount(),
          throwsException,
        );
      });
    });

    group('Database Lifecycle', () {
      test('should close database successfully', () async {
        // Arrange
        DatabaseService._isar = mockIsar;
        when(mockIsar.close()).thenAnswer((_) async {
          return null;
        });

        // Act
        await databaseService.close();

        // Assert
        verify(mockIsar.close()).called(1);
        expect(DatabaseService._isar, null);
        expect(DatabaseService._instance, null);
      });

      test('should handle close when not initialized', () async {
        // Arrange
        DatabaseService._isar = null;

        // Act & Assert - Should not throw
        await databaseService.close();
      });
    });

    group('Getter Methods', () {
      test('should return isar instance when initialized', () {
        // Arrange
        DatabaseService._isar = mockIsar;

        // Act
        final isar = databaseService.isar;

        // Assert
        expect(isar, mockIsar);
      });

      test('should throw when accessing isar before initialization', () {
        // Arrange
        DatabaseService._isar = null;

        // Act & Assert
        expect(
          () => databaseService.isar,
          throwsException,
        );
      });
    });
  });
}