import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/sync_service.dart';
import '../services/hub_discovery_service.dart';
import '../theme/app_theme.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> with SingleTickerProviderStateMixin {
  final _urlController = TextEditingController();
  final _hubDiscoveryService = HubDiscoveryService();
  late TabController _tabController;
  
  bool _isDiscovering = false;
  bool _isTestingConnection = false;
  bool? _connectionResult;
  List<DiscoveredHub> _discoveredHubs = [];
  DiscoveredHub? _selectedHub;
  String _discoveryStatus = '';
  String _networkInfo = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    final syncService = context.read<SyncService>();
    if (syncService.edgeHubUrl != null) {
      _urlController.text = syncService.edgeHubUrl!;
    }
    _loadNetworkInfo();
    _startDiscovery();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _connectionResult = null;
        _selectedHub = null;
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNetworkInfo() async {
    final info = await _hubDiscoveryService.getNetworkInfo();
    setState(() {
      _networkInfo = info;
    });
  }

  Future<void> _startDiscovery() async {
    setState(() {
      _isDiscovering = true;
      _discoveredHubs.clear();
      _selectedHub = null;
      _discoveryStatus = 'Starting discovery...';
    });

    try {
      final hubs = await _hubDiscoveryService.discoverHubs(
        onProgress: (status) {
          setState(() {
            _discoveryStatus = status;
          });
        },
      );

      setState(() {
        _discoveredHubs = hubs;
        _isDiscovering = false;
        if (hubs.isNotEmpty) {
          _discoveryStatus = 'Found ${hubs.length} hub(s)';
          // Automatically select the first hub
          _selectHub(hubs.first);
        } else {
          _discoveryStatus = 'No hubs found on network';
        }
      });
    } catch (e) {
      setState(() {
        _isDiscovering = false;
        _discoveryStatus = 'Discovery failed: $e';
      });
    }
  }

  Future<void> _testConnection() async {
    if (_urlController.text.isEmpty) return;

    setState(() {
      _isTestingConnection = true;
      _connectionResult = null;
    });

    final syncService = context.read<SyncService>();
    await syncService.setEdgeHubUrl(_urlController.text);
    final result = await syncService.testConnection();

    setState(() {
      _isTestingConnection = false;
      _connectionResult = result;
    });
  }

  Future<void> _selectHub(DiscoveredHub hub) async {
    setState(() {
      _selectedHub = hub;
      _urlController.text = hub.url;
      _connectionResult = null;
    });
    
    // Automatically save the hub URL to sync service
    final syncService = context.read<SyncService>();
    await syncService.setEdgeHubUrl(hub.url);
  }

  Future<void> _testLocalhost() async {
    setState(() {
      _discoveryStatus = 'Testing localhost...';
    });

    try {
      // Test common localhost addresses
      final testIPs = ['10.0.2.2', '192.168.1.7', '127.0.0.1']; // Common addresses for development
      
      for (final ip in testIPs) {
        final hub = await _hubDiscoveryService.testSpecificIP(ip);
        if (hub != null) {
          setState(() {
            _discoveredHubs = [hub];
            _discoveryStatus = 'Found hub on $ip';
          });
          await _selectHub(hub);
          return;
        }
      }
      
      setState(() {
        _discoveryStatus = 'No hub found on localhost';
      });
    } catch (e) {
      setState(() {
        _discoveryStatus = 'Localhost test failed: $e';
      });
    }
  }

  bool _isButtonDisabled() {
    if (_tabController.index == 0) {
      // Auto Find tab: disabled if discovering or no hub selected
      return _isDiscovering || _selectedHub == null;
    } else {
      // Manual tab: disabled if connection not successful
      return _connectionResult != true;
    }
  }

  Future<void> _performSync() async {
    final syncService = context.read<SyncService>();
    final result = await syncService.syncContent();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? AppTheme.success : AppTheme.error,
        ),
      );

      if (result.success) {
        // After successful sync, go to authentication flow to check hub settings
        // This ensures proper authentication flow based on hub configuration
        if (context.canPop()) {
          context.pop();
        } else {
          // Go to auth flow instead of home to check hub settings
          context.go('/auth');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf0faf8),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFf0faf8), // Very subtle light green
              Color(0xFFecf8f5), // Slightly more green tint
              Color(0xFFe8f6f2), // Light green tint
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom app bar
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        // Check if we can pop (there's a previous route)
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          // If no previous route, go to home screen
                          context.go('/');
                        }
                      },
                      icon: const Icon(Icons.arrow_back, size: 28),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.textPrimary,
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingMd),
                    const Expanded(
                      child: Text(
                        '🌟 Connect to Story Hub',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Network status card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF19a88c), Color(0xFF22C55E)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Center(
                        child: Text('📶', style: TextStyle(fontSize: 28)),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Network Status',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingXs),
                          Text(
                            _networkInfo,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingLg),

              // Tab bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF19a88c), Color(0xFF22C55E)],
                    ),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppTheme.textSecondary,
                  labelStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('🔍', style: TextStyle(fontSize: 18)),
                          SizedBox(width: 8),
                          Text('Auto Find'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('⚙️', style: TextStyle(fontSize: 18)),
                          SizedBox(width: 8),
                          Text('Manual'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingLg),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAutoDiscoveryTab(),
                    _buildManualConnectionTab(),
                  ],
                ),
              ),

              // Bottom sync section - make it flexible to avoid overflow
              _buildSyncSection(),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildAutoDiscoveryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        children: [
          // Fun discovery card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spacingXl),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Fun discovery icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF19a88c), Color(0xFF22C55E)],
                    ),
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF19a88c).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🔍', style: TextStyle(fontSize: 40)),
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingLg),
                
                const Text(
                  'Looking for Story Hubs!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: AppTheme.spacingSm),
                
                const Text(
                  'I\'m searching for story hubs on your network. This is like magic - I can find them automatically!',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: AppTheme.spacingLg),
                
                // Discovery status
                if (_isDiscovering) ...[
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingLg),
                    decoration: BoxDecoration(
                      color: const Color(0xFF19a88c).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(
                        color: const Color(0xFF19a88c).withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF19a88c)),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Searching...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                _discoveryStatus,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_discoveredHubs.isNotEmpty) ...[
                  // Success! Show discovered hubs
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingLg),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(
                        color: AppTheme.success.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text('🎉', style: TextStyle(fontSize: 24)),
                            const SizedBox(width: AppTheme.spacingSm),
                            Expanded(
                              child: Text(
                                'Found ${_discoveredHubs.length} Story Hub${_discoveredHubs.length > 1 ? 's' : ''}!',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingMd),
                        
                        // List of discovered hubs
                        ...(_discoveredHubs.map((hub) => Container(
                          margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
                          decoration: BoxDecoration(
                            color: _selectedHub == hub 
                                ? const Color(0xFF19a88c).withOpacity(0.2)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                            border: Border.all(
                              color: _selectedHub == hub 
                                  ? const Color(0xFF19a88c)
                                  : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(AppTheme.spacingMd),
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF19a88c), Color(0xFF22C55E)],
                                ),
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: const Center(
                                child: Text('🏠', style: TextStyle(fontSize: 24)),
                              ),
                            ),
                            title: Text(
                              hub.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              'Super fast! (${hub.responseTime}ms)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: _selectedHub == hub 
                                ? Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF19a88c),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: const Center(
                                      child: Text('✓', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                                    ),
                                  )
                                : null,
                            onTap: () async => await _selectHub(hub),
                          ),
                        ))),
                      ],
                    ),
                  ),
                ] else ...[
                  // No hubs found
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingLg),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(
                        color: AppTheme.accent.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text('🤔', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: AppTheme.spacingMd),
                        const Text(
                          'Hmm, I couldn\'t find any story hubs',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppTheme.spacingSm),
                        Text(
                          _discoveryStatus,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: AppTheme.spacingLg),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isDiscovering ? null : _startDiscovery,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF19a88c),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingLg),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                          ),
                          elevation: 4,
                          shadowColor: const Color(0xFF19a88c).withOpacity(0.3),
                        ),
                        icon: _isDiscovering 
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.refresh, size: 20),
                        label: Text(
                          _isDiscovering ? 'Searching...' : '🔍 Search Again',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingMd),
                    ElevatedButton(
                      onPressed: _testLocalhost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingLg,
                          vertical: AppTheme.spacingLg,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                        ),
                        elevation: 4,
                      ),
                      child: const Text('💻', style: TextStyle(fontSize: 20)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualConnectionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        children: [
          // Manual connection card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spacingXl),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Manual connection icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)],
                    ),
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF60A5FA).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('⚙️', style: TextStyle(fontSize: 40)),
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingLg),
                
                const Text(
                  'Manual Connection',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: AppTheme.spacingSm),
                
                const Text(
                  'If the automatic search didn\'t work, you can enter the story hub address yourself. Ask a grown-up to help!',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: AppTheme.spacingXl),
                
                // Input field
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(
                      color: const Color(0xFF19a88c).withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: '🏠 Story Hub Address',
                      hintText: 'https://edgehub.hiqma.org',
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF19a88c),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.link, color: Colors.white),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(AppTheme.spacingLg),
                      labelStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      hintStyle: const TextStyle(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    keyboardType: TextInputType.url,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingLg),
                
                // Test connection button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isTestingConnection ? null : _testConnection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF19a88c),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingLg),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                      ),
                      elevation: 4,
                      shadowColor: const Color(0xFF19a88c).withOpacity(0.3),
                    ),
                    icon: _isTestingConnection
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.wifi_find, size: 20),
                    label: Text(
                      _isTestingConnection ? 'Testing...' : '🔍 Test Connection',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                
                // Connection result
                if (_connectionResult != null) ...[
                  const SizedBox(height: AppTheme.spacingLg),
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingLg),
                    decoration: BoxDecoration(
                      color: _connectionResult! 
                          ? AppTheme.success.withOpacity(0.1)
                          : AppTheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(
                        color: _connectionResult! 
                            ? AppTheme.success.withOpacity(0.3)
                            : AppTheme.error.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _connectionResult! ? '✅' : '❌',
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: AppTheme.spacingMd),
                        Expanded(
                          child: Text(
                            _connectionResult! 
                                ? 'Great! Connection successful!'
                                : 'Oops! Couldn\'t connect. Check the address.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _connectionResult! 
                                  ? AppTheme.success
                                  : AppTheme.error,
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
        ],
      ),
    );
  }

  Widget _buildSyncSection() {
    return Consumer<SyncService>(
      builder: (context, syncService, child) {
        return Container(
          margin: const EdgeInsets.all(AppTheme.spacingMd),
          constraints: const BoxConstraints(
            maxHeight: 600, // Limit maximum height to prevent overflow
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sync status header
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                        ),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const Center(
                        child: Text('📊', style: TextStyle(fontSize: 24)),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            syncService.isSyncing ? 'Syncing Stories...' : 'Ready to Sync!',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            syncService.syncedCount > 0 
                                ? '${syncService.syncedCount} stories downloaded'
                                : 'No stories yet - let\'s get some!',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Sync stages (show when syncing) - make more compact
                if (syncService.isSyncing && syncService.syncStages.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacingMd),
                  Container(
                    constraints: const BoxConstraints(
                      maxHeight: 300, // Limit stages height
                    ),
                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                    decoration: BoxDecoration(
                      color: const Color(0xFF19a88c).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(
                        color: const Color(0xFF19a88c).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Sync Progress',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingSm),
                        
                        // Scrollable sync stages list
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              children: syncService.syncStages.asMap().entries.map((entry) {
                                final index = entry.key;
                                final stage = entry.value;
                                final isCurrentStage = index == syncService.currentStageIndex;
                                
                                return Container(
                                  margin: const EdgeInsets.only(bottom: AppTheme.spacingXs),
                                  padding: const EdgeInsets.all(AppTheme.spacingSm),
                                  decoration: BoxDecoration(
                                    color: _getStageBackgroundColor(stage.status, isCurrentStage),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                    border: isCurrentStage ? Border.all(
                                      color: const Color(0xFF19a88c),
                                      width: 2,
                                    ) : null,
                                  ),
                                  child: Row(
                                    children: [
                                      // Stage emoji and status indicator - smaller
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: _getStageIndicatorColor(stage.status),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Center(
                                          child: _getStageStatusWidget(stage.status, stage.emoji),
                                        ),
                                      ),
                                      
                                      const SizedBox(width: AppTheme.spacingSm),
                                      
                                      // Stage info - more compact
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              stage.title,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: _getStageTextColor(stage.status),
                                              ),
                                            ),
                                            if (stage.details != null) ...[
                                              const SizedBox(height: 1),
                                              Text(
                                                stage.details!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: _getStageTextColor(stage.status).withOpacity(0.8),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                            
                                            // Progress bar for current stage - smaller
                                            if (isCurrentStage && stage.progress != null) ...[
                                              const SizedBox(height: 2),
                                              SizedBox(
                                                height: 3,
                                                child: LinearProgressIndicator(
                                                  value: stage.progress! / 100,
                                                  backgroundColor: Colors.grey.withOpacity(0.3),
                                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF19a88c)),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      
                                      // Duration (for completed stages) - smaller
                                      if (stage.duration != null) ...[
                                        const SizedBox(width: AppTheme.spacingXs),
                                        Text(
                                          '${stage.duration!.inMilliseconds}ms',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: _getStageTextColor(stage.status).withOpacity(0.6),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: AppTheme.spacingMd),
                
                // Big sync button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: syncService.isSyncing || _isButtonDisabled()
                        ? null
                        : _performSync,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF19a88c),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingLg),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                      ),
                      elevation: 8,
                      shadowColor: const Color(0xFF19a88c).withOpacity(0.4),
                    ),
                    icon: syncService.isSyncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.download, size: 20),
                    label: Text(
                      syncService.isSyncing 
                          ? '⏳ ${syncService.currentStage?.title ?? 'Syncing...'}' 
                          : '🚀 Download Stories!',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacingSm),
                
                // Help text - more compact
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingSm),
                  decoration: BoxDecoration(
                    color: const Color(0xFF19a88c).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: const Row(
                    children: [
                      Text('💡', style: TextStyle(fontSize: 16)),
                      SizedBox(width: AppTheme.spacingXs),
                      Expanded(
                        child: Text(
                          'Choose a story hub above, then tap the big button to download amazing stories!',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper methods for stage styling
  Color _getStageBackgroundColor(SyncStageStatus status, bool isCurrentStage) {
    if (isCurrentStage) {
      return const Color(0xFF19a88c).withOpacity(0.1);
    }
    
    switch (status) {
      case SyncStageStatus.completed:
        return AppTheme.success.withOpacity(0.1);
      case SyncStageStatus.failed:
        return AppTheme.error.withOpacity(0.1);
      case SyncStageStatus.skipped:
        return Colors.grey.withOpacity(0.1);
      default:
        return Colors.transparent;
    }
  }

  Color _getStageIndicatorColor(SyncStageStatus status) {
    switch (status) {
      case SyncStageStatus.inProgress:
        return const Color(0xFF19a88c);
      case SyncStageStatus.completed:
        return AppTheme.success;
      case SyncStageStatus.failed:
        return AppTheme.error;
      case SyncStageStatus.skipped:
        return Colors.grey;
      default:
        return Colors.grey.withOpacity(0.3);
    }
  }

  Color _getStageTextColor(SyncStageStatus status) {
    switch (status) {
      case SyncStageStatus.inProgress:
        return const Color(0xFF19a88c);
      case SyncStageStatus.completed:
        return AppTheme.success;
      case SyncStageStatus.failed:
        return AppTheme.error;
      default:
        return AppTheme.textPrimary;
    }
  }

  Widget _getStageStatusWidget(SyncStageStatus status, String emoji) {
    switch (status) {
      case SyncStageStatus.inProgress:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
      case SyncStageStatus.completed:
        return const Icon(Icons.check, color: Colors.white, size: 16);
      case SyncStageStatus.failed:
        return const Icon(Icons.close, color: Colors.white, size: 16);
      case SyncStageStatus.skipped:
        return const Icon(Icons.remove, color: Colors.white, size: 16);
      default:
        return Text(emoji, style: const TextStyle(fontSize: 16));
    }
  }
}