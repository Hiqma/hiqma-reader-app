import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../services/authentication_service.dart';
import '../widgets/modern_card.dart';
import '../widgets/animated_progress.dart';
import '../widgets/device_code_display.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<StudentProgressWithTitle> _allProgress = [];
  int _totalPoints = 0;
  int _completedCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final content = await DatabaseService.instance.getAllContent();
      final progressData = <StudentProgressWithTitle>[];
      int points = 0;
      int completed = 0;

      for (final item in content) {
        final progress = await DatabaseService.instance.getProgressByContent(item.id);
        if (progress != null) {
          progressData.add(StudentProgressWithTitle(
            contentId: progress.contentId,
            progress: progress.progress,
            points: progress.points,
            completedAt: progress.completedAt,
            quizScores: progress.quizScores,
            title: item.title,
          ));
          points += progress.points;
          if (progress.progress == 100) completed++;
        }
      }

      setState(() {
        _allProgress = progressData;
        _totalPoints = points;
        _completedCount = completed;
        _isLoading = false;
      });
    } catch (error) {
      print('Failed to load profile: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

  int _getAverageQuizScore(List<int> scores) {
    if (scores.isEmpty) return 0;
    return (scores.reduce((a, b) => a + b) / scores.length).round();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF0FDF4), // Green 50 - Light green background
              Color(0xFFDCFCE7), // Green 100 - Light green variant
              Color(0xFFBBF7D0), // Green 200 - Slightly more green
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                )
              : CustomScrollView(
                  slivers: [
                    // App bar
                    SliverAppBar(
                      title: const Text('My Learning Journey 🌈'),
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => context.pop(),
                      ),
                      floating: true,
                      snap: true,
                    ),
                    
                    // Content
                    SliverPadding(
                      padding: const EdgeInsets.all(AppTheme.spacingLg),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // Hero card
                          _buildHeroCard(),
                          
                          const SizedBox(height: AppTheme.spacingXl),
                          
                          // Section title
                          const Text(
                            'Your Story Adventures 🌟',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          
                          const SizedBox(height: AppTheme.spacingMd),
                          
                          // Progress cards
                          ..._buildProgressCards(),
                          
                          const SizedBox(height: AppTheme.spacingXl),
                          
                          // Badges section
                          const Text(
                            'Your Super Badges 🏅',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          
                          const SizedBox(height: AppTheme.spacingMd),
                          
                          _buildBadgeGrid(),
                          
                          const SizedBox(height: AppTheme.spacingXxl),
                        ]),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Celebrate every story, quiz, and spark of curiosity.',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingMd),
          
          // Device code chip
          Consumer<AuthenticationService>(
            builder: (context, authService, child) {
              return DeviceCodeChip(
                authenticationService: authService,
              );
            },
          ),
          
          const SizedBox(height: AppTheme.spacingLg),
          
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  emoji: '🏆',
                  number: _totalPoints.toString(),
                  label: 'Points',
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(
                child: _buildStatCard(
                  emoji: '✅',
                  number: _completedCount.toString(),
                  label: 'Finished',
                  color: AppTheme.secondary,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(
                child: _buildStatCard(
                  emoji: '📚',
                  number: _allProgress.length.toString(),
                  label: 'Stories',
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String emoji,
    required String number,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(height: AppTheme.spacingXs),
          Text(
            number,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingXs),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildProgressCards() {
    if (_allProgress.isEmpty) {
      return [
        ModernCard(
          title: 'Start Your Adventure!',
          subtitle: 'Read your first story to see progress here',
          icon: '🚀',
          color: AppTheme.accent,
        ),
      ];
    }

    final colors = [
      AppTheme.primary,
      AppTheme.secondary,
      AppTheme.accent,
      const Color(0xFFEC4899), // Pink
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFF97316), // Orange
    ];

    return _allProgress.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final color = colors[index % colors.length];
      final isCompleted = item.progress == 100;

      return Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
        child: ModernCard(
          title: item.title,
          subtitle: isCompleted
              ? 'Completed! 🎉 ${item.points} points'
              : '${item.progress}% complete',
          icon: isCompleted ? '🏆' : '📖',
          color: color,
          progress: item.progress.toDouble(),
          child: Column(
            children: [
              const SizedBox(height: AppTheme.spacingMd),
              AnimatedProgress(
                progress: item.progress.toDouble(),
                color: color,
                height: 12,
              ),
              
              if (item.quizScores.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacingSm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd,
                    vertical: AppTheme.spacingXs,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    '🧠 Quiz: ${_getAverageQuizScore(item.quizScores)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
              
              if (item.completedAt != null) ...[
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  '✨ Finished on ${_formatDate(item.completedAt!)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildBadgeGrid() {
    final badges = <Widget>[];

    // Star Collector badge
    if (_totalPoints >= 100) {
      badges.add(_buildBadge(
        icon: '🌟',
        title: 'Star Collector',
        description: '100 Points!',
        color: const Color(0xFFF59E0B),
      ));
    }

    // First Reader badge
    if (_completedCount >= 1) {
      badges.add(_buildBadge(
        icon: '📚',
        title: 'First Reader',
        description: 'Story Complete!',
        color: AppTheme.secondary,
      ));
    }

    // Bookworm badge
    if (_completedCount >= 5) {
      badges.add(_buildBadge(
        icon: '📚',
        title: 'Bookworm',
        description: '5 Stories!',
        color: AppTheme.primary,
      ));
    }

    // Quiz Master badge
    if (_allProgress.any((p) => _getAverageQuizScore(p.quizScores) >= 90)) {
      badges.add(_buildBadge(
        icon: '🧠',
        title: 'Quiz Master',
        description: '90%+ Average!',
        color: const Color(0xFFEC4899),
      ));
    }

    // Super Star badge
    if (_totalPoints >= 500) {
      badges.add(_buildBadge(
        icon: '💎',
        title: 'Super Star',
        description: '500 Points!',
        color: AppTheme.accent,
      ));
    }

    if (badges.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        child: const Center(
          child: Text(
            'Complete stories to earn badges! 🏅',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: AppTheme.spacingMd,
      runSpacing: AppTheme.spacingMd,
      children: badges,
    );
  }

  Widget _buildBadge({
    required String icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      width: (MediaQuery.of(context).size.width - AppTheme.spacingLg * 3) / 2,
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: color.withOpacity(0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 30),
          ),
          const SizedBox(height: AppTheme.spacingXs),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class StudentProgressWithTitle extends StudentProgress {
  final String title;

  StudentProgressWithTitle({
    required super.contentId,
    required super.progress,
    required super.points,
    super.completedAt,
    required super.quizScores,
    required this.title,
  });
}