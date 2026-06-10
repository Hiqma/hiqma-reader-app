import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/quiz_question.dart';

/// Offline AI-powered scoring service that evaluates comprehension answers
/// without requiring internet connectivity. Uses rule-based NLP and fuzzy matching.
class OfflineAIScoringService {
  static const double _exactMatchThreshold = 0.9;
  static const double _partialMatchThreshold = 0.6;
  static const double _semanticMatchThreshold = 0.7;

  /// Score an answer using offline AI techniques
  Future<bool> scoreAnswer(QuizQuestion question, String selectedAnswer) async {
    try {
      // Get the correct answer
      String correctAnswer;
      if (question.correctAnswer >= 0 && question.correctAnswer < question.options.length) {
        correctAnswer = question.options[question.correctAnswer];
      } else {
        // Fallback to first option if correctAnswer index is invalid
        correctAnswer = question.options.isNotEmpty ? question.options[0] : '';
      }

      // Multiple scoring approaches for robustness
      final scores = <double>[
        _exactStringMatch(selectedAnswer, correctAnswer),
        _fuzzyStringMatch(selectedAnswer, correctAnswer),
        _semanticSimilarity(selectedAnswer, correctAnswer),
        _keywordMatch(selectedAnswer, correctAnswer),
        _contextualMatch(question.question, selectedAnswer, correctAnswer),
      ];

      // Weighted average of different scoring methods
      final weights = [0.3, 0.25, 0.2, 0.15, 0.1];
      double finalScore = 0.0;
      
      for (int i = 0; i < scores.length; i++) {
        finalScore += scores[i] * weights[i];
      }

      // Return true if score exceeds threshold
      return finalScore >= _partialMatchThreshold;
      
    } catch (e) {
      debugPrint('Error in AI scoring: $e');
      // Fallback to simple string comparison
      return _simpleStringMatch(selectedAnswer, question);
    }
  }

  /// Exact string matching with normalization
  double _exactStringMatch(String answer1, String answer2) {
    final normalized1 = _normalizeText(answer1);
    final normalized2 = _normalizeText(answer2);
    
    return normalized1 == normalized2 ? 1.0 : 0.0;
  }

  /// Fuzzy string matching using Levenshtein distance
  double _fuzzyStringMatch(String answer1, String answer2) {
    final normalized1 = _normalizeText(answer1);
    final normalized2 = _normalizeText(answer2);
    
    if (normalized1.isEmpty || normalized2.isEmpty) return 0.0;
    
    final distance = _levenshteinDistance(normalized1, normalized2);
    final maxLength = max(normalized1.length, normalized2.length);
    
    return 1.0 - (distance / maxLength);
  }

  /// Semantic similarity using word overlap and synonyms
  double _semanticSimilarity(String answer1, String answer2) {
    final words1 = _extractKeywords(_normalizeText(answer1));
    final words2 = _extractKeywords(_normalizeText(answer2));
    
    if (words1.isEmpty || words2.isEmpty) return 0.0;
    
    int commonWords = 0;
    int synonymMatches = 0;
    
    for (final word1 in words1) {
      if (words2.contains(word1)) {
        commonWords++;
      } else {
        // Check for synonyms
        for (final word2 in words2) {
          if (_areSynonyms(word1, word2)) {
            synonymMatches++;
            break;
          }
        }
      }
    }
    
    final totalWords = max(words1.length, words2.length);
    return (commonWords + synonymMatches * 0.8) / totalWords;
  }

  /// Keyword-based matching focusing on important terms
  double _keywordMatch(String answer1, String answer2) {
    final keywords1 = _extractImportantKeywords(_normalizeText(answer1));
    final keywords2 = _extractImportantKeywords(_normalizeText(answer2));
    
    if (keywords1.isEmpty || keywords2.isEmpty) return 0.0;
    
    int matches = 0;
    for (final keyword in keywords1) {
      if (keywords2.contains(keyword)) {
        matches++;
      }
    }
    
    return matches / max(keywords1.length, keywords2.length);
  }

