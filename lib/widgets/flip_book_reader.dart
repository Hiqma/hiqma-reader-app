import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:confetti/confetti.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../models/vocabulary_word.dart';
import '../models/reading_progress.dart';
import '../models/quiz_question.dart';
import '../screens/comprehension_quiz_screen.dart';
import 'vocabulary_modal.dart';
import 'dart:io';

class FlipBookReader extends StatefulWidget {
  final String contentId;
  final List<String> pages;
  final VoidCallback onComplete;
  final Function(double) onReadingProgress;

  const FlipBookReader({
    super.key,
    required this.contentId,
    required this.pages,
    required this.onComplete,
    required this.onReadingProgress,
  });

  @override
  State<FlipBookReader> createState() => _FlipBookReaderState();
}

class _FlipBookReaderState extends State<FlipBookReader> {
  PageController? _pageController;
  final ConfettiController _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  
  int _currentPage = 0;
  double _fontSize = 22.0; // Larger default font size for children
  bool _showControls = false;
  List<VocabularyWord> _vocabularyWords = [];
  bool _isInitialized = false;
  
  // Progress tracking
  DateTime? _pageStartTime;
  Map<int, int> _pageTimeSpent = {}; // page index -> seconds spent
  String? _contentId;
  
  // Image preloading
  final Set<String> _preloadedImages = {};

  @override
  void initState() {
    super.initState();
    _contentId = widget.contentId;
    _initializePageController();
    _loadVocabulary();
    _startPageTimer();
    _preloadImages();
  }

