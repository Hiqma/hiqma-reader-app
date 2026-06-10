import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/quiz_question.dart';

class InteractiveQuiz extends StatefulWidget {
  final List<QuizQuestion> questions;
  final Function(int score, Map<String, dynamic> answers) onComplete;

  const InteractiveQuiz({
    super.key,
    required this.questions,
    required this.onComplete,
  });

  @override
  State<InteractiveQuiz> createState() => _InteractiveQuizState();
}

class _InteractiveQuizState extends State<InteractiveQuiz> {
  int _currentQuestionIndex = 0;
  final Map<String, dynamic> _answers = {};
  int _score = 0;

  QuizQuestion get _currentQuestion => widget.questions[_currentQuestionIndex];
  bool get _isLastQuestion => _currentQuestionIndex == widget.questions.length - 1;

  void _selectAnswer(String answer) {
    setState(() {
      _answers[_currentQuestion.id] = answer;
    });
  }

  void _nextQuestion() {
    if (_answers.containsKey(_currentQuestion.id)) {
      // Check if answer is correct
      final selectedAnswer = _answers[_currentQuestion.id];
      if (selectedAnswer == _currentQuestion.correctAnswer) {
        _score++;
      }

      if (_isLastQuestion) {
        // Calculate final score as percentage
        final finalScore = ((_score / widget.questions.length) * 100).round();
        widget.onComplete(finalScore, _answers);
      } else {
        setState(() {
          _currentQuestionIndex++;
        });
      }
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text('Quiz ${_currentQuestionIndex + 1}/${widget.questions.length}'),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
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
            
            // Question card
            Expanded(
              child: Container(
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question text
                    Text(
                      _currentQuestion.question,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    
                    const SizedBox(height: AppTheme.spacingXl),
                    
                    // Answer options
                    Expanded(
                      child: ListView.builder(
                        itemCount: _currentQuestion.options.length,
                        itemBuilder: (context, index) {
                          final option = _currentQuestion.options[index];
                          final isSelected = _answers[_currentQuestion.id] == option;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                            child: InkWell(
                              onTap: () => _selectAnswer(option),
                              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                              child: Container(
                                padding: const EdgeInsets.all(AppTheme.spacingLg),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.primary.withOpacity(0.1) : const Color(0xFFF7FAFC),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.primary : AppTheme.border,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
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
                                              size: 16,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: AppTheme.spacingMd),
                                    Expanded(
                                      child: Text(
                                        option,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                          color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
            
            // Navigation buttons
            Row(
              children: [
                if (_currentQuestionIndex > 0)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _previousQuestion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.textSecondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        ),
                      ),
                      child: const Text('Previous'),
                    ),
                  ),
                
                if (_currentQuestionIndex > 0) const SizedBox(width: AppTheme.spacingMd),
                
                Expanded(
                  flex: _currentQuestionIndex > 0 ? 1 : 2,
                  child: ElevatedButton(
                    onPressed: _answers.containsKey(_currentQuestion.id) ? _nextQuestion : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _answers.containsKey(_currentQuestion.id) 
                          ? AppTheme.primary 
                          : AppTheme.textTertiary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      ),
                    ),
                    child: Text(_isLastQuestion ? 'Finish Quiz' : 'Next Question'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}