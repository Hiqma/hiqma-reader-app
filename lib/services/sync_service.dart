import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/content.dart';
import '../models/quiz_question.dart';
import 'database_service.dart';
import 'authentication_service.dart';

/// Represents a stage in the sync process
class SyncStage {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final SyncStageStatus status;
  final int? progress; // 0-100 percentage
  final String? details;
  final DateTime? startTime;
  final DateTime? endTime;

  SyncStage({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    this.status = SyncStageStatus.pending,
    this.progress,
    this.details,
    this.startTime,
    this.endTime,
  });

  SyncStage copyWith({
    String? id,
    String? title,
    String? description,
    String? emoji,
    SyncStageStatus? status,
    int? progress,
    String? details,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return SyncStage(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      details: details ?? this.details,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  Duration? get duration {
    if (startTime != null && endTime != null) {
      return endTime!.difference(startTime!);
    }
    return null;
  }
}

enum SyncStageStatus {
  pending,
  inProgress,
  completed,
  failed,
  skipped,
}

class SyncService extends ChangeNotifier {
  static const String _edgeHubUrlKey = 'edge_hub_url';
  static const String _lastSyncKey = 'last_sync_time';
  
  final AuthenticationService? _authenticationService;
  
  bool _isSyncing = false;
  String? _edgeHubUrl;
  DateTime? _lastSyncTime;
  String _syncStatus = 'Ready to sync';
  int _syncedCount = 0;

  // Enhanced sync stages tracking
  List<SyncStage> _syncStages = [];
  int _currentStageIndex = -1;

  bool get isSyncing => _isSyncing;
  String? get edgeHubUrl => _edgeHubUrl;
  DateTime? get lastSyncTime => _lastSyncTime;
  String get syncStatus => _syncStatus;
  int get syncedCount => _syncedCount;
  List<SyncStage> get syncStages => List.unmodifiable(_syncStages);
  int get currentStageIndex => _currentStageIndex;
  SyncStage? get currentStage => _currentStageIndex >= 0 && _currentStageIndex < _syncStages.length 
      ? _syncStages[_currentStageIndex] 
      : null;

  SyncService({AuthenticationService? authenticationService}) 
      : _authenticationService = authenticationService {
    _loadSettings();
  }

  /// Initialize sync stages
  void _initializeSyncStages() {
    _syncStages = [
      SyncStage(
        id: 'connection',
        title: 'Connecting to Hub',
        description: 'Establishing connection with the story hub',
        emoji: '🔗',
      ),
      SyncStage(
        id: 'hub_settings',
        title: 'Getting Hub Settings',
        description: 'Downloading hub configuration and settings',
        emoji: '⚙️',
      ),
      SyncStage(
        id: 'students',
        title: 'Syncing Students',
        description: 'Downloading student information for offline access',
        emoji: '👥',
      ),
      SyncStage(
        id: 'content_list',
        title: 'Fetching Content List',
        description: 'Getting list of available stories and updates',
        emoji: '📋',
      ),
      SyncStage(
        id: 'content_download',
        title: 'Downloading Stories',
        description: 'Downloading new and updated stories',
        emoji: '📚',
      ),
      SyncStage(
        id: 'images',
        title: 'Downloading Images',
        description: 'Downloading story images and covers',
        emoji: '🖼️',
      ),
      SyncStage(
        id: 'analytics',
        title: 'Sending Activity Logs',
        description: 'Uploading student activity and progress data',
        emoji: '📊',
      ),
      SyncStage(
        id: 'completion',
        title: 'Finalizing Sync',
        description: 'Completing sync and updating local database',
        emoji: '✅',
      ),
    ];
    _currentStageIndex = -1;
    notifyListeners();
  }

  /// Update a specific sync stage
  void _updateStage(String stageId, {
    SyncStageStatus? status,
    int? progress,
    String? details,
  }) {
    final stageIndex = _syncStages.indexWhere((stage) => stage.id == stageId);
    if (stageIndex != -1) {
      final currentStage = _syncStages[stageIndex];
      _syncStages[stageIndex] = currentStage.copyWith(
        status: status,
        progress: progress,
        details: details,
        startTime: status == SyncStageStatus.inProgress ? DateTime.now() : currentStage.startTime,
        endTime: (status == SyncStageStatus.completed || status == SyncStageStatus.failed) 
            ? DateTime.now() 
            : currentStage.endTime,
      );
      
      // Update current stage index
      if (status == SyncStageStatus.inProgress) {
        _currentStageIndex = stageIndex;
      }
      
      notifyListeners();
    }
  }

  /// Mark stage as started
  void _startStage(String stageId, {String? details}) {
    _updateStage(stageId, status: SyncStageStatus.inProgress, details: details);
    final stage = _syncStages.firstWhere((s) => s.id == stageId);
    _syncStatus = stage.title;
  }

  /// Mark stage as completed with minimum display time
  Future<void> _completeStage(String stageId, {String? details}) async {
    final stage = _syncStages.firstWhere((s) => s.id == stageId);
    
    // Ensure minimum display time of 1 second for user visibility
    if (stage.startTime != null) {
      final elapsed = DateTime.now().difference(stage.startTime!);
      const minDuration = Duration(seconds: 1);
      
      if (elapsed < minDuration) {
        final remainingTime = minDuration - elapsed;
        await Future.delayed(remainingTime);
      }
    }
    
    _updateStage(stageId, status: SyncStageStatus.completed, progress: 100, details: details);
  }

  /// Mark stage as failed with minimum display time
  Future<void> _failStage(String stageId, {String? details}) async {
    final stage = _syncStages.firstWhere((s) => s.id == stageId);
    
    // Ensure minimum display time even for failed stages
    if (stage.startTime != null) {
      final elapsed = DateTime.now().difference(stage.startTime!);
      const minDuration = Duration(milliseconds: 500);
      
      if (elapsed < minDuration) {
        final remainingTime = minDuration - elapsed;
        await Future.delayed(remainingTime);
      }
    }
    
    _updateStage(stageId, status: SyncStageStatus.failed, details: details);
  }

  /// Mark stage as skipped with minimum display time
  Future<void> _skipStage(String stageId, {String? details}) async {
    final stage = _syncStages.firstWhere((s) => s.id == stageId);
    
    // Show skipped stages briefly so users understand what was checked
    if (stage.startTime != null) {
      final elapsed = DateTime.now().difference(stage.startTime!);
      const minDuration = Duration(milliseconds: 800);
      
      if (elapsed < minDuration) {
        final remainingTime = minDuration - elapsed;
        await Future.delayed(remainingTime);
      }
    }
    
    _updateStage(stageId, status: SyncStageStatus.skipped, details: details);
  }

  /// Update stage progress
  void _updateStageProgress(String stageId, int progress, {String? details}) {
    _updateStage(stageId, progress: progress, details: details);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _edgeHubUrl = prefs.getString(_edgeHubUrlKey);
    final lastSyncString = prefs.getString(_lastSyncKey);
    if (lastSyncString != null) {
      _lastSyncTime = DateTime.parse(lastSyncString);
    }
    notifyListeners();
  }

  Future<void> setEdgeHubUrl(String url) async {
    _edgeHubUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_edgeHubUrlKey, url);
    notifyListeners();
  }

  Future<void> clearEdgeHubUrl() async {
    _edgeHubUrl = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_edgeHubUrlKey);
    notifyListeners();
  }

  Future<bool> testConnection() async {
    if (_edgeHubUrl == null) return false;
    
    try {
      // Try the info endpoint first (which we know works)
      final response = await http.get(
        Uri.parse('$_edgeHubUrl/api/hub/info'),
        headers: _getRequestHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return true;
      }
      
      // Fallback to status endpoint
      final statusResponse = await http.get(
        Uri.parse('$_edgeHubUrl/api/hub/status'),
        headers: _getRequestHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      return statusResponse.statusCode == 200;
    } catch (e) {
      debugPrint('Connection test failed: $e');
      return false;
    }
  }

  // Hub settings cache
  Map<String, dynamic>? _hubSettings;
  
  Map<String, dynamic>? get hubSettings => _hubSettings;

  Future<SyncResult> syncContent() async {
    if (_isSyncing) {
      return SyncResult(success: false, message: 'Sync already in progress');
    }

    if (_edgeHubUrl == null) {
      return SyncResult(success: false, message: 'Edge hub URL not configured');
    }

    _isSyncing = true;
    _syncedCount = 0;
    
    // Initialize sync stages
    _initializeSyncStages();
    notifyListeners();

    try {
      // Stage 1: Connection
      _startStage('connection', details: 'Testing connection to $_edgeHubUrl');
      
      final isConnected = await testConnection();
      if (!isConnected) {
        _updateStageProgress('connection', 50, details: 'Hub not reachable, searching for new hub...');
        
        final rediscovered = await _rediscoverHub();
        if (!rediscovered) {
          await _failStage('connection', details: 'Cannot connect to edge hub and rediscovery failed');
          throw Exception('Cannot connect to edge hub and rediscovery failed');
        }
      }
      await _completeStage('connection', details: 'Successfully connected to hub');

      // Stage 2: Hub Settings
      _startStage('hub_settings', details: 'Downloading hub configuration');
      
      // Build sync URL with last sync time for incremental sync and device code
      final queryParams = <String, String>{};
      if (_lastSyncTime != null) {
        queryParams['since'] = _lastSyncTime!.toIso8601String();
      }
      
      // Add device code to query params if available
      final deviceQueryParams = _getRequestQueryParams();
      queryParams.addAll(deviceQueryParams);
      
      final uri = Uri.parse('$_edgeHubUrl/api/hub/download').replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: _getRequestHeaders(),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        await _failStage('hub_settings', details: 'Failed to fetch content: ${response.statusCode}');
        throw Exception('Failed to fetch content: ${response.statusCode}');
      }

      final Map<String, dynamic> responseData = json.decode(response.body);
      final List<dynamic> contentData = responseData['content'] ?? [];
      final List<dynamic> studentsData = responseData['students'] ?? [];
      
      // Extract hub settings if available
      if (responseData.containsKey('hubSettings')) {
        _hubSettings = responseData['hubSettings'];
        debugPrint('Hub settings received: $_hubSettings');
      }
      await _completeStage('hub_settings', details: 'Hub settings downloaded successfully');

      // Stage 3: Students Sync
      _startStage('students', details: 'Processing student data');
      
      if (studentsData.isNotEmpty) {
        _updateStageProgress('students', 50, details: 'Syncing ${studentsData.length} students to local database');
        await _syncStudentsToDatabase(studentsData);
        await _completeStage('students', details: 'Synced ${studentsData.length} students to local database');
      } else {
        await _skipStage('students', details: 'No student data to sync');
      }

      // Stage 4: Content List
      _startStage('content_list', details: 'Processing content list');
      
      if (contentData.isEmpty) {
        await _skipStage('content_list', details: 'No new content available');
        await _skipStage('content_download', details: 'No content to download');
        await _skipStage('images', details: 'No images to download');
        
        _lastSyncTime = DateTime.now();
        await _saveLastSyncTime();
        
        // Still do analytics sync
        await _performAnalyticsSync();
        
        _startStage('completion');
        await _completeStage('completion', details: 'Sync completed - no new content');
        
        return SyncResult(success: true, message: 'No new content to sync', syncedCount: 0);
      }

      _updateStageProgress('content_list', 50, details: 'Checking for updates...');

      // Get all existing content from local database for comparison
      final existingContent = await DatabaseService.instance.getAllContent();
      final existingContentMap = <String, Content>{};
      for (final content in existingContent) {
        existingContentMap[content.id] = content;
      }

      _updateStageProgress('content_list', 75, details: 'Processing ${contentData.length} items...');

      // Filter and convert to Content objects - only process new or updated content
      final List<Content> contentToSync = [];
      int skippedCount = 0;
      
      for (final item in contentData) {
        try {
          
          // Handle both cloudId (string) and id (number) from edge hub
          String contentId;
          if (item['cloudId'] != null) {
            contentId = item['cloudId'].toString();
          } else if (item['id'] != null) {
            contentId = item['id'].toString();
          } else {
            debugPrint('Content item missing both id and cloudId, skipping');
            continue;
          }

          // Parse remote content timestamps
          final remoteUpdatedAt = _parseDateTime(item['updatedAt']) ?? _parseDateTime(item['createdAt']) ?? DateTime.now();
          
          // Check if content already exists locally
          final existingLocalContent = existingContentMap[contentId];
          
          if (existingLocalContent != null) {
            // Content exists locally, check if remote version is newer
            final localUpdatedAt = existingLocalContent.updatedAt ?? existingLocalContent.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            
            if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
              // Content updated remotely, will sync
            } else {
              // Content is up to date, skip
              skippedCount++;
              continue;
            }
          }
          
          final content = Content(
            id: contentId,
            title: item['title'] as String,
            description: item['description'] as String? ?? '',
            htmlContent: item['htmlContent'] as String,
            category: _getCategoryName(item['categories']) ?? item['category'] ?? 'General',
            ageGroup: item['ageGroup'] as String? ?? 'All ages',
            language: item['language'] as String? ?? 'en',
            authorId: item['author'] as String?,
            targetCountries: _parseTargetCountries(item['targetCountries']),
            images: _parseImages(item['images']),
            coverImageUrl: item['coverImageUrl'] as String?,
            comprehensionQuestions: _parseComprehensionQuestions(item['comprehensionQuestions']),
            createdAt: _parseDateTime(item['createdAt']) ?? DateTime.now(),
            updatedAt: remoteUpdatedAt,
          );
          contentToSync.add(content);

        } catch (e) {
          // Skip invalid content item
        }
      }

      _completeStage('content_list', details: 'Found ${contentToSync.length} items to sync, ${skippedCount} up to date');

      // Stage 5: Content Download
      if (contentToSync.isNotEmpty) {
        _startStage('content_download', details: 'Downloading ${contentToSync.length} stories');
        
        // Save content to database first (without images)
        await DatabaseService.instance.insertContentList(contentToSync);
        _syncedCount = contentToSync.length;
        
        await _completeStage('content_download', details: 'Downloaded ${contentToSync.length} stories');

        // Stage 6: Images Download
        _startStage('images', details: 'Downloading images for stories');
        
        int imageProgress = 0;
        final totalImages = contentToSync.fold<int>(0, (sum, content) => 
            sum + (content.coverImageUrl != null ? 1 : 0) + content.images.length);
        
        if (totalImages > 0) {
          for (int i = 0; i < contentToSync.length; i++) {
            final content = contentToSync[i];
            _updateStageProgress('images', 
                ((i / contentToSync.length) * 100).round(), 
                details: 'Processing images for: ${content.title}');
            
            // Download cover image if available
            if (content.coverImageUrl != null && content.coverImageUrl!.isNotEmpty) {
              try {
                final localCoverPath = await _downloadAndCacheImage(content.coverImageUrl!);
                if (localCoverPath != null) {
                  contentToSync[i] = Content(
                    id: content.id,
                    title: content.title,
                    description: content.description,
                    htmlContent: content.htmlContent,
                    category: content.category,
                    ageGroup: content.ageGroup,
                    language: content.language,
                    authorId: content.authorId,
                    targetCountries: content.targetCountries,
                    images: content.images,
                    coverImageUrl: localCoverPath, // Use local path
                    comprehensionQuestions: content.comprehensionQuestions,
                    createdAt: content.createdAt,
                    updatedAt: content.updatedAt,
                  );
                }
              } catch (e) {
                // Failed to download cover image
              }
            }
            
            // Download content images if available
            if (content.images.isNotEmpty) {
              try {
                final localImages = <String>[];
                for (final imageUrl in content.images) {
                  final localPath = await _downloadAndCacheImage(imageUrl);
                  if (localPath != null) {
                    localImages.add(localPath);
                  }
                }
                if (localImages.isNotEmpty) {
                  contentToSync[i] = Content(
                    id: content.id,
                    title: content.title,
                    description: content.description,
                    htmlContent: content.htmlContent,
                    category: content.category,
                    ageGroup: content.ageGroup,
                    language: content.language,
                    authorId: content.authorId,
                    targetCountries: content.targetCountries,
                    images: localImages, // Use local paths
                    coverImageUrl: contentToSync[i].coverImageUrl, // Keep updated cover image
                    comprehensionQuestions: content.comprehensionQuestions,
                    createdAt: content.createdAt,
                    updatedAt: content.updatedAt,
                  );
                }
              } catch (e) {
                // Failed to download content images
              }
            }
          }

          // Update database with local image paths
          await DatabaseService.instance.insertContentList(contentToSync);
          await _completeStage('images', details: 'Downloaded images for ${contentToSync.length} stories');
        } else {
          await _skipStage('images', details: 'No images to download');
        }
      } else {
        await _skipStage('content_download', details: 'No new content to download');
        await _skipStage('images', details: 'No images to download');
      }

      _lastSyncTime = DateTime.now();
      await _saveLastSyncTime();

      // Stage 7: Analytics Sync
      await _performAnalyticsSync();

      // Stage 8: Completion
      _startStage('completion', details: 'Finalizing sync process');
      
      String statusMessage;
      if (contentToSync.isEmpty && skippedCount > 0) {
        statusMessage = 'All content up to date';
      } else if (skippedCount > 0) {
        statusMessage = 'Synced ${contentToSync.length} new/updated items, ${skippedCount} already up to date';
      } else {
        statusMessage = 'Synced ${contentToSync.length} items successfully';
      }
      
      await _completeStage('completion', details: statusMessage);
      _syncStatus = statusMessage;
      notifyListeners();

      return SyncResult(
        success: true,
        message: statusMessage,
        syncedCount: contentToSync.length,
      );

    } catch (e) {
      _syncStatus = 'Sync failed: ${e.toString()}';
      
      // Mark current stage as failed if any
      if (_currentStageIndex >= 0 && _currentStageIndex < _syncStages.length) {
        final currentStage = _syncStages[_currentStageIndex];
        await _failStage(currentStage.id, details: e.toString());
      }
      
      notifyListeners();
      return SyncResult(success: false, message: e.toString());
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Perform analytics sync as a separate stage
  Future<void> _performAnalyticsSync() async {
    debugPrint('=== ANALYTICS SYNC START ===');
    _startStage('analytics', details: 'Checking for activity logs to upload');
    
    try {
      debugPrint('Getting database instance...');
      final db = await DatabaseService.instance.database;
      
      debugPrint('Querying for unsynced events...');
      final unsyncedEvents = await db.query(
        'analytics_events',
        where: 'synced = ?',
        whereArgs: [0],
        orderBy: 'timestamp ASC',
      );
      
      debugPrint('Found ${unsyncedEvents.length} unsynced events');
      
      if (unsyncedEvents.isEmpty) {
        debugPrint('No activity logs to upload - skipping analytics sync');
        await _skipStage('analytics', details: 'No activity logs to upload');
        return;
      }

      // Log sample events for debugging
      debugPrint('Sample unsynced events:');
      for (int i = 0; i < unsyncedEvents.length && i < 3; i++) {
        final event = unsyncedEvents[i];
        debugPrint('  Event ${i + 1}: ${event['eventType']} - Content: ${event['contentId']} - Time: ${event['timeSpent']}s - Student: ${event['studentCode'] ?? 'anonymous'}');
      }

      _updateStageProgress('analytics', 25, details: 'Uploading ${unsyncedEvents.length} activity logs');

      // Prepare analytics data for edge hub
      debugPrint('Preparing analytics data for upload...');
      final analyticsData = unsyncedEvents.map((event) => {
        'sessionId': event['sessionId'],
        'contentId': event['contentId'],
        'deviceId': event['deviceId'],
        'studentId': event['studentId'],
        'studentCode': event['studentCode'], // Include student code for filtering
        'eventType': event['eventType'],
        'eventData': event['eventData'] != null ? json.decode(event['eventData'] as String) : {},
        'timeSpent': event['timeSpent'],
        'quizScore': event['quizScore'],
        'moduleCompleted': event['moduleCompleted'] == 1,
        'timestamp': event['timestamp'],
      }).toList();

      debugPrint('Analytics data prepared: ${analyticsData.length} events');

      _updateStageProgress('analytics', 50, details: 'Sending activity logs to hub');

      // === LOG FULL PAYLOAD BEFORE SENDING ===
      debugPrint('');
      debugPrint('=== FULL ANALYTICS PAYLOAD TO EDGE HUB ===');
      debugPrint('Number of events: ${analyticsData.length}');
      debugPrint('');
      
      // Log each event in detail
      for (int i = 0; i < analyticsData.length; i++) {
        final event = analyticsData[i];
        debugPrint('Event ${i + 1}/${analyticsData.length}:');
        debugPrint('  sessionId: ${event['sessionId']}');
        debugPrint('  contentId: ${event['contentId']}');
        debugPrint('  deviceId: ${event['deviceId']}');
        debugPrint('  studentId: ${event['studentId']}');  // <-- KEY FIELD
        debugPrint('  studentCode: ${event['studentCode']}');
        debugPrint('  eventType: ${event['eventType']}');
        debugPrint('  timeSpent: ${event['timeSpent']}s');
        debugPrint('  quizScore: ${event['quizScore']}');
        debugPrint('  moduleCompleted: ${event['moduleCompleted']}');
        debugPrint('  timestamp: ${event['timestamp']}');
        debugPrint('');
      }
      
      debugPrint('Full JSON payload:');
      debugPrint(json.encode({'analyticsData': analyticsData}));
      debugPrint('=== END PAYLOAD ===');
      debugPrint('');

      // Send analytics data to edge hub
      final uri = Uri.parse('$_edgeHubUrl/api/analytics/collect');
      debugPrint('Sending POST request to: $uri');
      debugPrint('Request headers: ${_getRequestHeaders()}');
      
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          ..._getRequestHeaders(),
        },
        body: json.encode({
          'analyticsData': analyticsData,
        }),
      ).timeout(const Duration(seconds: 30));

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Analytics upload successful! Marking events as synced...');
        _updateStageProgress('analytics', 75, details: 'Marking logs as synced');
        
        // Mark events as synced
        final batch = db.batch();
        for (final event in unsyncedEvents) {
          batch.update(
            'analytics_events',
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [event['id']],
          );
        }
        await batch.commit();
        
        debugPrint('Successfully marked ${unsyncedEvents.length} events as synced');
        await _completeStage('analytics', details: 'Successfully uploaded ${unsyncedEvents.length} activity logs');
        debugPrint('=== ANALYTICS SYNC COMPLETE ===');
      } else {
        debugPrint('Analytics upload failed with status: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        await _failStage('analytics', details: 'Failed to upload logs: HTTP ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      debugPrint('Analytics sync error: $e');
      debugPrint('Stack trace: $stackTrace');
      await _failStage('analytics', details: 'Error uploading logs: $e');
      // Don't throw error - analytics sync failure shouldn't break content sync
    }
  }

  String? _getCategoryName(dynamic categories) {
    if (categories is List && categories.isNotEmpty) {
      final firstCategory = categories.first;
      if (firstCategory is Map && firstCategory.containsKey('name')) {
        return firstCategory['name'] as String;
      }
    }
    return null;
  }

  DateTime? _parseDateTime(dynamic dateValue) {
    if (dateValue == null) return null;
    try {
      if (dateValue is String) {
        return DateTime.parse(dateValue);
      } else if (dateValue is DateTime) {
        return dateValue;
      }
    } catch (e) {
      debugPrint('Error parsing date: $dateValue - $e');
    }
    return null;
  }

  List<String> _parseTargetCountries(dynamic countriesValue) {
    if (countriesValue == null) return [];
    try {
      if (countriesValue is String) {
        final decoded = json.decode(countriesValue);
        if (decoded is List) {
          return List<String>.from(decoded);
        }
      } else if (countriesValue is List) {
        return List<String>.from(countriesValue);
      }
    } catch (e) {
      debugPrint('Error parsing target countries: $countriesValue - $e');
    }
    return [];
  }

  List<QuizQuestion> _parseComprehensionQuestions(dynamic questionsValue) {
    if (questionsValue == null) return [];
    try {
      List<dynamic> questionsList = [];
      
      if (questionsValue is String) {
        final decoded = json.decode(questionsValue);
        if (decoded is List) {
          questionsList = decoded;
        }
      } else if (questionsValue is List) {
        questionsList = questionsValue;
      }
      
      return questionsList.map((q) {
        // Convert the question map to handle correctAnswer conversion
        final questionMap = Map<String, dynamic>.from(q);
        
        // Convert correctAnswer from string to index if needed
        if (questionMap['correctAnswer'] is String) {
          final correctAnswerText = questionMap['correctAnswer'] as String;
          final options = List<String>.from(questionMap['options'] ?? []);
          final correctIndex = options.indexOf(correctAnswerText);
          questionMap['correctAnswer'] = correctIndex >= 0 ? correctIndex : 0;
        }
        
        // Ensure id field exists
        if (questionMap['id'] == null) {
          questionMap['id'] = DateTime.now().millisecondsSinceEpoch.toString();
        }
        
        return QuizQuestion.fromMap(questionMap);
      }).toList();
    } catch (e) {
      // Error parsing comprehension questions - return empty list
    }
    return [];
  }

  List<String> _parseImages(dynamic images) {
    if (images == null) return [];
    if (images is String) {
      try {
        final parsed = json.decode(images);
        return List<String>.from(parsed);
      } catch (e) {
        return [images];
      }
    }
    if (images is List) {
      return List<String>.from(images);
    }
    return [];
  }

  Future<String?> _downloadAndCacheImage(String imageUrl) async {
    try {
      debugPrint('Downloading image: $imageUrl');
      
      // Check if it's already a local path
      if (!imageUrl.startsWith('http')) {
        debugPrint('Already local path: $imageUrl');
        return imageUrl;
      }
      
      // Convert edge hub image URL to local filename
      String filename;
      if (imageUrl.contains('/images/')) {
        filename = imageUrl.split('/images/').last;
      } else {
        final uri = Uri.parse(imageUrl);
        filename = path.basename(uri.path);
      }
      
      debugPrint('Extracted filename: $filename');
      
      // Get app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(path.join(appDir.path, 'cached_images'));
      
      // Create images directory if it doesn't exist
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
        debugPrint('Created images directory: ${imagesDir.path}');
      }
      
      final localFile = File(path.join(imagesDir.path, filename));
      
      // Check if file already exists
      if (await localFile.exists()) {
        debugPrint('File already exists: ${localFile.path}');
        return localFile.path;
      }
      
      // Use the original imageUrl directly if it's already a full URL
      String downloadUrl = imageUrl;
      
      debugPrint('Downloading from: $downloadUrl');
      
      final response = await http.get(
        Uri.parse(downloadUrl),
        headers: _getRequestHeaders(),
      ).timeout(const Duration(seconds: 30));
      
      debugPrint('Download response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        await localFile.writeAsBytes(response.bodyBytes);
        debugPrint('Saved image to: ${localFile.path}');
        return localFile.path;
      } else {
        debugPrint('Failed to download image: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error downloading image: $e');
      return null;
    }
  }

  Future<void> _cleanupOldImages() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(path.join(appDir.path, 'cached_images'));
      
      if (await imagesDir.exists()) {
        final files = await imagesDir.list().toList();
        final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
        
        for (final file in files) {
          if (file is File) {
            final stat = await file.stat();
            if (stat.modified.isBefore(cutoffDate)) {
              await file.delete();
              debugPrint('Deleted old cached image: ${path.basename(file.path)}');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to cleanup old images: $e');
    }
  }

  Future<void> _saveLastSyncTime() async {
    if (_lastSyncTime != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, _lastSyncTime!.toIso8601String());
      
      // Cleanup old images after successful sync
      await _cleanupOldImages();
    }
  }

  String getTimeSinceLastSync() {
    if (_lastSyncTime == null) return 'Never';
    
    final now = DateTime.now();
    final difference = now.difference(_lastSyncTime!);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  /// Get request headers including device code
  Map<String, String> _getRequestHeaders() {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    
    // Add device code to headers if available
    if (_authenticationService?.currentDeviceCode != null) {
      headers['X-Device-Code'] = _authenticationService!.currentDeviceCode!;
    }
    
    return headers;
  }

  /// Get request query parameters including device code
  Map<String, String> _getRequestQueryParams() {
    final params = <String, String>{};
    
    // Add device code to query params if available
    if (_authenticationService?.currentDeviceCode != null) {
      params['deviceCode'] = _authenticationService!.currentDeviceCode!;
    }
    
    return params;
  }

  /// Attempt to rediscover the hub on the network
  Future<bool> _rediscoverHub() async {
    try {
      // Try common IP addresses on the local network
      final commonIPs = [
        '192.168.1.7',   // Current known IP
        '192.168.1.1',   // Router
        '192.168.1.100', // Common static IP
        '192.168.1.101',
        '192.168.1.102',
        '192.168.1.200',
        '192.168.1.254', // Common router IP
      ];
      
      for (final ip in commonIPs) {
        final hubUrl = 'https://edgehub.hiqma.org';
        try {
          final response = await http.get(
            Uri.parse('$hubUrl/api/hub/info'),
            headers: {'Accept': 'application/json'},
          ).timeout(const Duration(seconds: 2));
          
          if (response.statusCode == 200) {
            // Found a hub! Update the URL
            await setEdgeHubUrl(hubUrl);
            debugPrint('Hub rediscovered at: $hubUrl');
            return true;
          }
        } catch (e) {
          // Continue to next IP
        }
      }
      
      debugPrint('Hub rediscovery failed - no hub found on network');
      return false;
    } catch (e) {
      debugPrint('Hub rediscovery error: $e');
      return false;
    }
  }

  /// Force full resync by clearing last sync time
  Future<void> forceFullResync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSyncKey);
    _lastSyncTime = null;
    debugPrint('Cleared last sync time - next sync will be full resync');
    notifyListeners();
  }

  /// Clear all cached images
  Future<void> clearCachedImages() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(path.join(appDir.path, 'cached_images'));
      
      if (await imagesDir.exists()) {
        await imagesDir.delete(recursive: true);
        debugPrint('Cleared all cached images');
      }
    } catch (e) {
      debugPrint('Error clearing cached images: $e');
    }
  }

  /// Force download cover images for existing content
  Future<void> forceDownloadCoverImages() async {
    try {
      final allContent = await DatabaseService.instance.getAllContent();
      
      for (final content in allContent) {
        if (content.coverImageUrl != null && 
            content.coverImageUrl!.isNotEmpty && 
            content.coverImageUrl!.startsWith('http')) {
          final localPath = await _downloadAndCacheImage(content.coverImageUrl!);
          
          if (localPath != null) {
            final updatedContent = Content(
              id: content.id,
              title: content.title,
              description: content.description,
              htmlContent: content.htmlContent,
              category: content.category,
              ageGroup: content.ageGroup,
              language: content.language,
              authorId: content.authorId,
              targetCountries: content.targetCountries,
              images: content.images,
              coverImageUrl: localPath,
              comprehensionQuestions: content.comprehensionQuestions,
              createdAt: content.createdAt,
              updatedAt: content.updatedAt,
            );
            
            await DatabaseService.instance.insertContentList([updatedContent]);
          }
        }
      }
    } catch (e) {
      debugPrint('Error downloading cover images: $e');
    }
  }

  /// Get hub settings from edge hub
  Future<Map<String, dynamic>?> getHubSettings() async {
    if (_edgeHubUrl == null) {
      return null;
    }

    try {
      final uri = Uri.parse('$_edgeHubUrl/api/hub/settings');
      final response = await http.get(
        uri,
        headers: _getRequestHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _hubSettings = data;
        debugPrint('Hub settings fetched: $_hubSettings');
        return _hubSettings;
      } else {
        debugPrint('Failed to fetch hub settings: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching hub settings: $e');
      return null;
    }
  }

  /// Check if student authentication is required based on hub settings
  bool isStudentAuthenticationRequired() {
    if (_hubSettings == null) return false;
    return _hubSettings!['requireStudentAuthentication'] == true;
  }

  /// Check if anonymous access is allowed based on hub settings
  bool isAnonymousAccessAllowed() {
    if (_hubSettings == null) return true; // Default to allow anonymous access
    return _hubSettings!['allowAnonymousAccess'] == true;
  }

  /// Get authentication message from hub settings
  String? getAuthenticationMessage() {
    if (_hubSettings == null) return null;
    return _hubSettings!['authenticationMessage'];
  }

  /// Sync students data to local database for offline authentication
  Future<void> _syncStudentsToDatabase(List<dynamic> studentsData) async {
    try {
      final students = studentsData.map((studentJson) {
        return {
          'id': studentJson['id']?.toString() ?? '',
          'studentCode': studentJson['studentCode']?.toString() ?? '',
          'firstName': studentJson['firstName']?.toString(),
          'lastName': studentJson['lastName']?.toString(),
          'grade': studentJson['grade']?.toString(),
          'age': studentJson['age']?.toString(),
          'status': studentJson['status']?.toString() ?? 'active',
        };
      }).toList();

      await DatabaseService.instance.syncStudents(students);
    } catch (e) {
      debugPrint('Error syncing students to database: $e');
    }
  }
}

class SyncResult {
  final bool success;
  final String message;
  final int syncedCount;

  SyncResult({
    required this.success,
    required this.message,
    this.syncedCount = 0,
  });
}