import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/authentication_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import 'student_login_screen.dart';

/// Screen that handles the authentication flow based on hub settings
class AuthenticationFlowScreen extends StatefulWidget {
  const AuthenticationFlowScreen({super.key});

  @override
  State<AuthenticationFlowScreen> createState() => _AuthenticationFlowScreenState();
}

class _AuthenticationFlowScreenState extends State<AuthenticationFlowScreen> {
  bool _isLoading = true;
  bool _isCheckingSettings = true;
  String _status = 'Checking hub settings...';
  Map<String, dynamic>? _hubSettings;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkHubSettingsAndProceed();
  }

  Future<void> _checkHubSettingsAndProceed() async {
    try {
      debugPrint('🔍 AuthenticationFlowScreen: Starting hub settings check');
      
      setState(() {
        _isCheckingSettings = true;
        _status = 'Connecting to learning hub...';
      });

      final syncService = context.read<SyncService>();
      final authService = context.read<AuthenticationService>();

      debugPrint('🔍 AuthenticationFlowScreen: Current auth state - isDeviceRegistered: ${authService.isDeviceRegistered}, currentSession: ${authService.currentSession}');

      // First ensure we have a hub URL
      if (syncService.edgeHubUrl == null) {
        debugPrint('🔍 AuthenticationFlowScreen: No hub URL configured, redirecting to sync');
        setState(() {
          _status = 'No hub configured. Redirecting to sync...';
        });
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          context.go('/sync');
        }
        return;
      }

      setState(() {
        _status = 'Getting hub authentication settings...';
      });

      // Get hub settings
      _hubSettings = await syncService.getHubSettings();
      debugPrint('🔍 AuthenticationFlowScreen: Retrieved hub settings: $_hubSettings');

      if (_hubSettings == null) {
        // If we can't get hub settings, default to allowing anonymous access
        debugPrint('🔍 AuthenticationFlowScreen: Could not fetch hub settings, defaulting to anonymous access');
        setState(() {
          _status = 'Using default settings...';
        });
        await Future.delayed(const Duration(milliseconds: 500));
        await authService.startAnonymousSession();
        if (mounted) {
          context.go('/');
        }
        return;
      }

      setState(() {
        _status = 'Processing authentication requirements...';
      });

      // Check authentication requirements
      final requiresStudentAuth = _hubSettings!['requireStudentAuthentication'] == true;
      final allowsAnonymousAccess = _hubSettings!['allowAnonymousAccess'] == true;

      debugPrint('🔍 AuthenticationFlowScreen: Hub settings - requireStudentAuth=$requiresStudentAuth, allowAnonymousAccess=$allowsAnonymousAccess');

      if (requiresStudentAuth && !allowsAnonymousAccess) {
        // Student authentication is required
        debugPrint('🔍 AuthenticationFlowScreen: Student authentication REQUIRED - showing login screen');
        setState(() {
          _isLoading = false;
          _isCheckingSettings = false;
          _status = 'Student authentication required';
        });
      } else if (allowsAnonymousAccess && !requiresStudentAuth) {
        // Anonymous access is allowed, proceed directly
        debugPrint('🔍 AuthenticationFlowScreen: Anonymous access allowed - proceeding to home');
        setState(() {
          _status = 'Anonymous access allowed. Loading content...';
        });
        await authService.startAnonymousSession();
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          context.go('/');
        }
      } else {
        // Invalid configuration - both disabled or both enabled
        debugPrint('🔍 AuthenticationFlowScreen: Invalid hub configuration');
        setState(() {
          _errorMessage = 'Invalid hub configuration. Please contact your administrator.';
          _isLoading = false;
          _isCheckingSettings = false;
        });
      }

    } catch (e) {
      debugPrint('🔍 AuthenticationFlowScreen: Error checking hub settings: $e');
      setState(() {
        _errorMessage = 'Failed to connect to learning hub: ${e.toString()}';
        _isLoading = false;
        _isCheckingSettings = false;
      });
    }
  }

  Future<void> _loginStudent(String studentCode) async {
    setState(() {
      _isLoading = true;
      _status = 'Login successful! Loading content...';
    });

    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      context.go('/');
    }
  }

  Future<void> _continueAnonymously() async {
    setState(() {
      _isLoading = true;
      _status = 'Starting anonymous session...';
    });

    final authService = context.read<AuthenticationService>();
    await authService.startAnonymousSession();
    
    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFEFEFE), Color(0xFFFDFDFD), Color(0xFFFCFCFC)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingXl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App logo/icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                      child: Image.asset(
                        'assets/logo.png',
                        width: 60,
                        height: 60,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacingXl),

                  // App title
                  const Text(
                    'Hiqma Learning',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacingXxl),

                  if (_isCheckingSettings) ...[
                    // Loading indicator
                    const CircularProgressIndicator(color: AppTheme.primary),
                    const SizedBox(height: AppTheme.spacingLg),
                    Text(
                      _status,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else if (_errorMessage != null) ...[
                    // Error state
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingLg),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: AppTheme.spacingMd),
                          const Text(
                            'Connection Error',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingMd),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppTheme.textSecondary,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppTheme.spacingLg),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => context.go('/sync'),
                                  child: const Text('Setup Hub'),
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingMd),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _checkHubSettingsAndProceed,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Retry'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else if (_hubSettings != null && _hubSettings!['requireStudentAuthentication'] == true) ...[
                    // Student authentication required
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingLg),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.person,
                            size: 48,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(height: AppTheme.spacingMd),
                          const Text(
                            'Student Login Required',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingMd),
                          
                          // Show custom authentication message if available
                          if (_hubSettings!['authenticationMessage'] != null && 
                              _hubSettings!['authenticationMessage'].toString().isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(AppTheme.spacingMd),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                              ),
                              child: Text(
                                _hubSettings!['authenticationMessage'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppTheme.textPrimary,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingLg),
                          ] else ...[
                            const Text(
                              'Please enter your student code to access learning content.',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppTheme.textSecondary,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppTheme.spacingLg),
                          ],

                          // Embed student login form
                          _buildStudentLoginForm(),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentLoginForm() {
    return Consumer<AuthenticationService>(
      builder: (context, authService, child) {
        return StudentLoginForm(
          onLogin: _loginStudent,
          isLoading: _isLoading,
          errorMessage: _errorMessage,
          showAnonymousOption: false, // Never show anonymous option when auth is required
        );
      },
    );
  }
}

