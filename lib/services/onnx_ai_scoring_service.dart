import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import '../models/quiz_question.dart';
import 'offline_ai_scoring_service.dart';

/// ONNX-powered AI scoring service that combines machine learning semantic analysis
/// with rule-based scoring for comprehensive answer evaluation
class ONNXAIScoringService {
  static ONNXAIScoringService? _instance;
  static ONNXAIScoringService get instance => _instance ??= ONNXAIScoringService._();
  
  ONNXAIScoringService._();

  // ONNX Runtime components
  OnnxRuntime? _ort;
  OrtSession? _session;
  bool _isModelLoaded = false;
  
  // Fallback to rule-based scoring
  final OfflineAIScoringService _ruleBasedScoring = OfflineAIScoringService();
  
  // Model configuration
  static const String _modelPath = 'assets/models/sentence_transformer.onnx';
  static const int _maxSequenceLength = 128;
  static const double _semanticThreshold = 0.8;
  static const double _hybridThreshold = 0.65;

  /// Initialize ONNX Runtime with sentence transformer model
  Future<void> initialize() async {
    if (_isModelLoaded) return;
    
    try {
      debugPrint('Initializing ONNX Runtime for AI scoring...');
      _ort = OnnxRuntime();
      
      // Check if model file exists
      try {
        await rootBundle.load(_modelPath);
        debugPrint('ONNX model found, loading...');
      } catch (e) {
        debugPrint('ONNX model not found at $_modelPath');
        debugPrint('Falling back to rule-based scoring only');
        _isModelLoaded = false;
        return;
      }
      
      // Load the sentence transformer model
      _session = await _ort!.createSessionFromAsset(_modelPath);
      
      _isModelLoaded = true;
      debugPrint('ONNX sentence transformer model loaded successfully');
      
    } catch (e) {
      debugPrint('Failed to initialize ONNX Runtime: $e');
      debugPrint('Falling back to rule-based scoring only');
      _isModelLoaded = false;
    }
  }

  /// Score an answer using ONNX + rule-based hybrid approach
  Future<bool> scoreAnswer(QuizQuestion question, String selectedAnswer) async {
    try {
      // Ensure model is initialized
      await initialize();
      
      // Get the correct answer text
      String correctAnswer;
      if (question.correctAnswer >= 0 && question.correctAnswer < question.options.length) {
        correctAnswer = question.options[question.correctAnswer];
      } else {
        debugPrint('Invalid correct answer index, falling back to rule-based scoring');
        return await _ruleBasedScoring.scoreAnswer(question, selectedAnswer);
      }

      // Determine question type and scoring strategy
      final questionType = _determineQuestionType(question, selectedAnswer);
      
      switch (questionType) {
        case QuestionType.multipleChoice:
          // Use rule-based for multiple choice (faster and accurate)
          return await _ruleBasedScoring.scoreAnswer(question, selectedAnswer);
          
        case QuestionType.shortAnswer:
        case QuestionType.essay:
          // Use ONNX + rule-based for open-ended questions
          return await _scoreSemanticAnswer(correctAnswer, selectedAnswer, questionType);
          
        default:
          return await _ruleBasedScoring.scoreAnswer(question, selectedAnswer);
      }
      
    } catch (e) {
      debugPrint('Error in ONNX AI scoring: $e');
      // Always fallback to rule-based scoring
      return await _ruleBasedScoring.scoreAnswer(question, selectedAnswer);
    }
  }

