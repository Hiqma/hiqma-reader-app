import 'package:flutter/foundation.dart';
import '../models/content.dart';
import '../models/quiz_question.dart';
import 'analytics_service.dart';
import 'progress_tracking_service.dart';
import 'authentication_service.dart';

/// Service to integrate analytics tracking throughout the app
class AnalyticsIntegrationService {
  final AnalyticsService _analyticsService;
  final ProgressTrackingService _progressTrackingService;
  final AuthenticationService _authenticationService;

  AnalyticsIntegrationService({
    required AnalyticsService analyticsService,
    required ProgressTrackingService progressTrackingService,
    required AuthenticationService authenticationService,
  })  : _analyticsService = analyticsService,
        _progressTrackingService = progressTrackingService,
        _authenticationService = authenticationService;

  /// Initialize analytics integration
  Future<void> initialize() async {
    try {
      await _analyticsService.initialize();
      await _analyticsService.trackAppLaunch();
      debugPrint('Analytics integration initialized');
    } catch (e) {
      debugPrint('Error initializing analytics integration: $e');
    }
  }

  /// Track app lifecycle events
  Future<void> trackAppPaused() async {
    await _analyticsService.trackEvent(
      contentId: 'app',
      eventType: AnalyticsEventType.sessionEnd,
      eventData: {'reason': 'app_paused'},
    );
  }

  Future<void> trackAppResumed() async {
    await _analyticsService.trackEvent(
      contentId: 'app',
      eventType: AnalyticsEventType.sessionStart,
      eventData: {'reason': 'app_resumed'},
    );
  }

  Future<void> trackAppClosed() async {
    await _analyticsService.trackAppClose();
  }

  /// Track navigation events
  Future<void> trackScreenView(String screenName, {Map<String, dynamic>? metadata}) async {
    await _analyticsService.trackEvent(
      contentId: 'navigation',
      eventType: AnalyticsEventType.contentView,
      eventData: {
        'screenName': screenName,
        'timestamp': DateTime.now().toIso8601String(),
        ...?metadata,
      },
    );
  }

  /// Track content interaction events
  Future<void> trackContentOpened(Content content) async {
    await _analyticsService.trackContentView(
      content.id,
      metadata: {
        'title': content.title,
        'category': content.category,
        'ageGroup': content.ageGroup,
        'language': content.language,
        'authorId': content.authorId,
        'contentLength': content.htmlContent.length,
        'hasQuestions': content.comprehensionQuestions.isNotEmpty,
        'questionCount': content.comprehensionQuestions.length,
      },
    );
  }

  Future<void> trackContentStarted(Content content) async {
    await _progressTrackingService.startReading(content);
    // Analytics tracking is handled by the progress tracking service
  }

  Future<void> trackPageTurn(String contentId, int fromPage, int toPage, int timeOnPage) async {
    // Track page completion
    await _analyticsService.trackPageComplete(
      contentId,
      fromPage,
      metadata: {
        'timeSpent': timeOnPage,
        'nextPage': toPage,
      },
    );

    // Track new page view
    await _analyticsService.trackPageView(
      contentId,
      toPage,
      metadata: {
        'previousPage': fromPage,
        'navigationDirection': toPage > fromPage ? 'forward' : 'backward',
      },
    );

    // Update progress
    await _progressTrackingService.updateProgress(
      contentId: contentId,
      currentPage: toPage,
      additionalTimeSpent: timeOnPage,
    );
  }

  Future<void> trackContentCompleted(Content content, int totalTimeSpent) async {
    await _progressTrackingService.finishReading(content.id, markCompleted: true);
    // Analytics tracking is handled by the progress tracking service
  }

  /// Track quiz interactions
  Future<void> trackQuizStarted(Content content) async {
    await _analyticsService.trackQuizStart(
      content.id,
      metadata: {
        'title': content.title,
        'questionCount': content.comprehensionQuestions.length,
        'quizType': 'comprehension',
      },
    );
  }

