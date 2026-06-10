import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/content.dart';
import '../models/reading_progress.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../services/authentication_service.dart';
import '../widgets/device_code_display.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Content> _allContent = [];
  List<Content> _filteredContent = [];
  List<ReadingProgress> _currentlyReading = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  bool _hubConnected = false;
  String _activeCategory = 'All';
  List<Map<String, String>> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkHubConnection();

    // Add observer to detect when app comes back into focus
    WidgetsBinding.instance.addObserver(this);

    // Listen to sync service changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final syncService = context.read<SyncService>();
      syncService.addListener(_onSyncServiceChanged);
    });
  }

  @override
  void dispose() {
    // Remove observer and listener to prevent memory leaks
    WidgetsBinding.instance.removeObserver(this);
    final syncService = context.read<SyncService>();
    syncService.removeListener(_onSyncServiceChanged);
    super.dispose();
  }

  void _onSyncServiceChanged() {
    // Reload data when sync service state changes (e.g., sync completes)
    if (!context.read<SyncService>().isSyncing) {
      _loadData();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh data when app comes back into focus
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  // Method to refresh data when returning from other screens
  void _refreshOnReturn() {
    if (mounted) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final content = await DatabaseService.instance.getAllContent();
      final currentlyReading = await DatabaseService.instance
          .getCurrentlyReading();
      final stats = await DatabaseService.instance.getReadingStats();

      setState(() {
        _allContent = content;
        _categories = _generateCategoriesFromContent(content);

        // Reset active category to 'All' if current category no longer exists
        if (!_categories.any((cat) => cat['id'] == _activeCategory)) {
          _activeCategory = 'All';
        }

        _filteredContent = _getFilteredContent();
        _currentlyReading = currentlyReading;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('HomeScreen: Error loading data: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  List<Map<String, String>> _generateCategoriesFromContent(
    List<Content> content,
  ) {
    // Start with "All" category
    final categories = <Map<String, String>>[
      {'id': 'All', 'label': 'All', 'icon': '📚'},
    ];

    // Get distinct categories from content (preserve original case)
    final distinctCategories = content
        .map((item) => item.category.trim())
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList();

    // Sort categories alphabetically
    distinctCategories.sort();

    // Add each category using the original category name as both id and label
    for (final category in distinctCategories) {
      categories.add({
        'id': category,
        'label': category,
        'icon': '📖', // Simple book icon for all categories
      });
    }

    return categories;
  }

  List<Content> _getFilteredContent() {
    // Get content IDs that are currently being read
    final currentlyReadingIds = _currentlyReading
        .map((progress) => progress.contentId)
        .toSet();

    // Filter out currently reading books from the main list
    List<Content> availableContent = _allContent
        .where((content) => !currentlyReadingIds.contains(content.id))
        .toList();

    // Apply category filter
    if (_activeCategory != 'All') {
      availableContent = availableContent
          .where((content) => content.category.trim() == _activeCategory)
          .toList();
    }

    // Sort by category to group books of the same category together
    availableContent.sort((a, b) => a.category.compareTo(b.category));

    return availableContent;
  }

  void _checkHubConnection() {
    // Simulate hub connection check
    setState(() {
      _hubConnected = true; // You can implement real connection check here
    });
  }

  Future<void> _handleSync() async {
    final syncService = context.read<SyncService>();

    if (syncService.edgeHubUrl == null) {
      context.push('/sync');
      return;
    }

    final result = await syncService.syncContent();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? AppTheme.success : AppTheme.error,
        ),
      );

      // Always reload data after sync attempt to refresh the UI
      if (result.success) {
        await _loadData();
      }
    }
  }

  Future<void> _handleForceSync() async {
    final syncService = context.read<SyncService>();

    // Clear cached hub URL to force rediscovery
    await syncService.clearEdgeHubUrl();

    // Now attempt sync which will trigger rediscovery
    final result = await syncService.syncContent();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? AppTheme.success : AppTheme.error,
        ),
      );

      // Always reload data after sync attempt to refresh the UI
      if (result.success) {
        await _loadData();
      }
    }
  }

  String _getContentIcon(String category) {
    const icons = {
      'folktales': '🧚‍♀️',
      'poetry': '🎵',
      'short-stories': '📖',
      'historical': '🏰',
      'mathematics': '🔢',
      'science': '🔬',
    };
    return icons[category.toLowerCase()] ?? '📚';
  }

  String _getFunDescription(String category) {
    const descriptions = {
      'folktales': 'Magic Stories',
      'poetry': 'Fun Poems',
      'short-stories': 'Quick Tales',
      'historical': 'Old Times',
      'mathematics': 'Number Fun',
      'science': 'Cool Facts',
    };
    return descriptions[category.toLowerCase()] ?? 'Fun Story';
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
            colors: [
              Color(0xFFFEFEFE), // Almost white
              Color(0xFFFDFDFD), // Very subtle tint
              Color(0xFFFCFCFC), // Barely noticeable teal tint
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                )
              : Column(
                  children: [
                    // App bar
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingMd),
                      child: Row(
                        children: [
                          // Device code display on the left
                          Consumer<AuthenticationService>(
                            builder: (context, authService, child) {
                              return CompactDeviceCodeDisplay(
                                authenticationService: authService,
                              );
                            },
                          ),

                          // App title with logo in the center
                          Expanded(
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/images/hiqma_logo.png',
                                    width: 24,
                                    height: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Hiqma Learning',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Sync status indicator on the right
                          Consumer<SyncService>(
                            builder: (context, syncService, child) {
                              if (syncService.isSyncing) {
                                return const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primary,
                                  ),
                                );
                              }
                              return Icon(
                                _hubConnected
                                    ? Icons.cloud_done
                                    : Icons.cloud_off,
                                size: 16,
                                color: _hubConnected
                                    ? AppTheme.success
                                    : AppTheme.textSecondary,
                              );
                            },
                          ),
                        ],
                      ),
                    ),



                    // Main content
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadData,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Show hero card only if we have content
                              if (_allContent.isNotEmpty) ...[
                                _buildHeroCard(),
                                const SizedBox(height: AppTheme.spacingLg),

                                // Currently reading section (only if there are books in progress)
                                _buildCurrentlyReadingSection(),
                                if (_currentlyReading.isNotEmpty)
                                  const SizedBox(height: AppTheme.spacingLg),

                                // Category filters
                                _buildCategoryFilters(),

                                const SizedBox(height: AppTheme.spacingLg),
                              ] else ...[
                                // Add some top spacing when no hero card
                                const SizedBox(height: AppTheme.spacingLg),
                              ],

                              // Books section (includes sync instructions when empty)
                              _buildBooksSection(),

                              const SizedBox(
                                height: 100,
                              ), // Space for bottom nav
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom navigation (only show if we have content)
                    if (_allContent.isNotEmpty) _buildBottomNavigation(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF0D9488), // Teal 600 - darker side of gradient
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome back! 👋',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXs),
            const Text(
              'Your Reading Journey',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '📚',
                    '${_stats['totalContent'] ?? 0}',
                    'Stories',
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: _buildStatItem(
                    '✅',
                    '${_stats['completedContent'] ?? 0}',
                    'Finished',
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: _buildStatItem(
                    '🏆',
                    '${_stats['totalPoints'] ?? 0}',
                    'Points',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String emoji, String number, String label) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 2),
          Text(
            number,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentlyReadingSection() {
    // Only show this section if there are books in progress
    if (_currentlyReading.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
          child: Text(
            'Continue Reading',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.65,
              crossAxisSpacing: AppTheme.spacingMd,
              mainAxisSpacing: AppTheme.spacingLg,
            ),
            itemCount: _currentlyReading.length,
            itemBuilder: (context, index) {
              final progress = _currentlyReading[index];
              return _buildCurrentlyReadingBookItem(progress);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentlyReadingBookItem(ReadingProgress progress) {
    return FutureBuilder<Content?>(
      future: DatabaseService.instance.getContent(progress.contentId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.grey.withOpacity(0.2),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final content = snapshot.data!;
        final progressPercentage = progress.progressPercentage;

        return GestureDetector(
          onTap: () async {
            await context.push('/content/${progress.contentId}');
            // Refresh data when returning from content screen
            _refreshOnReturn();
          },
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: _getBookColor(
                          content.category,
                        ).withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        // Cover image or gradient background
                        if (content.coverImageUrl != null &&
                            content.coverImageUrl!.isNotEmpty &&
                            !content.coverImageUrl!.startsWith('http'))
                          Positioned.fill(
                            child: Image.file(
                              File(content.coverImageUrl!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                debugPrint(
                                  'Error loading cover image ${content.coverImageUrl}: $error',
                                );
                                return _buildGradientBackground(content);
                              },
                            ),
                          )
                        else
                          _buildGradientBackground(content),

                        // Dark overlay for text readability
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.3),
                                  Colors.black.withOpacity(0.7),
                                ],
                                stops: const [0.0, 0.6, 1.0],
                              ),
                            ),
                          ),
                        ),
                        // Content overlay
                        Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingMd),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top row with category icon and progress percentage
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Category icon
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getContentIcon(content.category),
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                  ),
                                  // Progress percentage badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${(progressPercentage * 100).round()}%',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: _getBookColor(content.category),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Title at bottom
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    content.title,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          offset: Offset(0, 1),
                                          blurRadius: 3,
                                          color: Colors.black54,
                                        ),
                                      ],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${progress.totalPages - progress.currentPage} pages left',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          offset: Offset(0, 1),
                                          blurRadius: 2,
                                          color: Colors.black54,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Progress bar overlaid at 30% height from bottom (approximately 80px from bottom for typical card height)
                        Positioned(
                          bottom:
                              80, // Fixed position - approximately 30% from bottom
                          left: AppTheme.spacingMd,
                          right: AppTheme.spacingMd,
                          child: Container(
                            height: 12, // Thicker progress bar
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progressPercentage,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF06B6D4), // Cyan 500
                                      Color(0xFF14B8A6), // Teal 500
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF06B6D4,
                                      ).withOpacity(0.4),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                content.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryFilters() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isActive = category['id'] == _activeCategory;

          return GestureDetector(
            onTap: () {
              setState(() {
                _activeCategory = category['id']!;
                _filteredContent = _getFilteredContent();
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: AppTheme.spacingSm),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMd,
                vertical: AppTheme.spacingSm,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.primary
                    : AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (category['icon']!.isNotEmpty) ...[
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.white.withOpacity(0.9)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          category['icon']!,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingSm),
                  ],
                  Text(
                    category['label']!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isActive ? Colors.white : AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBooksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Only show section title if we have content
        if (_allContent.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
            child: Text(
              _activeCategory == 'All'
                  ? 'Discover New Stories'
                  : _activeCategory,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
        ],

        if (_allContent.isEmpty)
          _buildSyncInstructionsInterface()
        else if (_filteredContent.isEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
            padding: const EdgeInsets.all(AppTheme.spacingXl),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: AppTheme.secondary.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.secondary.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(Icons.search_off, size: 48, color: AppTheme.secondary),
                const SizedBox(height: AppTheme.spacingMd),
                Text(
                  'No $_activeCategory Found',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                const Text(
                  'Try selecting a different category or check back later for new content.',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.65,
                crossAxisSpacing: AppTheme.spacingMd,
                mainAxisSpacing: AppTheme.spacingLg,
              ),
              itemCount: _filteredContent.length,
              itemBuilder: (context, index) {
                final content = _filteredContent[index];
                return _buildBookItem(content);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildBookItem(Content content) {
    return GestureDetector(
      onTap: () async {
        await context.push(
          '/book/${content.id}?title=${Uri.encodeComponent(content.title)}',
        );
        // Refresh data when returning from book detail screen
        _refreshOnReturn();
      },
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _getBookColor(content.category).withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // Cover image or gradient background
                    if (content.coverImageUrl != null &&
                        content.coverImageUrl!.isNotEmpty &&
                        !content.coverImageUrl!.startsWith('http'))
                      Positioned.fill(
                        child: Image.file(
                          File(content.coverImageUrl!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildGradientBackground(content);
                          },
                        ),
                      )
                    else
                      _buildGradientBackground(content),

                    // Dark overlay for text readability
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.3),
                              Colors.black.withOpacity(0.7),
                            ],
                            stops: const [0.0, 0.6, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Content overlay
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingMd),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row with category icon and age group
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Category icon
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _getContentIcon(content.category),
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                              // Age group badge
                              if (content.ageGroup.isNotEmpty &&
                                  content.ageGroup != 'All ages')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    content.ageGroup,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: _getBookColor(content.category),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          // Title at bottom
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                content.title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(0, 1),
                                      blurRadius: 3,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getFunDescription(content.category),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(0, 1),
                                      blurRadius: 2,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            content.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildGradientBackground(Content content) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getBookColor(content.category),
            _getBookColor(content.category).withOpacity(0.85),
            _getBookColor(content.category).withOpacity(0.7),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Colors.white.withOpacity(0.1),
              Colors.transparent,
              Colors.black.withOpacity(0.1),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBookColor(String category) {
    const colors = {
      'folktales': Color(0xFF14B8A6), // Teal 500
      'science': Color(0xFF06B6D4), // Cyan 500
      'mathematics': Color(0xFFF59E0B), // Amber 500
      'poetry': Color(0xFFEC4899), // Pink 500
      'historical': Color(0xFF8B5CF6), // Violet 500
      'short-stories': Color(0xFFF97316), // Orange 500
      'general': Color(0xFF14B8A6), // Default teal
    };
    return colors[category.toLowerCase()] ?? AppTheme.primary;
  }

  Widget _buildSyncInstructionsInterface() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      child: Column(
        children: [
          // Main playful instruction card
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
                const SizedBox(height: AppTheme.spacingLg),

                // Fun title with emojis
                const Text(
                  '🌟 Let\'s Get Some Stories! 🌟',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppTheme.spacingSm),

                // Child-friendly subtitle
                const Text(
                  'Ready for amazing adventures? Let\'s connect to your story hub and download tons of fun books to read!',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppTheme.spacingXl),

                // Playful steps
                _buildPlayfulInstructionStep(
                  stepNumber: '1',
                  emoji: '📶',
                  title: 'Connect to Wi-Fi',
                  description:
                      'Make sure you\'re on the same Wi-Fi as your story hub!',
                  color: AppTheme.secondary, // Blue
                ),

                const SizedBox(height: AppTheme.spacingLg),

                _buildPlayfulInstructionStep(
                  stepNumber: '2',
                  emoji: '🔍',
                  title: 'Auto-Discovery',
                  description:
                      'The app will automatically find your story hub!',
                  color: AppTheme.primary, // Green
                ),

                const SizedBox(height: AppTheme.spacingLg),

                _buildPlayfulInstructionStep(
                  stepNumber: '3',
                  emoji: '📚',
                  title: 'Download Stories',
                  description: 'Watch as amazing stories appear like magic!',
                  color: AppTheme.accent, // Orange
                ),

                const SizedBox(height: AppTheme.spacingXl),

                // Fun action button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.push('/sync'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary, // Use theme teal color
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacingLg,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                      ),
                      elevation: 4,
                      shadowColor: const Color(0xFF19a88c).withOpacity(0.3),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Let\'s Get Stories!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacingLg),

          // Friendly help card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const Center(
                        child: Text('🤔', style: TextStyle(fontSize: 24)),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingMd),
                    const Expanded(
                      child: Text(
                        'Need a Grown-Up\'s Help?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingMd),
                const Text(
                  'If you can\'t find your story hub, ask a teacher or parent to help you set it up. They know all about the technical stuff! 👨‍🏫👩‍🏫',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayfulInstructionStep({
    required String stepNumber,
    required String emoji,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          // Fun step number circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                stepNumber,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(width: AppTheme.spacingMd),

          // Big emoji
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),

          const SizedBox(width: AppTheme.spacingMd),

          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Consumer2<SyncService, AuthenticationService>(
      builder: (context, syncService, authService, child) {
        final hubSettings = syncService.hubSettings;
        final requiresStudentAuth = hubSettings?['requireStudentAuthentication'] == true;
        final isStudentLoggedIn = authService.isStudentLoggedIn;
        
        return Container(
          margin: const EdgeInsets.all(AppTheme.spacingMd),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMd,
            vertical: AppTheme.spacingSm,
          ),
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
          child: Row(
            children: [
              // Offline/Online status
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _hubConnected = !_hubConnected),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _hubConnected
                              ? AppTheme.primary.withOpacity(0.2)
                              : AppTheme.warning.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        ),
                        child: Center(
                          child: Text(
                            _hubConnected ? '📡' : '📱',
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingXs),
                      Text(
                        _hubConnected ? 'Online' : 'Offline',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Sync button
              GestureDetector(
                onTap: () => context.push('/sync'),
                onLongPress: () async {
                  final syncService = context.read<SyncService>();
                  await syncService.forceDownloadCoverImages();
                  await _loadData(); // Refresh the UI
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cover images download complete!'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingLg,
                    vertical: AppTheme.spacingSm,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '🔄',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                      SizedBox(width: AppTheme.spacingXs),
                      Text(
                        'Sync Hub',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Conditional logout button (only show if student auth is required and student is logged in)
              if (requiresStudentAuth && isStudentLoggedIn) ...[
                const SizedBox(width: AppTheme.spacingMd),
                GestureDetector(
                  onTap: () async {
                    // Show confirmation dialog
                    final shouldLogout = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('End Session'),
                        content: const Text('Are you sure you want to end your learning session?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('End Session'),
                          ),
                        ],
                      ),
                    );

                    if (shouldLogout == true) {
                      await authService.logoutStudent();
                      if (mounted) {
                        context.go('/auth');
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingMd,
                      vertical: AppTheme.spacingSm,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '👋',
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(width: AppTheme.spacingXs),
                        Text(
                          'End Session',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Profile button
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/profile'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        ),
                        child: const Center(
                          child: Text('🏆', style: TextStyle(fontSize: 24)),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingXs),
                      const Text(
                        'My Progress',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
