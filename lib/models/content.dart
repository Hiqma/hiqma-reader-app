import 'quiz_question.dart';

class Content {
  final String id;
  final String title;
  final String description;
  final String htmlContent;
  final String category;
  final String ageGroup;
  final String language;
  final String? authorId;
  final List<String> targetCountries;
  final List<String> images;
  final String? coverImageUrl;
  final List<QuizQuestion> comprehensionQuestions;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<String>? pages; // For split content pages

  Content({
    required this.id,
    required this.title,
    required this.description,
    required this.htmlContent,
    required this.category,
    required this.ageGroup,
    required this.language,
    this.authorId,
    required this.targetCountries,
    required this.images,
    this.coverImageUrl,
    required this.comprehensionQuestions,
    this.createdAt,
    this.updatedAt,
    this.pages,
  });

  factory Content.fromMap(Map<String, dynamic> map) {
    return Content(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      htmlContent: map['htmlContent'] as String,
      category: map['category'] as String? ?? 'general',
      ageGroup: map['ageGroup'] as String? ?? 'All ages',
      language: map['language'] as String? ?? 'English',
      authorId: map['authorId'] as String?,
      targetCountries: List<String>.from(map['targetCountries'] ?? []),
      images: List<String>.from(map['images'] ?? []),
      coverImageUrl: map['coverImageUrl'] as String?,
      comprehensionQuestions: (map['comprehensionQuestions'] as List?)
          ?.map((q) => QuizQuestion.fromMap(q))
          .toList() ?? [],
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
      pages: map['pages'] != null ? List<String>.from(map['pages']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'htmlContent': htmlContent,
      'category': category,
      'ageGroup': ageGroup,
      'language': language,
      'authorId': authorId,
      'targetCountries': targetCountries,
      'images': images,
      'coverImageUrl': coverImageUrl,
      'comprehensionQuestions': comprehensionQuestions.map((q) => q.toMap()).toList(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'pages': pages,
    };
  }

  Content copyWith({
    String? id,
    String? title,
    String? description,
    String? htmlContent,
    String? category,
    String? ageGroup,
    String? language,
    String? authorId,
    List<String>? targetCountries,
    List<String>? images,
    String? coverImageUrl,
    List<QuizQuestion>? comprehensionQuestions,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? pages,
  }) {
    return Content(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      htmlContent: htmlContent ?? this.htmlContent,
      category: category ?? this.category,
      ageGroup: ageGroup ?? this.ageGroup,
      language: language ?? this.language,
      authorId: authorId ?? this.authorId,
      targetCountries: targetCountries ?? this.targetCountries,
      images: images ?? this.images,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      comprehensionQuestions: comprehensionQuestions ?? this.comprehensionQuestions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pages: pages ?? this.pages,
    );
  }

  // Helper method to get pages (split content if not already split)
  List<String> getPages() {
    if (pages != null && pages!.isNotEmpty) {
      return pages!;
    }

    // First check for explicit page breaks
    if (htmlContent.contains('data-page-break="true"')) {
      final pageBreakSplit = htmlContent.split(RegExp(r'<div[^>]*data-page-break="true"[^>]*>.*?</div>', caseSensitive: false));
      return pageBreakSplit.where((page) => page.trim().isNotEmpty).toList();
    }

    // Split by h2 tags or by paragraphs if no h2 tags
    final h2Split = htmlContent.split(RegExp(r'<h2[^>]*>', caseSensitive: false));
    if (h2Split.length > 1) {
      final splitPages = <String>[];
      for (int i = 0; i < h2Split.length; i++) {
        if (i == 0) {
          if (h2Split[i].trim().isNotEmpty) {
            splitPages.add(h2Split[i]);
          }
        } else {
          splitPages.add('<h2>${h2Split[i]}');
        }
      }
      return splitPages.where((page) => page.trim().isNotEmpty).toList();
    } else {
      // Split by paragraphs, grouping 3-4 paragraphs per page
      final paragraphs = htmlContent.split(RegExp(r'</p>', caseSensitive: false))
          .where((p) => p.trim().isNotEmpty).toList();
      const paragraphsPerPage = 4;
      final splitPages = <String>[];
      
      for (int i = 0; i < paragraphs.length; i += paragraphsPerPage) {
        final pageParagraphs = paragraphs.skip(i).take(paragraphsPerPage).toList();
        splitPages.add('${pageParagraphs.join('</p>')}</p>');
      }
      
      return splitPages.isNotEmpty ? splitPages : [htmlContent];
    }
  }
}