  Future<void> trackQuizAnswered({
    required String contentId,
    required int questionIndex,
    required QuizQuestion question,
    required String selectedAnswer,
    required bool isCorrect,
    required int timeSpent,
  }) async {
    await _analyticsService.trackQuizAnswer(
      contentId,
      questionIndex,
      isCorrect,
      metadata: {
        'question': question.question,
        'selectedAnswer': selectedAnswer,
        'correctAnswer': question.correctAnswer,
        'timeSpent': timeSpent,
      },
    );
  }

  Future<void> trackQuizCompleted({
    required Content content,
    required int score,
    required int totalQuestions,
    required int totalTimeSpent,
    required List<bool> answers,
  }) async {
    final correctAnswers = answers.where((answer) => answer).length;
    final accuracy = totalQuestions > 0 ? (correctAnswers / totalQuestions * 100).round() : 0;

    await _analyticsService.trackQuizComplete(
      content.id,
      score,
      totalQuestions,
      metadata: {
        'title': content.title,
        'accuracy': accuracy,
        'totalTimeSpent': totalTimeSpent,
        'averageTimePerQuestion': totalQuestions > 0 ? (totalTimeSpent / totalQuestions).round() : 0,
        'answers': answers,
        'category': content.category,
        'ageGroup': content.ageGroup,
      },
    );
  }

