import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:rxdart/rxdart.dart';
import '../../models/network_state.dart';
import 'mesh_service.dart';
import 'online_service.dart';

/// Interface for network monitoring service
abstract class INetworkService {
  Stream<NetworkState> get networkState;
  Stream<bool> get hasInternetConnection;
  Stream<NetworkMode> get currentMode;
  Future<void> initialize();
  Future<void> setMode(NetworkMode mode);
  Future<bool> checkInternetConnection();
  Future<void> refreshNetworkState();
  NetworkState get currentNetworkState;
  Map<String, dynamic> getNetworkStatistics();
  bool get isOnline;
  bool get isOffline;
  void dispose();
}

/// Network monitoring service that manages connectivity and mode switching
class NetworkService implements INetworkService {
  static NetworkService? _instance;
  
  final Connectivity _connectivity = Connectivity();
  final IMeshService _meshService;
  final IOnlineService _onlineService;
  
  // Network state management
  final BehaviorSubject<NetworkState> _networkStateController = 
      BehaviorSubject<NetworkState>.seeded(NetworkState.initial());
  
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _connectionCheckTimer;
  Timer? _modeTransitionTimer;
  
  bool _isInitialized = false;
  NetworkMode _userPreferredMode = NetworkMode.auto;
  
  // Configuration
  static const Duration connectionCheckInterval = Duration(seconds: 10);
  static const Duration modeTransitionDelay = Duration(seconds: 2);

  NetworkService._({
    required IMeshService meshService,
    required IOnlineService onlineService,
  }) : _meshService = meshService,
       _onlineService = onlineService;

  static NetworkService getInstance({
    IMeshService? meshService,
    IOnlineService? onlineService,
  }) {
    _instance ??= NetworkService._(
      meshService: meshService ?? MeshService.getInstance(),
      onlineService: onlineService ?? OnlineService.getInstance(),
    );
    return _instance!;
  }

  @override
  Stream<NetworkState> get networkState => _networkStateController.stream;

  @override
  Stream<bool> get hasInternetConnection => 
      _networkStateController.stream.map((state) => state.hasInternetConnection);

  @override
  Stream<NetworkMode> get currentMode => 
      _networkStateController.stream.map((state) => state.mode);

  @override
  NetworkState get currentNetworkState => _networkStateController.value;

  @override
  bool get isOnline => currentNetworkState.isOnlineMode;

  @override
  bool get isOffline => currentNetworkState.isOfflineMode;

