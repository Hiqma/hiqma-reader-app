class ReadingProgress {
  final String id;
  final String contentId;
  final String? deviceId;
  final String? studentId;
  final int currentPage;
  final int totalPages;
  final int timeSpent; // in seconds
  final DateTime lastRead;
  final bool completed;

  ReadingProgress({
    required this.id,
    required this.contentId,
    this.deviceId,
    this.studentId,
    required this.currentPage,
    required this.totalPages,
    required this.timeSpent,
    required this.lastRead,
    required this.completed,
  });

  factory ReadingProgress.fromMap(Map<String, dynamic> map) {
    return ReadingProgress(
      id: map['id'] as String,
      contentId: map['contentId'] as String,
      deviceId: map['deviceId'] as String?,
      studentId: map['studentId'] as String?,
      currentPage: map['currentPage'] as int,
      totalPages: map['totalPages'] as int,
      timeSpent: map['timeSpent'] as int,
      lastRead: DateTime.parse(map['lastRead'] as String),
      completed: (map['completed'] as int) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'contentId': contentId,
      'deviceId': deviceId,
      'studentId': studentId,
      'currentPage': currentPage,
      'totalPages': totalPages,
      'timeSpent': timeSpent,
      'lastRead': lastRead.toIso8601String(),
      'completed': completed ? 1 : 0,
    };
  }

  double get progressPercentage {
    if (totalPages == 0) return 0.0;
    return (currentPage / totalPages).clamp(0.0, 1.0);
  }

  ReadingProgress copyWith({
    String? id,
    String? contentId,
    String? deviceId,
    String? studentId,
    int? currentPage,
    int? totalPages,
    int? timeSpent,
    DateTime? lastRead,
    bool? completed,
  }) {
    return ReadingProgress(
      id: id ?? this.id,
      contentId: contentId ?? this.contentId,
      deviceId: deviceId ?? this.deviceId,
      studentId: studentId ?? this.studentId,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      timeSpent: timeSpent ?? this.timeSpent,
      lastRead: lastRead ?? this.lastRead,
      completed: completed ?? this.completed,
    );
  }

  /// Check if this progress belongs to the current session
  bool belongsToSession(String? deviceId, String? studentId) {
    return this.deviceId == deviceId && this.studentId == studentId;
  }

  /// Get a display name for this progress session
  String get sessionDisplayName {
    if (studentId != null) {
      return 'Student Session';
    } else if (deviceId != null) {
      return 'Anonymous Session';
    } else {
      return 'Legacy Session';
    }
  }
}