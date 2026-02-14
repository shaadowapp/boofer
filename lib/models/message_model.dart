import 'package:uuid/uuid.dart';

enum MessageType { text, image, video, audio, file }

enum MessageStatus { pending, sent, delivered, read, failed }

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
        '${senderId}_${now.millisecondsSinceEpoch}_${text.hashCode}';

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
    };
  }

  /// Create from JSON
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      senderId: json['sender_id'] ?? json['senderId'] ?? '',
      receiverId: json['receiver_id'] ?? json['receiverId'],
      conversationId: json['conversation_id'] ?? json['conversationId'],
      timestamp: DateTime.parse(json['timestamp']),
      isOffline: (json['is_offline'] ?? json['isOffline']) ?? false,
      status: MessageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MessageStatus.pending,
      ),
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      messageHash: json['message_hash'] ?? json['messageHash'],
      mediaUrl: json['media_url'] ?? json['mediaUrl'],
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
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
