import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/quiz_question.dart';
import 'onnx_ai_scoring_service.dart';
import 'offline_ai_scoring_service.dart';

/// Enhanced AI scoring service that uses ONNX Runtime for semantic analysis
/// with advanced rule-based algorithms as fallback
class EnhancedAIScoringService {
  static EnhancedAIScoringService? _instance;
  static EnhancedAIScoringService get instance => _instance ??= EnhancedAIScoringService._();
  
  EnhancedAIScoringService._();

  // ONNX-powered scoring service
  final ONNXAIScoringService _onnxScoring = ONNXAIScoringService.instance;
  
  // Fallback to rule-based scoring
  final OfflineAIScoringService _ruleBasedScoring = OfflineAIScoringService();
  
  // Enhanced scoring thresholds
  static const double _semanticThreshold = 0.75;
  static const double _hybridThreshold = 0.65;

  /// Initialize the enhanced scoring service with ONNX Runtime
  Future<void> initialize() async {
    try {
      await _onnxScoring.initialize();
      debugPrint('Enhanced AI scoring service initialized with ONNX Runtime');
    } catch (e) {
      debugPrint('ONNX initialization failed, using rule-based scoring: $e');
    }
  }

  /// Score an answer using ONNX + advanced rule-based hybrid approach
  Future<bool> scoreAnswer(QuizQuestion question, String selectedAnswer) async {
    try {
      // Use ONNX-powered scoring (which includes rule-based fallback)
      return await _onnxScoring.scoreAnswer(question, selectedAnswer);
    } catch (e) {
      debugPrint('Error in enhanced AI scoring: $e');
      // Final fallback to pure rule-based scoring
      return await _ruleBasedScoring.scoreAnswer(question, selectedAnswer);
    }
  }

  /// Get detailed scoring information for debugging
  Future<Map<String, dynamic>> getDetailedScoring(QuizQuestion question, String selectedAnswer) async {
    try {
      // Use ONNX detailed scoring (includes fallback logic)
      return await _onnxScoring.getDetailedScoring(question, selectedAnswer);
    } catch (e) {
      // Final fallback to rule-based detailed scoring
      return _ruleBasedScoring.getDetailedScoring(question, selectedAnswer);
    }
  }

  /// Dispose resources
  void dispose() {
    _onnxScoring.dispose();
    debugPrint('Enhanced AI scoring service disposed');
  }
}

/// Question types for different scoring strategies
enum QuestionType {
  multipleChoice,
  shortAnswer,
  essay,
}