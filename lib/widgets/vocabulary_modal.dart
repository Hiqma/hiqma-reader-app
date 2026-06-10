import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/vocabulary_word.dart';

class VocabularyModal extends StatefulWidget {
  final List<VocabularyWord> vocabularyWords;
  final VoidCallback onClose;

  const VocabularyModal({
    super.key,
    required this.vocabularyWords,
    required this.onClose,
  });

  @override
  State<VocabularyModal> createState() => _VocabularyModalState();
}

class _VocabularyModalState extends State<VocabularyModal> {
  final TextEditingController _searchController = TextEditingController();
  final PageController _pageController = PageController();
  
  String _searchQuery = '';
  int _currentPage = 0;
  static const int _wordsPerPage = 5;

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  List<VocabularyWord> get _filteredWords {
    if (_searchQuery.isEmpty) {
      return widget.vocabularyWords;
    }
    return widget.vocabularyWords
        .where((word) => word.word.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  int get _totalPages {
    return (_filteredWords.length / _wordsPerPage).ceil();
  }



  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      setState(() {
        _currentPage++;
      });
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _currentPage = 0; // Reset to first page when searching
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppTheme.border, width: 1),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'My Words 📚',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, size: 24),
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
            
            // Search bar
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search words...',
                  hintStyle: const TextStyle(color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: const Color(0xFFF7FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                ),
              ),
            ),
            
            // Words list
            Expanded(
              child: _filteredWords.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.book_outlined,
                            size: 64,
                            color: AppTheme.textTertiary,
                          ),
                          SizedBox(height: AppTheme.spacingMd),
                          Text(
                            'No words saved yet! 📚',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          SizedBox(height: AppTheme.spacingSm),
                          Text(
                            'Tap words while reading to add them here.',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : PageView.builder(
                      controller: _pageController,
                      itemCount: _totalPages,
                      onPageChanged: (page) => setState(() => _currentPage = page),
                      itemBuilder: (context, pageIndex) {
                        final startIndex = pageIndex * _wordsPerPage;
                        final endIndex = (startIndex + _wordsPerPage).clamp(0, _filteredWords.length);
                        final pageWords = _filteredWords.sublist(startIndex, endIndex);
                        
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
                          itemCount: pageWords.length,
                          itemBuilder: (context, index) {
                            final word = pageWords[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                              padding: const EdgeInsets.all(AppTheme.spacingMd),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    word.word,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.spacingXs),
                                  Text(
                                    word.definition,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  if (word.category.isNotEmpty) ...[
                                    const SizedBox(height: AppTheme.spacingXs),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppTheme.spacingSm,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                      ),
                                      child: Text(
                                        word.category,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
            
            // Pagination controls
            if (_filteredWords.isNotEmpty && _totalPages > 1)
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppTheme.border, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: _currentPage > 0 ? _prevPage : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentPage > 0 ? AppTheme.primary : AppTheme.textTertiary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingMd,
                          vertical: AppTheme.spacingSm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                      child: const Text('Previous'),
                    ),
                    
                    Text(
                      '${_currentPage + 1} of $_totalPages',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    
                    ElevatedButton(
                      onPressed: _currentPage < _totalPages - 1 ? _nextPage : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentPage < _totalPages - 1 ? AppTheme.primary : AppTheme.textTertiary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingMd,
                          vertical: AppTheme.spacingSm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}