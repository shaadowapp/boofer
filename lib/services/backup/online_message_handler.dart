import 'dart:async';
import '../models/message_model.dart';
import 'online_service.dart';
import 'message_repository.dart';

/// Handler for online message transmission with advanced features
class OnlineMessageHandler {
  final IOnlineService _onlineService;
  final IMessageRepository _messageRepository;
  
  // Retry configuration
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  // Message queue for offline scenarios
  final List<Message> _pendingMessages = <Message>[];
  Timer? _retryTimer;

  OnlineMessageHandler({
    required IOnlineService onlineService,
    required IMessageRepository messageRepository,
  }) : _onlineService = onlineService,
       _messageRepository = messageRepository {
    
    // Listen for connection status changes
    _onlineService.isConnected.listen(_handleConnectionChange);
  }

  /// Send message with retry logic
  Future<void> sendMessageWithRetry(
    String text, 
    String senderId, {
    String? conversationId,
    int maxAttempts = maxRetryAttempts,
  }) async {
    final message = Message.create(
      text: text,
      senderId: senderId,
      isOffline: false,
      conversationId: conversationId,
      status: MessageStatus.pending,
    );

    await _sendMessageWithRetryLogic(message, maxAttempts);
  }

  /// Internal method to handle message sending with retry
  Future<void> _sendMessageWithRetryLogic(Message message, int maxAttempts) async {
    int attempts = 0;
    
    while (attempts < maxAttempts) {
      try {
        attempts++;
        
        if (!_onlineService.isOnline) {
          // Queue message for later if offline
          await _queueMessageForLater(message);
          return;
        }

        // Attempt to send message
        await _onlineService.sendOnlineMessage(
          message.text, 
          message.senderId,
        );
        
        // Success - update message status
        message.status = MessageStatus.sent;
        await _messageRepository.saveMessage(message);
        
        print('Message sent successfully after $attempts attempts');
        return;
        
      } catch (e) {
        print('Send attempt $attempts failed: $e');
        
        if (attempts >= maxAttempts) {
          // All attempts failed - mark as failed
          message.status = MessageStatus.failed;
          await _messageRepository.saveMessage(message);
          
          print('Message failed after $maxAttempts attempts');
          rethrow;
        }
        
        // Wait before retry
        await Future.delayed(retryDelay * attempts);
      }
    }
  }

  /// Queue message for sending when connection is restored
  Future<void> _queueMessageForLater(Message message) async {
    message.status = MessageStatus.pending;
    await _messageRepository.saveMessage(message);
    
    _pendingMessages.add(message);
    print('Message queued for later transmission: ${message.text}');
  }

  /// Handle connection status changes
  void _handleConnectionChange(bool isConnected) {
    if (isConnected && _pendingMessages.isNotEmpty) {
      print('Connection restored, processing ${_pendingMessages.length} pending messages');
      _processPendingMessages();
    }
  }

  /// Process all pending messages when connection is restored
  void _processPendingMessages() {
    if (_pendingMessages.isEmpty) return;
    
    // Cancel existing retry timer
    _retryTimer?.cancel();
    
    // Start processing pending messages
    _retryTimer = Timer(const Duration(seconds: 1), () async {
      final messagesToProcess = List<Message>.from(_pendingMessages);
      _pendingMessages.clear();
      
      for (final message in messagesToProcess) {
        try {
          await _sendMessageWithRetryLogic(message, 2); // Fewer retries for queued messages
        } catch (e) {
          print('Failed to send queued message: $e');
          // Message is already marked as failed in the retry logic
        }
      }
    });
  }

  /// Send multiple messages in batch
  Future<List<bool>> sendBatchMessages(
    List<String> texts, 
    String senderId, {
    String? conversationId,
  }) async {
    final results = <bool>[];
    
    for (final text in texts) {
      try {
        await sendMessageWithRetry(
          text, 
          senderId, 
          conversationId: conversationId,
        );
        results.add(true);
      } catch (e) {
        print('Failed to send batch message: $text - $e');
        results.add(false);
      }
    }
    
    final successCount = results.where((r) => r).length;
    print('Batch send completed: $successCount/${texts.length} successful');
    
    return results;
  }

  /// Retry failed messages
  Future<void> retryFailedMessages() async {
    try {
      final failedMessages = await _messageRepository.getFailedMessages();
      
      if (failedMessages.isEmpty) {
        print('No failed messages to retry');
        return;
      }

      print('Retrying ${failedMessages.length} failed messages');
      
      for (final message in failedMessages) {
        try {
          await _sendMessageWithRetryLogic(message, 2);
        } catch (e) {
          print('Retry failed for message ${message.id}: $e');
        }
      }
      
    } catch (e) {
      print('Error retrying failed messages: $e');
    }
  }

  /// Send message with delivery confirmation
  Future<bool> sendMessageWithConfirmation(
    String text, 
    String senderId, {
    String? conversationId,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final completer = Completer<bool>();
    Timer? timeoutTimer;
    StreamSubscription? messageSubscription;
    
    try {
      // Create message with unique hash for tracking
      final message = Message.create(
        text: text,
        senderId: senderId,
        isOffline: false,
        conversationId: conversationId,
      );
      
      // Set up timeout
      timeoutTimer = Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });
      
      // Listen for message confirmation (this would require server-side implementation)
      messageSubscription = _onlineService.incomingMessages.listen((incomingMessage) {
        // Check if this is a delivery confirmation for our message
        if (_isDeliveryConfirmation(incomingMessage, message)) {
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        }
      });
      
      // Send the message
      await _sendMessageWithRetryLogic(message, maxRetryAttempts);
      
      // Wait for confirmation or timeout
      return await completer.future;
      
    } catch (e) {
      print('Error sending message with confirmation: $e');
      if (!completer.isCompleted) {
        completer.complete(false);
      }
      return false;
    } finally {
      timeoutTimer?.cancel();
      messageSubscription?.cancel();
    }
  }

  /// Check if incoming message is a delivery confirmation
  bool _isDeliveryConfirmation(Message incomingMessage, Message sentMessage) {
    // This would require a specific message format for confirmations
    // For now, we'll use a simple text-based check
    return incomingMessage.text.startsWith('DELIVERED:${sentMessage.messageHash}');
  }

  /// Get transmission statistics
  Map<String, dynamic> getTransmissionStatistics() {
    return {
      'pendingMessages': _pendingMessages.length,
      'isRetryTimerActive': _retryTimer?.isActive ?? false,
      'isOnline': _onlineService.isOnline,
    };
  }

  /// Clear pending messages queue
  void clearPendingMessages() {
    _pendingMessages.clear();
    _retryTimer?.cancel();
    print('Pending messages queue cleared');
  }

  /// Schedule periodic retry of failed messages
  void startPeriodicRetry({Duration interval = const Duration(minutes: 5)}) {
    Timer.periodic(interval, (timer) {
      if (_onlineService.isOnline) {
        retryFailedMessages();
      }
    });
    
    print('Periodic retry started with ${interval.inMinutes} minute interval');
  }

  /// Validate message before sending
  bool validateMessage(String text, String senderId) {
    if (text.trim().isEmpty) {
      print('Message validation failed: empty text');
      return false;
    }
    
    if (senderId.trim().isEmpty) {
      print('Message validation failed: empty sender ID');
      return false;
    }
    
    if (text.length > 1000) { // Reasonable limit for online messages
      print('Message validation failed: text too long (${text.length} chars)');
      return false;
    }
    
    return true;
  }

  /// Dispose resources
  void dispose() {
    _retryTimer?.cancel();
    _pendingMessages.clear();
  }
}