import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/authentication_service.dart';
import '../services/hub_discovery_service.dart';
import '../theme/app_theme.dart';

/// Screen that handles app initialization and device registration
class InitializationScreen extends StatefulWidget {
  const InitializationScreen({Key? key}) : super(key: key);

  @override
  State<InitializationScreen> createState() => _InitializationScreenState();
}

class _InitializationScreenState extends State<InitializationScreen> {
  bool _isInitializing = true;
  String _initializationStatus = 'Initializing app...';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() {
        _initializationStatus = 'Setting up services...';
      });

      // Initialize authentication service
      final authService = context.read<AuthenticationService>();
      await authService.initialize();

      setState(() {
        _initializationStatus = 'Checking device registration...';
      });

      // Check if device is already registered
      if (authService.isDeviceRegistered &&
          authService.currentDeviceCode != null) {
        // Device is registered, proceed to authentication flow
        debugPrint('🔍 InitializationScreen: Device is registered, proceeding to auth flow');
        setState(() {
          _initializationStatus = 'Device registered! Checking authentication...';
        });

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          debugPrint('🔍 InitializationScreen: Navigating to /auth');
          context.go('/auth');
        }
      } else {
        // Device not registered, show registration screen
        debugPrint('🔍 InitializationScreen: Device not registered, showing registration UI');
        setState(() {
          _initializationStatus = 'Device registration required';
          _isInitializing = false;
        });
      }
    } catch (e) {
      setState(() {
        _initializationStatus = 'Initialization failed: ${e.toString()}';
        _isInitializing = false;
      });
    }
  }

  Future<void> _autoRegisterDevice() async {
    setState(() {
      _isInitializing = true;
      _initializationStatus = 'Searching for learning hub...';
    });

    try {
      // First, discover the hub
      final hubDiscoveryService = context.read<HubDiscoveryService>();

      setState(() {
        _initializationStatus = 'Scanning network for learning hub...';
      });

      final hubUrl = await hubDiscoveryService.getCurrentHubUrl();

      if (hubUrl == null) {
        setState(() {
          _initializationStatus = 'No learning hub found on network';
          _isInitializing = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No learning hub found. Please ensure you are connected to the same Wi-Fi network as the hub.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      setState(() {
        _initializationStatus = 'Found learning hub! Registering device...';
      });

      // Now register the device
      final authService = context.read<AuthenticationService>();
      final result = await authService.autoRegisterDevice();

      if (result.success) {
        setState(() {
          _initializationStatus = 'Registration successful! Checking authentication...';
        });

        await Future.delayed(const Duration(milliseconds: 1000));

        if (mounted) {
          context.go('/auth');
        }
      } else {
        setState(() {
          _initializationStatus = 'Registration failed: ${result.message}';
          _isInitializing = false;
        });

        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _initializationStatus = 'Registration failed: ${e.toString()}';
        _isInitializing = false;
      });
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
                    width: 180,
                    height: 180,
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
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacingMd),

                  const Text(
                    'Interactive Learning for Everyone',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppTheme.spacingXxl),

                  if (_isInitializing) ...[
                    // Loading indicator
                    const CircularProgressIndicator(color: AppTheme.primary),

                    const SizedBox(height: AppTheme.spacingLg),

                    Text(
                      _initializationStatus,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    // Registration required message
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
                            Icons.devices,
                            size: 48,
                            color: AppTheme.primary,
                          ),

                          const SizedBox(height: AppTheme.spacingMd),

                          const Text(
                            'Device Registration Required',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),

                          const SizedBox(height: AppTheme.spacingMd),

                          const Text(
                            'To get started, this device needs to be registered with the learning hub. A device code will be automatically assigned.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: AppTheme.textPrimary,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: AppTheme.spacingLg),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _autoRegisterDevice(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMd,
                                  ),
                                ),
                              ),
                              child: const Text(
                                'Register Device',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: AppTheme.spacingMd),

                          TextButton(
                            onPressed: () => context.go('/device-registration'),
                            child: const Text(
                              'I have a specific device code',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
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
}