  /// Score semantic answers using ONNX + rule-based hybrid
  Future<bool> _scoreSemanticAnswer(String correctAnswer, String selectedAnswer, QuestionType type) async {
    try {
      if (!_isModelLoaded || _session == null) {
        debugPrint('ONNX model not available, using rule-based scoring');
        return await _ruleBasedScoring.scoreAnswer(
          QuizQuestion(
            id: 'temp',
            question: '',
            options: [correctAnswer],
            correctAnswer: 0,
            explanation: '',
          ),
          selectedAnswer,
        );
      }

      // Get semantic similarity using ONNX
      final semanticScore = await _calculateSemanticSimilarity(correctAnswer, selectedAnswer);
      
      debugPrint('ONNX semantic similarity score: $semanticScore');
      
      // High confidence semantic match
      if (semanticScore >= _semanticThreshold) {
        debugPrint('High ONNX semantic similarity - CORRECT');
        return true;
      }
      
      // Low confidence semantic match
      if (semanticScore < 0.4) {
        debugPrint('Low ONNX semantic similarity - INCORRECT');
        return false;
      }
      
      // Medium confidence: combine with rule-based scoring
      debugPrint('Medium ONNX semantic similarity, combining with rule-based scoring');
      final ruleBasedResult = await _ruleBasedScoring.scoreAnswer(
        QuizQuestion(
          id: 'temp',
          question: '',
          options: [correctAnswer],
          correctAnswer: 0,
          explanation: '',
        ),
        selectedAnswer,
      );
      
      // Hybrid scoring: weight ONNX and rule-based results
      final hybridScore = (semanticScore * 0.7) + (ruleBasedResult ? 0.3 : 0.0);
      
      debugPrint('ONNX hybrid score: $hybridScore (threshold: $_hybridThreshold)');
      return hybridScore >= _hybridThreshold;
      
    } catch (e) {
      debugPrint('Error in ONNX semantic scoring: $e');
      return await _ruleBasedScoring.scoreAnswer(
        QuizQuestion(
          id: 'temp',
          question: '',
          options: [correctAnswer],
          correctAnswer: 0,
          explanation: '',
        ),
        selectedAnswer,
      );
    }
  }

  /// Calculate semantic similarity using ONNX sentence transformer
  Future<double> _calculateSemanticSimilarity(String text1, String text2) async {
    try {
      if (_session == null) throw Exception('ONNX session not loaded');
      
      // Get embeddings for both texts
      final embedding1 = await _getTextEmbedding(text1);
      final embedding2 = await _getTextEmbedding(text2);
      
      if (embedding1 == null || embedding2 == null) {
        throw Exception('Failed to generate ONNX embeddings');
      }
      
      // Calculate cosine similarity
      return _cosineSimilarity(embedding1, embedding2);
      
    } catch (e) {
      debugPrint('Error calculating ONNX semantic similarity: $e');
      return 0.0;
    }
  }

  /// Generate text embedding using ONNX model
  Future<List<double>?> _getTextEmbedding(String text) async {
    try {
      if (_session == null) return null;
      
      // Preprocess and tokenize text
      final tokens = _tokenizeText(text);
      
      // Create input tensor
      final inputIds = await OrtValue.fromList(tokens, [1, tokens.length]);
      final attentionMask = await OrtValue.fromList(
        List.filled(tokens.length, 1), 
        [1, tokens.length]
      );
      
      final inputs = {
        'input_ids': inputIds,
        'attention_mask': attentionMask,
      };
      
      // Run ONNX inference
      final outputs = await _session!.run(inputs);
      
      // Extract embeddings (assuming last_hidden_state output)
      List<double> embeddings;
      if (outputs.containsKey('last_hidden_state')) {
        final rawEmbeddings = await outputs['last_hidden_state']!.asList();
        embeddings = rawEmbeddings.cast<double>();
      } else if (outputs.containsKey('pooler_output')) {
        final rawEmbeddings = await outputs['pooler_output']!.asList();
        embeddings = rawEmbeddings.cast<double>();
      } else {
        // Use first output if specific keys not found
        final outputKeys = outputs.keys.toList();
        if (outputKeys.isNotEmpty) {
          final rawEmbeddings = await outputs[outputKeys.first]!.asList();
          embeddings = rawEmbeddings.cast<double>();
        } else {
          throw Exception('No outputs from ONNX model');
        }
      }
      
      // Memory is managed automatically - no need to release
      
      // Mean pooling if we have sequence embeddings
      if (embeddings.length > 768) {
        return _meanPooling(embeddings, tokens.length);
      }
      
      return embeddings;
      
    } catch (e) {
      debugPrint('Error generating ONNX text embedding: $e');
      return null;
    }
  }

  /// Tokenize text for ONNX model (simplified BERT-like tokenization)
  List<int> _tokenizeText(String text) {
    // This is a simplified tokenizer - in production, you'd use a proper
    // tokenizer that matches your ONNX model (e.g., BERT tokenizer)
    
    final normalizedText = text.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    final words = normalizedText.split(' ');
    final tokens = <int>[101]; // [CLS] token
    
    // Simple word-to-token mapping (replace with proper tokenizer)
    for (final word in words) {
      if (tokens.length >= _maxSequenceLength - 1) break;
      
      // Hash-based tokenization (simplified)
      final tokenId = (word.hashCode.abs() % 30000) + 1000;
      tokens.add(tokenId);
    }
    
    tokens.add(102); // [SEP] token
    
    // Pad to fixed length
    while (tokens.length < _maxSequenceLength) {
      tokens.add(0); // [PAD] token
    }
    
    return tokens.take(_maxSequenceLength).toList();
  }