  /// Track vocabulary interactions
  Future<void> trackVocabularyLookup({
    required String contentId,
    required String word,
    required String definition,
    String? category,
  }) async {
    await _analyticsService.trackVocabularyLookup(
      contentId,
      word,
      metadata: {
        'definition': definition,
        'category': category,
        'wordLength': word.length,
        'lookupTime': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> trackVocabularyAdded({
    required String contentId,
    required String word,
    required String definition,
  }) async {
    await _analyticsService.trackEvent(
      contentId: contentId,
      eventType: AnalyticsEventType.bookmarkAdd,
      eventData: {
        'type': 'vocabulary',
        'word': word,
        'definition': definition,
        'addedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Track authentication events
  Future<void> trackDeviceRegistrationAttempt(String deviceCode) async {
    await _analyticsService.trackEvent(
      contentId: 'device_registration',
      eventType: AnalyticsEventType.deviceRegistration,
      eventData: {
        'deviceCode': deviceCode,
        'attempt': true,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> trackDeviceRegistrationResult(String deviceCode, bool success, {String? errorMessage}) async {
    await _analyticsService.trackDeviceRegistration(deviceCode, success, errorMessage: errorMessage);
  }

  Future<void> trackStudentLoginAttempt(String studentCode) async {
    await _analyticsService.trackEvent(
      contentId: 'student_login',
      eventType: AnalyticsEventType.studentLogin,
      eventData: {
        'studentCode': studentCode,
        'attempt': true,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> trackStudentLoginResult(String studentCode, bool success, {String? errorMessage}) async {
    await _analyticsService.trackStudentLogin(studentCode, success, errorMessage: errorMessage);
  }

  Future<void> trackStudentLogout() async {
    await _analyticsService.trackStudentLogout();
  }

  Future<void> trackStudentSwitch(String fromStudentCode, String toStudentCode) async {
    await _analyticsService.trackEvent(
      contentId: 'student_switch',
      eventType: AnalyticsEventType.studentLogin,
      eventData: {
        'fromStudentCode': fromStudentCode,
        'toStudentCode': toStudentCode,
        'switchTime': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Track sync events
  Future<void> trackSyncStarted() async {
    await _analyticsService.trackSyncStart();
  }

  Future<void> trackSyncCompleted(bool success, int itemsSynced, {String? errorMessage}) async {
    await _analyticsService.trackSyncComplete(success, itemsSynced, errorMessage: errorMessage);
  }

  /// Track user engagement patterns
  Future<void> trackUserEngagement({
    required String contentId,
    required int sessionDuration,
    required int pagesViewed,
    required int interactionCount,
    bool completedContent = false,
  }) async {
    await _analyticsService.trackEvent(
      contentId: contentId,
      eventType: AnalyticsEventType.sessionEnd,
      timeSpent: sessionDuration,
      moduleCompleted: completedContent,
      eventData: {
        'pagesViewed': pagesViewed,
        'interactionCount': interactionCount,
        'engagementRate': pagesViewed > 0 ? (interactionCount / pagesViewed).toStringAsFixed(2) : '0',
        'averageTimePerPage': pagesViewed > 0 ? (sessionDuration / pagesViewed).round() : 0,
        'completedContent': completedContent,
      },
    );
  }

  /// Track errors and issues
  Future<void> trackError({
    required String contentId,
    required String errorType,
    required String errorMessage,
    String? stackTrace,
    Map<String, dynamic>? additionalData,
  }) async {
    await _analyticsService.trackError(
      contentId,
      errorType,
      errorMessage,
      metadata: {
        'stackTrace': stackTrace,
        'timestamp': DateTime.now().toIso8601String(),
        'sessionContext': _authenticationService.getSessionContext(),
        ...?additionalData,
      },
    );
  }

  /// Track performance metrics
  Future<void> trackPerformanceMetric({
    required String metricName,
    required double value,
    String? contentId,
    Map<String, dynamic>? metadata,
  }) async {
    await _analyticsService.trackEvent(
      contentId: contentId ?? 'performance',
      eventType: AnalyticsEventType.contentView,
      eventData: {
        'metricType': 'performance',
        'metricName': metricName,
        'value': value,
        'timestamp': DateTime.now().toIso8601String(),
        ...?metadata,
      },
    );
  }

  /// Get analytics summary for current session
  Future<Map<String, dynamic>> getSessionAnalyticsSummary() async {
    try {
      final analyticsStats = await _analyticsService.getAnalyticsStats();
      final readingStats = await _progressTrackingService.getReadingStats();
      
      return {
        'analytics': analyticsStats,
        'reading': readingStats,
        'sessionContext': _authenticationService.getSessionContext(),
        'generatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getting session analytics summary: $e');
      return {};
    }
  }

  /// Sync analytics to hub
  Future<bool> syncAnalytics() async {
    try {
      await trackSyncStarted();
      
      // Get count of events before sync
      final unsyncedEventsBefore = await _analyticsService.getUnsyncedEvents();
      final eventCountBefore = unsyncedEventsBefore.length;
      
      final success = await _analyticsService.syncAnalyticsToHub();
      
      if (success) {
        await trackSyncCompleted(true, eventCountBefore);
      } else {
        await trackSyncCompleted(false, 0, errorMessage: 'Sync failed - events remain queued');
      }
      
      return success;
    } catch (e) {
      await trackSyncCompleted(false, 0, errorMessage: e.toString());
      return false;
    }
  }

  /// Batch sync analytics with retry logic
  Future<Map<String, dynamic>> batchSyncAnalytics({
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 5),
  }) async {
    int attempts = 0;
    List<String> errors = [];
    
    while (attempts < maxRetries) {
      attempts++;
      
      try {
        final unsyncedEvents = await _analyticsService.getUnsyncedEvents();
        if (unsyncedEvents.isEmpty) {
          return {
            'success': true,
            'message': 'No events to sync',
            'attempts': attempts,
            'eventsSynced': 0,
          };
        }

        await trackSyncStarted();
        final success = await _analyticsService.syncAnalyticsToHub();
        
        if (success) {
          await trackSyncCompleted(true, unsyncedEvents.length);
          return {
            'success': true,
            'message': 'Sync completed successfully',
            'attempts': attempts,
            'eventsSynced': unsyncedEvents.length,
          };
        } else {
          errors.add('Attempt $attempts: Sync failed');
          if (attempts < maxRetries) {
            await Future.delayed(retryDelay);
          }
        }
      } catch (e) {
        errors.add('Attempt $attempts: ${e.toString()}');
        if (attempts < maxRetries) {
          await Future.delayed(retryDelay);
        }
      }
    }

    await trackSyncCompleted(false, 0, errorMessage: 'Max retries exceeded: ${errors.join(', ')}');
    return {
      'success': false,
      'message': 'Sync failed after $maxRetries attempts',
      'attempts': attempts,
      'errors': errors,
      'eventsSynced': 0,
    };
  }
}