  /// Contextual matching considering the question context
  double _contextualMatch(String question, String selectedAnswer, String correctAnswer) {
    final questionKeywords = _extractKeywords(_normalizeText(question));
    final selectedKeywords = _extractKeywords(_normalizeText(selectedAnswer));
    final correctKeywords = _extractKeywords(_normalizeText(correctAnswer));
    
    // Check if selected answer relates to question context
    int contextMatches = 0;
    for (final qKeyword in questionKeywords) {
      if (selectedKeywords.contains(qKeyword) && correctKeywords.contains(qKeyword)) {
        contextMatches++;
      }
    }
    
    return questionKeywords.isNotEmpty ? contextMatches / questionKeywords.length : 0.0;
  }

  /// Normalize text for comparison
  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }

  /// Extract keywords from text (remove stop words)
  List<String> _extractKeywords(String text) {
    final stopWords = {
      'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
      'of', 'with', 'by', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
      'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
      'should', 'may', 'might', 'must', 'can', 'this', 'that', 'these',
      'those', 'i', 'you', 'he', 'she', 'it', 'we', 'they', 'me', 'him',
      'her', 'us', 'them', 'my', 'your', 'his', 'its', 'our', 'their'
    };
    
    return text
        .split(' ')
        .where((word) => word.length > 2 && !stopWords.contains(word))
        .toList();
  }

  /// Extract important keywords (nouns, verbs, adjectives)
  List<String> _extractImportantKeywords(String text) {
    // Simple heuristic: words that are longer and not common
    final commonWords = {
      'very', 'much', 'many', 'some', 'more', 'most', 'good', 'bad', 'big',
      'small', 'new', 'old', 'first', 'last', 'long', 'short', 'high', 'low',
      'right', 'left', 'same', 'different', 'other', 'another', 'each', 'every'
    };
    
    return _extractKeywords(text)
        .where((word) => word.length > 3 && !commonWords.contains(word))
        .toList();
  }

  /// Check if two words are synonyms (basic synonym detection)
  bool _areSynonyms(String word1, String word2) {
    final synonymGroups = [
      ['big', 'large', 'huge', 'enormous', 'giant', 'massive'],
      ['small', 'little', 'tiny', 'mini', 'miniature'],
      ['happy', 'glad', 'joyful', 'cheerful', 'pleased'],
      ['sad', 'unhappy', 'sorrowful', 'melancholy'],
      ['fast', 'quick', 'rapid', 'swift', 'speedy'],
      ['slow', 'sluggish', 'gradual'],
      ['smart', 'intelligent', 'clever', 'bright', 'wise'],
      ['beautiful', 'pretty', 'lovely', 'attractive', 'gorgeous'],
      ['ugly', 'unattractive', 'hideous'],
      ['good', 'excellent', 'great', 'wonderful', 'fantastic'],
      ['bad', 'terrible', 'awful', 'horrible'],
      ['easy', 'simple', 'effortless'],
      ['hard', 'difficult', 'challenging', 'tough'],
      ['start', 'begin', 'commence', 'initiate'],
      ['end', 'finish', 'complete', 'conclude'],
      ['help', 'assist', 'aid', 'support'],
      ['show', 'display', 'demonstrate', 'exhibit'],
      ['make', 'create', 'build', 'construct', 'produce'],
      ['break', 'destroy', 'damage', 'ruin'],
      ['find', 'discover', 'locate', 'detect'],
      ['give', 'provide', 'offer', 'supply'],
      ['take', 'grab', 'seize', 'capture'],
      ['say', 'speak', 'tell', 'talk', 'communicate'],
      ['look', 'see', 'watch', 'observe', 'view'],
      ['hear', 'listen', 'sound'],
      ['think', 'believe', 'consider', 'ponder'],
      ['know', 'understand', 'comprehend', 'realize'],
      ['learn', 'study', 'educate', 'train'],
      ['teach', 'instruct', 'educate', 'train'],
      ['work', 'job', 'employment', 'occupation'],
      ['home', 'house', 'residence', 'dwelling'],
      ['car', 'vehicle', 'automobile'],
      ['food', 'meal', 'nutrition'],
      ['water', 'liquid', 'fluid'],
      ['money', 'cash', 'currency', 'funds'],
      ['time', 'period', 'duration', 'moment'],
      ['place', 'location', 'spot', 'area', 'region'],
      ['person', 'individual', 'human', 'people'],
      ['child', 'kid', 'youngster', 'youth'],
      ['adult', 'grownup', 'mature'],
      ['man', 'male', 'gentleman'],
      ['woman', 'female', 'lady'],
      ['friend', 'buddy', 'companion', 'pal'],
      ['family', 'relatives', 'kin'],
      ['school', 'education', 'academy', 'institution'],
      ['book', 'text', 'literature', 'reading'],
      ['story', 'tale', 'narrative', 'account'],
      ['color', 'hue', 'shade', 'tint'],
      ['number', 'digit', 'numeral', 'figure'],
      ['animal', 'creature', 'beast', 'wildlife'],
      ['plant', 'vegetation', 'flora'],
      ['tree', 'wood', 'forest'],
      ['flower', 'blossom', 'bloom'],
      ['sun', 'sunshine', 'solar'],
      ['moon', 'lunar'],
      ['star', 'stellar'],
      ['earth', 'world', 'planet', 'globe'],
      ['sky', 'heaven', 'atmosphere'],
      ['ocean', 'sea', 'marine'],
      ['river', 'stream', 'flow'],
      ['mountain', 'hill', 'peak'],
      ['city', 'town', 'urban'],
      ['country', 'nation', 'state'],
    ];
    
    for (final group in synonymGroups) {
      if (group.contains(word1) && group.contains(word2)) {
        return true;
      }
    }
    
    return false;
  }

  /// Calculate Levenshtein distance between two strings
  int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;
    
    final matrix = List.generate(
      s1.length + 1,
      (i) => List.filled(s2.length + 1, 0),
    );
    
    // Initialize first row and column
    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }
    
    // Fill the matrix
    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce(min);
      }
    }
    
    return matrix[s1.length][s2.length];
  }

  /// Simple fallback string matching
  bool _simpleStringMatch(String selectedAnswer, QuizQuestion question) {
    if (question.correctAnswer >= 0 && question.correctAnswer < question.options.length) {
      final correctAnswer = question.options[question.correctAnswer];
      return _normalizeText(selectedAnswer) == _normalizeText(correctAnswer);
    }
    return false;
  }

  /// Evaluate answer confidence (for future use)
  double evaluateConfidence(QuizQuestion question, String selectedAnswer) {
    try {
      String correctAnswer;
      if (question.correctAnswer >= 0 && question.correctAnswer < question.options.length) {
        correctAnswer = question.options[question.correctAnswer];
      } else {
        return 0.0;
      }

      final exactMatch = _exactStringMatch(selectedAnswer, correctAnswer);
      final fuzzyMatch = _fuzzyStringMatch(selectedAnswer, correctAnswer);
      final semanticMatch = _semanticSimilarity(selectedAnswer, correctAnswer);
      
      // Higher confidence for exact matches, lower for fuzzy matches
      if (exactMatch >= 0.9) return 0.95;
      if (fuzzyMatch >= 0.8) return 0.8;
      if (semanticMatch >= 0.7) return 0.7;
      if (fuzzyMatch >= 0.6) return 0.6;
      
      return 0.3; // Low confidence
    } catch (e) {
      return 0.1; // Very low confidence on error
    }
  }

  /// Get detailed scoring breakdown (for debugging)
  Map<String, double> getDetailedScoring(QuizQuestion question, String selectedAnswer) {
    try {
      String correctAnswer;
      if (question.correctAnswer >= 0 && question.correctAnswer < question.options.length) {
        correctAnswer = question.options[question.correctAnswer];
      } else {
        correctAnswer = question.options.isNotEmpty ? question.options[0] : '';
      }

      return {
        'exactMatch': _exactStringMatch(selectedAnswer, correctAnswer),
        'fuzzyMatch': _fuzzyStringMatch(selectedAnswer, correctAnswer),
        'semanticSimilarity': _semanticSimilarity(selectedAnswer, correctAnswer),
        'keywordMatch': _keywordMatch(selectedAnswer, correctAnswer),
        'contextualMatch': _contextualMatch(question.question, selectedAnswer, correctAnswer),
      };
    } catch (e) {
      return {'error': 0.0};
    }
  }
}