import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/content.dart';
import '../services/database_service.dart';
import '../services/analytics_service.dart';
import '../services/authentication_service.dart';
import '../services/hub_discovery_service.dart';
import '../widgets/flip_book_reader.dart';
import '../widgets/interactive_quiz.dart';
import '../widgets/quiz_results.dart';

class ContentScreen extends StatefulWidget {
  final String contentId;
  final String title;

  const ContentScreen({
    super.key,
    required this.contentId,
    required this.title,
  });

  @override
  State<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends State<ContentScreen> {
  Content? _content;
  String _currentView = 'reading'; // 'reading', 'quiz', 'results'
  int _quizScore = 0;
  Map<String, dynamic> _quizAnswers = {};
  double _readingProgress = 0;
  bool _isLoading = true;
  
  // Analytics services
  late AnalyticsService _analyticsService;
  String? _sessionId;
  DateTime? _readingStartTime;

  @override
  void initState() {
    super.initState();
    debugPrint('=== CONTENT SCREEN INIT STATE ===');
    debugPrint('Content ID: ${widget.contentId}');
    debugPrint('Title: ${widget.title}');
    debugPrint('Calling _initializeAnalytics()...');
    _initializeAnalytics();
    debugPrint('Calling _loadContent()...');
    _loadContent();
    debugPrint('=== INIT STATE COMPLETE ===');
  }

  Future<void> _initializeAnalytics() async {
    try {
      debugPrint('=== INITIALIZING ANALYTICS IN CONTENT SCREEN ===');
      debugPrint('Content ID: ${widget.contentId}');
      debugPrint('Title: ${widget.title}');
      
      // Get the existing AuthenticationService from Provider
      debugPrint('Step 1: Getting AuthenticationService from Provider...');
      final authService = Provider.of<AuthenticationService>(context, listen: false);
      debugPrint('Step 1: AuthenticationService obtained ✓');
      
      // Check authentication state
      final sessionContext = authService.getSessionContext();
      debugPrint('📊 Current authentication state:');
      debugPrint('  Device ID: ${sessionContext['deviceId']}');
      debugPrint('  Student ID: ${sessionContext['studentId']}');
      debugPrint('  Student Code: ${sessionContext['studentCode']}');
      debugPrint('  Is Authenticated: ${sessionContext['isAuthenticated']}');
      
      // Initialize analytics service with the existing auth service
      debugPrint('Step 2: Creating AnalyticsService with existing auth service...');
      _analyticsService = AnalyticsService(
        hubDiscoveryService: HubDiscoveryService(),
        databaseService: DatabaseService.instance,
        authenticationService: authService, // ✅ Use existing instance from Provider
      );
      debugPrint('Step 2: AnalyticsService created ✓');
      
      debugPrint('Step 3: Initializing analytics service...');
      await _analyticsService.initialize();
      debugPrint('Step 3: Analytics service initialized ✓');
      
      // Generate session ID and track content start
      debugPrint('Step 4: Generating session ID...');
      _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      _readingStartTime = DateTime.now();
      debugPrint('Step 4: Session ID: $_sessionId ✓');
      
      debugPrint('Step 5: Tracking content start...');
      await _analyticsService.trackContentStart(
        widget.contentId,
        metadata: {
          'title': widget.title,
          'startTime': _readingStartTime!.toIso8601String(),
        },
      );
      debugPrint('Step 5: Content start tracked ✓');
      
      debugPrint('=== ANALYTICS INITIALIZATION COMPLETE ===');
    } catch (e, stackTrace) {
      debugPrint('❌ ❌ ❌ ANALYTICS INITIALIZATION FAILED ❌ ❌ ❌');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('Session ID will remain null!');
    }
  }

  Future<void> _loadContent() async {
    try {
      final content = await DatabaseService.instance.getContent(widget.contentId);
      
      if (content == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Content not found')),
          );
          context.pop();
        }
        return;
      }

      // Load existing reading progress
      final existingProgress = await DatabaseService.instance.getReadingProgress(widget.contentId);
      if (existingProgress != null) {
        final progressPercentage = (existingProgress.currentPage / existingProgress.totalPages) * 100;
        setState(() {
          _readingProgress = progressPercentage;
        });
      }

      setState(() {
        _content = content;
        _isLoading = false;
      });
    } catch (error) {
      print('Failed to load content: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load content')),
        );
        context.pop();
      }
    }
  }

  void _handleReadingComplete() async {
    try {
      // Calculate reading time
      final timeSpent = _readingStartTime != null 
          ? DateTime.now().difference(_readingStartTime!).inSeconds
          : 0;

      // Track reading completion
      if (_sessionId != null) {
        await _analyticsService.trackEvent(
          contentId: widget.contentId,
          eventType: AnalyticsEventType.contentView,
          timeSpent: timeSpent,
          moduleCompleted: true, // Reading is complete (quiz was handled by FlipBookReader if present)
          eventData: {
            'title': widget.title,
            'readingCompleted': true,
            'readingTimeSpent': timeSpent,
            'hasQuiz': _content?.comprehensionQuestions.isNotEmpty == true,
          },
        );
      }
    } catch (e) {
      print('Failed to track reading completion: $e');
    }

    // FlipBookReader handles comprehension questions internally with ComprehensionQuizScreen
    // So we can directly complete the content here
    _handleContentComplete();
  }

  void _handleQuizComplete(int score, Map<String, dynamic> answers) {
    setState(() {
      _quizScore = score;
      _quizAnswers = answers;
      _currentView = 'results';
    });
    
    // Save progress to database
    _saveProgress(score);
  }

  Future<void> _handleContentComplete() async {
    try {
      // Calculate total time spent
      final timeSpent = _readingStartTime != null 
          ? DateTime.now().difference(_readingStartTime!).inSeconds
          : 0;

      // Save progress to database
      await DatabaseService.instance.saveProgress(
        StudentProgress(
          contentId: widget.contentId,
          progress: 100,
          points: _quizScore,
          completedAt: DateTime.now(),
          quizScores: _quizScore > 0 ? [_quizScore] : [],
        ),
      );

      // Track content completion with analytics
      if (_sessionId != null) {
        await _analyticsService.trackContentComplete(
          widget.contentId,
          metadata: {
            'title': widget.title,
            'finalScore': _quizScore,
            'completedAt': DateTime.now().toIso8601String(),
            'totalTimeSpent': timeSpent,
          },
        );
      }
      
      if (mounted) {
        context.pop();
      }
    } catch (error) {
      print('Failed to save progress: $error');
    }
  }

  Future<void> _saveProgress(int score) async {
    try {
      // Calculate total time spent
      final timeSpent = _readingStartTime != null 
          ? DateTime.now().difference(_readingStartTime!).inSeconds
          : 0;

      // Save progress to database
      await DatabaseService.instance.saveProgress(
        StudentProgress(
          contentId: widget.contentId,
          progress: 100,
          points: score,
          completedAt: DateTime.now(),
          quizScores: [score],
        ),
      );

      // Track content completion with analytics
      if (_sessionId != null) {
        await _analyticsService.trackContentComplete(
          widget.contentId,
          metadata: {
            'title': widget.title,
            'finalScore': score,
            'completedAt': DateTime.now().toIso8601String(),
            'totalTimeSpent': timeSpent,
          },
        );
      }
    } catch (error) {
      print('Failed to save progress: $error');
    }
  }

  void _handleRetryQuiz() {
    setState(() {
      _currentView = 'quiz';
      _quizAnswers = {};
    });
  }

  @override
  void dispose() {
    debugPrint('=== CONTENT SCREEN DISPOSE ===');
    debugPrint('Session ID: $_sessionId');
    debugPrint('Current view: $_currentView');
    
    // Track session end if user exits without completing
    if (_sessionId != null && _currentView != 'results') {
      final timeSpent = _readingStartTime != null 
          ? DateTime.now().difference(_readingStartTime!).inSeconds
          : 0;
      
      debugPrint('Tracking session end - Time spent: ${timeSpent}s');
      
      _analyticsService.trackEvent(
        contentId: widget.contentId,
        eventType: AnalyticsEventType.sessionEnd,
        timeSpent: timeSpent,
        moduleCompleted: false,
        eventData: {
          'title': widget.title,
          'exitedAt': _currentView,
          'sessionTimeSpent': timeSpent,
        },
      );
      
      debugPrint('Session end tracked');
    } else {
      debugPrint('Not tracking session end - sessionId: $_sessionId, currentView: $_currentView');
    }
    
    debugPrint('=== DISPOSE COMPLETE ===');
    super.dispose();
  }

  void _handleProgressUpdate(double progress) {
    setState(() {
      _readingProgress = progress;
    });
    
    // Save reading progress periodically
    if (progress % 25 == 0) { // Save every 25%
      DatabaseService.instance.saveProgress(
        StudentProgress(
          contentId: widget.contentId,
          progress: progress.round(),
          points: 0,
          quizScores: [],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF0FDF4), // Green 50 - Light green background
                Color(0xFFDCFCE7), // Green 100 - Light green variant
              ],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
        ),
      );
    }

    if (_content == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(widget.title),
          backgroundColor: AppTheme.background,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: Text(
            'Content not found',
            style: TextStyle(
              fontSize: 18,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _currentView == 'reading' ? AppBar(
        title: Text(_content!.title),
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // Share functionality can be implemented here
            },
          ),
        ],
      ) : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF0FDF4), // Green 50 - Light green background
              Color(0xFFDCFCE7), // Green 100 - Light green variant
            ],
          ),
        ),
        child: _buildCurrentView(),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case 'reading':
        return FlipBookReader(
          contentId: widget.contentId,
          pages: _content!.getPages(),
          onComplete: _handleReadingComplete,
          onReadingProgress: _handleProgressUpdate,
        );
      case 'quiz':
        return InteractiveQuiz(
          questions: _content!.comprehensionQuestions,
          onComplete: _handleQuizComplete,
        );
      case 'results':
        return QuizResults(
          score: _quizScore,
          questions: _content!.comprehensionQuestions,
          answers: _quizAnswers,
          onRetry: _handleRetryQuiz,
          onContinue: _handleContentComplete,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}