import 'package:flutter/material.dart';
import '../models/reading_progress.dart';
import '../models/content.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class CurrentlyReadingCard extends StatefulWidget {
  final ReadingProgress progress;
  final VoidCallback onTap;

  const CurrentlyReadingCard({
    super.key,
    required this.progress,
    required this.onTap,
  });

  @override
  State<CurrentlyReadingCard> createState() => _CurrentlyReadingCardState();
}

class _CurrentlyReadingCardState extends State<CurrentlyReadingCard> {
  Content? _content;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    final content = await DatabaseService.instance.getContent(widget.progress.contentId);
    if (mounted) {
      setState(() => _content = content);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_content == null) {
      return const SizedBox(
        width: 160,
        child: Card(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return SizedBox(
      width: 160,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress indicator
              LinearProgressIndicator(
                value: widget.progress.progressPercentage,
                backgroundColor: AppTheme.surfaceVariant,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
              
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        _content!.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: AppTheme.spacingSm),
                      
                      // Category
                      Text(
                        _content!.category,
                        style: AppTextStyles.bookCategory,
                      ),
                      
                      const Spacer(),
                      
                      // Progress text with child-friendly language
                      Text(
                        '${(widget.progress.progressPercentage * 100).round()}% done! 🎉',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                      
                      // Pages left info
                      Text(
                        '${widget.progress.totalPages - widget.progress.currentPage} pages left',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}