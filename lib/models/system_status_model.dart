class SystemStatus {
  final bool isGlobalMaintenance;
  final bool isMessagingActive;
  final bool isDiscoverActive;
  final bool isProfileUpdatesActive;
  final String maintenanceMessage;
  final String minAppVersion;
  final bool forceUpdate;
  final String updateUrl;
  final DateTime updatedAt;

  SystemStatus({
    required this.isGlobalMaintenance,
    required this.isMessagingActive,
    required this.isDiscoverActive,
    required this.isProfileUpdatesActive,
    required this.maintenanceMessage,
    required this.minAppVersion,
    required this.forceUpdate,
    required this.updateUrl,
    required this.updatedAt,
  });

  factory SystemStatus.fromJson(Map<String, dynamic> json) {
    return SystemStatus(
      isGlobalMaintenance: json['is_global_maintenance'] ?? false,
      isMessagingActive: json['is_messaging_active'] ?? true,
      isDiscoverActive: json['is_discover_active'] ?? true,
      isProfileUpdatesActive: json['is_profile_updates_active'] ?? true,
      maintenanceMessage:
          json['maintenance_message'] ?? 'System maintenance in progress.',
      minAppVersion: json['min_app_version'] ?? '1.0.0',
      forceUpdate: json['force_update'] ?? false,
      updateUrl: json['update_url'] ??
          'https://play.google.com/store/apps/details?id=shaadowapp.boofer',
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  factory SystemStatus.initial() {
    return SystemStatus(
      isGlobalMaintenance: false,
      isMessagingActive: true,
      isDiscoverActive: true,
      isProfileUpdatesActive: true,
      maintenanceMessage: 'System maintenance in progress.',
      minAppVersion: '1.0.0',
      forceUpdate: false,
      updateUrl: 'https://play.google.com/store/apps/details?id=shaadowapp.boofer',
      updatedAt: DateTime.now(),
    );
  }
}
