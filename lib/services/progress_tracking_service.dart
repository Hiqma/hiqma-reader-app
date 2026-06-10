import 'package:flutter/foundation.dart';
import '../models/reading_progress.dart';
import '../models/content.dart';
import 'database_service.dart';
import 'authentication_service.dart';
import 'analytics_service.dart';

/// Enhanced progress tracking service with device/student attribution
class ProgressTrackingService extends ChangeNotifier {
  final DatabaseService _databaseService;
  final AuthenticationService _authenticationService;
  final AnalyticsService _analyticsService;

  Map<String, ReadingProgress> _currentProgress = {};
  Map<String, DateTime> _sessionStartTimes = {};
  bool _isInitialized = false;

  ProgressTrackingService({
    required DatabaseService databaseService,
    required AuthenticationService authenticationService,
    required AnalyticsService analyticsService,
  })  : _databaseService = databaseService,
        _authenticationService = authenticationService,
        _analyticsService = analyticsService;

  // Getters
  bool get isInitialized => _isInitialized;
  Map<String, ReadingProgress> get currentProgress => Map.unmodifiable(_currentProgress);

  /// Initialize the progress tracking service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadCurrentProgress();
      _isInitialized = true;
      
      // Listen to authentication changes
      _authenticationService.addListener(_onAuthenticationChanged);
      
