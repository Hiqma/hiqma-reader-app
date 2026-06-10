import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'services/database_service.dart';
import 'services/sync_service.dart';
import 'services/authentication_service.dart';
import 'services/hub_discovery_service.dart';
import 'screens/initialization_screen.dart';
import 'screens/device_registration_screen.dart';
import 'screens/authentication_flow_screen.dart';
import 'screens/home_screen.dart';
import 'screens/book_detail_screen.dart';
import 'screens/content_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/sync_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize database
  await DatabaseService.instance.initDatabase();
  
  runApp(const HiqmaLearningApp());
}

class HiqmaLearningApp extends StatelessWidget {
  const HiqmaLearningApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<HubDiscoveryService>(create: (_) => HubDiscoveryService()),
        ChangeNotifierProvider<AuthenticationService>(
          create: (context) => AuthenticationService(
            databaseService: DatabaseService.instance,
            hubDiscoveryService: Provider.of<HubDiscoveryService>(context, listen: false),
          ),
        ),
        ChangeNotifierProvider<SyncService>(
          create: (context) => SyncService(
            authenticationService: Provider.of<AuthenticationService>(context, listen: false),
          ),
        ),
      ],
      child: MaterialApp.router(
        title: 'Hiqma Learning',
        theme: AppTheme.lightTheme,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

final GoRouter _router = GoRouter(
  initialLocation: '/init',
  routes: [
    GoRoute(
      path: '/init',
      builder: (context, state) => const InitializationScreen(),
    ),
    GoRoute(
      path: '/device-registration',
      builder: (context, state) => const DeviceRegistrationScreen(),
    ),
    GoRoute(
      path: '/auth',
      builder: (context, state) => const AuthenticationFlowScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/book/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final title = state.uri.queryParameters['title'] ?? '';
        return BookDetailScreen(contentId: id, title: title);
      },
    ),
    GoRoute(
      path: '/content/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final title = state.uri.queryParameters['title'] ?? '';
        return ContentScreen(contentId: id, title: title);
      },
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/sync',
      builder: (context, state) => const SyncScreen(),
    ),
  ],
);