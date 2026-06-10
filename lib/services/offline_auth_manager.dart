import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'authentication_service.dart';
import 'database_service.dart';

/// Manages offline authentication caching and synchronization
class OfflineAuthManager extends ChangeNotifier {
  final AuthenticationService _authService;
  final DatabaseService _databaseService;
  final Connectivity _connectivity;

  bool _isOnline = false;
  bool _isSyncing = false;
  Timer? _syncTimer;
  Timer? _maintenanceTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  OfflineAuthManager({
    required AuthenticationService authService,
    required DatabaseService databaseService,
    Connectivity? connectivity,
  }) : _authService = authService,
       _databaseService = databaseService,
       _connectivity = connectivity ?? Connectivity();

  // Getters
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;

  /// Initialize the offline authentication manager
  Future<void> initialize() async {
    // Check initial connectivity
    final connectivityResults = await _connectivity.checkConnectivity();
    _isOnline = !connectivityResults.contains(ConnectivityResult.none);

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );

    // Start periodic sync when online
    if (_isOnline) {
      _startPeriodicSync();
    }

    // Start maintenance timer
    _startMaintenanceTimer();

    notifyListeners();
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(List<ConnectivityResult> results) async {
    final wasOnline = _isOnline;
    _isOnline = !results.contains(ConnectivityResult.none);

    if (!wasOnline && _isOnline) {
      // Just came back online
      debugPrint('Network connection restored - starting sync');
      await _onBackOnline();
      _startPeriodicSync();
    } else if (wasOnline && !_isOnline) {
      // Just went offline
      debugPrint('Network connection lost - entering offline mode');
      await _onGoingOffline();
      _stopPeriodicSync();
    }

    notifyListeners();
  }

  /// Handle going back online
  Future<void> _onBackOnline() async {
    try {
      // Sync offline authentication data
      await _authService.syncOfflineAuthData();
      
      // Refresh cached students
      await _authService.refreshCachedStudents();
      
      debugPrint('Offline authentication data synced successfully');
    } catch (e) {
      debugPrint('Error syncing offline auth data: $e');
    }
  }

  /// Handle going offline
  Future<void> _onGoingOffline() async {
    try {
      // Maintain authentication state during outage
      await _authService.maintainAuthStateDuringOutage();
      
      debugPrint('Authentication state maintained for offline use');
    } catch (e) {
      debugPrint('Error maintaining auth state: $e');
    }
  }

  /// Start periodic sync when online
  void _startPeriodicSync() {
    _stopPeriodicSync();
    
    if (_isOnline) {
      _syncTimer = Timer.periodic(Duration(minutes: 5), (timer) async {
        if (_isOnline && !_isSyncing) {
          await _performPeriodicSync();
        }
      });
    }
  }

