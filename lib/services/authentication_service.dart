import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import '../models/device.dart';
import '../models/student.dart';
import 'database_service.dart';
import 'hub_discovery_service.dart';

class AuthenticationService extends ChangeNotifier {
  static const String _currentSessionKey = 'current_session';
  static const String _registeredDeviceKey = 'registered_device';
  static const String _cachedStudentsKey = 'cached_students';
  static const String _deviceCodeKey = 'device_code';

  final DatabaseService _databaseService;
  final HubDiscoveryService _hubDiscoveryService;
  
  Device? _currentDevice;
  Student? _currentStudent;
  AuthSession? _currentSession;
  List<Student> _cachedStudents = [];
  String? _currentDeviceCode;
  bool _isInitialized = false;
  bool _isRegistering = false;
  bool _isAuthenticating = false;

  AuthenticationService({
    required DatabaseService databaseService,
    required HubDiscoveryService hubDiscoveryService,
  }) : _databaseService = databaseService,
       _hubDiscoveryService = hubDiscoveryService;

  // Getters
  Device? get currentDevice => _currentDevice;
  Student? get currentStudent => _currentStudent;
  AuthSession? get currentSession => _currentSession;
  List<Student> get cachedStudents => List.unmodifiable(_cachedStudents);
  String? get currentDeviceCode => _currentDeviceCode;
  bool get isInitialized => _isInitialized;
  bool get isRegistering => _isRegistering;
  bool get isAuthenticating => _isAuthenticating;
  bool get isDeviceRegistered => _currentDevice != null;
  bool get isStudentLoggedIn => _currentStudent != null && _currentSession?.isActive == true;
  bool get isAnonymousSession => _currentSession?.isAnonymous == true && _currentSession?.isActive == true;

  /// Initialize the authentication service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadStoredData();
      await _validateCurrentSession();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing authentication service: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Auto-register device with edge hub (device code assigned automatically)
  Future<AuthResult> autoRegisterDevice() async {
    if (_isRegistering) {
      return AuthResult.error('Device registration already in progress');
    }

    _isRegistering = true;
    notifyListeners();

    try {
      // Get current hub URL
      final hubUrl = await _hubDiscoveryService.getCurrentHubUrl();
      if (hubUrl == null) {
        return AuthResult.error('No edge hub found. Please ensure you are connected to the hub network.');
      }

      // Get device info
      final deviceInfo = await _getDeviceInfo();

      // Auto-register with edge hub
      final response = await http.post(
        Uri.parse('$hubUrl/api/devices/auto-register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'deviceInfo': deviceInfo.toJson(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['device'] != null) {
          _currentDevice = Device.fromJson(data['device']);
          _currentDeviceCode = data['device']['deviceCode'];
          
          // Save device data and device code persistently
          await _saveDeviceData();
          await _saveDeviceCode();
          // Note: Removed automatic anonymous session creation
          // The authentication flow screen will determine the appropriate session type
          
          notifyListeners();
          return AuthResult.success('Device registered successfully with code: ${_currentDeviceCode}');
        } else {
          return AuthResult.error(data['message'] ?? 'Device registration failed');
        }
      } else if (response.statusCode == 404) {
        final data = jsonDecode(response.body);
        return AuthResult.error(data['message'] ?? 'No available device codes. Please contact your administrator.');
      } else {
        return AuthResult.error('Registration failed. Please try again.');
      }
    } catch (e) {
      debugPrint('Device registration error: $e');
      return AuthResult.error('Network error. Please check your connection and try again.');
    } finally {
      _isRegistering = false;
      notifyListeners();
    }
  }

