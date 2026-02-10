import 'dart:async';
import 'dart:typed_data';
import 'package:rxdart/rxdart.dart';
import '../../models/message_model.dart';
import 'message_repository.dart';
import 'mesh_message_handler.dart';

/// Handler for processing incoming mesh messages
class MeshReceptionHandler {
  final IMessageRepository _messageRepository;
  final BehaviorSubject<Message> _processedMessagesController = BehaviorSubject<Message>();
  final BehaviorSubject<String> _errorController = BehaviorSubject<String>();
  
  // Message deduplication cache
  final Set<String> _processedMessageHashes = <String>{};
  final int _maxCacheSize = 1000;
  
  // Message chunk reconstruction
  final Map<String, List<Message>> _messageChunks = <String, List<Message>>{};
  final Map<String, Timer> _chunkTimeouts = <String, Timer>{};
  
  MeshReceptionHandler({required IMessageRepository messageRepository})
      : _messageRepository = messageRepository;

  /// Stream of successfully processed messages
  Stream<Message> get processedMessages => _processedMessagesController.stream;

  /// Stream of processing errors
  Stream<String> get errors => _errorController.stream;

  /// Process incoming mesh data
  Future<void> processIncomingData(Uint8List data, String senderId) async {
    try {
      print('Processing incoming mesh data: ${data.length} bytes from $senderId');

      // Deserialize the message
      final message = MeshMessageHandler.deserializeMessage(data);
      
      // Validate the message
      if (!MeshMessageHandler.validateMessage(message)) {
        throw Exception('Invalid message received');
      }

      // Check for duplicate messages
      if (await _isDuplicateMessage(message)) {
        print('Duplicate message ignored: ${message.messageHash}');
        return;
      }

      // Handle different message types
      if (MeshMessageHandler.isAcknowledgment(message)) {
        await _handleAcknowledgment(message);
      } else if (_isChunkedMessage(message)) {
        await _handleChunkedMessage(message);
      } else {
        await _handleRegularMessage(message);
      }

    } catch (e) {
      final errorMsg = 'Error processing incoming mesh data: $e';
      print(errorMsg);
      _errorController.add(errorMsg);
    }
  }

  /// Handle regular (non-chunked) messages
  Future<void> _handleRegularMessage(Message message) async {
    try {
      // Set message as delivered since we received it successfully
      final deliveredMessage = message.copyWith(status: MessageStatus.delivered);
      
      // Save to database
      await _messageRepository.saveMessage(deliveredMessage);

      // Add to deduplication cache
      if (deliveredMessage.messageHash != null) {
        _addToDeduplicationCache(deliveredMessage.messageHash!);
      }

      // Emit the processed message
      _processedMessagesController.add(deliveredMessage);

      print('Regular message processed successfully: ${deliveredMessage.text}');
    } catch (e) {
      print('Error handling regular message: $e');
      rethrow;
    }
  }

  /// Handle acknowledgment messages
  Future<void> _handleAcknowledgment(Message ackMessage) async {
    try {
      final originalMessageHash = MeshMessageHandler.getAcknowledgedMessageHash(ackMessage);
      if (originalMessageHash == null) {
        print('Invalid acknowledgment message');
        return;
      }

      // Find the original message and update its status
      final originalMessage = await _messageRepository.findMessageByHash(originalMessageHash);
      if (originalMessage != null) {
        await _messageRepository.updateMessageStatus(originalMessage.id, MessageStatus.delivered);
        print('Message acknowledged: $originalMessageHash');
      } else {
        print('Original message not found for acknowledgment: $originalMessageHash');
      }

    } catch (e) {
      print('Error handling acknowledgment: $e');
    }
  }

  /// Handle chunked messages (for future enhancement)
  Future<void> _handleChunkedMessage(Message chunkMessage) async {
    try {
      final messageHash = chunkMessage.messageHash ?? '';
      final chunkMatch = RegExp(r'(.+)_chunk_(\d+)_of_(\d+)').firstMatch(messageHash);
      
      if (chunkMatch == null) {
        print('Invalid chunk message format');
        return;
      }

      final baseHash = chunkMatch.group(1)!;
      final chunkNumber = int.parse(chunkMatch.group(2)!);
      final totalChunks = int.parse(chunkMatch.group(3)!);

      // Initialize chunk collection for this message
      _messageChunks[baseHash] ??= <Message>[];
      _messageChunks[baseHash]!.add(chunkMessage);

      // Set timeout for chunk collection
      _chunkTimeouts[baseHash]?.cancel();
      _chunkTimeouts[baseHash] = Timer(const Duration(seconds: 30), () {
        _cleanupChunks(baseHash);
      });

      print('Received chunk $chunkNumber of $totalChunks for message $baseHash');

      // Check if we have all chunks
      if (_messageChunks[baseHash]!.length == totalChunks) {
        await _reconstructAndProcessMessage(baseHash);
      }

    } catch (e) {
      print('Error handling chunked message: $e');
    }
  }

