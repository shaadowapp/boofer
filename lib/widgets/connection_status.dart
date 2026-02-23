import 'package:flutter/material.dart';
import '../models/network_state.dart';

/// Widget that displays the current connection status
class ConnectionStatusIndicator extends StatelessWidget {
  final NetworkState networkState;
  final VoidCallback? onTap;
  final bool showDetails;

  const ConnectionStatusIndicator({
    super.key,
    required this.networkState,
    this.onTap,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _getStatusColor(context).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _getStatusColor(context).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getStatusIcon(), size: 16, color: _getStatusColor(context)),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStatusText(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(context),
                  ),
                ),
                if (showDetails) ...[
                  const SizedBox(height: 2),
                  Text(
                    _getDetailText(),
                    style: TextStyle(
                      fontSize: 10,
                      color: _getStatusColor(context).withOpacity(0.8),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Get status icon based on network state
  IconData _getStatusIcon() {
    if (networkState.isOnlineMode) {
      return networkState.hasInternetConnection ? Icons.wifi : Icons.wifi_off;
    } else if (networkState.isOfflineMode) {
      return networkState.connectedPeers > 0
          ? Icons.device_hub
          : Icons.wifi_off;
    } else {
      // Auto mode
      if (networkState.hasInternetConnection) {
        return Icons.wifi;
      } else if (networkState.connectedPeers > 0) {
        return Icons.device_hub;
      } else {
        return Icons.autorenew;
      }
    }
  }

  /// Get status color based on network state
  Color _getStatusColor(BuildContext context) {
    if (networkState.isOnlineMode) {
      return networkState.hasInternetConnection ? Colors.green : Colors.red;
    } else if (networkState.isOfflineMode) {
      return networkState.connectedPeers > 0 ? Colors.blue : Colors.orange;
    } else {
      // Auto mode
      if (networkState.hasInternetConnection) {
        return Colors.green;
      } else if (networkState.connectedPeers > 0) {
        return Colors.blue;
      } else {
        return Colors.purple;
      }
    }
  }

  /// Get main status text
  String _getStatusText() {
    switch (networkState.mode) {
      case NetworkMode.online:
        return networkState.hasInternetConnection ? 'Online' : 'No Internet';
      case NetworkMode.offline:
        return networkState.connectedPeers > 0
            ? 'Offline (${networkState.connectedPeers} peers)'
            : 'Offline (No peers)';
      case NetworkMode.auto:
        if (networkState.hasInternetConnection) {
          return 'Auto (Online)';
        } else if (networkState.connectedPeers > 0) {
          return 'Auto (Offline)';
        } else {
          return 'Auto (Searching...)';
        }
    }
  }

  /// Get detail text for expanded view
  String _getDetailText() {
    final List<String> details = [];

    if (networkState.hasInternetConnection) {
      details.add('Internet: Connected');
    } else {
      details.add('Internet: Disconnected');
    }

    if (networkState.connectedPeers > 0) {
      details.add('Peers: ${networkState.connectedPeers}');
    } else {
      details.add('Peers: None');
    }

    return details.join(' • ');
  }
}

/// Floating connection status widget that can be positioned anywhere
class FloatingConnectionStatus extends StatelessWidget {
  final NetworkState networkState;
  final VoidCallback? onTap;
  final EdgeInsets margin;

  const FloatingConnectionStatus({
    super.key,
    required this.networkState,
    this.onTap,
    this.margin = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: margin.top,
      right: margin.right,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        child: ConnectionStatusIndicator(
          networkState: networkState,
          onTap: onTap,
          showDetails: false,
        ),
      ),
    );
  }
}

/// Connection status banner that shows at the top of the screen
class ConnectionStatusBanner extends StatelessWidget {
  final NetworkState networkState;
  final VoidCallback? onTap;
  final bool showCloseButton;
  final VoidCallback? onClose;

  const ConnectionStatusBanner({
    super.key,
    required this.networkState,
    this.onTap,
    this.showCloseButton = false,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // Only show banner for problematic states
    if (_shouldShowBanner()) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _getBannerColor(context),
          border: Border(
            bottom: BorderSide(
              color: _getBannerColor(context).withOpacity(0.3),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(_getBannerIcon(), size: 20, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getBannerTitle(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    _getBannerMessage(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              TextButton(
                onPressed: onTap,
                child: const Text(
                  'Settings',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            if (showCloseButton && onClose != null)
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  /// Check if banner should be shown
  bool _shouldShowBanner() {
    // Show banner for problematic connection states
    if (networkState.mode == NetworkMode.online &&
        !networkState.hasInternetConnection) {
      return true;
    }
    if (networkState.mode == NetworkMode.offline &&
        networkState.connectedPeers == 0) {
      return true;
    }
    if (networkState.mode == NetworkMode.auto &&
        !networkState.hasInternetConnection &&
        networkState.connectedPeers == 0) {
      return true;
    }
    return false;
  }

  /// Get banner background color
  Color _getBannerColor(BuildContext context) {
    if (networkState.mode == NetworkMode.online &&
        !networkState.hasInternetConnection) {
      return Colors.red;
    }
    if (networkState.mode == NetworkMode.offline &&
        networkState.connectedPeers == 0) {
      return Colors.orange;
    }
    return Colors.amber;
  }

  /// Get banner icon
  IconData _getBannerIcon() {
    if (networkState.mode == NetworkMode.online &&
        !networkState.hasInternetConnection) {
      return Icons.wifi_off;
    }
    if (networkState.mode == NetworkMode.offline &&
        networkState.connectedPeers == 0) {
      return Icons.device_hub;
    }
    return Icons.warning;
  }

  /// Get banner title
  String _getBannerTitle() {
    if (networkState.mode == NetworkMode.online &&
        !networkState.hasInternetConnection) {
      return 'No Internet Connection';
    }
    if (networkState.mode == NetworkMode.offline &&
        networkState.connectedPeers == 0) {
      return 'No Nearby Devices';
    }
    return 'Connection Issues';
  }

  /// Get banner message
  String _getBannerMessage() {
    if (networkState.mode == NetworkMode.online &&
        !networkState.hasInternetConnection) {
      return 'Switch to offline mode or check your internet connection';
    }
    if (networkState.mode == NetworkMode.offline &&
        networkState.connectedPeers == 0) {
      return 'Make sure other devices are nearby and have the app open';
    }
    return 'Unable to connect to internet or find nearby devices';
  }
}

/// Compact connection status widget for use in app bars
class CompactConnectionStatus extends StatelessWidget {
  final NetworkState networkState;
  final VoidCallback? onTap;

  const CompactConnectionStatus({
    super.key,
    required this.networkState,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getStatusColor().withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _getStatusColor().withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getStatusIcon(), size: 16, color: _getStatusColor()),
            const SizedBox(width: 4),
            Text(
              _getCompactText(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: _getStatusColor(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get status icon
  IconData _getStatusIcon() {
    if (networkState.isOnlineMode) {
      return networkState.hasInternetConnection ? Icons.wifi : Icons.wifi_off;
    } else if (networkState.isOfflineMode) {
      return networkState.connectedPeers > 0
          ? Icons.device_hub
          : Icons.wifi_off;
    } else {
      return Icons.autorenew;
    }
  }

  /// Get status color
  Color _getStatusColor() {
    if (networkState.isOnlineMode) {
      return networkState.hasInternetConnection ? Colors.green : Colors.red;
    } else if (networkState.isOfflineMode) {
      return networkState.connectedPeers > 0 ? Colors.blue : Colors.orange;
    } else {
      // Auto mode
      if (networkState.hasInternetConnection) {
        return Colors.green;
      } else if (networkState.connectedPeers > 0) {
        return Colors.blue;
      } else {
        return Colors.purple;
      }
    }
  }

  /// Get compact status text
  String _getCompactText() {
    return networkState.mode.name.toUpperCase();
  }
}

/// Legacy ConnectionStatus widget for backward compatibility with tests
class ConnectionStatus extends StatelessWidget {
  final bool isOnline;
  final bool isOfflineMode;
  final int peerCount;

  const ConnectionStatus({
    super.key,
    required this.isOnline,
    required this.isOfflineMode,
    required this.peerCount,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (isOnline) {
      statusColor = Colors.green;
      statusIcon = Icons.wifi;
      statusText = 'Online';
    } else if (isOfflineMode) {
      statusColor = Colors.orange;
      statusIcon = Icons.wifi_off;
      statusText = 'Offline';
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.error_outline;
      statusText = 'Disconnected';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isOfflineMode && peerCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.device_hub, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    '$peerCount ${peerCount == 1 ? 'peer' : 'peers'}',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
