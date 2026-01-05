// Stub message model without Isar dependencies

class Message {
  int id = 0; // Simple int instead of Isar Id

  late String text;
  late String senderId;
  late DateTime timestamp;
  late bool isOffline;
  late MessageStatus status;

  String? conversationId;
  String? messageHash; // For deduplication

  Message();

  Message.create({
    required this.text,
    required this.senderId,
    required this.isOffline,
    this.status = MessageStatus.pending,
    this.conversationId,
    DateTime? timestamp,
  }) {
    this.timestamp = timestamp ?? DateTime.now();
    messageHash = _generateMessageHash();
  }

  String _generateMessageHash() {
    return '${senderId}_${timestamp.millisecondsSinceEpoch}_${text.hashCode}';
  }

  @override
  String toString() {
    return 'Message{id: $id, text: $text, senderId: $senderId, timestamp: $timestamp, isOffline: $isOffline, status: $status}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Message &&
          runtimeType == other.runtimeType &&
          messageHash == other.messageHash;

  @override
  int get hashCode => messageHash.hashCode;
}

enum MessageStatus {
  pending,
  sent,
  delivered,
  failed
}