  /// Stop periodic sync
  void _stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Perform periodic sync
  Future<void> _performPeriodicSync() async {
    if (_isSyncing) return;

    _isSyncing = true;
    notifyListeners();

    try {
      // Sync offline authentication data
      await _authService.syncOfflineAuthData();
      
      // Check for pending registrations
      final pendingRegistrations = await _databaseService.getPendingOfflineRegistrations();
      if (pendingRegistrations.isNotEmpty) {
        debugPrint('Processing ${pendingRegistrations.length} pending registrations');
      }
      
    } catch (e) {
      debugPrint('Error during periodic sync: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Start maintenance timer for cleanup
  void _startMaintenanceTimer() {
    // Run maintenance every hour
    _maintenanceTimer = Timer.periodic(Duration(hours: 1), (timer) async {
      await _performMaintenance();
    });
  }

  /// Perform maintenance tasks
  Future<void> _performMaintenance() async {
    try {
      // Clean up old authentication cache data
      await _databaseService.cleanupOldAuthCache();
      
      // Maintain authentication state if offline
      if (!_isOnline) {
        await _authService.maintainAuthStateDuringOutage();
      }
      
      debugPrint('Authentication maintenance completed');
    } catch (e) {
      debugPrint('Error during maintenance: $e');
    }
  }

  /// Force sync offline authentication data
  Future<bool> forceSyncOfflineAuthData() async {
    if (!_isOnline) {
      debugPrint('Cannot sync - device is offline');
      return false;
    }

    if (_isSyncing) {
      debugPrint('Sync already in progress');
      return false;
    }

    _isSyncing = true;
    notifyListeners();

    try {
      await _authService.syncOfflineAuthData();
      debugPrint('Force sync completed successfully');
      return true;
    } catch (e) {
      debugPrint('Error during force sync: $e');
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Get offline authentication status
  Future<Map<String, dynamic>> getOfflineAuthStatus() async {
    final authStats = await _authService.getOfflineAuthStats();
    final authState = await _authService.getOfflineAuthState();
    final pendingRegistrations = await _databaseService.getPendingOfflineRegistrations();

    return {
      'isOnline': _isOnline,
      'isSyncing': _isSyncing,
      'canOperateOffline': await _authService.canOperateOffline(),
      'authStats': authStats,
      'authState': authState,
      'pendingRegistrations': pendingRegistrations.length,
      'lastSyncAttempt': DateTime.now().toIso8601String(),
    };
  }

  /// Check if device can authenticate offline
  Future<bool> canAuthenticateOffline(String deviceCode) async {
    return await _authService.isDeviceCachedForOffline(deviceCode);
  }

  /// Check if student can authenticate offline
  Future<bool> canStudentAuthenticateOffline(String studentCode) async {
    return await _authService.isStudentCachedForOffline(studentCode);
  }

  /// Register device with offline support
  Future<AuthResult> registerDeviceWithOfflineSupport(String deviceCode) async {
    return await _authService.registerDeviceWithOfflineSupport(deviceCode);
  }

  /// Login student with offline support
  Future<AuthResult> loginStudentWithOfflineSupport(String studentCode) async {
    return await _authService.loginStudentWithOfflineSupport(studentCode);
  }

  /// Get offline authentication statistics for UI display
  Future<Map<String, dynamic>> getOfflineAuthStatsForUI() async {
    final stats = await _authService.getOfflineAuthStats();
    final pendingRegistrations = await _databaseService.getPendingOfflineRegistrations();
    
    return {
      'cachedDevices': stats['cachedDevices'] ?? 0,
      'cachedStudents': stats['cachedStudents'] ?? 0,
      'activeSessions': stats['activeSessions'] ?? 0,
      'pendingRegistrations': pendingRegistrations.length,
      'offlineCapable': stats['offlineCapable'] ?? false,
      'isOnline': _isOnline,
      'isSyncing': _isSyncing,
      'lastUpdate': DateTime.now().toIso8601String(),
    };
  }

  /// Prepare for extended offline use
  Future<void> prepareForExtendedOfflineUse() async {
    try {
      // Ensure all current authentication data is cached
      if (_isOnline) {
        await _authService.refreshCachedStudents();
      }
      
      // Maintain current authentication state
      await _authService.maintainAuthStateDuringOutage();
      
      debugPrint('Prepared for extended offline use');
    } catch (e) {
      debugPrint('Error preparing for offline use: $e');
    }
  }

  /// Handle app resume (check connectivity and sync if needed)
  Future<void> handleAppResume() async {
    final connectivityResults = await _connectivity.checkConnectivity();
    final wasOnline = _isOnline;
    _isOnline = !connectivityResults.contains(ConnectivityResult.none);

    if (!wasOnline && _isOnline) {
      // App resumed and we're back online
      await _onBackOnline();
      _startPeriodicSync();
      notifyListeners();
    } else if (_isOnline) {
      // App resumed and we're still online - do a quick sync
      await _performPeriodicSync();
    }
  }

  /// Handle app pause (maintain state for offline)
  Future<void> handleAppPause() async {
    if (!_isOnline) {
      await _authService.maintainAuthStateDuringOutage();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    _maintenanceTimer?.cancel();
    super.dispose();
  }
}