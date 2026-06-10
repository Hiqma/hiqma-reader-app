import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import '../models/device.dart';
import 'database_service.dart';
import 'authentication_service.dart';
import 'hub_discovery_service.dart';

/// Analytics event types
enum AnalyticsEventType {
  appLaunch,
  appClose,
  contentView,
  contentStart,
  contentComplete,
  pageView,
  pageComplete,
  quizStart,
  quizComplete,
  quizAnswer,
  vocabularyLookup,
  bookmarkAdd,
  bookmarkRemove,
  sessionStart,
  sessionEnd,
  deviceRegistration,
  studentLogin,
  studentLogout,
  syncStart,
  syncComplete,
  error,
}

/// Analytics event data structure
class AnalyticsEvent {
  final String id;
  final String sessionId;
  final String contentId;
  final String? deviceId;
  final String? studentId;
  final AnalyticsEventType eventType;
  final Map<String, dynamic> eventData;
  final int timeSpent;
  final int? quizScore;
  final bool moduleCompleted;
  final DateTime timestamp;
  final bool synced;

  AnalyticsEvent({
    required this.id,
    required this.sessionId,
    required this.contentId,
    this.deviceId,
    this.studentId,
    required this.eventType,
    required this.eventData,
    this.timeSpent = 0,
    this.quizScore,
    this.moduleCompleted = false,
    DateTime? timestamp,
    this.synced = false,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'contentId': contentId,
      'deviceId': deviceId,
      'studentId': studentId,
      'eventType': eventType.name,
      'eventData': eventData,
      'timeSpent': timeSpent,
      'quizScore': quizScore,
      'moduleCompleted': moduleCompleted,
      'timestamp': timestamp.toIso8601String(),
      'synced': synced,
    };
  }

  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) {
    return AnalyticsEvent(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      contentId: json['contentId'] as String,
      deviceId: json['deviceId'] as String?,
      studentId: json['studentId'] as String?,
      eventType: AnalyticsEventType.values.firstWhere(
        (e) => e.name == json['eventType'],
        orElse: () => AnalyticsEventType.contentView,
      ),
      eventData: Map<String, dynamic>.from(json['eventData'] ?? {}),
      timeSpent: json['timeSpent'] as int? ?? 0,
      quizScore: json['quizScore'] as int?,
      moduleCompleted: json['moduleCompleted'] as bool? ?? false,
      timestamp: DateTime.parse(json['timestamp'] as String),
      synced: json['synced'] as bool? ?? false,
    );
  }

  AnalyticsEvent copyWith({
    String? id,
    String? sessionId,
    String? contentId,
    String? deviceId,
    String? studentId,
    AnalyticsEventType? eventType,
    Map<String, dynamic>? eventData,
    int? timeSpent,
    int? quizScore,
    bool? moduleCompleted,
    DateTime? timestamp,
    bool? synced,
  }) {
    return AnalyticsEvent(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      contentId: contentId ?? this.contentId,
      deviceId: deviceId ?? this.deviceId,
      studentId: studentId ?? this.studentId,
      eventType: eventType ?? this.eventType,
      eventData: eventData ?? this.eventData,
      timeSpent: timeSpent ?? this.timeSpent,
      quizScore: quizScore ?? this.quizScore,
      moduleCompleted: moduleCompleted ?? this.moduleCompleted,
      timestamp: timestamp ?? this.timestamp,
      synced: synced ?? this.synced,
    );
  }
}

/// Analytics service for tracking user interactions with device/student attribution
class AnalyticsService extends ChangeNotifier {
  final DatabaseService _databaseService;
  final AuthenticationService _authenticationService;
  final HubDiscoveryService _hubDiscoveryService;

  String? _currentSessionId;
  DateTime? _sessionStartTime;
  Map<String, DateTime> _contentStartTimes = {};
  Map<String, int> _pageTimeSpent = {};
  DeviceInfo? _deviceInfo;
  bool _isInitialized = false;

  AnalyticsService({
    required DatabaseService databaseService,
    required AuthenticationService authenticationService,
    required HubDiscoveryService hubDiscoveryService,
  })  : _databaseService = databaseService,
        _authenticationService = authenticationService,
        _hubDiscoveryService = hubDiscoveryService;

  // Getters
  String? get currentSessionId => _currentSessionId;
  bool get isInitialized => _isInitialized;
  Map<String, dynamic> get deviceMetadata => _deviceInfo?.toJson() ?? {};

