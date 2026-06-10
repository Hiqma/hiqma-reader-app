import 'dart:io';
import 'package:flutter/material.dart';
import '../models/content.dart';
import '../theme/app_theme.dart';

class BookCard extends StatelessWidget {
  final Content content;
  final VoidCallback onTap;

  const BookCard({
    super.key,
    required this.content,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book cover
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: content.coverImageUrl != null && content.coverImageUrl!.isNotEmpty
                      ? null
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _getCategoryColor(content.category).withOpacity(0.8),
                            _getCategoryColor(content.category),
                          ],
                        ),
                ),
                child: Stack(
                  children: [
                    // Cover image or placeholder pattern
                    Positioned.fill(
                      child: content.coverImageUrl != null && content.coverImageUrl!.isNotEmpty
                          ? (content.coverImageUrl!.startsWith('http')
                              ? Image.network(
                                  content.coverImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            _getCategoryColor(content.category).withOpacity(0.8),
                                            _getCategoryColor(content.category),
                                          ],
                                        ),
                                      ),
                                      child: CustomPaint(
                                        painter: BookCoverPainter(),
                                      ),
                                    );
                                  },
                                )
                              : Image.file(
                                  File(content.coverImageUrl!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            _getCategoryColor(content.category).withOpacity(0.8),
                                            _getCategoryColor(content.category),
                                          ],
                                        ),
                                      ),
                                      child: CustomPaint(
                                        painter: BookCoverPainter(),
                                      ),
                                    );
                                  },
                                )
                          : CustomPaint(
                              painter: BookCoverPainter(),
                            ),
                    ),
                    // Category badge
                    Positioned(
                      top: AppTheme.spacingSm,
                      right: AppTheme.spacingSm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingSm,
                          vertical: AppTheme.spacingXs,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Text(
                          _getCategoryIcon(content.category),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    // Title overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(AppTheme.spacingSm),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                        child: Text(
                          content.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Book info
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingSm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      content.category,
                      style: AppTextStyles.bookCategory,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (content.description.isNotEmpty)
                      Text(
                        content.description,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'science':
        return const Color(0xFF3B82F6); // Blue
      case 'history':
        return const Color(0xFF8B5CF6); // Purple
      case 'literature':
        return const Color(0xFFEC4899); // Pink
      case 'mathematics':
        return const Color(0xFF10B981); // Emerald
      case 'art':
        return const Color(0xFFF59E0B); // Amber
      case 'technology':
        return const Color(0xFF06B6D4); // Cyan
      default:
        return AppTheme.primary;
    }
  }

  String _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'science':
        return '🔬';
      case 'history':
        return '📚';
      case 'literature':
        return '📖';
      case 'mathematics':
        return '🔢';
      case 'art':
        return '🎨';
      case 'technology':
        return '💻';
      default:
        return '📘';
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