  /// Mean pooling for sequence embeddings
  List<double> _meanPooling(List<double> embeddings, int sequenceLength) {
    final embeddingDim = embeddings.length ~/ sequenceLength;
    final pooled = List.filled(embeddingDim, 0.0);
    
    for (int i = 0; i < sequenceLength; i++) {
      for (int j = 0; j < embeddingDim; j++) {
        pooled[j] += embeddings[i * embeddingDim + j];
      }
    }
    
    // Average
    for (int j = 0; j < embeddingDim; j++) {
      pooled[j] /= sequenceLength;
    }
    
    return pooled;
  }

  /// Calculate cosine similarity between two embedding vectors
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    
    if (normA == 0.0 || normB == 0.0) return 0.0;
    
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// Determine question type based on answer characteristics
  QuestionType _determineQuestionType(QuizQuestion question, String selectedAnswer) {
    // Check if it's multiple choice (selected answer matches one of the options exactly)
    for (final option in question.options) {
      if (selectedAnswer.trim().toLowerCase() == option.trim().toLowerCase()) {
        return QuestionType.multipleChoice;
      }
    }
    
    // Determine by answer length
    final wordCount = selectedAnswer.trim().split(RegExp(r'\s+')).length;
    
    if (wordCount <= 10) {
      return QuestionType.shortAnswer;
    } else {
      return QuestionType.essay;
    }
  }

  /// Get detailed scoring information for debugging
  Future<Map<String, dynamic>> getDetailedScoring(QuizQuestion question, String selectedAnswer) async {
    try {
      await initialize();
      
      String correctAnswer;
      if (question.correctAnswer >= 0 && question.correctAnswer < question.options.length) {
        correctAnswer = question.options[question.correctAnswer];
      } else {
        return {'error': 'Invalid correct answer index'};
      }

      final questionType = _determineQuestionType(question, selectedAnswer);
      final result = <String, dynamic>{
        'questionType': questionType.toString(),
        'correctAnswer': correctAnswer,
        'selectedAnswer': selectedAnswer,
        'modelLoaded': _isModelLoaded,
      };

      if (questionType == QuestionType.multipleChoice) {
        // Rule-based scoring details
        final ruleBasedDetails = _ruleBasedScoring.getDetailedScoring(question, selectedAnswer);
        result.addAll(ruleBasedDetails);
        result['scoringMethod'] = 'rule-based';
      } else {
        // ONNX + rule-based scoring details
        if (_isModelLoaded && _session != null) {
          final semanticScore = await _calculateSemanticSimilarity(correctAnswer, selectedAnswer);
          final ruleBasedResult = await _ruleBasedScoring.scoreAnswer(
            QuizQuestion(
              id: 'temp',
              question: '',
              options: [correctAnswer],
              correctAnswer: 0,
              explanation: '',
            ),
            selectedAnswer,
          );
          final hybridScore = (semanticScore * 0.7) + (ruleBasedResult ? 0.3 : 0.0);
          
          result.addAll({
            'onnxSemanticSimilarity': semanticScore,
            'ruleBasedResult': ruleBasedResult,
            'hybridScore': hybridScore,
            'scoringMethod': 'onnx-hybrid',
            'isCorrect': hybridScore >= _hybridThreshold,
          });
        } else {
          // Fallback to rule-based details
          final ruleBasedDetails = _ruleBasedScoring.getDetailedScoring(question, selectedAnswer);
          result.addAll(ruleBasedDetails);
          result['scoringMethod'] = 'rule-based-fallback';
        }
      }

      return result;
      
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Dispose ONNX resources
  void dispose() {
    try {
      // Memory management is handled automatically by flutter_onnxruntime
      _session = null;
      _ort = null;
      _isModelLoaded = false;
      debugPrint('ONNX AI scoring service disposed');
    } catch (e) {
      debugPrint('Error disposing ONNX resources: $e');
    }
  }
}

/// Question types for different scoring strategies
enum QuestionType {
  multipleChoice,
  shortAnswer,
  essay,
}