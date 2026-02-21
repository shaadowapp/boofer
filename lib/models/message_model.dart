import 'package:uuid/uuid.dart';
import 'dart:convert';

enum MessageType { text, image, video, audio, file, profile }

enum MessageStatus { pending, sent, delivered, read, failed, decryptionFailed }

class Message {
  final String id;
  final String text;
  final String senderId;
  final String? receiverId;
  final String? conversationId;
  final DateTime timestamp;
  final bool isOffline;
  final MessageStatus status;
  final MessageType type;
  final String? messageHash;
  final String? mediaUrl;
  final Map<String, dynamic>? metadata;
  final DateTime? expiresAt;

  // E2EE fields
  final bool isEncrypted;
  final Map<String, dynamic>? encryptedContent; // encrypted for recipient
  final Map<String, dynamic>?
  encryptedContentSender; // encrypted for sender (self-view)
  final String? encryptionVersion;

  const Message({
    required this.id,
    required this.text,
    required this.senderId,
    this.receiverId,
    this.conversationId,
    required this.timestamp,
    this.isOffline = false,
    this.status = MessageStatus.pending,
    this.type = MessageType.text,
    this.messageHash,
    this.mediaUrl,
    this.metadata,
    this.expiresAt,
    this.isEncrypted = false,
    this.encryptedContent,
    this.encryptedContentSender,
    this.encryptionVersion = '1.0',
  });

  /// Create a new message
  factory Message.create({
    required String text,
    required String senderId,
    String? receiverId,
    String? conversationId,
    MessageType type = MessageType.text,
    bool isOffline = false,
    MessageStatus status = MessageStatus.pending,
    String? mediaUrl,
    Map<String, dynamic>? metadata,
    DateTime? expiresAt,
  }) {
    final now = DateTime.now();
    // Use UUID v4 for valid Supabase ID
    final id = const Uuid().v4();
    final messageHash =
        '${senderId}_${receiverId ?? "self"}_${now.millisecondsSinceEpoch}_${text.hashCode}';

    return Message(
      id: id,
      text: text,
      senderId: senderId,
      receiverId: receiverId,
      conversationId: conversationId,
      timestamp: now,
      isOffline: isOffline,
      status: status,
      type: type,
      messageHash: messageHash,
      mediaUrl: mediaUrl,
      metadata: metadata,
      expiresAt: expiresAt,
    );
  }

  /// Create a copy with updated fields
  Message copyWith({
    String? id,
    String? text,
    String? senderId,
    String? receiverId,
    String? conversationId,
    DateTime? timestamp,
    bool? isOffline,
    MessageStatus? status,
    MessageType? type,
    String? messageHash,
    String? mediaUrl,
    Map<String, dynamic>? metadata,
    DateTime? expiresAt,
    bool? isEncrypted,
    Map<String, dynamic>? encryptedContent,
    Map<String, dynamic>? encryptedContentSender,
    String? encryptionVersion,
  }) {
    return Message(
      id: id ?? this.id,
      text: text ?? this.text,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      conversationId: conversationId ?? this.conversationId,
      timestamp: timestamp ?? this.timestamp,
      isOffline: isOffline ?? this.isOffline,
      status: status ?? this.status,
      type: type ?? this.type,
      messageHash: messageHash ?? this.messageHash,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      metadata: metadata ?? this.metadata,
      expiresAt: expiresAt ?? this.expiresAt,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      encryptedContent: encryptedContent ?? this.encryptedContent,
      encryptedContentSender:
          encryptedContentSender ?? this.encryptedContentSender,
      encryptionVersion: encryptionVersion ?? this.encryptionVersion,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'senderId': senderId,
      'receiverId': receiverId,
      'conversationId': conversationId,
      'timestamp': timestamp.toIso8601String(),
      'isOffline': isOffline,
      'status': status.name,
      'type': type.name,
      'messageHash': messageHash,
      'mediaUrl': mediaUrl,
      'metadata': metadata,
      'expires_at': expiresAt?.toIso8601String(),
      'isEncrypted': isEncrypted,
      'encryptedContent': encryptedContent,
      'encryptedContentSender': encryptedContentSender,
      'encryptionVersion': encryptionVersion,
    };
  }

  /// Create from JSON
  factory Message.fromJson(Map<String, dynamic> json) {
    // Robust type conversion helpers
    String toString(dynamic value) => value?.toString() ?? '';
    bool toBool(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) return value.toLowerCase() == 'true' || value == '1';
      return false;
    }

    DateTime parseDate(dynamic value, [DateTime? fallback]) {
      if (value == null) return fallback ?? DateTime.now();
      try {
        if (value is DateTime) return value;
        return DateTime.parse(value.toString());
      } catch (e) {
        return fallback ?? DateTime.now();
      }
    }

    return Message(
      id: toString(json['id']),
      text: toString(json['text']),
      senderId: toString(json['sender_id'] ?? json['senderId']),
      receiverId: json['receiver_id'] != null || json['receiverId'] != null
          ? toString(json['receiver_id'] ?? json['receiverId'])
          : null,
      conversationId:
          json['conversation_id'] != null || json['conversationId'] != null
          ? toString(json['conversation_id'] ?? json['conversationId'])
          : null,
      timestamp: parseDate(json['timestamp']),
      isOffline: toBool(json['is_offline'] ?? json['isOffline']),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == toString(json['status']),
        orElse: () => MessageStatus.pending,
      ),
      type: MessageType.values.firstWhere(
        (e) => e.name == toString(json['type']),
        orElse: () => MessageType.text,
      ),
      messageHash: toString(json['message_hash'] ?? json['messageHash']),
      mediaUrl: toString(json['media_url'] ?? json['mediaUrl']),
      metadata: json['metadata'] != null
          ? (json['metadata'] is String
                ? jsonDecode(json['metadata']) as Map<String, dynamic>
                : Map<String, dynamic>.from(json['metadata']))
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
      isEncrypted: toBool(json['is_encrypted'] ?? json['isEncrypted'] ?? false),
      encryptedContent:
          json['encrypted_content'] != null || json['encryptedContent'] != null
          ? ((json['encrypted_content'] ?? json['encryptedContent']) is String
                ? jsonDecode(
                        json['encrypted_content'] ?? json['encryptedContent'],
                      )
                      as Map<String, dynamic>
                : Map<String, dynamic>.from(
                    json['encrypted_content'] ?? json['encryptedContent'],
                  ))
          : null,
      encryptedContentSender: json['encrypted_content_sender'] != null
          ? (json['encrypted_content_sender'] is String
                ? jsonDecode(json['encrypted_content_sender'])
                      as Map<String, dynamic>
                : Map<String, dynamic>.from(json['encrypted_content_sender']))
          : null,
      encryptionVersion:
          json['encryption_version'] != null ||
              json['encryptionVersion'] != null
          ? toString(json['encryption_version'] ?? json['encryptionVersion'])
          : '1.0',
    );
  }

  /// Get chat ID for this message
  String? get chatId => conversationId;

  @override
  String toString() {
    return 'Message(id: $id, text: $text, senderId: $senderId, timestamp: $timestamp, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
