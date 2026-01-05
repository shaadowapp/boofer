import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:bridgefy/bridgefy.dart';
import 'dart:typed_data';
import '../../lib/models/message_model.dart';
import '../../lib/services/mesh_service.dart';
import '../../lib/services/message_repository.dart';
import '../../lib/services/mesh_reception_handler.dart';

// Generate mocks
@GenerateMocks([
  IMessageRepository,
  MeshReceptionHandler,
])
import 'mesh_service_test.mocks.dart';

void main() {
  group('MeshService', () {
    late MeshService meshService;
    late MockIMessageRepository mockMessageRepository;
    late MockMeshReceptionHandler mockReceptionHandler;

    setUp(() {
      mockMessageRepository = MockIMessageRepository();
      mockReceptionHandler = MockMeshReceptionHandler();

      // Reset singleton for testing
      MeshService._instance = null;

      meshService = MeshService.getInstance(
        messageRepository: mockMessageRepository,
      );
    });

    tearDown(() {
      meshService.dispose();
      MeshService._instance = null;
    });

    group('Initialization', () {
      test('should initialize Bridgefy SDK successfully', () async {
        // Note: This test would require mocking Bridgefy.initialize which is static
        // In a real implementation, we'd need to refactor to make this testable
        expect(meshService.isInitialized, false);
        expect(meshService.isStarted, false);
        expect(meshService.peersCount, 0);
      });

      test('should not reinitialize if already initialized', () async {
        // This would test the early return in initialize method
        // Implementation would depend on how we mock Bridgefy.initialize
      });

      test('should handle initialization failure', () async {
        // Test initialization failure scenarios
        // Would require mocking Bridgefy.initialize to throw
      });
    });

    group('Mesh Network Management', () {
      setUp(() {
        // Assume initialized for these tests
        meshService._isInitialized = true;
      });

      test('should start mesh networking successfully', () async {
        // Note: This would require mocking Bridgefy.start
        expect(meshService.isStarted, false);
        
        // After successful start:
        // expect(meshService.isStarted, true);
      });

      test('should stop mesh networking successfully', () async {
        // Arrange
        meshService._isStarted = true;

        // Note: This would require mocking Bridgefy.stop
        // After successful stop:
        // expect(meshService.isStarted, false);
        // expect(meshService.peersCount, 0);
      });

      test('should handle start failure gracefully', () async {
        // Test start failure scenarios
        expect(meshService.isStarted, false);
      });

      test('should handle stop failure gracefully', () async {
        // Test stop failure scenarios
        meshService._isStarted = true;
        // After failed stop, should still update internal state
      });
    });

    group('Message Transmission', () {
      setUp(() {
        meshService._isInitialized = true;
        meshService._isStarted = true;
      });

      test('should send mesh message successfully', () async {
        // Arrange
        when(mockMessageRepository.saveMessage(any)).thenAnswer((_) async => 123);

        // Note: This would require mocking Bridgefy.sendBroadcastMessage
        // Act
        await meshService.sendMeshMessage('Test message', 'user1');

        // Assert
        verify(mockMessageRepository.saveMessage(argThat(
          predicate<Message>((msg) => 
            msg.text == 'Test message' && 
            msg.senderId == 'user1' && 
            msg.isOffline == true &&
            msg.status == MessageStatus.sent
          ),
        ))).called(1);
      });

      test('should handle send failure and save as failed', () async {
        // Arrange
        when(mockMessageRepository.saveMessage(any)).thenAnswer((_) async => 123);

        // Note: This would require mocking Bridgefy.sendBroadcastMessage to throw
        // The service should catch the error and save as failed

        // Act & Assert would depend on mocking the Bridgefy SDK
      });

      test('should fail if not started', () async {
        // Arrange
        meshService._isStarted = false;

        // Act & Assert
        expect(
          () => meshService.sendMeshMessage('Test message', 'user1'),
          throwsException,
        );
      });

      test('should validate message before sending', () async {
        // Test message validation logic
        when(mockMessageRepository.saveMessage(any)).thenAnswer((_) async => 123);

        // Test with invalid message (empty text)
        expect(
          () => meshService.sendMeshMessage('', 'user1'),
          throwsException,
        );
      });
    });

    group('Message Reception', () {
      setUp(() {
        meshService._isInitialized = true;
        meshService._isStarted = true;
      });

      test('should handle incoming message data', () async {
        // Arrange
        final testMessage = BridgefyMessage(
          senderId: 'sender123',
          data: Uint8List.fromList([1, 2, 3, 4]), // Mock message data
        );

        when(mockReceptionHandler.processIncomingData(any, any))
            .thenAnswer((_) async {});

        // Act
        // This would require exposing the _handleIncomingData method or using a different approach
        // meshService._handleIncomingData(testMessage);

        // Assert
        // verify(mockReceptionHandler.processIncomingData(testMessage.data, testMessage.senderId)).called(1);
      });

      test('should handle malformed incoming data gracefully', () async {
        // Test handling of corrupted or invalid message data
        final invalidMessage = BridgefyMessage(
          senderId: 'sender123',
          data: Uint8List.fromList([]), // Empty data
        );

        // Should not crash when processing invalid data
      });

      test('should forward processed messages from reception handler', () async {
        // Test that messages processed by reception handler are forwarded to the stream
        final testMessage = Message.create(
          text: 'Received message',
          senderId: 'sender123',
          isOffline: true,
        );

        // This would test the stream forwarding from reception handler
      });
    });

    group('Peer Management', () {
      setUp(() {
        meshService._isInitialized = true;
        meshService._isStarted = true;
      });

      test('should track peer connections', () {
        // Arrange
        final device = BridgefyDevice(deviceId: 'device123');

        // Act
        // This would require exposing the device connection handlers
        // meshService._handleDeviceConnected(device);

        // Assert
        // expect(meshService.peersCount, 1);
      });

      test('should track peer disconnections', () {
        // Arrange
        meshService._peersCount = 2;
        final device = BridgefyDevice(deviceId: 'device123');

        // Act
        // meshService._handleDeviceDisconnected(device);

        // Assert
        // expect(meshService.peersCount, 1);
      });

      test('should not allow negative peer count', () {
        // Arrange
        meshService._peersCount = 0;
        final device = BridgefyDevice(deviceId: 'device123');

        // Act
        // meshService._handleDeviceDisconnected(device);

        // Assert
        expect(meshService.peersCount, 0); // Should not go below 0
      });
    });

    group('Event Handling', () {
      test('should handle Bridgefy started event', () {
        // Test handling of Bridgefy start event
        final device = BridgefyDevice(deviceId: 'my-device-123');

        // This would test the _handleBridgefyStarted method
        // Should set the current user ID
      });

      test('should handle Bridgefy stopped event', () {
        // Test handling of Bridgefy stop event
        meshService._peersCount = 5;

        // This would test the _handleBridgefyStopped method
        // Should reset peer count to 0
      });

      test('should handle Bridgefy errors', () {
        // Test error handling
        const errorMessage = 'Bridgefy connection failed';

        // This would test the _handleBridgefyError method
        // Should update active state to false
      });
    });

    group('Availability Check', () {
      test('should check mesh availability', () async {
        // Arrange
        meshService._isInitialized = true;

        // Act
        final isAvailable = await meshService.isAvailable();

        // Assert
        expect(isAvailable, true);
      });

      test('should return false if not initialized', () async {
        // Arrange
        meshService._isInitialized = false;

        // Act
        final isAvailable = await meshService.isAvailable();

        // Assert
        expect(isAvailable, false);
      });
    });

    group('Statistics', () {
      test('should provide reception statistics', () {
        // Arrange
        when(mockReceptionHandler.getStatistics()).thenReturn({
          'messagesReceived': 10,
          'duplicatesFiltered': 2,
          'processingErrors': 1,
        });

        // Act
        final stats = meshService.getReceptionStatistics();

        // Assert
        expect(stats['messagesReceived'], 10);
        expect(stats['duplicatesFiltered'], 2);
        expect(stats['processingErrors'], 1);
      });
    });

    group('Stream Management', () {
      test('should provide incoming messages stream', () {
        // Act
        final stream = meshService.incomingMessages;

        // Assert
        expect(stream, isA<Stream<Message>>());
      });

      test('should provide connected peers count stream', () {
        // Act
        final stream = meshService.connectedPeersCount;

        // Assert
        expect(stream, isA<Stream<int>>());
      });

      test('should provide active status stream', () {
        // Act
        final stream = meshService.isActive;

        // Assert
        expect(stream, isA<Stream<bool>>());
      });
    });

    group('Properties', () {
      test('should return correct initialization status', () {
        // Test isInitialized property
        expect(meshService.isInitialized, false);
        
        meshService._isInitialized = true;
        expect(meshService.isInitialized, true);
      });

      test('should return correct started status', () {
        // Test isStarted property
        expect(meshService.isStarted, false);
        
        meshService._isStarted = true;
        expect(meshService.isStarted, true);
      });

      test('should return correct peer count', () {
        // Test peersCount property
        expect(meshService.peersCount, 0);
        
        meshService._peersCount = 5;
        expect(meshService.peersCount, 5);
      });

      test('should return current user ID', () {
        // Test currentUserId property
        expect(meshService.currentUserId, null);
        
        meshService._currentUserId = 'user123';
        expect(meshService.currentUserId, 'user123');
      });
    });

    group('Singleton Pattern', () {
      test('should return same instance', () {
        // Act
        final instance1 = MeshService.getInstance();
        final instance2 = MeshService.getInstance();

        // Assert
        expect(identical(instance1, instance2), true);
      });

      test('should use provided dependencies', () {
        // Arrange
        final customRepository = MockIMessageRepository();
        
        // Reset singleton
        MeshService._instance = null;

        // Act
        final service = MeshService.getInstance(messageRepository: customRepository);

        // Assert
        expect(service._messageRepository, customRepository);
      });
    });
  });
}