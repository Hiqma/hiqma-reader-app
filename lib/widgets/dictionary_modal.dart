import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DictionaryModal extends StatefulWidget {
  final String word;
  final Function(String word, String definition) onAddToVocabulary;
  final VoidCallback onClose;

  const DictionaryModal({
    super.key,
    required this.word,
    required this.onAddToVocabulary,
    required this.onClose,
  });

  @override
  State<DictionaryModal> createState() => _DictionaryModalState();
}

class _DictionaryModalState extends State<DictionaryModal> {
  String _definition = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateDefinition();
  }

  Future<void> _generateDefinition() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate AI definition generation
    await Future.delayed(const Duration(seconds: 2));
    
    // Simple definition generator (in real app, this would call an AI service)
    final definitions = {
      'cat': 'A small domesticated carnivorous mammal with soft fur, a short snout, and retractable claws.',
      'dog': 'A domesticated carnivorous mammal that typically has a long snout, an acute sense of smell, and a barking voice.',
      'book': 'A written or printed work consisting of pages glued or sewn together along one side and bound in covers.',
      'tree': 'A woody perennial plant, typically having a main trunk and branches forming a distinct elevated crown.',
      'house': 'A building for human habitation, especially one that is lived in by a family or small group of people.',
      'water': 'A colorless, transparent, odorless liquid that forms the seas, lakes, rivers, and rain.',
      'sun': 'The star around which the earth orbits, providing light and heat for life on earth.',
      'moon': 'The natural satellite of the earth, visible (chiefly at night) by reflected light from the sun.',
    };

    final definition = definitions[widget.word.toLowerCase()] ?? 
        '${widget.word.substring(0, 1).toUpperCase()}${widget.word.substring(1)} - a word to learn! 📚';

    setState(() {
      _definition = definition;
      _isLoading = false;
    });
  }

  void _addToVocabulary() {
    widget.onAddToVocabulary(widget.word, _definition);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Word title
            Text(
              widget.word,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingLg),
            
            // Definition
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAFC),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: _isLoading
                  ? const Column(
                      children: [
                        CircularProgressIndicator(color: AppTheme.primary),
                        SizedBox(height: AppTheme.spacingMd),
                        Text(
                          'Looking up meaning... 🔍',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      _definition,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),
            
            const SizedBox(height: AppTheme.spacingXl),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _addToVocabulary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      ),
                    ),
                    child: const Text(
                      'Save Word 📚',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: AppTheme.spacingMd),
                
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.onClose,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.textSecondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      ),
                    ),
                    child: const Text(
                      'Got it! ✓',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}