      debugPrint('Progress tracking service initialized');
    } catch (e) {
      debugPrint('Error initializing progress tracking service: $e');
    }
  }

  /// Dispose the service
  @override
  void dispose() {
    _authenticationService.removeListener(_onAuthenticationChanged);
    super.dispose();
  }

  /// Start reading a content item
  Future<ReadingProgress> startReading(Content content) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final sessionContext = _authenticationService.getSessionContext();
      final deviceId = sessionContext['deviceId'] as String?;
      final studentId = sessionContext['studentId'] as String?;

      // Check if there's existing progress for this content and session
      ReadingProgress? existingProgress = await getProgressForContent(
        content.id,
        deviceId: deviceId,
        studentId: studentId,
      );

      if (existingProgress == null) {
        // Create new progress
        existingProgress = ReadingProgress(
          id: _generateProgressId(),
          contentId: content.id,
          deviceId: deviceId,
          studentId: studentId,
          currentPage: 0,
          totalPages: _calculateTotalPages(content),
          timeSpent: 0,
          lastRead: DateTime.now(),
          completed: false,
        );

        await _saveProgress(existingProgress);
      } else {
        // Update last read time
        existingProgress = existingProgress.copyWith(lastRead: DateTime.now());
        await _saveProgress(existingProgress);
      }

      _currentProgress[content.id] = existingProgress;
      _sessionStartTimes[content.id] = DateTime.now();

      // Track analytics
      await _analyticsService.trackContentStart(
        content.id,
        metadata: {
          'title': content.title,
          'category': content.category,
          'ageGroup': content.ageGroup,
          'currentPage': existingProgress.currentPage,
          'totalPages': existingProgress.totalPages,
          'previousTimeSpent': existingProgress.timeSpent,
        },
      );

      notifyListeners();
      return existingProgress;
    } catch (e) {
      debugPrint('Error starting reading: $e');
      rethrow;
    }
  }

  /// Update reading progress
  Future<ReadingProgress> updateProgress({
    required String contentId,
    int? currentPage,
    int? additionalTimeSpent,
    bool? completed,
  }) async {
    try {
      final existingProgress = _currentProgress[contentId];
      if (existingProgress == null) {
        throw StateError('No active reading session for content $contentId');
      }

      final sessionStartTime = _sessionStartTimes[contentId];
      final sessionTimeSpent = sessionStartTime != null
          ? DateTime.now().difference(sessionStartTime).inSeconds
          : 0;

      final updatedProgress = existingProgress.copyWith(
        currentPage: currentPage ?? existingProgress.currentPage,
        timeSpent: existingProgress.timeSpent + (additionalTimeSpent ?? sessionTimeSpent),
        lastRead: DateTime.now(),
        completed: completed ?? existingProgress.completed,
      );

      await _saveProgress(updatedProgress);
      _currentProgress[contentId] = updatedProgress;

      // Track page completion if page changed
      if (currentPage != null && currentPage != existingProgress.currentPage) {
        await _analyticsService.trackPageComplete(
          contentId,
          existingProgress.currentPage,
          metadata: {
            'timeSpentOnPage': sessionTimeSpent,
            'newPage': currentPage,
            'readingSpeed': _calculateReadingSpeed(sessionTimeSpent),
            'pageEngagement': _calculatePageEngagement(sessionTimeSpent),
          },
        );

        await _analyticsService.trackPageView(
          contentId,
          currentPage,
          metadata: {
            'totalPages': updatedProgress.totalPages,
            'progressPercentage': updatedProgress.progressPercentage * 100,
            'readingStreak': await _calculateReadingStreak(),
          },
        );
      }

      // Track completion if content is completed
      if (completed == true && !existingProgress.completed) {
        await _analyticsService.trackContentComplete(
          contentId,
          metadata: {
            'totalTimeSpent': updatedProgress.timeSpent,
            'totalPages': updatedProgress.totalPages,
            'completionDate': DateTime.now().toIso8601String(),
            'averageTimePerPage': updatedProgress.totalPages > 0 
                ? (updatedProgress.timeSpent / updatedProgress.totalPages).round()
                : 0,
            'readingEfficiency': _calculateReadingEfficiency(updatedProgress),
          },
        );
      }

      notifyListeners();
      return updatedProgress;
    } catch (e) {
      debugPrint('Error updating progress: $e');
      rethrow;
    }
  }

  /// Calculate reading speed in words per minute (estimated)
  double _calculateReadingSpeed(int timeSpentSeconds) {
    if (timeSpentSeconds == 0) return 0.0;
    // Estimate 150 words per page for children's books
    const estimatedWordsPerPage = 150;
    final wordsPerMinute = (estimatedWordsPerPage / (timeSpentSeconds / 60.0));
    return wordsPerMinute.clamp(0.0, 500.0); // Reasonable bounds
  }

  /// Calculate page engagement quality
  String _calculatePageEngagement(int timeSpentSeconds) {
    if (timeSpentSeconds < 5) return 'skipped';
    if (timeSpentSeconds < 15) return 'quick';
    if (timeSpentSeconds < 45) return 'normal';
    if (timeSpentSeconds < 120) return 'engaged';
    return 'deep';
  }

  /// Calculate reading streak (days)
  Future<int> _calculateReadingStreak() async {
    try {
      // This would need to be implemented in the database service
      // For now, return a placeholder
      return 1;
    } catch (e) {
      debugPrint('Error calculating reading streak: $e');
      return 0;
    }
  }

  /// Calculate reading efficiency score
  double _calculateReadingEfficiency(ReadingProgress progress) {
    if (progress.totalPages == 0 || progress.timeSpent == 0) return 0.0;
    
    final averageTimePerPage = progress.timeSpent / progress.totalPages;
    final completionRate = progress.progressPercentage;
    
    // Efficiency score based on completion rate and reasonable reading pace
    // Optimal reading time: 30-60 seconds per page for children
    final paceScore = averageTimePerPage >= 30 && averageTimePerPage <= 60 ? 1.0 : 0.7;
    final efficiencyScore = (completionRate * paceScore * 100).clamp(0.0, 100.0);
    
    return efficiencyScore;
  }

  /// Finish reading session
  Future<ReadingProgress> finishReading(String contentId, {bool markCompleted = false}) async {
    try {
      final sessionStartTime = _sessionStartTimes[contentId];
      final sessionTimeSpent = sessionStartTime != null
          ? DateTime.now().difference(sessionStartTime).inSeconds
          : 0;

      final updatedProgress = await updateProgress(
        contentId: contentId,
        additionalTimeSpent: sessionTimeSpent,
        completed: markCompleted,
      );

      // Clean up session data
      _sessionStartTimes.remove(contentId);

      return updatedProgress;
    } catch (e) {
      debugPrint('Error finishing reading: $e');
      rethrow;
    }
  }

  /// Get progress for a specific content item and session
  Future<ReadingProgress?> getProgressForContent(
    String contentId, {
    String? deviceId,
    String? studentId,
  }) async {
    try {
      // Use current session if not specified
      if (deviceId == null && studentId == null) {
        final sessionContext = _authenticationService.getSessionContext();
        deviceId = sessionContext['deviceId'] as String?;
        studentId = sessionContext['studentId'] as String?;
      }

      final progressData = await _databaseService.getProgressWithAttribution(
        contentId: contentId,
        deviceId: deviceId ?? '',
        studentId: studentId,
      );

      if (progressData != null) {
        return ReadingProgress.fromMap(progressData);
      }

      return null;
    } catch (e) {
      debugPrint('Error getting progress for content: $e');
      return null;
    }
  }

  /// Get all progress for current session
  Future<List<ReadingProgress>> getCurrentSessionProgress() async {
    try {
      final sessionContext = _authenticationService.getSessionContext();
      final deviceId = sessionContext['deviceId'] as String?;
      final studentId = sessionContext['studentId'] as String?;

      return await getAllProgressForSession(deviceId: deviceId, studentId: studentId);
    } catch (e) {
      debugPrint('Error getting current session progress: $e');
      return [];
    }
  }

  /// Get all progress for a specific session
  Future<List<ReadingProgress>> getAllProgressForSession({
    String? deviceId,
    String? studentId,
  }) async {
    try {
      // This would need to be implemented in the database service
      // For now, return empty list
      // TODO: Implement database query for session-specific progress
      return [];
    } catch (e) {
      debugPrint('Error getting session progress: $e');
      return [];
    }
  }

  /// Get reading statistics for current session
  Future<Map<String, dynamic>> getReadingStats() async {
    try {
      final sessionProgress = await getCurrentSessionProgress();
      
      final totalTimeSpent = sessionProgress.fold<int>(
        0,
        (sum, progress) => sum + progress.timeSpent,
      );
      
      final completedCount = sessionProgress.where((p) => p.completed).length;
      final inProgressCount = sessionProgress.where((p) => !p.completed && p.currentPage > 0).length;
      
      return {
        'totalContent': sessionProgress.length,
        'completedContent': completedCount,
        'inProgressContent': inProgressCount,
        'totalTimeSpent': totalTimeSpent,
        'averageTimePerContent': sessionProgress.isNotEmpty 
            ? (totalTimeSpent / sessionProgress.length).round()
            : 0,
        'completionRate': sessionProgress.isNotEmpty
            ? (completedCount / sessionProgress.length * 100).round()
            : 0,
      };
    } catch (e) {
      debugPrint('Error getting reading stats: $e');
      return {};
    }
  }

  /// Switch to different session (when student logs in/out)
  Future<void> switchSession() async {
    try {
      // Save any active sessions
      for (final contentId in _sessionStartTimes.keys) {
        await finishReading(contentId);
      }

      // Clear current progress and reload for new session
      _currentProgress.clear();
      _sessionStartTimes.clear();
      
      await _loadCurrentProgress();
      notifyListeners();
    } catch (e) {
      debugPrint('Error switching session: $e');
    }
  }

  /// Private methods

  Future<void> _loadCurrentProgress() async {
    try {
      final sessionProgress = await getCurrentSessionProgress();
      _currentProgress = {
        for (final progress in sessionProgress)
          progress.contentId: progress
      };
    } catch (e) {
      debugPrint('Error loading current progress: $e');
    }
  }

  Future<void> _saveProgress(ReadingProgress progress) async {
    try {
      await _databaseService.saveProgressWithAttribution(
        contentId: progress.contentId,
        deviceId: progress.deviceId ?? '',
        studentId: progress.studentId,
        progress: progress.currentPage,
        points: _calculatePoints(progress),
        completedAt: progress.completed ? DateTime.now() : null,
        quizScores: [], // TODO: Implement quiz scores tracking
      );
    } catch (e) {
      debugPrint('Error saving progress: $e');
      rethrow;
    }
  }

  void _onAuthenticationChanged() {
    // When authentication changes, switch to the new session
    switchSession();
  }

  String _generateProgressId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(8)}';
  }

  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(length, (index) => chars[DateTime.now().millisecondsSinceEpoch % chars.length]).join();
  }

  int _calculateTotalPages(Content content) {
    // This is a simple estimation - in a real app, you'd parse the content
    // to determine actual page count
    final contentLength = content.htmlContent.length;
    const averageWordsPerPage = 200;
    const averageCharsPerWord = 5;
    
    final estimatedPages = (contentLength / (averageWordsPerPage * averageCharsPerWord)).ceil();
    return estimatedPages.clamp(1, 100); // Reasonable bounds
  }

  int _calculatePoints(ReadingProgress progress) {
    // Simple points calculation based on progress and time spent
    final progressPoints = (progress.progressPercentage * 100).round();
    final timeBonus = (progress.timeSpent / 60).round(); // 1 point per minute
    final completionBonus = progress.completed ? 50 : 0;
    
    return progressPoints + timeBonus + completionBonus;
  }
}