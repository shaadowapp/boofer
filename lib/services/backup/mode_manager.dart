import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rxdart/rxdart.dart';
import '../../models/network_state.dart';
import 'network_service.dart';
import 'mesh_service.dart';
import 'online_service.dart';
import 'sync_service.dart';
import 'message_repository.dart';

/// Manager for handling mode switching and user preferences
class ModeManager {
  static ModeManager? _instance;
  
  final INetworkService _networkService;
  final IMeshService _meshService;
  final IOnlineService _onlineService;
  final SyncService _syncService;
  
  // Mode switching state
  final BehaviorSubject<bool> _isSwitchingController = BehaviorSubject<bool>.seeded(false);
  final BehaviorSubject<String> _switchStatusController = BehaviorSubject<String>.seeded('idle');
  
  // User preferences
  NetworkMode _savedUserMode = NetworkMode.auto;
  bool _autoSyncEnabled = true;
  bool _showModeNotifications = true;
  
  // Preference keys
  static const String _userModeKey = 'user_preferred_mode';
  static const String _autoSyncKey = 'auto_sync_enabled';
  static const String _notificationsKey = 'show_mode_notifications';
  
  bool _isInitialized = false;

  ModeManager._({
    required INetworkService networkService,
    required IMeshService meshService,
    required IOnlineService onlineService,
    required SyncService syncService,
  }) : _networkService = networkService,
       _meshService = meshService,
       _onlineService = onlineService,
       _syncService = syncService;

  static ModeManager getInstance({
    INetworkService? networkService,
    IMeshService? meshService,
    IOnlineService? onlineService,
    SyncService? syncService,
  }) {
    _instance ??= ModeManager._(
      networkService: networkService ?? NetworkService.getInstance(),
      meshService: meshService ?? MeshService.getInstance(),
      onlineService: onlineService ?? OnlineService.getInstance(),
      syncService: syncService ?? SyncService(
        onlineService: onlineService ?? OnlineService.getInstance(),
        messageRepository: MessageRepository(),
      ),
    );
    return _instance!;
  }

  /// Stream indicating if mode switching is in progress
  Stream<bool> get isSwitching => _isSwitchingController.stream;
  
  /// Stream of mode switching status messages
  Stream<String> get switchStatus => _switchStatusController.stream;

  /// Initialize the mode manager
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('Initializing ModeManager...');
      
      // Load user preferences
      await _loadUserPreferences();
      
      // Apply saved user mode
      await _networkService.setMode(_savedUserMode);
      
      // Set up network state monitoring
      _setupNetworkStateMonitoring();
      
