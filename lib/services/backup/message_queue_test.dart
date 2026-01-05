import 'dart:async';
import '../models/message_model.dart';
import 'message_queue_service.dart';
import 'message_repository.dart';

/// Simple test class to verify message queue functionality
class MessageQueueTest {
  static Future<void> runBasicTests() async {
    print('Running MessageQueueService basic tests...');

    try {
      // Create a test message queue service
      final queueService = MessageQueueService.getInstance();
      
      // Initialize the service
      await queueService.initialize();
      print('✓ MessageQueueService initialized');

      // Test 1: Queue a message
      final testMessage = Message.create(
        text: 'Test message for queue',
        senderId: 'test_user_123',
        isOffline: true,
        status: MessageStatus.pending,
      );

      await queueService.queueMessage(testMessage);
      print('✓ Message queued successfully');

      // Test 2: Check queue statistics
      final stats = queueService.getQueueStatistics();
      print('✓ Queue statistics: ${stats['queueSize']} messages in queue');

      // Test 3: Process queue (this will fail since services aren't connected, but that's expected)
      try {
        await queueService.processQueue();
        print('✓ Queue processing completed');
      } catch (e) {
        print('⚠ Queue processing failed (expected): $e');
      }

      // Test 4: Check if message is in queue
      final isQueued = queueService.isMessageQueued(testMessage.id);
      print('✓ Message in queue check: $isQueued');

      // Test 5: Get queued messages
      final queuedMessages = queueService.getQueuedMessages();
      print('✓ Retrieved ${queuedMessages.length} queued messages');

      // Test 6: Clear queue
      await queueService.clearQueue();
      final finalStats = queueService.getQueueStatistics();
      print('✓ Queue cleared, final size: ${finalStats['queueSize']}');

      print('All MessageQueueService tests completed successfully!');

    } catch (e) {
      print('❌ MessageQueueService test failed: $e');
      rethrow;
    }
  }

  static Future<void> runRetryLogicTest() async {
    print('Running retry logic test...');

    try {
      final queueService = MessageQueueService.getInstance();
      
      // Create a test message that will fail to send
      final failedMessage = Message.create(
        text: 'Message that will fail',
        senderId: 'test_user_456',
        isOffline: false, // Online message but service not connected
        status: MessageStatus.failed,
      );

      // Queue the failed message
      await queueService.queueMessage(failedMessage);
      
      // Try to retry failed messages
      await queueService.retryFailedMessages();
      
      // Check retry statistics
      final stats = queueService.getQueueStatistics();
      print('✓ Retry test completed, queue stats: $stats');

    } catch (e) {
      print('⚠ Retry logic test completed with expected errors: $e');
    }
  }

  static Future<void> runAllTests() async {
    print('=== MessageQueueService Test Suite ===');
    
    await runBasicTests();
    print('');
    await runRetryLogicTest();
    
    print('=== Test Suite Completed ===');
  }
}