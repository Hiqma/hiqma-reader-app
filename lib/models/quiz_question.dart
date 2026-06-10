class QuizQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctAnswer; // Index of correct answer in options
  final String explanation;
  final String type; // 'multiple_choice', 'short_answer', 'essay'
  final List<String> acceptableAnswers; // Multiple correct variations
  final double similarityThreshold; // Custom threshold per question

  QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    this.type = 'multiple_choice',
    this.acceptableAnswers = const [],
    this.similarityThreshold = 0.7,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    return QuizQuestion(
      id: map['id'] as String? ?? '',
      question: map['question'] as String? ?? '',
      options: List<String>.from(map['options'] as List? ?? []),
      correctAnswer: map['correctAnswer'] as int? ?? 0,
      explanation: map['explanation'] as String? ?? '',
      type: map['type'] as String? ?? 'multiple_choice',
      acceptableAnswers: List<String>.from(map['acceptableAnswers'] as List? ?? []),
      similarityThreshold: (map['similarityThreshold'] as num?)?.toDouble() ?? 0.7,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
      'type': type,
      'acceptableAnswers': acceptableAnswers,
      'similarityThreshold': similarityThreshold,
    };
  }

  /// Get the correct answer text
  String get correctAnswerText {
    if (correctAnswer >= 0 && correctAnswer < options.length) {
      return options[correctAnswer];
    }
    return options.isNotEmpty ? options[0] : '';
  }

  /// Check if this is an open-ended question (not multiple choice)
  bool get isOpenEnded {
    return type == 'short_answer' || type == 'essay';
  }

  /// Check if a given answer is correct
  bool isCorrectAnswer(String answer) {
    // For multiple choice, check exact match
    if (type == 'multiple_choice') {
      return answer == correctAnswerText;
    }
    
    // For open-ended questions, check against acceptable answers
    final normalizedAnswer = answer.toLowerCase().trim();
    
    // Check main correct answer
    if (normalizedAnswer == correctAnswerText.toLowerCase().trim()) {
      return true;
    }
    
    // Check acceptable variations
    for (final acceptable in acceptableAnswers) {
      if (normalizedAnswer == acceptable.toLowerCase().trim()) {
        return true;
      }
    }
    
    return false;
  }
}