  /// Initialize the analytics service
  Future<void> initialize() async {
    debugPrint('AnalyticsService.initialize() called');
    if (_isInitialized) {
      debugPrint('Already initialized, returning');
      return;
    }

    // Set initialized FIRST to prevent infinite loop
    _isInitialized = true;

    try {
      debugPrint('Loading device info...');
      await _loadDeviceInfo();
      debugPrint('Device info loaded ✓');
      
      debugPrint('Starting new session...');
      await _startNewSession();
      debugPrint('New session started ✓');
      
      // Listen to authentication changes
      debugPrint('Adding authentication listener...');
      _authenticationService.addListener(_onAuthenticationChanged);
      debugPrint('Authentication listener added ✓');
      
      debugPrint('Analytics service initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error initializing analytics service: $e');
      debugPrint('Stack trace: $stackTrace');
      _isInitialized = false; // Reset on error
    }
  }

  /// Dispose the service
  @override
  void dispose() {
    _authenticationService.removeListener(_onAuthenticationChanged);
    super.dispose();
  }

  /// Track an analytics event
  Future<void> trackEvent({
    required String contentId,
    required AnalyticsEventType eventType,
    Map<String, dynamic>? eventData,
    int timeSpent = 0,
    int? quizScore,
    bool moduleCompleted = false,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final sessionContext = _authenticationService.getSessionContext();
      final event = AnalyticsEvent(
        id: _generateEventId(),
        sessionId: _currentSessionId ?? 'unknown',
        contentId: contentId,
        deviceId: sessionContext['deviceId'] as String?,
        studentId: sessionContext['studentId'] as String?,
        eventType: eventType,
        eventData: {
          ...?eventData,
          'deviceCode': sessionContext['deviceCode'], // Include device code for filtering
          'deviceMetadata': deviceMetadata,
          'isAnonymous': sessionContext['isAnonymous'] ?? true,
          'isAuthenticated': sessionContext['isAuthenticated'] ?? false,
        },
        timeSpent: timeSpent,
        quizScore: quizScore,
        moduleCompleted: moduleCompleted,
      );

      await _storeEvent(event);
      debugPrint('Analytics event tracked: ${eventType.name} for content $contentId');
    } catch (e) {
      debugPrint('Error tracking analytics event: $e');
    }
  }

  /// Track app launch
  Future<void> trackAppLaunch() async {
    await trackEvent(
      contentId: 'app',
      eventType: AnalyticsEventType.appLaunch,
      eventData: {
        'appVersion': _deviceInfo?.appVersion,
        'platform': Platform.operatingSystem,
        'deviceModel': _deviceInfo?.model,
      },
    );
  }

  /// Track app close
  Future<void> trackAppClose() async {
    final sessionDuration = _sessionStartTime != null
        ? DateTime.now().difference(_sessionStartTime!).inSeconds
        : 0;

    await trackEvent(
      contentId: 'app',
      eventType: AnalyticsEventType.appClose,
      timeSpent: sessionDuration,
    );
  }

  /// Track content view
  Future<void> trackContentView(String contentId, {Map<String, dynamic>? metadata}) async {
    _contentStartTimes[contentId] = DateTime.now();
    
    await trackEvent(
      contentId: contentId,
      eventType: AnalyticsEventType.contentView,
      eventData: metadata,
    );
  }

  /// Track content start (when user begins reading)
  Future<void> trackContentStart(String contentId, {Map<String, dynamic>? metadata}) async {
    _contentStartTimes[contentId] = DateTime.now();
    
    await trackEvent(
      contentId: contentId,
      eventType: AnalyticsEventType.contentStart,
      eventData: metadata,
    );
  }

  /// Track content completion
  Future<void> trackContentComplete(String contentId, {Map<String, dynamic>? metadata}) async {
    final startTime = _contentStartTimes[contentId];
    final timeSpent = startTime != null
        ? DateTime.now().difference(startTime).inSeconds
        : 0;

    await trackEvent(
      contentId: contentId,
      eventType: AnalyticsEventType.contentComplete,
      timeSpent: timeSpent,
      moduleCompleted: true,
      eventData: metadata,
    );

    _contentStartTimes.remove(contentId);
  }

