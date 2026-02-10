import 'dart:convert';
import 'dart:typed_data';
import '../../models/message_model.dart';

/// Utility class for handling mesh message serialization and transmission
class MeshMessageHandler {
  static const int maxMessageSize = 1024; // 1KB limit for mesh messages
  static const String messageVersion = '1.0';

  /// Serialize a message for mesh transmission
  static Uint8List serializeMessage(Message message) {
    try {
      final messageData = {
        'version': messageVersion,
        'id': message.id,
        'text': message.text,
        'senderId': message.senderId,
        'timestamp': message.timestamp.millisecondsSinceEpoch,
        'isOffline': message.isOffline,
        'status': message.status.name,
        'conversationId': message.conversationId,
        'messageHash': message.messageHash,
        'checksum': _calculateChecksum(message.text),
      };

      final jsonString = jsonEncode(messageData);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));

      if (bytes.length > maxMessageSize) {
        throw Exception('Message too large for mesh transmission: ${bytes.length} bytes (max: $maxMessageSize)');
      }

      return bytes;
    } catch (e) {
      throw Exception('Failed to serialize message: $e');
    }
  }

  /// Deserialize a message from mesh transmission
  static Message deserializeMessage(Uint8List bytes) {
    try {
      final jsonString = utf8.decode(bytes);
      final messageData = jsonDecode(jsonString) as Map<String, dynamic>;

      // Verify message version
      final version = messageData['version'] as String?;
      if (version != messageVersion) {
        throw Exception('Unsupported message version: $version');
      }

      // Create message object with proper status
      final status = MessageStatus.values.firstWhere(
        (s) => s.name == messageData['status'],
        orElse: () => MessageStatus.delivered,
      );
      
      final message = Message(
        id: messageData['id'] as String,
        text: messageData['text'] as String,
        senderId: messageData['senderId'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(messageData['timestamp'] as int),
        isOffline: messageData['isOffline'] as bool,
        status: status,
        conversationId: messageData['conversationId'] as String?,
        messageHash: messageData['messageHash'] as String?,
      );

      // Verify checksum
      final expectedChecksum = messageData['checksum'] as String?;
      final actualChecksum = _calculateChecksum(message.text);
      if (expectedChecksum != actualChecksum) {
        throw Exception('Message checksum mismatch - data may be corrupted');
      }

      return message;
    } catch (e) {
      throw Exception('Failed to deserialize message: $e');
    }
  }

  /// Calculate a simple checksum for message integrity
  static String _calculateChecksum(String text) {
    int checksum = 0;
    for (int i = 0; i < text.length; i++) {
      checksum += text.codeUnitAt(i);
    }
    return checksum.toRadixString(16);
  }

  /// Validate message before transmission
  static bool validateMessage(Message message) {
    // Check required fields
    if (message.text.isEmpty) {
      print('Message validation failed: empty text');
      return false;
    }

    if (message.senderId.isEmpty) {
      print('Message validation failed: empty senderId');
      return false;
    }

    // Check message size
    try {
      final bytes = serializeMessage(message);
      if (bytes.length > maxMessageSize) {
        print('Message validation failed: too large (${bytes.length} bytes)');
        return false;
      }
    } catch (e) {
      print('Message validation failed: serialization error - $e');
      return false;
    }

    return true;
  }

  /// Split large messages into chunks (for future enhancement)
  static List<Message> splitMessage(Message message, int chunkSize) {
    if (message.text.length <= chunkSize) {
      return [message];
    }

    final chunks = <Message>[];
    final totalChunks = (message.text.length / chunkSize).ceil();
    
    for (int i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize < message.text.length) 
          ? start + chunkSize 
          : message.text.length;
      
      final chunkText = message.text.substring(start, end);
      final chunkMessage = Message.create(
        text: chunkText,
        senderId: message.senderId,
        isOffline: message.isOffline,
        conversationId: message.conversationId,
      );
      chunks.add(chunkMessage);
    }

    return chunks;
  }

  /// Reconstruct message from chunks (for future enhancement)
  static Message? reconstructMessage(List<Message> chunks) {
    if (chunks.isEmpty) return null;
    if (chunks.length == 1) return chunks.first;

    // Sort chunks by their order
    chunks.sort((a, b) {
      final aHash = a.messageHash ?? '';
      final bHash = b.messageHash ?? '';
      
      final aChunkMatch = RegExp(r'chunk_(\d+)_of_(\d+)').firstMatch(aHash);
      final bChunkMatch = RegExp(r'chunk_(\d+)_of_(\d+)').firstMatch(bHash);
      
      if (aChunkMatch == null || bChunkMatch == null) return 0;
      
      final aChunkNum = int.parse(aChunkMatch.group(1)!);
      final bChunkNum = int.parse(bChunkMatch.group(1)!);
      
      return aChunkNum.compareTo(bChunkNum);
    });

    // Reconstruct the full message
    final fullText = chunks.map((chunk) => chunk.text).join();
    final reconstructed = Message(
      id: chunks.first.id,
      text: fullText,
      senderId: chunks.first.senderId,
      timestamp: chunks.first.timestamp,
      isOffline: chunks.first.isOffline,
      conversationId: chunks.first.conversationId,
      messageHash: chunks.first.messageHash?.split('_chunk_').first,
    );

    return reconstructed;
  }

  /// Create a message acknowledgment
  static Message createAcknowledgment(Message originalMessage, String senderId) {
    return Message.create(
      text: 'ACK:${originalMessage.messageHash}',
      senderId: senderId,
      isOffline: true,
      conversationId: originalMessage.conversationId,
    );
  }

  /// Check if message is an acknowledgment
  static bool isAcknowledgment(Message message) {
    return message.text.startsWith('ACK:');
  }

  /// Extract original message hash from acknowledgment
  static String? getAcknowledgedMessageHash(Message ackMessage) {
    if (!isAcknowledgment(ackMessage)) return null;
    return ackMessage.text.substring(4); // Remove 'ACK:' prefix
  }

  /// Create a message retry with exponential backoff
  static Duration calculateRetryDelay(int attemptCount) {
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, max 30s
    final delaySeconds = (1 << attemptCount).clamp(1, 30);
    return Duration(seconds: delaySeconds);
  }

  /// Check if message should be retried based on age and attempt count
  static bool shouldRetryMessage(Message message, int maxAttempts, Duration maxAge) {
    if (message.status != MessageStatus.failed) return false;
    
    final age = DateTime.now().difference(message.timestamp);
    if (age > maxAge) return false;

    // This would require tracking attempt count in message metadata
    // For now, we'll use a simple time-based retry
    return true;
  }
}