  Future<void> _initializePageController() async {
    int initialPage = 0;
    
    if (_contentId != null) {
      try {
        final progress = await DatabaseService.instance.getReadingProgress(_contentId!);
        // Ensure we start from page 0 (first page) if no progress exists
        initialPage = progress?.currentPage ?? 0;
      } catch (e) {
        // If there's an error loading progress, start from page 0
        initialPage = 0;
      }
    }
    
    if (mounted) {
      setState(() {
        _currentPage = initialPage;
        _pageController = PageController(initialPage: initialPage);
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _recordPageTime(); // Record time for the current page before disposing
    _pageController?.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadVocabulary() async {
    final words = await DatabaseService.instance.getVocabulary();
    setState(() {
      _vocabularyWords = words;
    });
  }



  void _startPageTimer() {
    _pageStartTime = DateTime.now();
  }

  void _recordPageTime() {
    if (_pageStartTime != null) {
      final timeSpent = DateTime.now().difference(_pageStartTime!).inSeconds;
      _pageTimeSpent[_currentPage] = (_pageTimeSpent[_currentPage] ?? 0) + timeSpent;
      
      // Log detailed activity for analytics
      if (_contentId != null) {
        DatabaseService.instance.logActivity(
          contentId: _contentId!,
          action: 'page_read',
          timeSpent: timeSpent,
        );
        
        // Track reading engagement quality
        final engagementQuality = _calculateEngagementQuality(timeSpent);
        if (engagementQuality != null) {
          DatabaseService.instance.logActivity(
            contentId: _contentId!,
            action: 'engagement_quality',
            timeSpent: 0,
          );
        }
      }
    }
  }
  
  String? _calculateEngagementQuality(int timeSpent) {
    // Estimate reading time based on content length
    // Average reading speed for children: 100-200 words per minute
    // This is a simple heuristic - can be improved with actual word count
    if (timeSpent < 5) return 'skipped';
    if (timeSpent < 15) return 'quick_read';
    if (timeSpent < 60) return 'normal_read';
    if (timeSpent < 180) return 'engaged_read';
    return 'deep_read';
  }

  void _nextPage() {
    if (_pageController == null) return;
    
    _recordPageTime(); // Record time spent on current page
    
    if (_currentPage < widget.pages.length - 1) {
      final newPage = _currentPage + 1;
      _pageController!.animateToPage(
        newPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _updateProgress(newPage);
    } else {
      _completeReading();
    }
    
    _startPageTimer(); // Start timer for new page
  }

  void _prevPage() {
    if (_pageController == null) return;
    
    _recordPageTime(); // Record time spent on current page
    
    if (_currentPage > 0) {
      final newPage = _currentPage - 1;
      _pageController!.animateToPage(
        newPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _updateProgress(newPage);
    }
    
    _startPageTimer(); // Start timer for new page
  }

  void _updateProgress(int page) {
    setState(() {
      _currentPage = page;
    });
    final progress = (page / widget.pages.length) * 100;
    widget.onReadingProgress(progress);
    
    // Save reading progress to database
    _saveReadingProgress(page);
    
    // Preload next pages
    _preloadImages(startPage: page + 1);
  }

  Future<void> _saveReadingProgress(int currentPage) async {
    if (_contentId == null) return;
    
    final totalTimeSpent = _pageTimeSpent.values.fold(0, (sum, time) => sum + time);
    final isCompleted = currentPage >= widget.pages.length - 1;
    
    final readingProgress = ReadingProgress(
      id: '${_contentId}_progress',
      contentId: _contentId!,
      currentPage: currentPage, // This should be 0-based index
      totalPages: widget.pages.length,
      timeSpent: totalTimeSpent,
      lastRead: DateTime.now(),
      completed: isCompleted,
    );
    
    await DatabaseService.instance.updateReadingProgress(readingProgress);
  }

  void _completeReading() {
    _confettiController.play();
    Future.delayed(const Duration(seconds: 3), () {
      // Check if content has comprehension questions
      _checkForComprehensionQuestions();
    });
  }

  Future<void> _checkForComprehensionQuestions() async {
    try {
      // Get content details to check for comprehension questions
      final content = await DatabaseService.instance.getContent(_contentId!);
      
      if (content == null) {
        widget.onComplete();
        return;
      }
      
      if (content.comprehensionQuestions.isNotEmpty) {
        // Show comprehension questions
        if (mounted) {
          _showComprehensionQuestions(content.comprehensionQuestions);
        } else {
          widget.onComplete();
        }
      } else {
        // No questions, proceed with normal completion
        widget.onComplete();
      }
    } catch (e) {
      // Fallback to normal completion
      widget.onComplete();
    }
  }

  void _showComprehensionQuestions(List<QuizQuestion> questions) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ComprehensionQuizScreen(
          contentId: _contentId!,
          questions: questions,
          onComplete: (score, answers) {
            // Save quiz results and complete reading
            _saveQuizResults(score, answers);
            widget.onComplete();
          },
        ),
      ),
    );
  }

  Future<void> _saveQuizResults(int score, Map<String, dynamic> answers) async {
    try {
      if (_contentId != null) {
        // Log quiz completion analytics
        await DatabaseService.instance.logActivity(
          contentId: _contentId!,
          action: 'quiz_completed',
          timeSpent: 0,
        );

        // Save detailed quiz results
        await DatabaseService.instance.saveQuizResults(
          contentId: _contentId!,
          score: score,
          answers: answers,
          completedAt: DateTime.now(),
        );

        debugPrint('Quiz results saved: $score% score');
      }
    } catch (e) {
      debugPrint('Error saving quiz results: $e');
    }
  }

  void _adjustFontSize(double delta) {
    setState(() {
      _fontSize = (_fontSize + delta).clamp(18.0, 32.0); // Larger range for children
    });
  }

  void _showVocabularyModal() {
    showDialog(
      context: context,
      builder: (context) => VocabularyModal(
        vocabularyWords: _vocabularyWords,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  void _preloadImages({int? startPage}) {
    final start = startPage ?? _currentPage;
    // Preload 5 pages ahead for smoother experience
    final end = (start + 5).clamp(0, widget.pages.length - 1);
    
    for (int i = start; i <= end; i++) {
      _extractAndPreloadImages(widget.pages[i]);
    }
    
    // Also preload previous page for backward navigation
    if (start > 0) {
      _extractAndPreloadImages(widget.pages[start - 1]);
    }
  }

  void _extractAndPreloadImages(String htmlContent) {
    final imgRegex = RegExp(r'src="([^"]*)"');
    final matches = imgRegex.allMatches(htmlContent);
    
    for (final match in matches) {
      final src = match.group(1);
      if (src != null && !_preloadedImages.contains(src)) {
        _preloadedImages.add(src);
        
        // Preload with error handling to prevent crashes
        try {
          if (src.startsWith('http')) {
            precacheImage(
              NetworkImage(src),
              context,
              onError: (exception, stackTrace) {
                debugPrint('Failed to preload network image: $src - $exception');
              },
            );
          } else {
            final file = File(src);
            if (file.existsSync()) {
              precacheImage(
                FileImage(file),
                context,
                onError: (exception, stackTrace) {
                  debugPrint('Failed to preload file image: $src - $exception');
                },
              );
            }
          }
        } catch (e) {
          debugPrint('Error preloading image $src: $e');
        }
      }
    }
  }





  Widget _buildPage(String content, int index) {

    return Container(
      margin: const EdgeInsets.all(AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5), // Warmer, cream-colored background for easier reading
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08), // Softer shadow
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Use Html widget for better rendering
            Html(
              data: content,
              style: {
                "body": Style(
                  fontSize: FontSize(_fontSize),
                  lineHeight: const LineHeight(1.8), // More spacing for easier reading
                  color: AppTheme.textPrimary,
                  textAlign: TextAlign.center, // Center align to match dashboard
                  fontFamily: 'system-ui', // Use system font for better readability
                  letterSpacing: 0.5, // Slight letter spacing for clarity
                ),
                "h1": Style(
                  fontSize: FontSize(_fontSize * 1.6), // Slightly smaller ratio for better proportion
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                  margin: Margins.only(bottom: 20, top: 16),
                  lineHeight: const LineHeight(1.4),
                ),
                "h2": Style(
                  fontSize: FontSize(_fontSize * 1.3), // Better proportion
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                  margin: Margins.only(bottom: 16, top: 12),
                  lineHeight: const LineHeight(1.4),
                ),
                "h3": Style(
                  fontSize: FontSize(_fontSize * 1.1),
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  margin: Margins.only(bottom: 12, top: 8),
                ),
                "p": Style(
                  fontSize: FontSize(_fontSize),
                  lineHeight: const LineHeight(1.8),
                  margin: Margins.only(bottom: 20), // More space between paragraphs
                  textAlign: TextAlign.center,
                ),
                "strong": Style(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
                "em": Style(
                  fontStyle: FontStyle.italic,
                  color: AppTheme.textSecondary,
                ),
                "ul": Style(
                  margin: Margins.only(bottom: 16, left: 20),
                ),
                "ol": Style(
                  margin: Margins.only(bottom: 16, left: 20),
                ),
                "li": Style(
                  fontSize: FontSize(_fontSize),
                  lineHeight: const LineHeight(1.8),
                  margin: Margins.only(bottom: 8),
                ),
              },

            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state while initializing
    if (!_isInitialized || _pageController == null) {
      return Scaffold(
        backgroundColor: AppTheme.surface,
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              // Page content
              Expanded(
                child: PageView.builder(
                  controller: _pageController!,
                  onPageChanged: _updateProgress,
                  itemCount: widget.pages.length,
                  itemBuilder: (context, index) => _buildPage(widget.pages[index], index),
                ),
              ),
              
              // Controls
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  border: Border(
                    top: BorderSide(color: AppTheme.border, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    // Previous button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _currentPage > 0 ? _prevPage : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                          ),
                        ),
                        child: const Text('← Previous'),
                      ),
                    ),
                    
                    const SizedBox(width: AppTheme.spacingMd),
                    
                    // Page indicator
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Text(
                            'Page ${_currentPage + 1} of ${widget.pages.length}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingXs),
                          LinearProgressIndicator(
                            value: (_currentPage + 1) / widget.pages.length,
                            backgroundColor: AppTheme.border,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: AppTheme.spacingMd),
                    
                    // Next/Finish button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                          ),
                        ),
                        child: Text(
                          _currentPage == widget.pages.length - 1 ? 'Finish 🎉' : 'Next →',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Controls toggle button
          Positioned(
            top: 50,
            right: 20,
            child: FloatingActionButton.small(
              onPressed: () => setState(() => _showControls = !_showControls),
              backgroundColor: Colors.black.withOpacity(0.7),
              child: const Icon(Icons.settings, color: Colors.white),
            ),
          ),
          
          // Controls panel
          if (_showControls)
            Positioned(
              top: 100,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spacingSm),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildControlButton(
                      icon: Icons.text_decrease,
                      label: 'Smaller',
                      onPressed: () => _adjustFontSize(-2),
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    _buildControlButton(
                      icon: Icons.text_increase,
                      label: 'Bigger',
                      onPressed: () => _adjustFontSize(2),
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    _buildControlButton(
                      icon: Icons.book,
                      label: 'My Words',
                      onPressed: _showVocabularyModal,
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    _buildControlButton(
                      icon: Icons.close,
                      label: 'Close',
                      onPressed: () => setState(() => _showControls = false),
                    ),
                  ],
                ),
              ),
            ),
          
          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 1.57, // radians - 90 degrees
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.05,
              shouldLoop: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 80,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.2),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}