  /// Track page view
  Future<void> trackPageView(String contentId, int pageNumber, {Map<String, dynamic>? metadata}) async {
    final pageKey = '${contentId}_page_$pageNumber';
    _pageTimeSpent[pageKey] = DateTime.now().millisecondsSinceEpoch;

    await trackEvent(
      contentId: contentId,
      eventType: AnalyticsEventType.pageView,
      eventData: {
        'pageNumber': pageNumber,
        ...?metadata,
      },
    );
  }

  /// Track page completion
  Future<void> trackPageComplete(String contentId, int pageNumber, {Map<String, dynamic>? metadata}) async {
    final pageKey = '${contentId}_page_$pageNumber';
    final startTime = _pageTimeSpent[pageKey];
    final timeSpent = startTime != null
        ? DateTime.now().millisecondsSinceEpoch - startTime
        : 0;

    await trackEvent(
      contentId: contentId,
      eventType: AnalyticsEventType.pageComplete,
      timeSpent: (timeSpent / 1000).round(),
      eventData: {
        'pageNumber': pageNumber,
        ...?metadata,
      },
    );

    _pageTimeSpent.remove(pageKey);
  }

  /// Track quiz start
  Future<void> trackQuizStart(String contentId, {Map<String, dynamic>? metadata}) async {
    await trackEvent(
      contentId: contentId,
      eventType: AnalyticsEventType.quizStart,
      eventData: metadata,
    );
  }

  /// Track quiz completion
  Future<void> trackQuizComplete(String contentId, int score, int totalQuestions, {Map<String, dynamic>? metadata}) async {
    await trackEvent(
      contentId: contentId,
      eventType: AnalyticsEventType.quizComplete,
      quizScore: score,
      eventData: {
        'totalQuestions': totalQuestions,
        'scorePercentage': totalQuestions > 0 ? (score / totalQuestions * 100).round() : 0,
        ...?metadata,
      },
    );
  }

  /// Track quiz answer
  Future<void> trackQuizAnswer(String contentId, int questionIndex, bool isCorrect, {Map<String, dynamic>? metadata}) async {
    await trackEvent(
      contentId: contentId,
      eventType: AnalyticsEventType.quizAnswer,
      eventData: {
        'questionIndex': questionIndex,
        'isCorrect': isCorrect,
        ...?metadata,
      },
    );
  }

  /// Track vocabulary lookup
  Future<void> trackVocabularyLookup(String contentId, String word, {Map<String, dynamic>? metadata}) async {
    await trackEvent(
      contentId: contentId,
      eventType: AnalyticsEventType.vocabularyLookup,
      eventData: {
        'word': word,
        ...?metadata,
      },
    );
  }

  /// Track device registration
  Future<void> trackDeviceRegistration(String deviceCode, bool success, {String? errorMessage}) async {
    await trackEvent(
      contentId: 'device_registration',
      eventType: AnalyticsEventType.deviceRegistration,
      eventData: {
        'deviceCode': deviceCode,
        'success': success,
        'errorMessage': errorMessage,
      },
    );
  }

  /// Track student login
  Future<void> trackStudentLogin(String studentCode, bool success, {String? errorMessage}) async {
    await trackEvent(
      contentId: 'student_login',
      eventType: AnalyticsEventType.studentLogin,
      eventData: {
        'studentCode': studentCode,
        'success': success,
        'errorMessage': errorMessage,
      },
    );
  }

  /// Track student logout
  Future<void> trackStudentLogout() async {
    await trackEvent(
      contentId: 'student_logout',
      eventType: AnalyticsEventType.studentLogout,
    );
  }

  /// Track sync operations
  Future<void> trackSyncStart() async {
    await trackEvent(
      contentId: 'sync',
      eventType: AnalyticsEventType.syncStart,
    );
  }

  /// Track sync completion
  Future<void> trackSyncComplete(bool success, int itemsSynced, {String? errorMessage}) async {
    await trackEvent(
      contentId: 'sync',
      eventType: AnalyticsEventType.syncComplete,
      eventData: {
        'success': success,
        'itemsSynced': itemsSynced,
        'errorMessage': errorMessage,
      },
    );
  }

  /// Track errors
  Future<void> trackError(String contentId, String errorType, String errorMessage, {Map<String, dynamic>? metadata}) async {
    await trackEvent(
      contentId: contentId,
      eventType: AnalyticsEventType.error,
      eventData: {
        'errorType': errorType,
        'errorMessage': errorMessage,
        ...?metadata,
      },
    );
  }

