import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/content.dart';
import '../models/reading_progress.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class BookDetailScreen extends StatefulWidget {
  final String contentId;
  final String title;

  const BookDetailScreen({
    super.key,
    required this.contentId,
    required this.title,
  });

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  Content? _content;
  ReadingProgress? _progress;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Add this method to refresh data when returning from reading
  void _onResumed() {
    // Refresh data when the screen becomes active again
    _refreshData();
  }

  Future<void> _loadData() async {
    try {
      final content = await DatabaseService.instance.getContent(widget.contentId);
      final progress = await DatabaseService.instance.getReadingProgress(widget.contentId);
      
      setState(() {
        _content = content;
        _progress = progress;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading book: $e')),
        );
      }
    }
  }

  // Add this method to refresh data without showing loading
  Future<void> _refreshData() async {
    try {
      final content = await DatabaseService.instance.getContent(widget.contentId);
      final progress = await DatabaseService.instance.getReadingProgress(widget.contentId);
      
      if (mounted) {
        setState(() {
          _content = content;
          _progress = progress;
        });
      }
    } catch (e) {
      // Silently handle errors during refresh
    }
  }

  Future<void> _startReading() async {
    if (_content == null) return;

    // Create initial progress if it doesn't exist
    if (_progress == null) {
      final newProgress = ReadingProgress(
        id: '${widget.contentId}_progress',
        contentId: widget.contentId,
        currentPage: 1,
        totalPages: _calculateTotalPages(_content!.htmlContent),
        timeSpent: 0,
        lastRead: DateTime.now(),
        completed: false,
      );
      
      await DatabaseService.instance.updateReadingProgress(newProgress);
    }

    if (mounted) {
      // Navigate to content screen and refresh data when returning
      await context.push('/content/${widget.contentId}?title=${Uri.encodeComponent(_content!.title)}');
      
      // Refresh data after returning from reading
      await _refreshData();
    }
  }

  int _calculateTotalPages(String htmlContent) {
    // Simple page calculation based on content length
    // In a real app, you might want more sophisticated pagination
    const wordsPerPage = 250;
    final wordCount = htmlContent.split(' ').length;
    return (wordCount / wordsPerPage).ceil().clamp(1, 999);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _content == null
              ? const Center(
                  child: Text(
                    'Book not found',
                    style: TextStyle(fontSize: 18, color: AppTheme.textSecondary),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      // Book cover and basic info
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingLg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Book cover - bigger for detail view
                                  Container(
                                    width: 160,
                                    height: 240,
                                    decoration: BoxDecoration(
                                      gradient: _content!.coverImageUrl != null && _content!.coverImageUrl!.isNotEmpty
                                          ? null
                                          : LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                _getCategoryColor(_content!.category).withOpacity(0.8),
                                                _getCategoryColor(_content!.category),
                                              ],
                                            ),
                                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                      boxShadow: AppThemeExtensions.mediumShadow,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                      child: Stack(
                                        children: [
                                          // Cover image or decorative pattern
                                          Positioned.fill(
                                            child: _content!.coverImageUrl != null && _content!.coverImageUrl!.isNotEmpty
                                                ? Image.file(
                                                    File(_content!.coverImageUrl!),
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) {
                                                      return Container(
                                                        decoration: BoxDecoration(
                                                          gradient: LinearGradient(
                                                            begin: Alignment.topLeft,
                                                            end: Alignment.bottomRight,
                                                            colors: [
                                                              _getCategoryColor(_content!.category).withOpacity(0.8),
                                                              _getCategoryColor(_content!.category),
                                                            ],
                                                          ),
                                                        ),
                                                        child: Stack(
                                                          children: [
                                                            CustomPaint(
                                                              painter: BookCoverPainter(),
                                                            ),
                                                            const Center(
                                                              child: Icon(
                                                                Icons.menu_book,
                                                                size: 48,
                                                                color: Colors.white,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  )
                                                : Stack(
                                                    children: [
                                                      CustomPaint(
                                                        painter: BookCoverPainter(),
                                                      ),
                                                      const Center(
                                                        child: Icon(
                                                          Icons.menu_book,
                                                          size: 48,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                          // Category icon overlay (only show if no cover image)
                                          if (_content!.coverImageUrl == null || _content!.coverImageUrl!.isEmpty)
                                            Positioned(
                                              top: AppTheme.spacingSm,
                                              right: AppTheme.spacingSm,
                                              child: Container(
                                                padding: const EdgeInsets.all(AppTheme.spacingSm),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.9),
                                                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                                ),
                                                child: Text(
                                                  _getCategoryIcon(_content!.category),
                                                  style: const TextStyle(fontSize: 16),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  
                                  const SizedBox(width: AppTheme.spacingLg),
                                  
                                  // Book info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Title with child-friendly font
                                        Text(
                                          _content!.title,
                                          style: AppTextStyles.playfulTitle.copyWith(
                                            fontSize: 22,
                                            height: 1.2,
                                          ),
                                        ),
                                        
                                        const SizedBox(height: AppTheme.spacingMd),
                                        
                                        // Category badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppTheme.spacingMd,
                                            vertical: AppTheme.spacingSm,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getCategoryColor(_content!.category).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                                            border: Border.all(
                                              color: _getCategoryColor(_content!.category).withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _getCategoryIconData(_content!.category),
                                                color: _getCategoryColor(_content!.category),
                                                size: 16,
                                              ),
                                              const SizedBox(width: AppTheme.spacingSm),
                                              Text(
                                                _content!.category,
                                                style: TextStyle(
                                                  color: _getCategoryColor(_content!.category),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        
                                        const SizedBox(height: AppTheme.spacingMd),
                                        
                                        // Progress indicator
                                        if (_progress != null) ...[
                                          Container(
                                            padding: const EdgeInsets.all(AppTheme.spacingMd),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryLight.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.menu_book_outlined,
                                                      color: AppTheme.primary,
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: AppTheme.spacingSm),
                                                    Text(
                                                      'Reading Progress',
                                                      style: AppTextStyles.instructionText.copyWith(
                                                        fontWeight: FontWeight.w600,
                                                        color: AppTheme.primary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: AppTheme.spacingSm),
                                                Text(
                                                  '${(_progress!.progressPercentage * 100).round()}% Complete',
                                                  style: AppTextStyles.progressText.copyWith(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: AppTheme.spacingSm),
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                                  child: LinearProgressIndicator(
                                                    value: _progress!.progressPercentage,
                                                    backgroundColor: AppTheme.surfaceVariant,
                                                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                                                    minHeight: 8,
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
                              
                              const SizedBox(height: AppTheme.spacingLg),
                              
                              // Book details section
                              _buildBookDetailsSection(),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: AppTheme.spacingLg),
                      
                      // Description
                      if (_content!.description.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.description_outlined,
                              color: AppTheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: AppTheme.spacingSm),
                            Text(
                              'Story Description',
                              style: AppTextStyles.sectionTitle.copyWith(
                                color: AppTheme.textPrimary,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingMd),
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spacingLg),
                            child: Text(
                              _content!.description,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimary,
                                height: 1.7,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingLg),
                      ],
                      
                      // Reading stats
                      if (_progress != null) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.analytics_outlined,
                              color: AppTheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: AppTheme.spacingSm),
                            Text(
                              'My Reading Stats',
                              style: AppTextStyles.sectionTitle.copyWith(
                                color: AppTheme.textPrimary,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingMd),
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spacingLg),
                            child: Column(
                              children: [
                                _buildStatRow(Icons.bookmark_outline, 'Current Page', '${_progress!.currentPage}'),
                                _buildStatRow(Icons.menu_book_outlined, 'Total Pages', '${_progress!.totalPages}'),
                                _buildStatRow(Icons.access_time, 'Time Spent', '${(_progress!.timeSpent / 60).round()} minutes'),
                                _buildStatRow(Icons.calendar_today, 'Last Read', _formatDate(_progress!.lastRead)),
                              ],
                            ),
                          ),
                        ),
                      ],
                      ],
                    ),
                  ),
                ),
      bottomNavigationBar: _content == null
          ? null
          : Container(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _startReading,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 64),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                  elevation: 6,
                  shadowColor: AppTheme.primary.withOpacity(0.3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _progress == null ? Icons.play_circle_filled : Icons.menu_book,
                      size: 28,
                    ),
                    const SizedBox(width: AppTheme.spacingMd),
                    Text(
                      _progress == null ? 'Start Reading' : 'Continue Reading',
                      style: AppTextStyles.buttonTextLarge.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBookDetailsSection() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppTheme.primary,
                size: 18,
              ),
              const SizedBox(width: AppTheme.spacingSm),
              Text(
                'Book Details',
                style: AppTextStyles.instructionText.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Wrap(
            spacing: AppTheme.spacingMd,
            runSpacing: AppTheme.spacingMd,
            children: [
              _buildDetailChip(Icons.groups, _content!.ageGroup, AppTheme.accentPink),
              _buildDetailChip(Icons.language, _content!.language, AppTheme.secondary),
              if (_content!.comprehensionQuestions.isNotEmpty)
                _buildDetailChip(Icons.quiz, '${_content!.comprehensionQuestions.length} Questions', AppTheme.accent),
              if (_content!.targetCountries.isNotEmpty)
                _buildDetailChip(Icons.public, '${_content!.targetCountries.length} Countries', AppTheme.accentPurple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingLg,
        vertical: AppTheme.spacingMd,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 18,
          ),
          const SizedBox(width: AppTheme.spacingSm),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: AppTheme.textSecondary,
                size: 16,
              ),
              const SizedBox(width: AppTheme.spacingSm),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'folktales':
        return AppTheme.primary;
      case 'science':
        return AppTheme.secondary;
      case 'mathematics':
        return AppTheme.accent;
      case 'poetry':
        return AppTheme.accentPink;
      case 'historical':
        return AppTheme.accentPurple;
      case 'short-stories':
        return AppTheme.accentOrange;
      case 'moral tales':
        return const Color(0xFF10B981); // Emerald
      default:
        return AppTheme.primary;
    }
  }

  IconData _getCategoryIconData(String category) {
    switch (category.toLowerCase()) {
      case 'folktales':
        return Icons.auto_stories;
      case 'science':
        return Icons.science;
      case 'mathematics':
        return Icons.calculate;
      case 'poetry':
        return Icons.music_note;
      case 'historical':
        return Icons.history_edu;
      case 'short-stories':
        return Icons.menu_book;
      case 'moral tales':
        return Icons.favorite;
      default:
        return Icons.book;
    }
  }

  String _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'folktales':
        return '🧚‍♀️';
      case 'science':
        return '🔬';
      case 'mathematics':
        return '🔢';
      case 'poetry':
        return '🎵';
      case 'historical':
        return '🏰';
      case 'short-stories':
        return '📖';
      case 'moral tales':
        return '💎';
      default:
        return '📚';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class BookCoverPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1;

    // Draw a simple geometric pattern
    for (int i = 0; i < 5; i++) {
      canvas.drawLine(
        Offset(0, size.height * i / 5),
        Offset(size.width, size.height * i / 5),
        paint,
      );
    }

    for (int i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(size.width * i / 3, 0),
        Offset(size.width * i / 3, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}