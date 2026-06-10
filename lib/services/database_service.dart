import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/content.dart';
import '../models/reading_progress.dart';
import '../models/quiz_question.dart';
import '../models/vocabulary_word.dart';

class StudentProgress {
  final String contentId;
  final int progress;
  final int points;
  final DateTime? completedAt;
  final List<int> quizScores;

  StudentProgress({
    required this.contentId,
    required this.progress,
    required this.points,
    this.completedAt,
    required this.quizScores,
  });

  Map<String, dynamic> toMap() {
    return {
      'contentId': contentId,
      'progress': progress,
      'points': points,
      'completedAt': completedAt?.toIso8601String(),
      'quizScores': jsonEncode(quizScores),
    };
  }

  static StudentProgress fromMap(Map<String, dynamic> map) {
    return StudentProgress(
      contentId: map['contentId'],
      progress: map['progress'],
      points: map['points'],
      completedAt: map['completedAt'] != null ? DateTime.parse(map['completedAt']) : null,
      quizScores: List<int>.from(jsonDecode(map['quizScores'] ?? '[]')),
    );
  }
}

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('hiqma_mobile.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 6,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Content table - matches React Native structure
    await db.execute('''
      CREATE TABLE content (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        htmlContent TEXT NOT NULL,
        subject TEXT,
        gradeLevel TEXT,
        language TEXT,
        authorId TEXT,
        targetCountries TEXT,
        images TEXT,
        coverImageUrl TEXT,
        comprehensionQuestions TEXT,
        isPublished INTEGER DEFAULT 1,
        createdAt TEXT,
        updatedAt TEXT
      )
    ''');

    // Progress table - matches React Native structure with device/student attribution
    await db.execute('''
      CREATE TABLE progress (
        contentId TEXT,
        deviceId TEXT,
        studentId TEXT,
        progress INTEGER DEFAULT 0,
        points INTEGER DEFAULT 0,
        completedAt TEXT,
        quizScores TEXT DEFAULT '[]',
        PRIMARY KEY (contentId, deviceId, studentId)
      )
    ''');

    // Vocabulary table
    await db.execute('''
      CREATE TABLE vocabulary (
        word TEXT PRIMARY KEY,
        definition TEXT NOT NULL,
        category TEXT,
        learnedAt TEXT NOT NULL
      )
    ''');

    // Reading progress table (for detailed tracking) with device/student attribution
    await db.execute('''
      CREATE TABLE reading_progress (
        id TEXT PRIMARY KEY,
        contentId TEXT NOT NULL,
        deviceId TEXT,
        studentId TEXT,
        currentPage INTEGER NOT NULL DEFAULT 0,
        totalPages INTEGER NOT NULL DEFAULT 0,
        timeSpent INTEGER NOT NULL DEFAULT 0,
        lastRead TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (contentId) REFERENCES content (id)
      )
    ''');

    // Activity logs table with device/student attribution
    await db.execute('''
      CREATE TABLE activity_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contentId TEXT NOT NULL,
        deviceId TEXT,
        studentId TEXT,
        deviceCode TEXT,
        action TEXT NOT NULL,
        timeSpent INTEGER NOT NULL DEFAULT 0,
        timestamp TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (contentId) REFERENCES content (id)
      )
    ''');

    // Analytics events table for detailed analytics tracking
    await db.execute('''
      CREATE TABLE analytics_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId TEXT NOT NULL,
        contentId TEXT NOT NULL,
        deviceId TEXT,
        studentId TEXT,
        studentCode TEXT,
        deviceCode TEXT,
        eventType TEXT NOT NULL,
        eventData TEXT,
        timeSpent INTEGER NOT NULL DEFAULT 0,
        quizScore INTEGER,
        moduleCompleted INTEGER NOT NULL DEFAULT 0,
        timestamp TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (contentId) REFERENCES content (id)
      )
    ''');

    // Device authentication table
    await db.execute('''
      CREATE TABLE device_auth (
        id TEXT PRIMARY KEY,
        deviceCode TEXT NOT NULL,
        name TEXT,
        status TEXT NOT NULL,
        registeredAt TEXT,
        lastSeen TEXT,
        deviceInfo TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Student authentication table
    await db.execute('''
      CREATE TABLE student_auth (
        id TEXT PRIMARY KEY,
        studentCode TEXT NOT NULL,
        firstName TEXT,
        lastName TEXT,
        grade TEXT,
        age INTEGER,
        metadata TEXT,
        status TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Authentication sessions table
    await db.execute('''
      CREATE TABLE auth_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        deviceId TEXT NOT NULL,
        studentId TEXT,
        sessionStart TEXT NOT NULL,
        sessionEnd TEXT,
        isActive INTEGER NOT NULL DEFAULT 1,
        sessionData TEXT
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new tables for version 2
      await db.execute('''
        CREATE TABLE IF NOT EXISTS progress (
          contentId TEXT PRIMARY KEY,
          progress INTEGER DEFAULT 0,
          points INTEGER DEFAULT 0,
          completedAt TEXT,
          quizScores TEXT DEFAULT '[]'
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS vocabulary (
          word TEXT PRIMARY KEY,
          definition TEXT NOT NULL,
          category TEXT,
          learnedAt TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 3) {
      // Add authentication tables for version 3
      await db.execute('''
        CREATE TABLE IF NOT EXISTS device_auth (
          id TEXT PRIMARY KEY,
          deviceCode TEXT NOT NULL,
          name TEXT,
          status TEXT NOT NULL,
          registeredAt TEXT,
          lastSeen TEXT,
          deviceInfo TEXT,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS student_auth (
          id TEXT PRIMARY KEY,
          studentCode TEXT NOT NULL,
          firstName TEXT,
          lastName TEXT,
          grade TEXT,
          age INTEGER,
          metadata TEXT,
          status TEXT NOT NULL,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS auth_sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          deviceId TEXT NOT NULL,
          studentId TEXT,
          sessionStart TEXT NOT NULL,
          sessionEnd TEXT,
          isActive INTEGER NOT NULL DEFAULT 1,
          sessionData TEXT
        )
      ''');

      // Update existing tables to support device/student attribution
      await db.execute('ALTER TABLE progress ADD COLUMN deviceId TEXT');
      await db.execute('ALTER TABLE progress ADD COLUMN studentId TEXT');
      await db.execute('ALTER TABLE reading_progress ADD COLUMN deviceId TEXT');
      await db.execute('ALTER TABLE reading_progress ADD COLUMN studentId TEXT');
      await db.execute('ALTER TABLE activity_logs ADD COLUMN deviceId TEXT');
      await db.execute('ALTER TABLE activity_logs ADD COLUMN studentId TEXT');
      await db.execute('ALTER TABLE activity_logs ADD COLUMN deviceCode TEXT');
      await db.execute('ALTER TABLE activity_logs ADD COLUMN synced INTEGER DEFAULT 0');
    }

    if (oldVersion < 4) {
      // Add deviceCode column to activity_logs if it doesn't exist (for version 4)
      try {
        await db.execute('ALTER TABLE activity_logs ADD COLUMN deviceCode TEXT');
      } catch (e) {
        // Column might already exist from version 3 upgrade
        print('deviceCode column might already exist: $e');
      }

      // Add analytics_events table for version 4
      await db.execute('''
        CREATE TABLE IF NOT EXISTS analytics_events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sessionId TEXT NOT NULL,
          contentId TEXT NOT NULL,
          deviceId TEXT,
          studentId TEXT,
          studentCode TEXT,
          deviceCode TEXT,
          eventType TEXT NOT NULL,
          eventData TEXT,
          timeSpent INTEGER NOT NULL DEFAULT 0,
          quizScore INTEGER,
          moduleCompleted INTEGER NOT NULL DEFAULT 0,
          timestamp TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (contentId) REFERENCES content (id)
        )
      ''');
    }

    if (oldVersion < 5) {
      // Ensure analytics_events table exists for version 5 (in case upgrade from older versions)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS analytics_events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sessionId TEXT NOT NULL,
          contentId TEXT NOT NULL,
          deviceId TEXT,
          studentId TEXT,
          studentCode TEXT,
          deviceCode TEXT,
          eventType TEXT NOT NULL,
          eventData TEXT,
          timeSpent INTEGER NOT NULL DEFAULT 0,
          quizScore INTEGER,
          moduleCompleted INTEGER NOT NULL DEFAULT 0,
          timestamp TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (contentId) REFERENCES content (id)
        )
      ''');
    }

    if (oldVersion < 6) {
      // Add studentCode column to existing analytics_events table for version 6
      try {
        await db.execute('ALTER TABLE analytics_events ADD COLUMN studentCode TEXT');
      } catch (e) {
        // Column might already exist
        print('studentCode column might already exist: $e');
      }
    }
  }

  // Content operations - matches React Native functionality
  Future<void> saveContent(Content content) async {
    final db = await database;
    
    final createdAt = content.createdAt ?? DateTime.now();
    final updatedAt = content.updatedAt ?? DateTime.now();
    
    await db.insert(
      'content',
      {
        'id': content.id,
        'title': content.title,
        'description': content.description ?? '',
        'htmlContent': content.htmlContent,
        'subject': content.category ?? 'general',
        'gradeLevel': content.ageGroup ?? 'All ages',
        'language': content.language ?? 'English',
        'authorId': content.authorId ?? '',
        'targetCountries': jsonEncode(content.targetCountries ?? []),
        'images': jsonEncode(content.images ?? []),
        'coverImageUrl': content.coverImageUrl ?? '',
        'comprehensionQuestions': jsonEncode(content.comprehensionQuestions.map((q) => q.toMap()).toList()),
        'isPublished': 1,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Content?> getContent(String id) async {
    final db = await database;
    final result = await db.query(
      'content',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (result.isEmpty) return null;
    
    final row = result.first;
    return Content(
      id: row['id'] as String,
      title: row['title'] as String,
      description: row['description'] as String? ?? '',
      htmlContent: row['htmlContent'] as String,
      category: row['subject'] as String? ?? 'general',
      ageGroup: row['gradeLevel'] as String? ?? 'All ages',
      language: row['language'] as String? ?? 'English',
      authorId: row['authorId'] as String?,
      targetCountries: List<String>.from(jsonDecode(row['targetCountries'] as String? ?? '[]')),
      images: List<String>.from(jsonDecode(row['images'] as String? ?? '[]')),
      coverImageUrl: row['coverImageUrl'] as String?,
      comprehensionQuestions: (jsonDecode(row['comprehensionQuestions'] as String? ?? '[]') as List)
          .map((q) => QuizQuestion.fromMap(q))
          .toList(),
      createdAt: DateTime.parse(row['createdAt'] as String),
      updatedAt: DateTime.parse(row['updatedAt'] as String),
    );
  }

  Future<List<Content>> getAllContent() async {
    final db = await database;
    final result = await db.query(
      'content',
      where: 'isPublished = ?',
      whereArgs: [1],
      orderBy: 'createdAt DESC',
    );
    
    return result.map((row) => Content(
      id: row['id'] as String,
      title: row['title'] as String,
      description: row['description'] as String? ?? '',
      htmlContent: row['htmlContent'] as String,
      category: row['subject'] as String? ?? 'general',
      ageGroup: row['gradeLevel'] as String? ?? 'All ages',
      language: row['language'] as String? ?? 'English',
      authorId: row['authorId'] as String?,
      targetCountries: List<String>.from(jsonDecode(row['targetCountries'] as String? ?? '[]')),
      images: List<String>.from(jsonDecode(row['images'] as String? ?? '[]')),
      coverImageUrl: row['coverImageUrl'] as String?,
      comprehensionQuestions: (jsonDecode(row['comprehensionQuestions'] as String? ?? '[]') as List)
          .map((q) => QuizQuestion.fromMap(q))
          .toList(),
      createdAt: DateTime.parse(row['createdAt'] as String),
      updatedAt: DateTime.parse(row['updatedAt'] as String),
    )).toList();
  }

  Future<void> insertContentList(List<Content> contentList) async {
    final db = await database;
    final batch = db.batch();
    
    for (final content in contentList) {
      final createdAt = content.createdAt ?? DateTime.now();
      final updatedAt = content.updatedAt ?? DateTime.now();
      
      batch.insert(
        'content',
        {
          'id': content.id,
          'title': content.title,
          'description': content.description ?? '',
          'htmlContent': content.htmlContent,
          'subject': content.category ?? 'general',
          'gradeLevel': content.ageGroup ?? 'All ages',
          'language': content.language ?? 'English',
          'authorId': content.authorId ?? '',
          'targetCountries': jsonEncode(content.targetCountries ?? []),
          'images': jsonEncode(content.images ?? []),
          'coverImageUrl': content.coverImageUrl ?? '',
          'comprehensionQuestions': jsonEncode(content.comprehensionQuestions.map((q) => q.toMap()).toList()),
          'isPublished': 1,
          'createdAt': createdAt.toIso8601String(),
          'updatedAt': updatedAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit();
  }

  Future<void> deleteContent(String id) async {
    final db = await database;
    await db.delete(
      'content',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Progress operations - matches React Native functionality
  Future<void> saveProgress(StudentProgress progress) async {
    final db = await database;
    await db.insert(
      'progress',
      progress.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<StudentProgress>> getAllProgress() async {
    final db = await database;
    final result = await db.query(
      'progress',
      orderBy: 'completedAt DESC',
    );
    return result.map((map) => StudentProgress.fromMap(map)).toList();
  }

  Future<StudentProgress?> getProgressByContent(String contentId) async {
    final db = await database;
    final result = await db.query(
      'progress',
      where: 'contentId = ?',
      whereArgs: [contentId],
    );
    
    if (result.isEmpty) return null;
    return StudentProgress.fromMap(result.first);
  }

  // Vocabulary operations
  Future<bool> addToVocabulary(String word, String definition, [String? category]) async {
    final db = await database;
    try {
      await db.insert(
        'vocabulary',
        {
          'word': word.toLowerCase(),
          'definition': definition,
          'category': category ?? 'general',
          'learnedAt': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      return true;
    } catch (error) {
      print('Error adding word to vocabulary: $error');
      return false;
    }
  }

  Future<bool> isWordInVocabulary(String word) async {
    final db = await database;
    final result = await db.query(
      'vocabulary',
      where: 'word = ?',
      whereArgs: [word.toLowerCase()],
    );
    return result.isNotEmpty;
  }

  Future<List<VocabularyWord>> getVocabulary() async {
    final db = await database;
    final result = await db.query(
      'vocabulary',
      orderBy: 'learnedAt DESC',
    );
    
    return result.map((row) => VocabularyWord(
      word: row['word'] as String,
      definition: row['definition'] as String,
      category: row['category'] as String,
      learnedAt: DateTime.parse(row['learnedAt'] as String),
    )).toList();
  }

  // Reading progress operations (detailed tracking)
  Future<ReadingProgress?> getReadingProgress(String contentId) async {
    final db = await database;
    final result = await db.query(
      'reading_progress',
      where: 'contentId = ?',
      whereArgs: [contentId],
    );
    
    if (result.isNotEmpty) {
      return ReadingProgress.fromMap(result.first);
    }
    return null;
  }

  Future<void> updateReadingProgress(ReadingProgress progress) async {
    final db = await database;
    await db.insert(
      'reading_progress',
      progress.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ReadingProgress>> getAllReadingProgress() async {
    final db = await database;
    final result = await db.query(
      'reading_progress',
      orderBy: 'lastRead DESC',
    );
    return result.map((map) => ReadingProgress.fromMap(map)).toList();
  }

  Future<List<ReadingProgress>> getCurrentlyReading() async {
    final db = await database;
    final result = await db.query(
      'reading_progress',
      where: 'completed = ? AND currentPage > ?',
      whereArgs: [0, 0],
      orderBy: 'lastRead DESC',
      limit: 5,
    );
    return result.map((map) => ReadingProgress.fromMap(map)).toList();
  }

  // Activity logging
  Future<void> logActivity({
    required String contentId,
    required String action,
    required int timeSpent,
  }) async {
    final db = await instance.database;
    await db.insert('activity_logs', {
      'contentId': contentId,
      'action': action,
      'timeSpent': timeSpent,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // Statistics
  Future<Map<String, dynamic>> getReadingStats() async {
    final db = await database;
    
    // Total content
    final totalContentResult = await db.rawQuery('SELECT COUNT(*) as count FROM content WHERE isPublished = 1');
    final totalContent = totalContentResult.first['count'] as int;
    
    // Completed content
    final completedResult = await db.rawQuery('SELECT COUNT(*) as count FROM progress WHERE progress = 100');
    final completedContent = completedResult.first['count'] as int;
    
    // Total points
    final pointsResult = await db.rawQuery('SELECT SUM(points) as total FROM progress');
    final totalPoints = pointsResult.first['total'] as int? ?? 0;
    
    // Currently reading
    final currentlyReadingResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM progress WHERE progress > 0 AND progress < 100'
    );
    final currentlyReading = currentlyReadingResult.first['count'] as int;
    
    return {
      'totalContent': totalContent,
      'completedContent': completedContent,
      'totalPoints': totalPoints,
      'currentlyReading': currentlyReading,
      'completionRate': totalContent > 0 ? (completedContent / totalContent * 100).round() : 0,
    };
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('content');
    await db.delete('progress');
    await db.delete('vocabulary');
    await db.delete('reading_progress');
    await db.delete('activity_logs');
  }

  Future<void> initDatabase() async {
    await database; // This will trigger the database creation
  }

  // Authentication methods

  /// Save device authentication data
  Future<void> saveDeviceAuth(Map<String, dynamic> deviceData) async {
    final db = await database;
    await db.insert(
      'device_auth',
      deviceData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get device authentication data
  Future<Map<String, dynamic>?> getDeviceAuth() async {
    final db = await database;
    final result = await db.query('device_auth', limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  /// Save student authentication data
  Future<void> saveStudentAuth(Map<String, dynamic> studentData) async {
    final db = await database;
    await db.insert(
      'student_auth',
      studentData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all cached students
  Future<List<Map<String, dynamic>>> getCachedStudents() async {
    final db = await database;
    return await db.query('student_auth', where: 'status = ?', whereArgs: ['active']);
  }

  /// Sync students data from hub to local database
  Future<void> syncStudents(List<Map<String, dynamic>> studentsData) async {
    final db = await database;
    
    // Clear existing students and insert new ones
    await db.delete('student_auth');
    
    for (final studentData in studentsData) {
      await db.insert(
        'student_auth',
        {
          'id': studentData['id'],
          'studentCode': studentData['studentCode'],
          'firstName': studentData['firstName'],
          'lastName': studentData['lastName'],
          'grade': studentData['grade'],
          'age': studentData['age'] != null ? int.tryParse(studentData['age'].toString()) : null,
          'status': studentData['status'] ?? 'active',
          'metadata': '{}',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Save authentication session
  Future<int> saveAuthSession(Map<String, dynamic> sessionData) async {
    final db = await database;
    return await db.insert('auth_sessions', sessionData);
  }

  /// Get current active session
  Future<Map<String, dynamic>?> getCurrentSession() async {
    final db = await database;
    final result = await db.query(
      'auth_sessions',
      where: 'isActive = ?',
      whereArgs: [1],
      orderBy: 'sessionStart DESC',
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// End current session
  Future<void> endCurrentSession() async {
    final db = await database;
    await db.update(
      'auth_sessions',
      {
        'isActive': 0,
        'sessionEnd': DateTime.now().toIso8601String(),
      },
      where: 'isActive = ?',
      whereArgs: [1],
    );
  }

  /// Save progress with device/student attribution
  Future<void> saveProgressWithAttribution({
    required String contentId,
    required String deviceId,
    String? studentId,
    required int progress,
    required int points,
    DateTime? completedAt,
    List<int>? quizScores,
  }) async {
    final db = await database;
    await db.insert(
      'progress',
      {
        'contentId': contentId,
        'deviceId': deviceId,
        'studentId': studentId,
        'progress': progress,
        'points': points,
        'completedAt': completedAt?.toIso8601String(),
        'quizScores': jsonEncode(quizScores ?? []),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get progress with attribution
  Future<Map<String, dynamic>?> getProgressWithAttribution({
    required String contentId,
    required String deviceId,
    String? studentId,
  }) async {
    final db = await database;
    final result = await db.query(
      'progress',
      where: 'contentId = ? AND deviceId = ? AND studentId = ?',
      whereArgs: [contentId, deviceId, studentId ?? ''],
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// Log activity with device/student attribution
  Future<void> logActivityWithAttribution({
    required String contentId,
    required String deviceId,
    String? studentId,
    required String action,
    required int timeSpent,
    String? deviceCode,
  }) async {
    final db = await database;
    await db.insert('activity_logs', {
      'contentId': contentId,
      'deviceId': deviceId,
      'studentId': studentId,
      'action': action,
      'timeSpent': timeSpent,
      'deviceCode': deviceCode, // Store device code for analytics filtering
      'timestamp': DateTime.now().toIso8601String(),
      'synced': 0,
    });
  }

  /// Get unsynced activity logs
  Future<List<Map<String, dynamic>>> getUnsyncedActivities() async {
    final db = await database;
    return await db.query(
      'activity_logs',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'timestamp ASC',
    );
  }

  /// Mark activities as synced
  Future<void> markActivitiesAsSynced(List<int> activityIds) async {
    final db = await database;
    final batch = db.batch();
    for (final id in activityIds) {
      batch.update(
        'activity_logs',
        {'synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit();
  }

  /// Clear authentication data (for logout/reset)
  Future<void> clearAuthData() async {
    final db = await database;
    await db.delete('device_auth');
    await db.delete('student_auth');
    await db.delete('auth_sessions');
  }

  // Enhanced offline authentication caching methods

  /// Cache device registration for offline use
  Future<void> cacheDeviceForOffline(Map<String, dynamic> deviceData) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    await db.insert(
      'device_auth',
      {
        ...deviceData,
        'cachedAt': now,
        'lastValidated': now,
        'offlineCapable': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Cache student data for offline authentication
  Future<void> cacheStudentForOffline(Map<String, dynamic> studentData) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    await db.insert(
      'student_auth',
      {
        ...studentData,
        'cachedAt': now,
        'lastValidated': now,
        'offlineCapable': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Validate device authentication offline
  Future<Map<String, dynamic>?> validateDeviceOffline(String deviceCode) async {
    final db = await database;
    final result = await db.query(
      'device_auth',
      where: 'deviceCode = ? AND status = ? AND offlineCapable = ?',
      whereArgs: [deviceCode, 'active', 1],
    );
    
    if (result.isNotEmpty) {
      final device = result.first;
      
      // Update last seen timestamp
      await db.update(
        'device_auth',
        {'lastSeen': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [device['id']],
      );
      
      return device;
    }
    
    return null;
  }

  /// Validate student authentication offline
  Future<Map<String, dynamic>?> validateStudentOffline(String studentCode) async {
    final db = await database;
    final result = await db.query(
      'student_auth',
      where: 'studentCode = ? AND status = ? AND offlineCapable = ?',
      whereArgs: [studentCode, 'active', 1],
    );
    
    if (result.isNotEmpty) {
      final student = result.first;
      
      // Update last accessed timestamp
      await db.update(
        'student_auth',
        {'lastAccessed': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [student['id']],
      );
      
      return student;
    }
    
    return null;
  }

  /// Queue device registration for when online
  Future<void> queueDeviceRegistration(Map<String, dynamic> registrationData) async {
    final db = await database;
    
    // Create offline registration queue table if it doesn't exist
    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_registration_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        data TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        attempts INTEGER DEFAULT 0,
        lastAttempt TEXT,
        status TEXT DEFAULT 'pending'
      )
    ''');
    
    await db.insert('offline_registration_queue', {
      'type': 'device_registration',
      'data': jsonEncode(registrationData),
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'pending',
    });
  }

  /// Queue student login for when online
  Future<void> queueStudentLogin(Map<String, dynamic> loginData) async {
    final db = await database;
    
    // Create offline registration queue table if it doesn't exist
    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_registration_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        data TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        attempts INTEGER DEFAULT 0,
        lastAttempt TEXT,
        status TEXT DEFAULT 'pending'
      )
    ''');
    
    await db.insert('offline_registration_queue', {
      'type': 'student_login',
      'data': jsonEncode(loginData),
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'pending',
    });
  }

  /// Get pending offline registrations
  Future<List<Map<String, dynamic>>> getPendingOfflineRegistrations() async {
    final db = await database;
    
    try {
      return await db.query(
        'offline_registration_queue',
        where: 'status = ?',
        whereArgs: ['pending'],
        orderBy: 'createdAt ASC',
      );
    } catch (e) {
      // Table might not exist yet
      return [];
    }
  }

  /// Mark offline registration as completed
  Future<void> markOfflineRegistrationCompleted(int id) async {
    final db = await database;
    await db.update(
      'offline_registration_queue',
      {
        'status': 'completed',
        'lastAttempt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark offline registration as failed
  Future<void> markOfflineRegistrationFailed(int id, String error) async {
    final db = await database;
    await db.update(
      'offline_registration_queue',
      {
        'status': 'failed',
        'lastAttempt': DateTime.now().toIso8601String(),
        'attempts': 'attempts + 1',
        'error': error,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Check if device is cached for offline use
  Future<bool> isDeviceCachedForOffline(String deviceCode) async {
    final db = await database;
    final result = await db.query(
      'device_auth',
      where: 'deviceCode = ? AND offlineCapable = ?',
      whereArgs: [deviceCode, 1],
    );
    return result.isNotEmpty;
  }

  /// Check if student is cached for offline use
  Future<bool> isStudentCachedForOffline(String studentCode) async {
    final db = await database;
    final result = await db.query(
      'student_auth',
      where: 'studentCode = ? AND offlineCapable = ?',
      whereArgs: [studentCode, 1],
    );
    return result.isNotEmpty;
  }

  /// Get authentication state for offline use
  Future<Map<String, dynamic>> getOfflineAuthState() async {
    final db = await database;
    
    final deviceResult = await db.query(
      'device_auth',
      where: 'offlineCapable = ?',
      whereArgs: [1],
      limit: 1,
    );
    
    final studentsResult = await db.query(
      'student_auth',
      where: 'offlineCapable = ?',
      whereArgs: [1],
    );
    
    final currentSession = await getCurrentSession();
    
    return {
      'hasDevice': deviceResult.isNotEmpty,
      'device': deviceResult.isNotEmpty ? deviceResult.first : null,
      'cachedStudents': studentsResult,
      'currentSession': currentSession,
      'offlineCapable': deviceResult.isNotEmpty,
    };
  }

  /// Maintain authentication state during network outages
  Future<void> maintainAuthStateDuringOutage() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    // Update last seen for current device
    await db.update(
      'device_auth',
      {'lastSeen': now},
      where: 'offlineCapable = ?',
      whereArgs: [1],
    );
    
    // Keep current session active
    final currentSession = await getCurrentSession();
    if (currentSession != null) {
      await db.update(
        'auth_sessions',
        {'lastActivity': now},
        where: 'id = ?',
        whereArgs: [currentSession['id']],
      );
    }
  }

  /// Sync offline authentication data when back online
  Future<List<Map<String, dynamic>>> getOfflineAuthDataForSync() async {
    final db = await database;
    
    // Get device data that needs syncing
    final deviceResult = await db.query(
      'device_auth',
      where: 'offlineCapable = ? AND lastSeen > lastValidated',
      whereArgs: [1],
    );
    
    // Get student activity that needs syncing
    final studentActivity = await db.query(
      'auth_sessions',
      where: 'isActive = ? OR sessionEnd > ?',
      whereArgs: [1, DateTime.now().subtract(Duration(hours: 24)).toIso8601String()],
    );
    
    return [
      ...deviceResult.map((d) => {'type': 'device_activity', 'data': d}),
      ...studentActivity.map((s) => {'type': 'session_activity', 'data': s}),
    ];
  }

  /// Update authentication cache after successful online sync
  Future<void> updateAuthCacheAfterSync(Map<String, dynamic> syncResult) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    if (syncResult['deviceSynced'] == true) {
      await db.update(
        'device_auth',
        {'lastValidated': now},
        where: 'offlineCapable = ?',
        whereArgs: [1],
      );
    }
    
    if (syncResult['studentsSynced'] == true) {
      await db.update(
        'student_auth',
        {'lastValidated': now},
        where: 'offlineCapable = ?',
        whereArgs: [1],
      );
    }
  }

  /// Clean up old authentication cache data
  Future<void> cleanupOldAuthCache({int daysToKeep = 30}) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep)).toIso8601String();
    
    // Clean up old sessions
    await db.delete(
      'auth_sessions',
      where: 'isActive = ? AND sessionEnd < ?',
      whereArgs: [0, cutoffDate],
    );
    
    // Clean up old offline registration attempts
    try {
      await db.delete(
        'offline_registration_queue',
        where: 'status = ? AND createdAt < ?',
        whereArgs: ['completed', cutoffDate],
      );
    } catch (e) {
      // Table might not exist
    }
  }

  /// Get offline authentication statistics
  Future<Map<String, dynamic>> getOfflineAuthStats() async {
    final db = await database;
    
    final deviceCount = await db.query(
      'device_auth',
      where: 'offlineCapable = ?',
      whereArgs: [1],
    );
    
    final studentCount = await db.query(
      'student_auth',
      where: 'offlineCapable = ?',
      whereArgs: [1],
    );
    
    final sessionCount = await db.query(
      'auth_sessions',
      where: 'isActive = ?',
      whereArgs: [1],
    );
    
    final pendingRegistrations = await getPendingOfflineRegistrations();
    
    return {
      'cachedDevices': deviceCount.length,
      'cachedStudents': studentCount.length,
      'activeSessions': sessionCount.length,
      'pendingRegistrations': pendingRegistrations.length,
      'offlineCapable': deviceCount.isNotEmpty,
    };
  }

  Future close() async {
    final db = _database;
    if (db != null) {
      await db.close();
    }
  }

  /// Get unsynced analytics events for syncing to edge hub
  Future<List<Map<String, dynamic>>> getUnsyncedAnalyticsEvents() async {
    final db = await instance.database;
    return await db.query(
      'analytics_events',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'timestamp ASC',
    );
  }

  /// Mark analytics events as synced
  Future<void> markAnalyticsEventsSynced(List<int> eventIds) async {
    if (eventIds.isEmpty) return;
    
    final db = await instance.database;
    final batch = db.batch();
    
    for (final id in eventIds) {
      batch.update(
        'analytics_events',
        {'synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    
    await batch.commit();
  }

  // Quiz Results Methods

  /// Save quiz results for a content item
  Future<void> saveQuizResults({
    required String contentId,
    required int score,
    required Map<String, dynamic> answers,
    required DateTime completedAt,
    String? deviceId,
    String? studentId,
  }) async {
    final db = await database;
    
    // Create quiz results table if it doesn't exist
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quiz_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contentId TEXT NOT NULL,
        deviceId TEXT,
        studentId TEXT,
        score INTEGER NOT NULL,
        answers TEXT NOT NULL,
        completedAt TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (contentId) REFERENCES content (id)
      )
    ''');

    await db.insert(
      'quiz_results',
      {
        'contentId': contentId,
        'deviceId': deviceId,
        'studentId': studentId,
        'score': score,
        'answers': jsonEncode(answers),
        'completedAt': completedAt.toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
      },
    );

    // Update progress table with quiz score
    final existingProgress = await getProgressWithAttribution(
      contentId: contentId,
      deviceId: deviceId ?? '',
      studentId: studentId,
    );

    if (existingProgress != null) {
      final currentQuizScores = List<int>.from(
        jsonDecode(existingProgress['quizScores'] ?? '[]')
      );
      currentQuizScores.add(score);

      await saveProgressWithAttribution(
        contentId: contentId,
        deviceId: deviceId ?? '',
        studentId: studentId,
        progress: existingProgress['progress'] ?? 0,
        points: existingProgress['points'] ?? 0,
        completedAt: existingProgress['completedAt'] != null 
            ? DateTime.parse(existingProgress['completedAt'])
            : null,
        quizScores: currentQuizScores,
      );
    }
  }

  /// Get quiz results for a content item
  Future<List<Map<String, dynamic>>> getQuizResults({
    required String contentId,
    String? deviceId,
    String? studentId,
  }) async {
    final db = await database;
    
    String whereClause = 'contentId = ?';
    List<dynamic> whereArgs = [contentId];
    
    if (deviceId != null) {
      whereClause += ' AND deviceId = ?';
      whereArgs.add(deviceId);
    }
    
    if (studentId != null) {
      whereClause += ' AND studentId = ?';
      whereArgs.add(studentId);
    }

    try {
      final results = await db.query(
        'quiz_results',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'completedAt DESC',
      );

      return results.map((row) => {
        'id': row['id'],
        'contentId': row['contentId'],
        'deviceId': row['deviceId'],
        'studentId': row['studentId'],
        'score': row['score'],
        'answers': jsonDecode(row['answers'] as String),
        'completedAt': DateTime.parse(row['completedAt'] as String),
        'createdAt': DateTime.parse(row['createdAt'] as String),
      }).toList();
    } catch (e) {
      // Table might not exist yet
      return [];
    }
  }

  /// Get average quiz score for a content item
  Future<double?> getAverageQuizScore({
    required String contentId,
    String? deviceId,
    String? studentId,
  }) async {
    final results = await getQuizResults(
      contentId: contentId,
      deviceId: deviceId,
      studentId: studentId,
    );

    if (results.isEmpty) return null;

    final totalScore = results.fold<int>(0, (sum, result) => sum + (result['score'] as int));
    return totalScore / results.length;
  }

  /// Get best quiz score for a content item
  Future<int?> getBestQuizScore({
    required String contentId,
    String? deviceId,
    String? studentId,
  }) async {
    final results = await getQuizResults(
      contentId: contentId,
      deviceId: deviceId,
      studentId: studentId,
    );

    if (results.isEmpty) return null;

    return results.map((result) => result['score'] as int).reduce((a, b) => a > b ? a : b);
  }

  /// Get quiz statistics for all content
  Future<Map<String, dynamic>> getQuizStatistics({
    String? deviceId,
    String? studentId,
  }) async {
    final db = await database;
    
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];
    
    if (deviceId != null) {
      whereClause += ' AND deviceId = ?';
      whereArgs.add(deviceId);
    }
    
    if (studentId != null) {
      whereClause += ' AND studentId = ?';
      whereArgs.add(studentId);
    }

    try {
      final results = await db.query(
        'quiz_results',
        where: whereClause,
        whereArgs: whereArgs,
      );

      if (results.isEmpty) {
        return {
          'totalQuizzes': 0,
          'averageScore': 0.0,
          'bestScore': 0,
          'completionRate': 0.0,
        };
      }

      final scores = results.map((r) => r['score'] as int).toList();
      final totalQuizzes = scores.length;
      final averageScore = scores.reduce((a, b) => a + b) / totalQuizzes;
      final bestScore = scores.reduce((a, b) => a > b ? a : b);
      
      // Get total content count for completion rate
      final totalContent = await db.query('content');
      final completionRate = totalContent.isNotEmpty 
          ? (totalQuizzes / totalContent.length) * 100
          : 0.0;

      return {
        'totalQuizzes': totalQuizzes,
        'averageScore': averageScore,
        'bestScore': bestScore,
        'completionRate': completionRate,
        'scoreDistribution': _calculateScoreDistribution(scores),
      };
    } catch (e) {
      return {
        'totalQuizzes': 0,
        'averageScore': 0.0,
        'bestScore': 0,
        'completionRate': 0.0,
      };
    }
  }

  /// Calculate score distribution for analytics
  Map<String, int> _calculateScoreDistribution(List<int> scores) {
    final distribution = {
      'excellent': 0, // 90-100%
      'good': 0,      // 70-89%
      'fair': 0,      // 50-69%
      'poor': 0,      // 0-49%
    };

    for (final score in scores) {
      if (score >= 90) {
        distribution['excellent'] = distribution['excellent']! + 1;
      } else if (score >= 70) {
        distribution['good'] = distribution['good']! + 1;
      } else if (score >= 50) {
        distribution['fair'] = distribution['fair']! + 1;
      } else {
        distribution['poor'] = distribution['poor']! + 1;
      }
    }

    return distribution;
  }

  /// Delete old quiz results (for cleanup)
  Future<void> cleanupOldQuizResults({int daysOld = 90}) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
    
    try {
      await db.delete(
        'quiz_results',
        where: 'createdAt < ?',
        whereArgs: [cutoffDate.toIso8601String()],
      );
    } catch (e) {
      // Table might not exist
    }
  }
}