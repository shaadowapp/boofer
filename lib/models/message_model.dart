
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
  });

  /// Create a new message
  factory Message.create({
    required String text,
    required String senderId,
    String? receiverId,
    String? conversationId,
    MessageType type = MessageType.text,
    bool isOffline = false,
    String? mediaUrl,
    Map<String, dynamic>? metadata,
  }) {
    final now = DateTime.now();
    final id = '${senderId}_${now.millisecondsSinceEpoch}';
    final messageHash = '${senderId}_${now.millisecondsSinceEpoch}_${text.hashCode}';
    
    return Message(
      id: id,
      text: text,
      senderId: senderId,
      receiverId: receiverId,
      conversationId: conversationId,
      timestamp: now,
      isOffline: isOffline,
      type: type,
      messageHash: messageHash,
      mediaUrl: mediaUrl,
      metadata: metadata,
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
    };
  }

  /// Create from JSON
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      senderId: json['senderId'] ?? '',
      receiverId: json['receiverId'],
      conversationId: json['conversationId'],
      timestamp: DateTime.parse(json['timestamp']),
      isOffline: json['isOffline'] ?? false,
      status: MessageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MessageStatus.pending,
      ),
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      messageHash: json['messageHash'],
      mediaUrl: json['mediaUrl'],
      metadata: json['metadata'] != null 
          ? Map<String, dynamic>.from(json['metadata'])
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