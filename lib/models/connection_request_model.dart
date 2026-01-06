import 'dart:convert';

enum ConnectionRequestStatus {
  pending,
  accepted,
  declined,
  blocked,
}

class ConnectionRequest {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String message;
  final DateTime sentAt;
  final ConnectionRequestStatus status;
  final DateTime? respondedAt;

  const ConnectionRequest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.message,
    required this.sentAt,
    this.status = ConnectionRequestStatus.pending,
    this.respondedAt,
  });

  /// Create a copy with updated fields
  ConnectionRequest copyWith({
    String? id,
    String? fromUserId,
    String? toUserId,
    String? message,
    DateTime? sentAt,
    ConnectionRequestStatus? status,
    DateTime? respondedAt,
  }) {
    return ConnectionRequest(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      message: message ?? this.message,
      sentAt: sentAt ?? this.sentAt,
      status: status ?? this.status,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'message': message,
      'sentAt': sentAt.toIso8601String(),
      'status': status.name,
      'respondedAt': respondedAt?.toIso8601String(),
    };
  }

  /// Convert to database format with snake_case column names
  Map<String, dynamic> toDatabaseJson() {
    return {
      'id': id,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'message': message,
      'sent_at': sentAt.toIso8601String(),
      'status': status.name,
      'responded_at': respondedAt?.toIso8601String(),
    };
  }

  /// Create from JSON
  factory ConnectionRequest.fromJson(Map<String, dynamic> json) {
    return ConnectionRequest(
      id: json['id'] ?? '',
      fromUserId: json['fromUserId'] ?? json['from_user_id'] ?? '',
      toUserId: json['toUserId'] ?? json['to_user_id'] ?? '',
      message: json['message'] ?? '',
      sentAt: DateTime.parse(json['sentAt'] ?? json['sent_at']),
      status: ConnectionRequestStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ConnectionRequestStatus.pending,
      ),
      respondedAt: json['respondedAt'] != null 
          ? DateTime.parse(json['respondedAt'])
          : json['responded_at'] != null
          ? DateTime.parse(json['responded_at'])
          : null,
    );
  }

  /// Convert to JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Create from JSON string
  factory ConnectionRequest.fromJsonString(String jsonString) {
    return ConnectionRequest.fromJson(jsonDecode(jsonString));
  }

  @override
  String toString() {
    return 'ConnectionRequest(id: $id, from: $fromUserId, to: $toUserId, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConnectionRequest && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}