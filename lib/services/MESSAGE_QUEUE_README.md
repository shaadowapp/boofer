# Message Queue Service Implementation

## Overview

The `MessageQueueService` provides robust message queuing and automatic retry functionality for the Boofer chat application. It ensures reliable message delivery even in unstable network conditions.

## Key Features

### 1. Offline Message Queuing
- Messages are automatically queued when network services are unavailable
- Persistent storage ensures messages survive app restarts
- Automatic processing when network becomes available

### 2. Automatic Retry with Exponential Backoff
- Failed messages are automatically retried up to 3 times
- Exponential backoff prevents overwhelming the network
- Configurable retry delays (default: 5s, 10s, 20s)
- Maximum retry delay cap of 5 minutes

### 3. Message Status Tracking
- Real-time status updates: pending → sent → delivered → failed
- Queue statistics and monitoring
- Failed message identification and handling

## Configuration

```dart
final retryConfig = RetryConfig(
  maxRetries: 3,
  initialDelay: Duration(seconds: 5),
  backoffMultiplier: 2.0,
  maxDelay: Duration(minutes: 5),
);
```

## Usage

### Basic Usage
```dart
// Initialize the service
final queueService = MessageQueueService.getInstance();
await queueService.initialize();

// Queue a message for sending
final message = Message.create(
  text: 'Hello, world!',
  senderId: 'user123',
  isOffline: true,
);
await queueService.queueMessage(message);
```

### Monitoring Queue Status
```dart
// Listen to queue size changes
queueService.queueSize.listen((size) {
  print('Queue size: $size');
});

// Listen to queue statistics
queueService.queueStats.listen((stats) {
  print('Pending: ${stats['pending']}');
  print('Failed: ${stats['failed']}');
  print('Retrying: ${stats['retrying']}');
});
```

### Manual Operations
```dart
// Process queue manually
await queueService.processQueue();

// Retry failed messages
await queueService.retryFailedMessages();

// Clear the queue
await queueService.clearQueue();
```

## Integration with ChatService

The `MessageQueueService` is automatically integrated into the `ChatService`:

```dart
// Send a message (automatically queued)
await chatService.sendMessage('Hello!');

// Retry failed messages
await chatService.retryFailedMessages();

// Monitor queue status
chatService.queueSize.listen((size) => print('Queue: $size'));
```

## Architecture

### Components

1. **QueuedMessage**: Wrapper for messages with retry metadata
2. **RetryConfig**: Configuration for retry behavior
3. **MessageQueueService**: Main service class
4. **Integration**: Seamless integration with ChatService

### Flow

1. Message created and queued
2. Immediate send attempt
3. If failed, schedule retry with exponential backoff
4. Automatic retry up to max attempts
5. Mark as failed if all retries exhausted

### Error Handling

- Network unavailable: Queue message for later
- Send failure: Retry with backoff
- Max retries reached: Mark as permanently failed
- Service errors: Log and continue processing other messages

## Monitoring and Statistics

The service provides comprehensive monitoring:

```dart
final stats = queueService.getQueueStatistics();
print('Queue size: ${stats['queueSize']}');
print('Processing: ${stats['isProcessing']}');
print('Retry config: ${stats['retryConfig']}');
```

## Testing

Use the provided test class to verify functionality:

```dart
import 'lib/services/message_queue_test.dart';

// Run all tests
await MessageQueueTest.runAllTests();
```

## Performance Considerations

- Periodic queue processing every 30 seconds
- Retry checks every 10 seconds
- Automatic cleanup of sent messages
- Efficient database queries for failed messages

## Future Enhancements

- Priority queuing for important messages
- Network-aware retry strategies
- Message compression for large queues
- Advanced analytics and reporting