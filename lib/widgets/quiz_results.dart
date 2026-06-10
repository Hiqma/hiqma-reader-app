import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../theme/app_theme.dart';
import '../models/quiz_question.dart';

class QuizResults extends StatefulWidget {
  final int score;
  final List<QuizQuestion> questions;
  final Map<String, dynamic> answers;
  final VoidCallback onRetry;
  final VoidCallback onContinue;

  const QuizResults({
    super.key,
    required this.score,
    required this.questions,
    required this.answers,
    required this.onRetry,
    required this.onContinue,
  });

  @override
  State<QuizResults> createState() => _QuizResultsState();
}

class _QuizResultsState extends State<QuizResults> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    // Show confetti for good scores
    if (widget.score >= 70) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _confettiController.play();
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  String get _scoreMessage {
    if (widget.score >= 90) return "Outstanding! 🌟";
    if (widget.score >= 80) return "Excellent work! 🎉";
    if (widget.score >= 70) return "Great job! 👏";
    if (widget.score >= 60) return "Good effort! 👍";
    return "Keep practicing! 💪";
  }

  Color get _scoreColor {
    if (widget.score >= 80) return const Color(0xFF10B981); // Green
    if (widget.score >= 60) return const Color(0xFFF59E0B); // Yellow
    return const Color(0xFFEF4444); // Red
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              child: Column(
                children: [
                  // Header
                  const Text(
                    'Quiz Complete!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  
                  const SizedBox(height: AppTheme.spacingXl),
                  
                  // Score card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppTheme.spacingXl),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Score circle
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _scoreColor.withOpacity(0.1),
                            border: Border.all(color: _scoreColor, width: 4),
                          ),
                          child: Center(
                            child: Text(
                              '${widget.score}%',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: _scoreColor,
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: AppTheme.spacingLg),
                        
                        Text(
                          _scoreMessage,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        
                        const SizedBox(height: AppTheme.spacingMd),
                        
                        Text(
                          'You got ${_getCorrectAnswers()} out of ${widget.questions.length} questions right!',
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: AppTheme.spacingXl),
                  
                  // Question review
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTheme.spacingLg),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Review Your Answers',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          
                          const SizedBox(height: AppTheme.spacingMd),
                          
                          Expanded(
                            child: ListView.builder(
                              itemCount: widget.questions.length,
                              itemBuilder: (context, index) {
                                final question = widget.questions[index];
                                final userAnswer = widget.answers[question.id];
                                final isCorrect = userAnswer == question.correctAnswer;
                                
                                return Container(
                                  margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                                  decoration: BoxDecoration(
                                    color: isCorrect 
                                        ? const Color(0xFF10B981).withOpacity(0.1)
                                        : const Color(0xFFEF4444).withOpacity(0.1),
                                    border: Border.all(
                                      color: isCorrect 
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFEF4444),
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            isCorrect ? Icons.check_circle : Icons.cancel,
                                            color: isCorrect 
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFFEF4444),
                                            size: 20,
                                          ),
                                          const SizedBox(width: AppTheme.spacingSm),
                                          Expanded(
                                            child: Text(
                                              'Question ${index + 1}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: isCorrect 
                                                    ? const Color(0xFF10B981)
                                                    : const Color(0xFFEF4444),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      const SizedBox(height: AppTheme.spacingSm),
                                      
                                      Text(
                                        question.question,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      
                                      const SizedBox(height: AppTheme.spacingSm),
                                      
                                      if (!isCorrect) ...[
                                        Text(
                                          'Your answer: $userAnswer',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFFEF4444),
                                          ),
                                        ),
                                        Text(
                                          'Correct answer: ${question.correctAnswer}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF10B981),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ] else
                                        Text(
                                          'Correct! ✓',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF10B981),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: AppTheme.spacingXl),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: widget.onRetry,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.textSecondary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                            ),
                          ),
                          child: const Text('Try Again'),
                        ),
                      ),
                      
                      const SizedBox(width: AppTheme.spacingMd),
                      
                      Expanded(
                        child: ElevatedButton(
                          onPressed: widget.onContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                            ),
                          ),
                          child: const Text('Continue'),
                        ),
                      ),
                    ],
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

  int _getCorrectAnswers() {
    int correct = 0;
    for (final question in widget.questions) {
      if (widget.answers[question.id] == question.correctAnswer) {
        correct++;
      }
    }
    return correct;
  }
}