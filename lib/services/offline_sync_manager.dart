import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'analytics_service.dart';
import 'hub_discovery_service.dart';

/// Manages offline analytics sync and connectivity monitoring
class OfflineSyncManager extends ChangeNotifier {
  final AnalyticsService _analyticsService;
  final HubDiscoveryService _hubDiscoveryService;
  
  Timer? _syncTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = false;
  bool _isSyncing = false;
  DateTime? _lastSyncAttempt;
  DateTime? _lastSuccessfulSync;
  int _failedSyncAttempts = 0;
  
  // Sync configuration
  static const Duration _syncInterval = Duration(minutes: 5);
  static const int _maxRetryAttempts = 3;

  OfflineSyncManager({
    required AnalyticsService analyticsService,
    required HubDiscoveryService hubDiscoveryService,
  })  : _analyticsService = analyticsService,
        _hubDiscoveryService = hubDiscoveryService;

  // Getters
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncAttempt => _lastSyncAttempt;
  DateTime? get lastSuccessfulSync => _lastSuccessfulSync;
  int get failedSyncAttempts => _failedSyncAttempts;
  bool get hasQueuedEvents => _queuedEventsCount > 0;
  int _queuedEventsCount = 0;

  /// Initialize the offline sync manager
  Future<void> initialize() async {
    try {
      // Check initial connectivity
      final connectivityResults = await Connectivity().checkConnectivity();
      _isOnline = !connectivityResults.contains(ConnectivityResult.none);
      
      // Listen to connectivity changes
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
      
      // Start periodic sync timer
      _startSyncTimer();
      
      // Update queued events count
      await _updateQueuedEventsCount();
      
      debugPrint('Offline sync manager initialized - Online: $_isOnline');
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing offline sync manager: $e');
    }
  }

  /// Dispose the manager
  @override
  void dispose() {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  /// Manually trigger sync
  Future<bool> triggerSync() async {
    if (_isSyncing) {
      debugPrint('Sync already in progress');
      return false;
    }

    return await _performSync();
  }

  /// Get sync status information
  Map<String, dynamic> getSyncStatus() {
    return {
      'isOnline': _isOnline,
      'isSyncing': _isSyncing,
      'lastSyncAttempt': _lastSyncAttempt?.toIso8601String(),
      'lastSuccessfulSync': _lastSuccessfulSync?.toIso8601String(),
      'failedSyncAttempts': _failedSyncAttempts,
      'queuedEventsCount': _queuedEventsCount,
      'nextSyncIn': _getNextSyncTime(),
    };
  }

  /// Get detailed offline queue information
  Future<Map<String, dynamic>> getOfflineQueueInfo() async {
    try {
      final queueStatus = await _analyticsService.getOfflineQueueStatus();
      return {
        ...queueStatus,
        'syncStatus': getSyncStatus(),
      };
    } catch (e) {
      debugPrint('Error getting offline queue info: $e');
      return {'error': e.toString()};
    }
  }

  /// Force retry failed sync attempts
  Future<bool> forceRetrySync() async {
    _failedSyncAttempts = 0; // Reset failed attempts
    return await triggerSync();
  }

  /// Private methods

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) => _performSync());
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = !results.contains(ConnectivityResult.none);
    
    debugPrint('Connectivity changed: ${results.map((r) => r.name).join(', ')} (Online: $_isOnline)');
    
    // If we just came online and have queued events, trigger immediate sync
    if (!wasOnline && _isOnline && _queuedEventsCount > 0) {
      debugPrint('Came online with queued events - triggering immediate sync');
      Timer(const Duration(seconds: 2), () => _performSync()); // Small delay to ensure connection is stable
    }
    
    notifyListeners();
  }

  Future<bool> _performSync() async {
    if (_isSyncing) {
      return false;
    }

    if (!_isOnline) {
      debugPrint('Skipping sync - offline');
      return false;
    }

    if (_failedSyncAttempts >= _maxRetryAttempts) {
      debugPrint('Skipping sync - max retry attempts reached');
      return false;
    }

    _isSyncing = true;
    _lastSyncAttempt = DateTime.now();
    notifyListeners();

    try {
      // Check if hub is available
      final hubUrl = await _hubDiscoveryService.getCurrentHubUrl();
      if (hubUrl == null) {
        debugPrint('No hub available for sync');
        _failedSyncAttempts++;
        return false;
      }

      // Perform the sync
      final success = await _analyticsService.syncAnalyticsToHub();
      
      if (success) {
        _lastSuccessfulSync = DateTime.now();
        _failedSyncAttempts = 0;
        await _updateQueuedEventsCount();
        debugPrint('Sync completed successfully');
        
        // Clean up old events periodically
        if (_lastSuccessfulSync!.minute % 10 == 0) { // Every 10 minutes
          await _analyticsService.cleanupOldOfflineEvents();
        }
      } else {
        _failedSyncAttempts++;
        debugPrint('Sync failed - attempt $_failedSyncAttempts/$_maxRetryAttempts');
      }

      return success;
    } catch (e) {
      _failedSyncAttempts++;
      debugPrint('Sync error: $e - attempt $_failedSyncAttempts/$_maxRetryAttempts');
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _updateQueuedEventsCount() async {
    try {
      final queueStatus = await _analyticsService.getOfflineQueueStatus();
      _queuedEventsCount = queueStatus['totalQueuedEvents'] as int? ?? 0;
    } catch (e) {
      debugPrint('Error updating queued events count: $e');
      _queuedEventsCount = 0;
    }
  }

  String _getNextSyncTime() {
    if (_isSyncing) {
      return 'Syncing now';
    }
    
    if (!_isOnline) {
      return 'Waiting for connection';
    }
    
    if (_failedSyncAttempts >= _maxRetryAttempts) {
      return 'Max retries reached';
    }
    
    final nextSync = _lastSyncAttempt?.add(_syncInterval) ?? DateTime.now();
    final timeUntilSync = nextSync.difference(DateTime.now());
    
    if (timeUntilSync.isNegative) {
      return 'Soon';
    }
    
    final minutes = timeUntilSync.inMinutes;
    final seconds = timeUntilSync.inSeconds % 60;
    
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}