      _isInitialized = true;
      print('ModeManager initialized successfully');
      
    } catch (e) {
      print('Failed to initialize ModeManager: $e');
      rethrow;
    }
  }

  /// Switch to online mode
  Future<void> switchToOnlineMode() async {
    await _performModeSwitch(NetworkMode.online, 'Switching to online mode...');
  }

  /// Switch to offline mode
  Future<void> switchToOfflineMode() async {
    await _performModeSwitch(NetworkMode.offline, 'Switching to offline mode...');
  }

  /// Switch to automatic mode
  Future<void> switchToAutoMode() async {
    await _performModeSwitch(NetworkMode.auto, 'Switching to automatic mode...');
  }

  /// Perform mode switch with status tracking
  Future<void> _performModeSwitch(NetworkMode mode, String statusMessage) async {
    if (_isSwitchingController.value) {
      print('Mode switch already in progress');
      return;
    }
    
    _isSwitchingController.add(true);
    _switchStatusController.add(statusMessage);
    
    try {
      print('Switching to mode: $mode');
      
      // Save user preference
      _savedUserMode = mode;
      await _saveUserPreferences();
      
      // Perform the actual mode switch
      await _networkService.setMode(mode);
      
      // Handle post-switch actions
      await _handlePostSwitchActions(mode);
      
      _switchStatusController.add('Mode switched successfully');
      print('Successfully switched to mode: $mode');
      
    } catch (e) {
      final errorMsg = 'Failed to switch mode: $e';
      print(errorMsg);
      _switchStatusController.add(errorMsg);
      rethrow;
    } finally {
      _isSwitchingController.add(false);
    }
  }

  /// Handle actions after mode switch
  Future<void> _handlePostSwitchActions(NetworkMode mode) async {
    try {
      switch (mode) {
        case NetworkMode.online:
          await _handleOnlineModeActivation();
          break;
        case NetworkMode.offline:
          await _handleOfflineModeActivation();
          break;
        case NetworkMode.auto:
          await _handleAutoModeActivation();
          break;
      }
    } catch (e) {
      print('Error in post-switch actions: $e');
    }
  }

  /// Handle online mode activation
  Future<void> _handleOnlineModeActivation() async {
    if (_autoSyncEnabled) {
      // Trigger sync when switching to online mode
      _switchStatusController.add('Synchronizing messages...');
      await _syncService.triggerManualSync();
    }
    
    if (_showModeNotifications) {
      _switchStatusController.add('Online mode active - using internet connection');
    }
  }

  /// Handle offline mode activation
  Future<void> _handleOfflineModeActivation() async {
    if (_showModeNotifications) {
      final peerCount = _meshService.peersCount;
      _switchStatusController.add('Offline mode active - $peerCount peers connected');
    }
  }

  /// Handle auto mode activation
  Future<void> _handleAutoModeActivation() async {
    if (_showModeNotifications) {
      final hasInternet = _networkService.currentNetworkState.hasInternetConnection;
      final effectiveMode = hasInternet ? 'online' : 'offline';
      _switchStatusController.add('Auto mode active - currently $effectiveMode');
    }
  }

  /// Set up network state monitoring
  void _setupNetworkStateMonitoring() {
    _networkService.networkState.listen((networkState) {
      _handleNetworkStateChange(networkState);
    });
  }

  /// Handle network state changes
  void _handleNetworkStateChange(NetworkState networkState) {
    if (!_showModeNotifications) return;
    
    // Notify about automatic mode switches
    if (networkState.mode == NetworkMode.auto) {
      if (networkState.hasInternetConnection && networkState.isOnlineServiceActive) {
        _switchStatusController.add('Auto-switched to online mode');
      } else if (!networkState.hasInternetConnection && networkState.isMeshActive) {
        _switchStatusController.add('Auto-switched to offline mode');
      }
    }
    
    // Notify about peer connections in offline mode
    if (networkState.isOfflineMode) {
      final peerCount = networkState.connectedPeers;
      if (peerCount > 0) {
        _switchStatusController.add('$peerCount peers connected');
      } else {
        _switchStatusController.add('No peers connected - searching...');
      }
    }
  }

  /// Load user preferences from storage
  Future<void> _loadUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load user mode preference
      final modeString = prefs.getString(_userModeKey);
      if (modeString != null) {
        _savedUserMode = NetworkMode.values.firstWhere(
          (mode) => mode.name == modeString,
          orElse: () => NetworkMode.auto,
        );
      }
      
      // Load other preferences
      _autoSyncEnabled = prefs.getBool(_autoSyncKey) ?? true;
      _showModeNotifications = prefs.getBool(_notificationsKey) ?? true;
      
      print('User preferences loaded: mode=$_savedUserMode, autoSync=$_autoSyncEnabled, notifications=$_showModeNotifications');
      
    } catch (e) {
      print('Failed to load user preferences: $e');
      // Use defaults
    }
  }

  /// Save user preferences to storage
  Future<void> _saveUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString(_userModeKey, _savedUserMode.name);
      await prefs.setBool(_autoSyncKey, _autoSyncEnabled);
      await prefs.setBool(_notificationsKey, _showModeNotifications);
      
      print('User preferences saved');
      
    } catch (e) {
      print('Failed to save user preferences: $e');
    }
  }

  /// Get current user mode preference
  NetworkMode get userMode => _savedUserMode;

  /// Get current effective mode (what's actually active)
  NetworkMode get effectiveMode {
    final networkState = _networkService.currentNetworkState;
    if (networkState.mode == NetworkMode.auto) {
      return networkState.hasInternetConnection ? NetworkMode.online : NetworkMode.offline;
    }
    return networkState.mode;
  }

  /// Check if auto sync is enabled
  bool get isAutoSyncEnabled => _autoSyncEnabled;

  /// Enable/disable auto sync
  Future<void> setAutoSyncEnabled(bool enabled) async {
    _autoSyncEnabled = enabled;
    await _saveUserPreferences();
    
    if (enabled) {
      _syncService.startPeriodicSync();
    } else {
      _syncService.stopPeriodicSync();
    }
    
    print('Auto sync ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Check if mode notifications are enabled
  bool get showModeNotifications => _showModeNotifications;

  /// Enable/disable mode notifications
  Future<void> setShowModeNotifications(bool enabled) async {
    _showModeNotifications = enabled;
    await _saveUserPreferences();
    print('Mode notifications ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Get mode switching statistics
  Map<String, dynamic> getModeStatistics() {
    final networkState = _networkService.currentNetworkState;
    
    return {
      'userMode': _savedUserMode.name,
      'effectiveMode': effectiveMode.name,
      'isSwitching': _isSwitchingController.value,
      'switchStatus': _switchStatusController.value,
      'hasInternetConnection': networkState.hasInternetConnection,
      'connectedPeers': networkState.connectedPeers,
      'isMeshActive': networkState.isMeshActive,
      'isOnlineServiceActive': networkState.isOnlineServiceActive,
      'autoSyncEnabled': _autoSyncEnabled,
      'showNotifications': _showModeNotifications,
    };
  }

  /// Force a mode refresh (useful for testing)
  Future<void> refreshMode() async {
    await _networkService.refreshNetworkState();
    print('Mode refreshed');
  }

  /// Reset to default preferences
  Future<void> resetToDefaults() async {
    _savedUserMode = NetworkMode.auto;
    _autoSyncEnabled = true;
    _showModeNotifications = true;
    
    await _saveUserPreferences();
    await _networkService.setMode(_savedUserMode);
    
    print('Mode manager reset to defaults');
  }

  /// Get mode recommendation based on current conditions
  NetworkMode getRecommendedMode() {
    final networkState = _networkService.currentNetworkState;
    
    if (networkState.hasInternetConnection) {
      return NetworkMode.online;
    } else if (networkState.connectedPeers > 0) {
      return NetworkMode.offline;
    } else {
      // No internet and no peers - recommend auto mode
      return NetworkMode.auto;
    }
  }

  /// Check if current mode is optimal
  bool isCurrentModeOptimal() {
    final recommended = getRecommendedMode();
    final current = effectiveMode;
    
    return current == recommended || _savedUserMode == NetworkMode.auto;
  }

  /// Dispose resources
  void dispose() {
    _isSwitchingController.close();
    _switchStatusController.close();
  }
}