  /// Get unsynced analytics events
  Future<List<AnalyticsEvent>> getUnsyncedEvents() async {
    try {
      final db = await _databaseService.database;
      final results = await db.query(
        'analytics_events',
        where: 'synced = ?',
        whereArgs: [0],
        orderBy: 'timestamp ASC',
      );
      
      return results.map((row) => AnalyticsEvent(
        id: row['id'].toString(),
        sessionId: row['sessionId'] as String,
        contentId: row['contentId'] as String,
        deviceId: row['deviceId'] as String?,
        studentId: row['studentId'] as String?,
        eventType: AnalyticsEventType.values.firstWhere(
          (e) => e.name == row['eventType'],
          orElse: () => AnalyticsEventType.contentView,
        ),
        eventData: row['eventData'] != null 
            ? Map<String, dynamic>.from(jsonDecode(row['eventData'] as String))
            : {
                'studentCode': row['studentCode'], // Include student code in event data
              },
        timeSpent: row['timeSpent'] as int? ?? 0,
        quizScore: row['quizScore'] as int?,
        moduleCompleted: (row['moduleCompleted'] as int? ?? 0) == 1,
        timestamp: DateTime.parse(row['timestamp'] as String),
        synced: (row['synced'] as int? ?? 0) == 1,
      )).toList();
    } catch (e) {
      debugPrint('Error getting unsynced events: $e');
      return [];
    }
  }