  /// Reconstruct message from chunks and process it
  Future<void> _reconstructAndProcessMessage(String baseHash) async {
    try {
      final chunks = _messageChunks[baseHash];
      if (chunks == null || chunks.isEmpty) return;

      final reconstructedMessage = MeshMessageHandler.reconstructMessage(chunks);
      if (reconstructedMessage != null) {
        await _handleRegularMessage(reconstructedMessage);
        print('Chunked message reconstructed and processed: $baseHash');
      }

      // Cleanup
      _cleanupChunks(baseHash);

    } catch (e) {
      print('Error reconstructing chunked message: $e');
      _cleanupChunks(baseHash);
    }
  }

  /// Check if message is a chunked message
  bool _isChunkedMessage(Message message) {
    final messageHash = message.messageHash ?? '';
    return messageHash.contains('_chunk_');
  }

  /// Check if message is a duplicate
  Future<bool> _isDuplicateMessage(Message message) async {
    if (message.messageHash == null) return false;

    // Check in-memory cache first (faster)
    if (_processedMessageHashes.contains(message.messageHash)) {
      return true;
    }

    // Check database
    return await _messageRepository.messageExists(message.messageHash!);
  }

  /// Add message hash to deduplication cache
  void _addToDeduplicationCache(String messageHash) {
    _processedMessageHashes.add(messageHash);
    
    // Limit cache size to prevent memory issues
    if (_processedMessageHashes.length > _maxCacheSize) {
      final excess = _processedMessageHashes.length - _maxCacheSize;
      final toRemove = _processedMessageHashes.take(excess).toList();
      _processedMessageHashes.removeAll(toRemove);
    }
  }

  /// Cleanup chunks for a message
  void _cleanupChunks(String baseHash) {
    _messageChunks.remove(baseHash);
    _chunkTimeouts[baseHash]?.cancel();
    _chunkTimeouts.remove(baseHash);
  }

  /// Get reception statistics
  Map<String, dynamic> getStatistics() {
    return {
      'processedMessages': _processedMessagesController.hasValue ? 1 : 0,
      'cacheSize': _processedMessageHashes.length,
      'pendingChunks': _messageChunks.length,
      'activeTimeouts': _chunkTimeouts.length,
    };
  }

  /// Clear deduplication cache
  void clearCache() {
    _processedMessageHashes.clear();
    print('Message deduplication cache cleared');
  }

  /// Dispose resources
  void dispose() {
    // Cancel all chunk timeouts
    for (final timer in _chunkTimeouts.values) {
      timer.cancel();
    }
    _chunkTimeouts.clear();
    _messageChunks.clear();
    
    // Close streams
    _processedMessagesController.close();
    _errorController.close();
    
    // Clear cache
    _processedMessageHashes.clear();
  }

  /// Process multiple incoming messages in batch
  Future<void> processBatchMessages(List<Uint8List> dataList, List<String> senderIds) async {
    if (dataList.length != senderIds.length) {
      throw ArgumentError('Data list and sender IDs list must have the same length');
    }

    final futures = <Future<void>>[];
    for (int i = 0; i < dataList.length; i++) {
      futures.add(processIncomingData(dataList[i], senderIds[i]));
    }

    try {
      await Future.wait(futures);
      print('Batch processed ${dataList.length} messages');
    } catch (e) {
      print('Error in batch processing: $e');
      rethrow;
    }
  }

  /// Validate message integrity
  bool validateMessageIntegrity(Message message) {
    try {
      // Check required fields
      if (message.text.isEmpty || message.senderId.isEmpty) {
        return false;
      }

      // Check timestamp is reasonable (not too far in future/past)
      final now = DateTime.now();
      final timeDiff = now.difference(message.timestamp).abs();
      if (timeDiff > const Duration(days: 1)) {
        print('Message timestamp too far from current time: ${message.timestamp}');
        return false;
      }

      return true;
    } catch (e) {
      print('Error validating message integrity: $e');
      return false;
    }
  }
}