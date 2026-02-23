import 'dart:convert';

class OnboardingData {
  final bool completed;
  final bool termsAccepted;
  final String userName;
  final String virtualNumber;
  final String? pin;
  final DateTime? completedAt;
  final Map<String, dynamic>? additionalData;

  const OnboardingData({
    required this.completed,
    this.termsAccepted = false,
    required this.userName,
    required this.virtualNumber,
    this.pin,
    this.completedAt,
    this.additionalData,
  });

  /// Create a copy with updated fields
  OnboardingData copyWith({
    bool? completed,
    bool? termsAccepted,
    String? userName,
    String? virtualNumber,
    String? pin,
    DateTime? completedAt,
    Map<String, dynamic>? additionalData,
  }) {
    return OnboardingData(
      completed: completed ?? this.completed,
      termsAccepted: termsAccepted ?? this.termsAccepted,
      userName: userName ?? this.userName,
      virtualNumber: virtualNumber ?? this.virtualNumber,
      pin: pin ?? this.pin,
      completedAt: completedAt ?? this.completedAt,
      additionalData: additionalData ?? this.additionalData,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'completed': completed,
      'termsAccepted': termsAccepted,
      'userName': userName,
      'virtualNumber': virtualNumber,
      'pin': pin,
      'completedAt': completedAt?.toIso8601String(),
      'additionalData': additionalData,
    };
  }

  /// Create from JSON
  factory OnboardingData.fromJson(Map<String, dynamic> json) {
    return OnboardingData(
      completed: json['completed'] ?? false,
      termsAccepted: json['termsAccepted'] ?? false,
      userName: json['userName'] ?? '',
      virtualNumber: json['virtualNumber'] ?? '',
      pin: json['pin'],
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      additionalData: json['additionalData'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Create from JSON string
  factory OnboardingData.fromJsonString(String jsonString) {
    return OnboardingData.fromJson(jsonDecode(jsonString));
  }

  @override
  String toString() {
    return 'OnboardingData(completed: $completed, userName: $userName, virtualNumber: $virtualNumber)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OnboardingData &&
        other.completed == completed &&
        other.userName == userName &&
        other.virtualNumber == virtualNumber &&
        other.pin == pin;
  }

  @override
  int get hashCode {
    return Object.hash(completed, userName, virtualNumber, pin);
  }
}
