class Student {
  final String id;
  final String studentCode;
  final String? firstName;
  final String? lastName;
  final String? grade;
  final int? age;
  final Map<String, dynamic>? metadata;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Student({
    required this.id,
    required this.studentCode,
    this.firstName,
    this.lastName,
    this.grade,
    this.age,
    this.metadata,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as String,
      studentCode: json['studentCode'] as String,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      grade: json['grade'] as String?,
      age: json['age'] as int?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentCode': studentCode,
      'firstName': firstName,
      'lastName': lastName,
      'grade': grade,
      'age': age,
      'metadata': metadata,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Student copyWith({
    String? id,
    String? studentCode,
    String? firstName,
    String? lastName,
    String? grade,
    int? age,
    Map<String, dynamic>? metadata,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Student(
      id: id ?? this.id,
      studentCode: studentCode ?? this.studentCode,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      grade: grade ?? this.grade,
      age: age ?? this.age,
      metadata: metadata ?? this.metadata,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get display name for the student
  String get displayName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (firstName != null) {
      return firstName!;
    } else if (lastName != null) {
      return lastName!;
    } else {
      return studentCode;
    }
  }

  /// Get initials for the student
  String get initials {
    if (firstName != null && lastName != null) {
      return '${firstName![0].toUpperCase()}${lastName![0].toUpperCase()}';
    } else if (firstName != null) {
      return firstName![0].toUpperCase();
    } else if (lastName != null) {
      return lastName![0].toUpperCase();
    } else {
      return studentCode.substring(0, 2).toUpperCase();
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Student && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Student(id: $id, studentCode: $studentCode, displayName: $displayName, status: $status)';
  }
}

/// Authentication session data for local storage
class AuthSession {
  final String deviceId;
  final String? studentId;
  final DateTime sessionStart;
  final DateTime? sessionEnd;
  final bool isActive;
  final Map<String, dynamic>? sessionData;

  AuthSession({
    required this.deviceId,
    this.studentId,
    required this.sessionStart,
    this.sessionEnd,
    required this.isActive,
    this.sessionData,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      deviceId: json['deviceId'] as String? ?? '',
      studentId: json['studentId'] as String?,
      sessionStart: json['sessionStart'] != null 
          ? DateTime.parse(json['sessionStart'] as String)
          : DateTime.now(),
      sessionEnd: json['sessionEnd'] != null 
          ? DateTime.parse(json['sessionEnd'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? false,
      sessionData: json['sessionData'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'studentId': studentId,
      'sessionStart': sessionStart.toIso8601String(),
      'sessionEnd': sessionEnd?.toIso8601String(),
      'isActive': isActive,
      'sessionData': sessionData,
    };
  }

  AuthSession copyWith({
    String? deviceId,
    String? studentId,
    DateTime? sessionStart,
    DateTime? sessionEnd,
    bool? isActive,
    Map<String, dynamic>? sessionData,
  }) {
    return AuthSession(
      deviceId: deviceId ?? this.deviceId,
      studentId: studentId ?? this.studentId,
      sessionStart: sessionStart ?? this.sessionStart,
      sessionEnd: sessionEnd ?? this.sessionEnd,
      isActive: isActive ?? this.isActive,
      sessionData: sessionData ?? this.sessionData,
    );
  }

  /// Check if this is an anonymous session (no student logged in)
  bool get isAnonymous => studentId == null;

  /// Check if this is an authenticated session (student logged in)
  bool get isAuthenticated => studentId != null;

  /// Get session duration
  Duration get duration {
    final end = sessionEnd ?? DateTime.now();
    return end.difference(sessionStart);
  }

  @override
  String toString() {
    return 'AuthSession(deviceId: $deviceId, studentId: $studentId, isActive: $isActive, isAnonymous: $isAnonymous)';
  }
}