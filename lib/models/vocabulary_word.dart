class VocabularyWord {
  final String word;
  final String definition;
  final String category;
  final DateTime learnedAt;

  VocabularyWord({
    required this.word,
    required this.definition,
    required this.category,
    required this.learnedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'definition': definition,
      'category': category,
      'learnedAt': learnedAt.toIso8601String(),
    };
  }

  static VocabularyWord fromMap(Map<String, dynamic> map) {
    return VocabularyWord(
      word: map['word'],
      definition: map['definition'],
      category: map['category'],
      learnedAt: DateTime.parse(map['learnedAt']),
    );
  }
}