import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../theme/app_theme.dart';
import '../models/quiz_question.dart';
import '../services/enhanced_ai_scoring_service.dart';

class ComprehensionQuizScreen extends StatefulWidget {
  final String contentId;
  final List<QuizQuestion> questions;
  final Function(int score, Map<String, dynamic> answers) onComplete;

  const ComprehensionQuizScreen({
    super.key,
    required this.contentId,
    required this.questions,
    required this.onComplete,
  });

  @override
  State<ComprehensionQuizScreen> createState() => _ComprehensionQuizScreenState();
}

class _ComprehensionQuizScreenState extends State<ComprehensionQuizScreen>
    with TickerProviderStateMixin {
  int _currentQuestionIndex = 0;
  final Map<String, dynamic> _answers = {};
  final Map<String, bool> _questionCorrectness = {};
  bool _isProcessing = false;
  bool _showResults = false;
  int _finalScore = 0;
  
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late ConfettiController _confettiController;
  
  // Text input controller for open-ended questions
  final TextEditingController _textController = TextEditingController();

  QuizQuestion get _currentQuestion => widget.questions[_currentQuestionIndex];
  bool get _isLastQuestion => _currentQuestionIndex == widget.questions.length - 1;
  bool get _hasAnsweredCurrent => _answers.containsKey(_currentQuestion.id);
  bool get _isOpenEndedQuestion => _currentQuestion.isOpenEnded;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _confettiController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _selectAnswer(String answer) {
    setState(() {
      _answers[_currentQuestion.id] = answer;
    });
  }

  void _updateTextAnswer(String text) {
    setState(() {
      _answers[_currentQuestion.id] = text;
    });
  }

  Future<void> _nextQuestion() async {
    if (!_hasAnsweredCurrent) return;

    setState(() {
      _isProcessing = true;
    });

    // Score the current answer using offline AI
    final selectedAnswer = _answers[_currentQuestion.id] as String;
    final isCorrect = await _scoreAnswer(_currentQuestion, selectedAnswer);
    
    setState(() {
      _questionCorrectness[_currentQuestion.id] = isCorrect;
      _isProcessing = false;
    });

    // Show brief feedback
    await _showAnswerFeedback(isCorrect);

    if (_isLastQuestion) {
      await _completeQuiz();
    } else {
      setState(() {
        _currentQuestionIndex++;
        _textController.clear(); // Clear text input for next question
      });
      _slideController.reset();
      _slideController.forward();
    }
  }

  Future<bool> _scoreAnswer(QuizQuestion question, String selectedAnswer) async {
    try {
      // Use enhanced AI scoring service with TensorFlow Lite
      final scoringService = EnhancedAIScoringService.instance;
      return await scoringService.scoreAnswer(question, selectedAnswer);
    } catch (e) {
      debugPrint('Error scoring answer: $e');
      // Fallback to simple string matching
      return _fallbackScoring(question, selectedAnswer);
    }
  }

  bool _fallbackScoring(QuizQuestion question, String selectedAnswer) {
    // Simple fallback: check if selected answer matches correct answer index
    if (question.correctAnswer >= 0 && question.correctAnswer < question.options.length) {
      return selectedAnswer == question.options[question.correctAnswer];
    }
    
    // If no correct answer index, use fuzzy matching
    final correctAnswerText = question.options.isNotEmpty ? question.options[0] : '';
    return selectedAnswer.toLowerCase().trim() == correctAnswerText.toLowerCase().trim();
  }

  Future<void> _showAnswerFeedback(bool isCorrect) async {
    // Show a brief animation/feedback
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.all(AppTheme.spacingXl),
          decoration: BoxDecoration(
            color: isCorrect ? Colors.green.shade100 : Colors.red.shade100,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(
              color: isCorrect ? Colors.green : Colors.red,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                size: 64,
                color: isCorrect ? Colors.green : Colors.red,
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Text(
                isCorrect ? 'Correct!' : 'Not quite right',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isCorrect ? Colors.green.shade800 : Colors.red.shade800,
                ),
              ),
              if (!isCorrect && _currentQuestion.explanation.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacingMd),
                Text(
                  _currentQuestion.explanation,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.red.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    // Auto-dismiss after 2 seconds
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _completeQuiz() async {
    // Calculate final score
    final correctAnswers = _questionCorrectness.values.where((correct) => correct).length;
    _finalScore = ((correctAnswers / widget.questions.length) * 100).round();

    setState(() {
      _showResults = true;
    });

    // Show confetti for good scores
    if (_finalScore >= 70) {
      _confettiController.play();
    }

    // Auto-complete after showing results
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        widget.onComplete(_finalScore, _answers);
        Navigator.of(context).pop();
      }
    });
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
        // Restore previous answer if it was text input
        final previousAnswer = _answers[_currentQuestion.id];
        if (_isOpenEndedQuestion && previousAnswer != null) {
          _textController.text = previousAnswer.toString();
        } else {
          _textController.clear();
        }
      });
      _slideController.reset();
      _slideController.forward();
    }
  }

  void _skipToResults() {
    widget.onComplete(_finalScore, _answers);
    Navigator.of(context).pop();
  }

  Widget _buildTextInputAnswer() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFC),
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _currentQuestion.type == 'essay' 
                ? 'Write your answer in 2-3 sentences:'
                : 'Type your answer:',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          TextFormField(
            controller: _textController,
            maxLines: _currentQuestion.type == 'essay' ? 5 : 2,
            decoration: InputDecoration(
              hintText: _currentQuestion.type == 'essay'
                  ? 'Explain your answer with details...'
                  : 'Enter your answer...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: const BorderSide(color: AppTheme.primary, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(AppTheme.spacingMd),
            ),
            onChanged: _updateTextAnswer,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            'Tip: Use your own words to explain what you understood',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textTertiary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultipleChoiceAnswers() {
    return ListView.builder(
      itemCount: _currentQuestion.options.length,
      itemBuilder: (context, index) {
        final option = _currentQuestion.options[index];
        final isSelected = _answers[_currentQuestion.id] == option;
        
        return Container(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
          child: InkWell(
            onTap: _isProcessing ? null : () => _selectAnswer(option),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppTheme.primary.withOpacity(0.1) 
                    : const Color(0xFFF7FAFC),
                border: Border.all(
                  color: isSelected ? AppTheme.primary : AppTheme.border,
                  width: isSelected ? 3 : 1,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppTheme.primary : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? AppTheme.primary : AppTheme.textTertiary,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            size: 18,
                            color: Colors.white,
                          )
                        : Text(
                            String.fromCharCode(65 + index), // A, B, C, D
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textTertiary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                  ),
                  const SizedBox(width: AppTheme.spacingMd),
                  Expanded(
                    child: Text(
                      option,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showResults) {
      return _buildResultsScreen();
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text('Comprehension Quiz'),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            // Allow skipping quiz but with 0 score
            widget.onComplete(0, {});
            Navigator.of(context).pop();
          },
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: AppTheme.spacingMd),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMd,
              vertical: AppTheme.spacingSm,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: Text(
              '${_currentQuestionIndex + 1}/${widget.questions.length}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Column(
              children: [
                // Progress indicator
                LinearProgressIndicator(
                  value: (_currentQuestionIndex + 1) / widget.questions.length,
                  backgroundColor: AppTheme.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
                
                const SizedBox(height: AppTheme.spacingXl),
                
                // Question card with slide animation
                Expanded(
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTheme.spacingXl),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Question text
                          Container(
                            padding: const EdgeInsets.all(AppTheme.spacingLg),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                            ),
                            child: Text(
                              _currentQuestion.question,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: AppTheme.spacingXl),
                          
                          // Answer options - conditional based on question type
                          Expanded(
                            child: _isOpenEndedQuestion 
                                ? _buildTextInputAnswer()
                                : _buildMultipleChoiceAnswers(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingXl),
                
                // Navigation buttons
                Row(
                  children: [
                    if (_currentQuestionIndex > 0)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _previousQuestion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.textSecondary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingLg),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                            ),
                          ),
                          child: const Text(
                            'Previous',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    
                    if (_currentQuestionIndex > 0) const SizedBox(width: AppTheme.spacingMd),
                    
                    Expanded(
                      flex: _currentQuestionIndex > 0 ? 1 : 2,
                      child: ElevatedButton(
                        onPressed: (_hasAnsweredCurrent && !_isProcessing) ? _nextQuestion : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (_hasAnsweredCurrent && !_isProcessing)
                              ? AppTheme.primary 
                              : AppTheme.textTertiary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingLg),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                          ),
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                _isLastQuestion ? 'Finish Quiz' : 'Next Question',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
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

  Widget _buildResultsScreen() {
    final correctAnswers = _questionCorrectness.values.where((correct) => correct).length;
    final totalQuestions = widget.questions.length;
    
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingXl),
          child: Column(
            children: [
              const SizedBox(height: AppTheme.spacingXl),
              
              // Results header
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingXl),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      _finalScore >= 80 ? Icons.emoji_events : 
                      _finalScore >= 60 ? Icons.thumb_up : Icons.lightbulb,
                      size: 80,
                      color: _finalScore >= 80 ? Colors.amber : 
                             _finalScore >= 60 ? Colors.green : Colors.blue,
                    ),
                    
                    const SizedBox(height: AppTheme.spacingLg),
                    
                    Text(
                      _finalScore >= 80 ? 'Excellent!' : 
                      _finalScore >= 60 ? 'Good Job!' : 'Keep Learning!',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    
                    const SizedBox(height: AppTheme.spacingMd),
                    
                    Text(
                      'You scored $_finalScore%',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: _finalScore >= 70 ? Colors.green : Colors.orange,
                      ),
                    ),
                    
                    const SizedBox(height: AppTheme.spacingSm),
                    
                    Text(
                      '$correctAnswers out of $totalQuestions questions correct',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Continue button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _skipToResults,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingLg),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    ),
                  ),
                  child: const Text(
                    'Continue Reading',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}