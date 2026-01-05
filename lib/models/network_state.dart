enum NetworkMode {
  online,
  offline,
  auto
}

class NetworkState {
  final NetworkMode mode;
  final bool hasInternetConnection;
  final int connectedPeers;
  final DateTime lastSync;
  final bool isMeshActive;
  final bool isOnlineServiceActive;

  const NetworkState({
    required this.mode,
    required this.hasInternetConnection,
    required this.connectedPeers,
    required this.lastSync,
    this.isMeshActive = false,
    this.isOnlineServiceActive = false,
  });

  NetworkState copyWith({
    NetworkMode? mode,
    bool? hasInternetConnection,
    int? connectedPeers,
    DateTime? lastSync,
    bool? isMeshActive,
    bool? isOnlineServiceActive,
  }) {
    return NetworkState(
      mode: mode ?? this.mode,
      hasInternetConnection: hasInternetConnection ?? this.hasInternetConnection,
      connectedPeers: connectedPeers ?? this.connectedPeers,
      lastSync: lastSync ?? this.lastSync,
      isMeshActive: isMeshActive ?? this.isMeshActive,
      isOnlineServiceActive: isOnlineServiceActive ?? this.isOnlineServiceActive,
    );
  }

  bool get isOfflineMode => mode == NetworkMode.offline || (mode == NetworkMode.auto && !hasInternetConnection);
  bool get isOnlineMode => mode == NetworkMode.online || (mode == NetworkMode.auto && hasInternetConnection);

  @override
  String toString() {
    return 'NetworkState{mode: $mode, hasInternet: $hasInternetConnection, peers: $connectedPeers, meshActive: $isMeshActive, onlineActive: $isOnlineServiceActive}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkState &&
          runtimeType == other.runtimeType &&
          mode == other.mode &&
          hasInternetConnection == other.hasInternetConnection &&
          connectedPeers == other.connectedPeers &&
          isMeshActive == other.isMeshActive &&
          isOnlineServiceActive == other.isOnlineServiceActive;

  @override
  int get hashCode =>
      mode.hashCode ^
      hasInternetConnection.hashCode ^
      connectedPeers.hashCode ^
      isMeshActive.hashCode ^
      isOnlineServiceActive.hashCode;

  static NetworkState initial() {
    return NetworkState(
      mode: NetworkMode.auto,
      hasInternetConnection: false,
      connectedPeers: 0,
      lastSync: DateTime.now(),
    );
  }
}