/// Reusable student login form widget
class StudentLoginForm extends StatefulWidget {
  final Function(String) onLogin;
  final bool isLoading;
  final String? errorMessage;
  final bool showAnonymousOption;

  const StudentLoginForm({
    super.key,
    required this.onLogin,
    this.isLoading = false,
    this.errorMessage,
    this.showAnonymousOption = true,
  });

  @override
  State<StudentLoginForm> createState() => _StudentLoginFormState();
}

class _StudentLoginFormState extends State<StudentLoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _studentCodeController = TextEditingController();
  String? _localErrorMessage;

  @override
  void dispose() {
    _studentCodeController.dispose();
    super.dispose();
  }

  String? _validateStudentCode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a student code';
    }
    
    final cleanCode = value.trim().toUpperCase();
    if (cleanCode.length < 4 || cleanCode.length > 6) {
      return 'Student code must be 4-6 characters';
    }
    
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(cleanCode)) {
      return 'Student code can only contain letters and numbers';
    }
    
    return null;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Clear any previous error
    setState(() {
      _localErrorMessage = null;
    });
    
    // Call the parent's onLogin method and handle the result
    final authService = context.read<AuthenticationService>();
    final result = await authService.loginStudent(_studentCodeController.text.trim());
    
    if (mounted) {
      if (result.success) {
        // Success will be handled by the parent
        widget.onLogin(_studentCodeController.text.trim());
      } else {
        // Show error in the form
        setState(() {
          _localErrorMessage = result.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Show error message if there is one
          if (_localErrorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _localErrorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Student code input - Child-friendly design
          Center(
            child: SizedBox(
              width: 200, // Shorter width for the short code
              child: TextFormField(
                controller: _studentCodeController,
                style: const TextStyle(
                  fontSize: 32, // Large font for children
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4, // Space between characters for readability
                ),
                textAlign: TextAlign.center, // Center the text
                decoration: InputDecoration(
                  labelText: 'Student Code',
                  labelStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  hintText: 'ABC123',
                  hintStyle: TextStyle(
                    fontSize: 28,
                    color: Colors.grey.withOpacity(0.5),
                    letterSpacing: 4,
                  ),
                  prefixIcon: const Icon(
                    Icons.badge,
                    size: 28,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: AppTheme.primary.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppTheme.primary,
                      width: 3,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20, // More padding for the larger text
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: _validateStudentCode,
                onChanged: (value) {
                  // Clear error when user types
                  if (_localErrorMessage != null) {
                    setState(() {
                      _localErrorMessage = null;
                    });
                  }
                },
                onFieldSubmitted: (_) => _submitForm(),
              ),
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingLg),
          
          // Login button - Child-friendly design
          Center(
            child: SizedBox(
              width: 200, // Match the input width
              height: 64, // Taller button for children
              child: ElevatedButton(
                onPressed: widget.isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4, // More elevation for a playful look
                ),
                child: widget.isLoading
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 20, // Larger font for children
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
          
          // Help text - Child-friendly design
          const SizedBox(height: AppTheme.spacingLg),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.help_outline,
                  color: Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Ask your teacher for your student code!',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}