  /// Sync analytics to edge hub
  Future<bool> syncAnalyticsToHub() async {
    try {
      final unsyncedEvents = await getUnsyncedEvents();
      if (unsyncedEvents.isEmpty) {
        debugPrint('No unsynced analytics events to upload');
        return true;
      }

      final hubUrl = await _hubDiscoveryService.getCurrentHubUrl();
      if (hubUrl == null) {
        debugPrint('No edge hub connection for analytics sync - events queued for later');
        return false;
      }

      debugPrint('Syncing ${unsyncedEvents.length} analytics events to hub');

      // Get headers with device code
      final headers = _authenticationService.getRequestHeaders();
      
      final response = await http.post(
        Uri.parse('$hubUrl/api/analytics/events/batch'),
        headers: headers,
        body: jsonEncode({
          'events': unsyncedEvents.map((event) => event.toJson()).toList(),
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Mark events as synced in analytics_events table
        final db = await _databaseService.database;
        final batch = db.batch();
        
        for (final event in unsyncedEvents) {
          final eventId = int.tryParse(event.id);
          if (eventId != null) {
            batch.update(
              'analytics_events',
              {'synced': 1},
              where: 'id = ?',
              whereArgs: [eventId],
            );
          }
        }
        
        await batch.commit();

        debugPrint('Successfully synced ${unsyncedEvents.length} analytics events');
        return true;
      } else {
        debugPrint('Analytics sync failed: HTTP ${response.statusCode} - events remain queued');
        return false;
      }
    } catch (e) {
      debugPrint('Error syncing analytics: $e - events remain queued for retry');
      return false;
    }
  }

  /// Queue analytics event for offline sync
  Future<void> queueEventForOfflineSync(AnalyticsEvent event) async {
    try {
      await _storeEvent(event);
      debugPrint('Analytics event queued for offline sync: ${event.eventType.name}');
    } catch (e) {
      debugPrint('Error queuing event for offline sync: $e');
    }
  }

  /// Get offline analytics queue status
  Future<Map<String, dynamic>> getOfflineQueueStatus() async {
    try {
      final unsyncedEvents = await getUnsyncedEvents();
      final eventsByType = <String, int>{};
      
      for (final event in unsyncedEvents) {
        eventsByType[event.eventType.name] = (eventsByType[event.eventType.name] ?? 0) + 1;
      }

      return {
        'totalQueuedEvents': unsyncedEvents.length,
        'eventsByType': eventsByType,
        'oldestEvent': unsyncedEvents.isNotEmpty 
            ? unsyncedEvents.map((e) => e.timestamp).reduce((a, b) => a.isBefore(b) ? a : b).toIso8601String()
            : null,
        'newestEvent': unsyncedEvents.isNotEmpty 
            ? unsyncedEvents.map((e) => e.timestamp).reduce((a, b) => a.isAfter(b) ? a : b).toIso8601String()
            : null,
      };
    } catch (e) {
      debugPrint('Error getting offline queue status: $e');
      return {'totalQueuedEvents': 0, 'eventsByType': {}, 'error': e.toString()};
    }
  }

  /// Retry sync for failed events
  Future<bool> retrySyncFailedEvents() async {
    try {
      debugPrint('Retrying sync for failed analytics events');
      return await syncAnalyticsToHub();
    } catch (e) {
      debugPrint('Error retrying sync: $e');
      return false;
    }
  }

  /// Clean up old offline events (to prevent storage bloat)
  Future<void> cleanupOldOfflineEvents({int maxDaysOld = 30, int maxEvents = 10000}) async {
    try {
      // This would need to be implemented in the database service
      // For now, just log the intent
      debugPrint('Cleaning up old offline analytics events (older than $maxDaysOld days or exceeding $maxEvents events)');
      
      // TODO: Implement cleanup logic in database service
      // - Delete events older than maxDaysOld days that are already synced
      // - If total events exceed maxEvents, delete oldest synced events first
    } catch (e) {
      debugPrint('Error cleaning up old offline events: $e');
    }
  }

  /// Get analytics statistics
  Future<Map<String, dynamic>> getAnalyticsStats() async {
    try {
      final sessionContext = _authenticationService.getSessionContext();
      final deviceId = sessionContext['deviceId'] as String?;
      final studentId = sessionContext['studentId'] as String?;
      final studentCode = sessionContext['studentCode'] as String?;

      // This would need to be implemented in the database service
      // For now, return basic stats
      return {
        'currentSession': _currentSessionId,
        'sessionDuration': _sessionStartTime != null
            ? DateTime.now().difference(_sessionStartTime!).inMinutes
            : 0,
        'deviceId': deviceId,
        'studentId': studentId,
        'studentCode': studentCode,
        'isAnonymous': sessionContext['isAnonymous'] ?? true,
        'contentStartTimes': _contentStartTimes.length,
        'pageTimeSpent': _pageTimeSpent.length,
      };
    } catch (e) {
      debugPrint('Error getting analytics stats: $e');
      return {};
    }
  }

  /// Get analytics events for a specific student
  Future<List<AnalyticsEvent>> getEventsForStudent(String studentCode) async {
    try {
      final db = await _databaseService.database;
      final results = await db.query(
        'analytics_events',
        where: 'studentCode = ?',
        whereArgs: [studentCode],
        orderBy: 'timestamp DESC',
      );
      
      return results.map((row) => AnalyticsEvent(
        id: row['id'].toString(),
        sessionId: row['sessionId'] as String,
        contentId: row['contentId'] as String,
        deviceId: row['deviceId'] as String?,
        studentId: row['studentId'] as String?,
        eventType: AnalyticsEventType.values.firstWhere(
          (e) => e.name == row['eventType'],
          orElse: () => AnalyticsEventType.contentView,
        ),
        eventData: row['eventData'] != null 
            ? Map<String, dynamic>.from(jsonDecode(row['eventData'] as String))
            : {},
        timeSpent: row['timeSpent'] as int? ?? 0,
        quizScore: row['quizScore'] as int?,
        moduleCompleted: (row['moduleCompleted'] as int? ?? 0) == 1,
        timestamp: DateTime.parse(row['timestamp'] as String),
        synced: (row['synced'] as int? ?? 0) == 1,
      )).toList();
    } catch (e) {
      debugPrint('Error getting events for student $studentCode: $e');
      return [];
    }
  }

  /// Get analytics summary for a specific student
  Future<Map<String, dynamic>> getStudentAnalyticsSummary(String studentCode) async {
    try {
      final events = await getEventsForStudent(studentCode);
      
      final contentEvents = events.where((e) => e.eventType == AnalyticsEventType.contentView).length;
      final quizEvents = events.where((e) => e.eventType == AnalyticsEventType.quizComplete).length;
      final totalTimeSpent = events.fold<int>(0, (sum, event) => sum + event.timeSpent);
      final averageQuizScore = events
          .where((e) => e.quizScore != null)
          .map((e) => e.quizScore!)
          .fold<double>(0, (sum, score) => sum + score) / 
          (events.where((e) => e.quizScore != null).length > 0 
              ? events.where((e) => e.quizScore != null).length 
              : 1);

      return {
        'studentCode': studentCode,
        'totalEvents': events.length,
        'contentViews': contentEvents,
        'quizzesCompleted': quizEvents,
        'totalTimeSpent': totalTimeSpent,
        'averageQuizScore': averageQuizScore.isNaN ? 0 : averageQuizScore.round(),
        'lastActivity': events.isNotEmpty ? events.first.timestamp.toIso8601String() : null,
      };
    } catch (e) {
      debugPrint('Error getting student analytics summary: $e');
      return {'studentCode': studentCode, 'error': e.toString()};
    }
  }

  /// Private methods

  Future<void> _loadDeviceInfo() async {
    try {
      final deviceInfoPlugin = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();
      
      String model = 'Unknown';
      String osVersion = 'Unknown';
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        model = '${androidInfo.manufacturer} ${androidInfo.model}';
        osVersion = 'Android ${androidInfo.version.release}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        model = iosInfo.model;
        osVersion = '${iosInfo.systemName} ${iosInfo.systemVersion}';
      }

      _deviceInfo = DeviceInfo(
        model: model,
        osVersion: osVersion,
        appVersion: packageInfo.version,
      );
    } catch (e) {
      debugPrint('Error loading device info: $e');
    }
  }

  Future<void> _startNewSession() async {
    _currentSessionId = _generateSessionId();
    _sessionStartTime = DateTime.now();
    _contentStartTimes.clear();
    _pageTimeSpent.clear();

    await trackEvent(
      contentId: 'session',
      eventType: AnalyticsEventType.sessionStart,
    );
  }

  void _onAuthenticationChanged() {
    // When authentication state changes, we might want to start a new session
    // or update the current session context
    notifyListeners();
  }

  Future<void> _storeEvent(AnalyticsEvent event) async {
    try {
      final sessionContext = _authenticationService.getSessionContext();
      
      debugPrint('=== STORING ANALYTICS EVENT ===');
      debugPrint('Event Type: ${event.eventType.name}');
      debugPrint('Content ID: ${event.contentId}');
      debugPrint('Session ID: ${event.sessionId}');
      debugPrint('Time Spent: ${event.timeSpent}s');
      debugPrint('Student Code: ${sessionContext['studentCode'] ?? 'anonymous'}');
      
      // Store in analytics_events table for detailed analytics
      final db = await _databaseService.database;
      final eventId = await db.insert('analytics_events', {
        'sessionId': event.sessionId,
        'contentId': event.contentId,
        'deviceId': event.deviceId ?? sessionContext['deviceId'] ?? '',
        'studentId': event.studentId ?? sessionContext['studentId'],
        'studentCode': sessionContext['studentCode'], // Store student code for easy filtering
        'deviceCode': sessionContext['deviceCode'],
        'eventType': event.eventType.name,
        'eventData': jsonEncode(event.eventData),
        'timeSpent': event.timeSpent,
        'quizScore': event.quizScore,
        'moduleCompleted': event.moduleCompleted ? 1 : 0,
        'timestamp': event.timestamp.toIso8601String(),
        'synced': 0,
      });

      debugPrint('Event stored successfully with ID: $eventId');
      
      // Check total unsynced events
      final unsyncedCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM analytics_events WHERE synced = 0'
      );
      debugPrint('Total unsynced events in database: ${unsyncedCount.first['count']}');

      // Also store in activity_logs for backward compatibility
      await _databaseService.logActivityWithAttribution(
        contentId: event.contentId,
        deviceId: event.deviceId ?? sessionContext['deviceId'] ?? '',
        studentId: event.studentId ?? sessionContext['studentId'],
        action: event.eventType.name,
        timeSpent: event.timeSpent,
        deviceCode: sessionContext['deviceCode'] as String?,
      );
      
      debugPrint('=== EVENT STORAGE COMPLETE ===');
    } catch (e, stackTrace) {
      debugPrint('Error storing analytics event: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  AnalyticsEvent _activityToEvent(Map<String, dynamic> activity) {
    return AnalyticsEvent(
      id: activity['id'].toString(),
      sessionId: _currentSessionId ?? 'unknown',
      contentId: activity['contentId'] as String,
      deviceId: activity['deviceId'] as String?,
      studentId: activity['studentId'] as String?,
      eventType: AnalyticsEventType.values.firstWhere(
        (e) => e.name == activity['action'],
        orElse: () => AnalyticsEventType.contentView,
      ),
      eventData: {},
      timeSpent: activity['timeSpent'] as int? ?? 0,
      timestamp: DateTime.parse(activity['timestamp'] as String),
      synced: (activity['synced'] as int? ?? 0) == 1,
    );
  }

  String _generateEventId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(8)}';
  }

  String _generateSessionId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(12)}';
  }

  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(length, (index) => chars[DateTime.now().millisecondsSinceEpoch % chars.length]).join();
  }
}