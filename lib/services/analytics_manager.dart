import 'package:flutter/foundation.dart';
import 'analytics_service.dart';
import 'analytics_integration_service.dart';
import 'progress_tracking_service.dart';
import 'offline_sync_manager.dart';
import 'authentication_service.dart';
import 'database_service.dart';
import 'hub_discovery_service.dart';

/// Central manager for all analytics functionality
class AnalyticsManager extends ChangeNotifier {
  late final AnalyticsService _analyticsService;
  late final AnalyticsIntegrationService _integrationService;
  late final ProgressTrackingService _progressTrackingService;
  late final OfflineSyncManager _offlineSyncManager;
  
  final AuthenticationService _authenticationService;
  final DatabaseService _databaseService;
  final HubDiscoveryService _hubDiscoveryService;

  bool _isInitialized = false;

  AnalyticsManager({
    required AuthenticationService authenticationService,
    required DatabaseService databaseService,
    required HubDiscoveryService hubDiscoveryService,
  })  : _authenticationService = authenticationService,
        _databaseService = databaseService,
        _hubDiscoveryService = hubDiscoveryService;

  // Getters
  bool get isInitialized => _isInitialized;
  AnalyticsService get analytics => _analyticsService;
  AnalyticsIntegrationService get integration => _integrationService;
  ProgressTrackingService get progress => _progressTrackingService;
  OfflineSyncManager get offlineSync => _offlineSyncManager;

  /// Initialize all analytics services
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize core analytics service
      _analyticsService = AnalyticsService(
        databaseService: _databaseService,
        authenticationService: _authenticationService,
        hubDiscoveryService: _hubDiscoveryService,
      );

      // Initialize progress tracking service
      _progressTrackingService = ProgressTrackingService(
        databaseService: _databaseService,
        authenticationService: _authenticationService,
        analyticsService: _analyticsService,
      );

      // Initialize integration service
      _integrationService = AnalyticsIntegrationService(
        analyticsService: _analyticsService,
        progressTrackingService: _progressTrackingService,
        authenticationService: _authenticationService,
      );

      // Initialize offline sync manager
      _offlineSyncManager = OfflineSyncManager(
        analyticsService: _analyticsService,
        hubDiscoveryService: _hubDiscoveryService,
      );

      // Initialize all services
      await _analyticsService.initialize();
      await _progressTrackingService.initialize();
      await _integrationService.initialize();
      await _offlineSyncManager.initialize();

      _isInitialized = true;
      
      // Listen to changes
      _offlineSyncManager.addListener(_onSyncStatusChanged);
      
      debugPrint('Analytics manager initialized successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing analytics manager: $e');
      rethrow;
    }
  }

  /// Dispose all services
  @override
  void dispose() {
    _offlineSyncManager.removeListener(_onSyncStatusChanged);
    _offlineSyncManager.dispose();
    _progressTrackingService.dispose();
    _analyticsService.dispose();
    super.dispose();
  }

  /// Get comprehensive analytics dashboard data
  Future<Map<String, dynamic>> getDashboardData() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final [
        sessionSummary,
        syncStatus,
        queueInfo,
        readingStats,
      ] = await Future.wait([
        _integrationService.getSessionAnalyticsSummary(),
        Future.value(_offlineSyncManager.getSyncStatus()),
        _offlineSyncManager.getOfflineQueueInfo(),
        _progressTrackingService.getReadingStats(),
      ]);

      return {
        'session': sessionSummary,
        'sync': syncStatus,
        'queue': queueInfo,
        'reading': readingStats,
        'isInitialized': _isInitialized,
        'generatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getting dashboard data: $e');
      return {
        'error': e.toString(),
        'isInitialized': _isInitialized,
        'generatedAt': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Perform full analytics sync
  Future<Map<String, dynamic>> performFullSync() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      return await _integrationService.batchSyncAnalytics();
    } catch (e) {
      debugPrint('Error performing full sync: $e');
      return {
        'success': false,
        'message': 'Sync failed: ${e.toString()}',
        'error': e.toString(),
      };
    }
  }

  /// Get analytics health status
  Map<String, dynamic> getHealthStatus() {
    if (!_isInitialized) {
      return {
        'status': 'not_initialized',
        'message': 'Analytics manager not initialized',
        'healthy': false,
      };
    }

    try {
      final syncStatus = _offlineSyncManager.getSyncStatus();
      final queuedEvents = syncStatus['queuedEventsCount'] as int? ?? 0;
      final failedAttempts = syncStatus['failedSyncAttempts'] as int? ?? 0;
      final isOnline = syncStatus['isOnline'] as bool? ?? false;

      String status;
      String message;
      bool healthy;

      if (!isOnline) {
        status = 'offline';
        message = 'Device is offline - analytics queued for sync';
        healthy = queuedEvents < 1000; // Healthy if queue isn't too large
      } else if (failedAttempts >= 3) {
        status = 'sync_failed';
        message = 'Multiple sync failures - manual intervention may be needed';
        healthy = false;
      } else if (queuedEvents > 500) {
        status = 'queue_large';
        message = 'Large analytics queue - sync may be slow';
        healthy = true;
      } else {
        status = 'healthy';
        message = 'Analytics system operating normally';
        healthy = true;
      }

      return {
        'status': status,
        'message': message,
        'healthy': healthy,
        'details': {
          'isOnline': isOnline,
          'queuedEvents': queuedEvents,
          'failedAttempts': failedAttempts,
          'lastSync': syncStatus['lastSuccessfulSync'],
        },
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Error checking health status: ${e.toString()}',
        'healthy': false,
        'error': e.toString(),
      };
    }
  }

  /// Export analytics data for debugging
  Future<Map<String, dynamic>> exportAnalyticsData() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final unsyncedEvents = await _analyticsService.getUnsyncedEvents();
      final dashboardData = await getDashboardData();
      final healthStatus = getHealthStatus();

      return {
        'export': {
          'timestamp': DateTime.now().toIso8601String(),
          'version': '1.0.0',
          'deviceInfo': _analyticsService.deviceMetadata,
        },
        'health': healthStatus,
        'dashboard': dashboardData,
        'unsyncedEvents': unsyncedEvents.map((e) => e.toJson()).toList(),
        'eventCount': unsyncedEvents.length,
      };
    } catch (e) {
      debugPrint('Error exporting analytics data: $e');
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Reset analytics data (for testing/debugging)
  Future<void> resetAnalyticsData() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // This would need to be implemented in the database service
      // For now, just log the intent
      debugPrint('Resetting analytics data - this would clear all local analytics');
      
      // TODO: Implement reset functionality
      // - Clear all unsynced analytics events
      // - Reset progress tracking data
      // - Clear session data
      // - Restart analytics services
      
      await _integrationService.trackError(
        contentId: 'analytics_reset',
        errorType: 'user_action',
        errorMessage: 'Analytics data reset requested',
      );
    } catch (e) {
      debugPrint('Error resetting analytics data: $e');
    }
  }

  /// Private methods

  void _onSyncStatusChanged() {
    notifyListeners();
  }
}