  @override
  Future<void> initialize() async {
    if (_isInitialized) {
      print('NetworkService already initialized');
      return;
    }

    try {
      print('Initializing NetworkService...');
      
      // Check initial connectivity
      final initialConnectivity = await _connectivity.checkConnectivity();
      final hasInternet = await _testInternetConnection();
      
      // Update initial state
      _updateNetworkState(
        hasInternetConnection: hasInternet,
        mode: _userPreferredMode,
      );
      
      // Set up connectivity monitoring
      _setupConnectivityMonitoring();
      
      // Set up periodic connection checks
      _startPeriodicConnectionCheck();
      
      // Listen to service state changes
      _setupServiceStateListeners();
      
      _isInitialized = true;
      print('NetworkService initialized successfully');
      
    } catch (e) {
      print('Failed to initialize NetworkService: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  @override
  Future<void> setMode(NetworkMode mode) async {
    if (!_isInitialized) {
      throw Exception('NetworkService not initialized. Call initialize() first.');
    }

    if (_userPreferredMode == mode) {
      print('Mode already set to: $mode');
      return;
    }

    try {
      print('Setting network mode to: $mode');
      
      _userPreferredMode = mode;
      
      // Update network state with new mode
      _updateNetworkState(mode: mode);
      
      // Trigger mode transition after a short delay
      _scheduleServiceModeTransition();
      
    } catch (e) {
      print('Failed to set network mode: $e');
      rethrow;
    }
  }

  @override
  Future<bool> checkInternetConnection() async {
    try {
      final hasConnection = await _testInternetConnection();
      
      // Update state if connection status changed
      if (hasConnection != currentNetworkState.hasInternetConnection) {
        _updateNetworkState(hasInternetConnection: hasConnection);
      }
      
      return hasConnection;
    } catch (e) {
      print('Error checking internet connection: $e');
      return false;
    }
  }

  /// Set up connectivity monitoring
  void _setupConnectivityMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (ConnectivityResult result) {
        _handleConnectivityChange(result);
      },
      onError: (error) {
        print('Connectivity monitoring error: $error');
      },
    );
  }

  /// Handle connectivity changes
  void _handleConnectivityChange(ConnectivityResult result) async {
    print('Connectivity changed: $result');
    
    // Check if we have any connection
    final hasConnection = result != ConnectivityResult.none;
    
    if (hasConnection) {
      // Test actual internet connectivity
      final hasInternet = await _testInternetConnection();
      _updateNetworkState(hasInternetConnection: hasInternet);
    } else {
      // No connection at all
      _updateNetworkState(hasInternetConnection: false);
    }
    
    // Schedule service mode transition
    _scheduleServiceModeTransition();
  }

  /// Test actual internet connection
  Future<bool> _testInternetConnection() async {
    try {
      // Try to connect to a reliable service
      // In a real app, you might ping your own server or a reliable endpoint
      final ConnectivityResult result = await _connectivity.checkConnectivity();
      
      // For now, we'll assume connection if we have WiFi or mobile data
      return result == ConnectivityResult.wifi ||
             result == ConnectivityResult.mobile;
          
    } catch (e) {
      print('Internet connection test failed: $e');
      return false;
    }
  }

  /// Start periodic connection checking
  void _startPeriodicConnectionCheck() {
    _connectionCheckTimer = Timer.periodic(connectionCheckInterval, (timer) {
      checkInternetConnection();
    });
  }

  /// Set up listeners for service state changes
  void _setupServiceStateListeners() {
    // For stub services, we don't have streams for these properties
    // In a real implementation, these would be streams
    // For now, we'll just skip setting up listeners
    print('Service state listeners setup (stub implementation)');
  }

  /// Schedule service mode transition
  void _scheduleServiceModeTransition() {
    _modeTransitionTimer?.cancel();
    _modeTransitionTimer = Timer(modeTransitionDelay, () {
      _performServiceModeTransition();
    });
  }

  /// Perform the actual service mode transition
  void _performServiceModeTransition() async {
    try {
      final currentState = currentNetworkState;
      
      print('Performing service mode transition. Current state: $currentState');
      
      if (currentState.isOnlineMode) {
        // Switch to online mode
        await _activateOnlineMode();
      } else if (currentState.isOfflineMode) {
        // Switch to offline mode
        await _activateOfflineMode();
      }
      
    } catch (e) {
      print('Error during service mode transition: $e');
    }
  }

  /// Activate online mode
  Future<void> _activateOnlineMode() async {
    try {
      print('Activating online mode...');
      
      // Stop mesh service if running
      if (_meshService.isStarted) {
        await _meshService.stop();
      }
      
      // Start online service
      if (!_onlineService.isOnline) {
        await _onlineService.connect();
      }
      
      print('Online mode activated');
      
    } catch (e) {
      print('Failed to activate online mode: $e');
      // Fall back to offline mode
      await _activateOfflineMode();
    }
  }

  /// Activate offline mode
  Future<void> _activateOfflineMode() async {
    try {
      print('Activating offline mode...');
      
      // Disconnect online service
      if (_onlineService.isOnline) {
        await _onlineService.disconnect();
      }
      
      // Start mesh service
      if (!_meshService.isStarted) {
        await _meshService.start();
      }
      
      print('Offline mode activated');
      
    } catch (e) {
      print('Failed to activate offline mode: $e');
    }
  }

  /// Update network state
  void _updateNetworkState({
    NetworkMode? mode,
    bool? hasInternetConnection,
    int? connectedPeers,
    DateTime? lastSync,
    bool? isMeshActive,
    bool? isOnlineServiceActive,
  }) {
    final currentState = _networkStateController.value;
    
    final newState = currentState.copyWith(
      mode: mode,
      hasInternetConnection: hasInternetConnection,
      connectedPeers: connectedPeers,
      lastSync: lastSync,
      isMeshActive: isMeshActive,
      isOnlineServiceActive: isOnlineServiceActive,
    );
    
    if (newState != currentState) {
      _networkStateController.add(newState);
      print('Network state updated: $newState');
    }
  }

  /// Get network statistics
  @override
  Map<String, dynamic> getNetworkStatistics() {
    final state = currentNetworkState;
    
    return {
      'isInitialized': _isInitialized,
      'currentMode': state.mode.name,
      'hasInternetConnection': state.hasInternetConnection,
      'connectedPeers': state.connectedPeers,
      'isMeshActive': state.isMeshActive,
      'isOnlineServiceActive': state.isOnlineServiceActive,
      'isOnlineMode': state.isOnlineMode,
      'isOfflineMode': state.isOfflineMode,
      'userPreferredMode': _userPreferredMode.name,
      'lastSync': state.lastSync.toIso8601String(),
    };
  }

  /// Force a network state refresh
  @override
  Future<void> refreshNetworkState() async {
    try {
      print('Refreshing network state...');
      
      final hasInternet = await checkInternetConnection();
      final peerCount = _meshService.peersCount;
      final isMeshActive = _meshService.isStarted;
      final isOnlineActive = _onlineService.isOnline;
      
      _updateNetworkState(
        hasInternetConnection: hasInternet,
        connectedPeers: peerCount,
        isMeshActive: isMeshActive,
        isOnlineServiceActive: isOnlineActive,
      );
      
      print('Network state refreshed');
      
    } catch (e) {
      print('Error refreshing network state: $e');
    }
  }

  /// Get user preferred mode
  NetworkMode get userPreferredMode => _userPreferredMode;

  /// Check if automatic mode switching is enabled
  bool get isAutoModeEnabled => _userPreferredMode == NetworkMode.auto;

  /// Enable/disable automatic mode switching
  Future<void> setAutoMode(bool enabled) async {
    if (enabled) {
      await setMode(NetworkMode.auto);
    } else {
      // If disabling auto mode, switch to current effective mode
      final currentState = currentNetworkState;
      if (currentState.hasInternetConnection) {
        await setMode(NetworkMode.online);
      } else {
        await setMode(NetworkMode.offline);
      }
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectionCheckTimer?.cancel();
    _modeTransitionTimer?.cancel();
    _networkStateController.close();
  }
}