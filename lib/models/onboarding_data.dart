class OnboardingData {
  final String userName;
  final String virtualNumber;
  final String? pin;
  final bool completed;
  final DateTime completedAt;

  OnboardingData({
    required this.userName,
    required this.virtualNumber,
    this.pin,
    required this.completed,
    required this.completedAt,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'userName': userName,
      'virtualNumber': virtualNumber,
      'pin': pin,
      'completed': completed,
      'completedAt': completedAt.toIso8601String(),
    };
  }

  // Create from JSON
  factory OnboardingData.fromJson(Map<String, dynamic> json) {
    return OnboardingData(
      userName: json['userName'] as String,
      virtualNumber: json['virtualNumber'] as String,
      pin: json['pin'] as String?,
      completed: json['completed'] as bool,
      completedAt: DateTime.parse(json['completedAt'] as String),
    );
  }

  // Create a copy with updated fields
  OnboardingData copyWith({
    String? userName,
    String? virtualNumber,
    String? pin,
    bool? completed,
    DateTime? completedAt,
  }) {
    return OnboardingData(
      userName: userName ?? this.userName,
      virtualNumber: virtualNumber ?? this.virtualNumber,
      pin: pin ?? this.pin,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}