  /// Register device with edge hub using specific device code (legacy method)
  Future<AuthResult> registerDevice(String deviceCode) async {
    if (_isRegistering) {
      return AuthResult.error('Device registration already in progress');
    }

    _isRegistering = true;
    notifyListeners();

    try {
      // Validate device code format
      if (!_isValidDeviceCode(deviceCode)) {
        return AuthResult.error('Invalid device code format. Please enter a 6-8 character code.');
      }

      // Get current hub URL
      final hubUrl = await _hubDiscoveryService.getCurrentHubUrl();
      if (hubUrl == null) {
        return AuthResult.error('No edge hub found. Please ensure you are connected to the hub network.');
      }

      // Get device info
      final deviceInfo = await _getDeviceInfo();

      // Register with edge hub
      final response = await http.post(
        Uri.parse('$hubUrl/api/devices/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'deviceCode': deviceCode.toUpperCase(),
          'deviceInfo': deviceInfo.toJson(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['device'] != null) {
          _currentDevice = Device.fromJson(data['device']);
          _currentDeviceCode = deviceCode.toUpperCase();
          
          // Save device data and device code persistently
          await _saveDeviceData();
          await _saveDeviceCode();
          // Note: Removed automatic anonymous session creation
          // The authentication flow screen will determine the appropriate session type
          
          notifyListeners();
          return AuthResult.success('Device registered successfully');
        } else {
          return AuthResult.error(data['message'] ?? 'Device registration failed');
        }
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        return AuthResult.error(data['message'] ?? 'Invalid device code');
      } else if (response.statusCode == 409) {
        return AuthResult.error('Device code already registered on another device');
      } else {
        return AuthResult.error('Registration failed. Please try again.');
      }
    } catch (e) {
      debugPrint('Device registration error: $e');
      return AuthResult.error('Network error. Please check your connection and try again.');
    } finally {
      _isRegistering = false;
      notifyListeners();
    }
  }

  /// Login student using local authentication only
  Future<AuthResult> loginStudent(String studentCode) async {
    debugPrint('🔐 loginStudent() called with code: $studentCode');
    
    if (!isDeviceRegistered) {
      return AuthResult.error('Device must be registered before student login');
    }

    if (_isAuthenticating) {
      return AuthResult.error('Student authentication already in progress');
    }

    _isAuthenticating = true;
    notifyListeners();

    try {
      // Validate student code format
      if (!_isValidStudentCode(studentCode)) {
        return AuthResult.error('Invalid student code format. Please enter a 4-6 character code.');
      }

      // Get students from local database
      final cachedStudentsData = await DatabaseService.instance.getCachedStudents();
      debugPrint('📚 Found ${cachedStudentsData.length} students in database');
      
      if (cachedStudentsData.isEmpty) {
        return AuthResult.error('No students data available. Please sync with the hub first.');
      }

      // Find student by code (case-insensitive)
      final studentData = cachedStudentsData.firstWhere(
        (student) => student['studentCode'].toString().toUpperCase() == studentCode.toUpperCase(),
        orElse: () => <String, dynamic>{},
      );

      if (studentData.isEmpty) {
        debugPrint('❌ Student code not found: $studentCode');
        return AuthResult.error('Student code not found. Please check your code and try again.');
      }

      debugPrint('✅ Found student: ${studentData['id']} (${studentData['studentCode']})');

      // Create student object and login
      final student = Student(
        id: studentData['id'],
        studentCode: studentData['studentCode'],
        firstName: studentData['firstName'],
        lastName: studentData['lastName'],
        grade: studentData['grade'],
        age: studentData['age'],
        status: studentData['status'] ?? 'active',
        createdAt: studentData['createdAt'] != null 
            ? DateTime.parse(studentData['createdAt'])
            : DateTime.now(),
        updatedAt: studentData['updatedAt'] != null 
            ? DateTime.parse(studentData['updatedAt'])
            : DateTime.now(),
      );

      await _loginStudentOffline(student);
      debugPrint('✅ Student login complete');
      return AuthResult.success('Student logged in successfully');

    } catch (e) {
      debugPrint('❌ Student login error: $e');
      return AuthResult.error('Login failed. Please try again.');
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  /// Logout current student and return to anonymous session
  Future<void> logoutStudent() async {
    if (_currentSession != null) {
      // End current session
      _currentSession = _currentSession!.copyWith(
        sessionEnd: DateTime.now(),
        isActive: false,
      );
      await _saveSessionData();
    }

    _currentStudent = null;
    await _startAnonymousSession();
    notifyListeners();
  }

  /// Switch to a different student
  Future<AuthResult> switchStudent(String studentCode) async {
    await logoutStudent();
    return await loginStudent(studentCode);
  }

  /// Start anonymous session (no student login)
  Future<void> startAnonymousSession() async {
    if (!isDeviceRegistered) {
      throw StateError('Device must be registered before starting a session');
    }

    await _startAnonymousSession();
    notifyListeners();
  }

  /// Get current session context for analytics
  Map<String, dynamic> getSessionContext() {
    debugPrint('🔍 getSessionContext() called:');
    debugPrint('  _currentStudent: ${_currentStudent?.id} (${_currentStudent?.studentCode})');
    debugPrint('  _currentDevice: ${_currentDevice?.id}');
    debugPrint('  _currentSession: ${_currentSession?.studentId}');
    debugPrint('  isStudentLoggedIn: $isStudentLoggedIn');
    
    return {
      'deviceId': _currentDevice?.id,
      'deviceCode': _currentDeviceCode,
      'studentId': _currentStudent?.id,
      'studentCode': _currentStudent?.studentCode, // Add student code for activity tagging
      'sessionId': _currentSession?.deviceId,
      'isAnonymous': isAnonymousSession,
      'isAuthenticated': isStudentLoggedIn,
    };
  }

  /// Get device code for edge hub interactions
  String? getDeviceCodeForRequests() {
    return _currentDeviceCode;
  }

  /// Get headers for edge hub requests
  Map<String, String> getRequestHeaders({bool includeDeviceCode = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    if (includeDeviceCode && _currentDeviceCode != null) {
      headers['X-Device-Code'] = _currentDeviceCode!;
    }
    
    return headers;
  }

  /// Get query parameters for edge hub requests
  Map<String, String> getRequestQueryParams({bool includeDeviceCode = true}) {
    final params = <String, String>{};
    
    if (includeDeviceCode && _currentDeviceCode != null) {
      params['deviceCode'] = _currentDeviceCode!;
    }
    
    return params;
  }

  /// Refresh cached students from edge hub
  Future<void> refreshCachedStudents() async {
    try {
      final hubUrl = await _hubDiscoveryService.getCurrentHubUrl();
      if (hubUrl == null) return;

      final response = await http.get(
        Uri.parse('$hubUrl/api/students'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _cachedStudents = data.map((json) => Student.fromJson(json)).toList();
        await _saveCachedStudents();
        await _cacheStudentsForOffline();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error refreshing cached students: $e');
    }
  }

  // Enhanced offline authentication methods

  /// Check if device can operate offline
  Future<bool> canOperateOffline() async {
    final authState = await _databaseService.getOfflineAuthState();
    return authState['offlineCapable'] == true;
  }

  /// Register device with offline queueing support
  Future<AuthResult> registerDeviceWithOfflineSupport(String deviceCode) async {
    // Try online registration first
    final onlineResult = await registerDevice(deviceCode);
    
    if (onlineResult.success) {
      // Cache device for offline use
      if (_currentDevice != null) {
        await _databaseService.cacheDeviceForOffline(_currentDevice!.toJson());
      }
      return onlineResult;
    }
    
    // If online registration fails, queue for later
    final deviceInfo = await _getDeviceInfo();
    await _databaseService.queueDeviceRegistration({
      'deviceCode': deviceCode.toUpperCase(),
      'deviceInfo': deviceInfo.toJson(),
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    return AuthResult.success('Device registration queued for when online');
  }

  /// Login student with offline support
  Future<AuthResult> loginStudentWithOfflineSupport(String studentCode) async {
    if (!isDeviceRegistered) {
      return AuthResult.error('Device must be registered before student login');
    }

    if (_isAuthenticating) {
      return AuthResult.error('Student authentication already in progress');
    }

    _isAuthenticating = true;
    notifyListeners();

    try {
      // Validate student code format
      if (!_isValidStudentCode(studentCode)) {
        return AuthResult.error('Invalid student code format. Please enter a 4-6 character code.');
      }

      // Try offline authentication first
      final offlineStudent = await _databaseService.validateStudentOffline(studentCode.toUpperCase());
      if (offlineStudent != null) {
        final student = Student.fromJson(offlineStudent);
        await _loginStudentOffline(student);
        return AuthResult.success('Student logged in successfully (offline)');
      }

      // Try online authentication
      final hubUrl = await _hubDiscoveryService.getCurrentHubUrl();
      if (hubUrl == null) {
        // Queue login attempt for when online
        await _databaseService.queueStudentLogin({
          'studentCode': studentCode.toUpperCase(),
          'timestamp': DateTime.now().toIso8601String(),
        });
        return AuthResult.error('No network connection. Login attempt queued for when online.');
      }

      final response = await http.post(
        Uri.parse('$hubUrl/api/students/authenticate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'studentCode': studentCode.toUpperCase(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['student'] != null) {
          final student = Student.fromJson(data['student']);
          await _loginStudentOnlineWithCaching(student);
          return AuthResult.success('Student logged in successfully');
        } else {
          return AuthResult.error(data['message'] ?? 'Student authentication failed');
        }
      } else if (response.statusCode == 401) {
        return AuthResult.error('Invalid student code');
      } else {
        return AuthResult.error('Authentication failed. Please try again.');
      }
    } catch (e) {
      debugPrint('Student login error: $e');
      // Queue login attempt for when online
      await _databaseService.queueStudentLogin({
        'studentCode': studentCode.toUpperCase(),
        'timestamp': DateTime.now().toIso8601String(),
        'error': e.toString(),
      });
      return AuthResult.error('Network error. Login attempt queued for when online.');
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  /// Maintain authentication state during network outages
  Future<void> maintainAuthStateDuringOutage() async {
    await _databaseService.maintainAuthStateDuringOutage();
    
    // Update last seen for current device
    if (_currentDevice != null) {
      _currentDevice = _currentDevice!.copyWith(lastSeen: DateTime.now());
      await _saveDeviceData();
    }
    
    // Keep current session active
    if (_currentSession != null && _currentSession!.isActive) {
      await _databaseService.saveAuthSession({
        'deviceId': _currentSession!.deviceId,
        'studentId': _currentSession!.studentId,
        'sessionStart': _currentSession!.sessionStart.toIso8601String(),
        'isActive': 1,
        'lastActivity': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Sync offline authentication data when back online
  Future<void> syncOfflineAuthData() async {
    try {
      final hubUrl = await _hubDiscoveryService.getCurrentHubUrl();
      if (hubUrl == null) return;

      // Process pending registrations
      final pendingRegistrations = await _databaseService.getPendingOfflineRegistrations();
      
      for (final registration in pendingRegistrations) {
        try {
          final data = jsonDecode(registration['data']);
          
          if (registration['type'] == 'device_registration') {
            final response = await http.post(
              Uri.parse('$hubUrl/api/devices/register'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(data),
            );
            
            if (response.statusCode == 200 || response.statusCode == 201) {
              await _databaseService.markOfflineRegistrationCompleted(registration['id']);
              
              // Update current device if this was our registration
              final responseData = jsonDecode(response.body);
              if (responseData['success'] == true && responseData['device'] != null) {
                _currentDevice = Device.fromJson(responseData['device']);
                await _saveDeviceData();
                await _databaseService.cacheDeviceForOffline(_currentDevice!.toJson());
              }
            } else {
              await _databaseService.markOfflineRegistrationFailed(
                registration['id'], 
                'HTTP ${response.statusCode}'
              );
            }
          } else if (registration['type'] == 'student_login') {
            final response = await http.post(
              Uri.parse('$hubUrl/api/students/authenticate'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(data),
            );
            
            if (response.statusCode == 200) {
              final responseData = jsonDecode(response.body);
              if (responseData['success'] == true && responseData['student'] != null) {
                final student = Student.fromJson(responseData['student']);
                await _databaseService.cacheStudentForOffline(student.toJson());
                await _databaseService.markOfflineRegistrationCompleted(registration['id']);
              }
            } else {
              await _databaseService.markOfflineRegistrationFailed(
                registration['id'], 
                'HTTP ${response.statusCode}'
              );
            }
          }
        } catch (e) {
          await _databaseService.markOfflineRegistrationFailed(
            registration['id'], 
            e.toString()
          );
        }
      }

      // Sync authentication activity data
      final authDataForSync = await _databaseService.getOfflineAuthDataForSync();
      if (authDataForSync.isNotEmpty) {
        // Send activity data to hub for analytics
        final response = await http.post(
          Uri.parse('$hubUrl/api/analytics/sync-auth-activity'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'activities': authDataForSync}),
        );
        
        if (response.statusCode == 200) {
          await _databaseService.updateAuthCacheAfterSync({
            'deviceSynced': true,
            'studentsSynced': true,
          });
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error syncing offline auth data: $e');
    }
  }

  /// Get offline authentication statistics
  Future<Map<String, dynamic>> getOfflineAuthStats() async {
    return await _databaseService.getOfflineAuthStats();
  }

  /// Check if specific student is cached for offline use
  Future<bool> isStudentCachedForOffline(String studentCode) async {
    return await _databaseService.isStudentCachedForOffline(studentCode);
  }

  /// Check if device is cached for offline use
  Future<bool> isDeviceCachedForOffline(String deviceCode) async {
    return await _databaseService.isDeviceCachedForOffline(deviceCode);
  }

  /// Get offline authentication state
  Future<Map<String, dynamic>> getOfflineAuthState() async {
    return await _databaseService.getOfflineAuthState();
  }

  /// Private methods

  Future<void> _loadStoredData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load device data
    final deviceJson = prefs.getString(_registeredDeviceKey);
    if (deviceJson != null) {
      try {
        _currentDevice = Device.fromJson(jsonDecode(deviceJson));
        debugPrint('📱 Loaded device: ${_currentDevice?.id}');
      } catch (e) {
        debugPrint('Error loading device data: $e');
      }
    }

    // Load device code
    _currentDeviceCode = prefs.getString(_deviceCodeKey);
    debugPrint('📱 Loaded device code: $_currentDeviceCode');

    // Load cached students FIRST before loading session
    final studentsJson = prefs.getString(_cachedStudentsKey);
    if (studentsJson != null) {
      try {
        final List<dynamic> data = jsonDecode(studentsJson);
        _cachedStudents = data.map((json) => Student.fromJson(json)).toList();
        debugPrint('👥 Loaded ${_cachedStudents.length} cached students');
      } catch (e) {
        debugPrint('Error loading cached students: $e');
      }
    }

    // Load current session
    final sessionJson = prefs.getString(_currentSessionKey);
    if (sessionJson != null) {
      try {
        _currentSession = AuthSession.fromJson(jsonDecode(sessionJson));
        debugPrint('📝 Loaded session: studentId=${_currentSession?.studentId}, isActive=${_currentSession?.isActive}');
        
        // Load current student if session has studentId
        if (_currentSession?.studentId != null) {
          try {
            _currentStudent = _cachedStudents.firstWhere(
              (student) => student.id == _currentSession!.studentId,
            );
            debugPrint('👤 Restored current student: ${_currentStudent?.id} (${_currentStudent?.studentCode})');
          } catch (e) {
            debugPrint('⚠️ Student not found in cached students: ${_currentSession!.studentId}');
            // Try loading from database
            final cachedStudentsData = await DatabaseService.instance.getCachedStudents();
            final studentData = cachedStudentsData.firstWhere(
              (student) => student['id'] == _currentSession!.studentId,
              orElse: () => <String, dynamic>{},
            );
            
            if (studentData.isNotEmpty) {
              _currentStudent = Student(
                id: studentData['id'],
                studentCode: studentData['studentCode'],
                firstName: studentData['firstName'],
                lastName: studentData['lastName'],
                grade: studentData['grade'],
                age: studentData['age'],
                status: studentData['status'] ?? 'active',
                createdAt: studentData['createdAt'] != null 
                    ? DateTime.parse(studentData['createdAt'])
                    : DateTime.now(),
                updatedAt: studentData['updatedAt'] != null 
                    ? DateTime.parse(studentData['updatedAt'])
                    : DateTime.now(),
              );
              debugPrint('👤 Loaded student from database: ${_currentStudent?.id} (${_currentStudent?.studentCode})');
            } else {
              debugPrint('❌ Could not find student in database either');
            }
          }
        }
      } catch (e) {
        debugPrint('Error loading session data: $e');
        _currentSession = null;
        _currentStudent = null;
      }
    }
  }

  Future<void> _validateCurrentSession() async {
    if (_currentSession != null && _currentSession!.isActive) {
      // Check if session is still valid (not too old)
      final sessionAge = DateTime.now().difference(_currentSession!.sessionStart);
      if (sessionAge.inDays > 7) {
        // Session too old, clear it but don't start new session automatically
        _currentSession = null;
        await _saveSessionData();
      }
    }
    // Note: Removed automatic anonymous session creation
    // The authentication flow screen will determine the appropriate session type
    // based on hub settings
  }

  Future<void> _startAnonymousSession() async {
    if (_currentDevice == null) return;

    _currentSession = AuthSession(
      deviceId: _currentDevice!.id,
      sessionStart: DateTime.now(),
      isActive: true,
    );

    await _saveSessionData();
  }

  Future<void> _loginStudentOffline(Student student) async {
    await _endCurrentSession();
    
    _currentStudent = student;
    debugPrint('🔐 _currentStudent SET: ${student.id} (${student.studentCode})');
    
    _currentSession = AuthSession(
      deviceId: _currentDevice!.id,
      studentId: student.id,
      sessionStart: DateTime.now(),
      isActive: true,
    );
    debugPrint('🔐 _currentSession SET: deviceId=${_currentDevice!.id}, studentId=${student.id}');

    await _saveSessionData();
    notifyListeners();
  }

  Future<void> _loginStudentOnline(Student student) async {
    // Cache the student for offline use
    final existingIndex = _cachedStudents.indexWhere((s) => s.id == student.id);
    if (existingIndex >= 0) {
      _cachedStudents[existingIndex] = student;
    } else {
      _cachedStudents.add(student);
    }
    await _saveCachedStudents();

    await _loginStudentOffline(student);
  }

  Future<void> _loginStudentOnlineWithCaching(Student student) async {
    // Cache the student for offline use in database
    await _databaseService.cacheStudentForOffline(student.toJson());
    
    // Also cache in memory
    await _loginStudentOnline(student);
  }

  Future<void> _cacheStudentsForOffline() async {
    // Cache all students in database for offline use
    for (final student in _cachedStudents) {
      await _databaseService.cacheStudentForOffline(student.toJson());
    }
  }

  Future<void> _endCurrentSession() async {
    if (_currentSession != null && _currentSession!.isActive) {
      _currentSession = _currentSession!.copyWith(
        sessionEnd: DateTime.now(),
        isActive: false,
      );
      await _saveSessionData();
    }
  }

  Future<void> _saveDeviceData() async {
    if (_currentDevice == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_registeredDeviceKey, jsonEncode(_currentDevice!.toJson()));
  }

  Future<void> _saveDeviceCode() async {
    if (_currentDeviceCode == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceCodeKey, _currentDeviceCode!);
  }

  Future<void> _saveSessionData() async {
    if (_currentSession == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentSessionKey, jsonEncode(_currentSession!.toJson()));
  }

  Future<void> _saveCachedStudents() async {
    final prefs = await SharedPreferences.getInstance();
    final studentsJson = _cachedStudents.map((student) => student.toJson()).toList();
    await prefs.setString(_cachedStudentsKey, jsonEncode(studentsJson));
  }

  Future<DeviceInfo> _getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();
    
    String model = 'Unknown';
    String osVersion = 'Unknown';
    
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfoPlugin.androidInfo;
      model = '${androidInfo.manufacturer} ${androidInfo.model}';
      osVersion = 'Android ${androidInfo.version.release}';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfoPlugin.iosInfo;
      model = iosInfo.model;
      osVersion = '${iosInfo.systemName} ${iosInfo.systemVersion}';
    }

    return DeviceInfo(
      model: model,
      osVersion: osVersion,
      appVersion: packageInfo.version,
    );
  }

  bool _isValidDeviceCode(String code) {
    // Device codes should be 6-8 characters, alphanumeric
    final regex = RegExp(r'^[A-Z0-9]{6,8}$', caseSensitive: false);
    return regex.hasMatch(code);
  }

  bool _isValidStudentCode(String code) {
    // Student codes should be 4-6 characters, alphanumeric
    final regex = RegExp(r'^[A-Z0-9]{4,6}$', caseSensitive: false);
    return regex.hasMatch(code);
  }
}

/// Result class for authentication operations
class AuthResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  AuthResult._({
    required this.success,
    required this.message,
    this.data,
  });

  factory AuthResult.success(String message, [Map<String, dynamic>? data]) {
    return AuthResult._(success: true, message: message, data: data);
  }

  factory AuthResult.error(String message, [Map<String, dynamic>? data]) {
    return AuthResult._(success: false, message: message, data: data);
  }

  @override
  String toString() {
    return 'AuthResult(success: $success, message: $message)';
  }
}