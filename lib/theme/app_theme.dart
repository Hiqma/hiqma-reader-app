import 'package:flutter/material.dart';

class AppTheme {
  // Teal Child-Friendly Color Palette
  static const Color primary = Color(0xFF14B8A6); // Teal 500 - Main brand color
  static const Color primaryLight = Color(0xFF5EEAD4); // Teal 300 - Lighter variant
  static const Color primaryDark = Color(0xFF0D9488); // Teal 600 - Darker variant
  
  static const Color secondary = Color(0xFF06B6D4); // Cyan 500 - Complementary
  static const Color secondaryLight = Color(0xFF67E8F9); // Cyan 300
  static const Color secondaryDark = Color(0xFF0891B2); // Cyan 600
  
  // Playful accent colors for variety
  static const Color accent = Color(0xFFFBBF24); // Amber 400 - Warm accent
  static const Color accentPink = Color(0xFFF472B6); // Pink 400 - Fun accent
  static const Color accentPurple = Color(0xFFA78BFA); // Purple 400 - Creative accent
  static const Color accentOrange = Color(0xFFFB923C); // Orange 400 - Energetic accent
  
  // Background colors with light teal tint
  static const Color background = Color(0xFFF0FDFA); // Teal 50 - Very light teal background
  static const Color surface = Color(0xFFFFFFFF); // Pure white for cards
  static const Color surfaceVariant = Color(0xFFCCFDF7); // Teal 100 - Light teal variant
  static const Color surfaceTint = Color(0xFFA7F3D0); // Teal 200 - Slightly more teal
  
  // Text colors optimized for teal theme
  static const Color textPrimary = Color(0xFF134E4A); // Teal 900 - Dark teal for primary text
  static const Color textSecondary = Color(0xFF115E59); // Teal 800 - Medium teal for secondary text
  static const Color textTertiary = Color(0xFF0F766E); // Teal 700 - Lighter teal for tertiary text
  static const Color textMuted = Color(0xFF6B7280); // Gray 500 - Neutral muted text
  
  // Status colors
  static const Color success = Color(0xFF10B981); // Emerald 500 - Success states
  static const Color warning = Color(0xFFF59E0B); // Amber 500 - Warning states
  static const Color error = Color(0xFFEF4444); // Red 500 - Error states
  static const Color info = Color(0xFF3B82F6); // Blue 500 - Info states
  
  // Border and divider colors
  static const Color border = Color(0xFFA7F3D0); // Teal 200 - Subtle teal borders
  static const Color borderLight = Color(0xFFCCFDF7); // Teal 100 - Very light borders
  static const Color borderDark = Color(0xFF5EEAD4); // Teal 300 - More visible borders
  
  // Spacing
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacing2xl = 48.0;
  static const double spacingXxl = 64.0;
  
  // Border radius
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusPill = 999.0;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primary,
        primaryContainer: primaryLight,
        secondary: secondary,
        secondaryContainer: secondaryLight,
        surface: surface,
        surfaceVariant: surfaceVariant,
        background: background,
        error: error,
        onPrimary: Colors.white,
        onPrimaryContainer: textPrimary,
        onSecondary: Colors.white,
        onSecondaryContainer: textPrimary,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
        onBackground: textPrimary,
        onError: Colors.white,
        outline: border,
        outlineVariant: borderLight,
      ),
      
      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      
      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingLg,
            vertical: spacingMd,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingMd,
            vertical: spacingSm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
        ),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingMd,
          vertical: spacingMd,
        ),
      ),
      
      // Text Theme
      textTheme: const TextTheme(
        // Headings
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          height: 1.2,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.3,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.3,
        ),
        
        // Titles
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.4,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          height: 1.4,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          height: 1.4,
        ),
        
        // Body text
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.4,
        ),
        
        // Labels
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textTertiary,
        ),
      ),
      
      // Icon Theme
      iconTheme: const IconThemeData(
        color: textSecondary,
        size: 24,
      ),
      
      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: surfaceVariant,
        thickness: 1,
        space: 1,
      ),
    );
  }
}

// Child-friendly theme extensions
extension AppThemeExtensions on AppTheme {
  // Playful gradient combinations
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppTheme.primary, AppTheme.primaryLight],
  );
  
  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppTheme.secondary, AppTheme.secondaryLight],
  );
  
  static const LinearGradient rainbowGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppTheme.primaryLight, AppTheme.accentPink, AppTheme.accent, AppTheme.secondary],
  );
  
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppTheme.background, AppTheme.surfaceVariant],
  );
  
  // Playful shadow presets
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: AppTheme.primary.withOpacity(0.1),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> get mediumShadow => [
    BoxShadow(
      color: AppTheme.primary.withOpacity(0.15),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> get strongShadow => [
    BoxShadow(
      color: AppTheme.primary.withOpacity(0.2),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
  
  // Fun color combinations for different content types
  static const Map<String, Color> categoryColors = {
    'folktales': Color(0xFF14B8A6), // Teal
    'science': Color(0xFF06B6D4), // Cyan
    'mathematics': Color(0xFFF59E0B), // Amber
    'poetry': Color(0xFFF472B6), // Pink
    'historical': Color(0xFFA78BFA), // Purple
    'short-stories': Color(0xFFFB923C), // Orange
  };
}

// Custom text styles for child-friendly interface
class AppTextStyles {
  // Playful heading styles
  static const TextStyle heroTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    color: AppTheme.textPrimary,
    height: 1.2,
    letterSpacing: -0.5,
  );
  
  static const TextStyle playfulTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppTheme.textPrimary,
    height: 1.3,
  );
  
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppTheme.textPrimary,
    height: 1.3,
  );
  
  // Content styles
  static const TextStyle bookTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppTheme.textPrimary,
    height: 1.3,
  );
  
  static const TextStyle bookCategory = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppTheme.textSecondary,
    letterSpacing: 0.5,
  );
  
  static const TextStyle instructionText = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppTheme.textSecondary,
    height: 1.5,
  );
  
  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );
  
  static const TextStyle buttonTextLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: Colors.white,
  );
  
  // Stats and numbers
  static const TextStyle statsNumber = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppTheme.textPrimary,
  );
  
  static const TextStyle statsLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppTheme.textSecondary,
  );
  
  static const TextStyle progressText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppTheme.primary,
  );
  
  // Helper text styles
  static const TextStyle helpText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppTheme.textMuted,
    height: 1.4,
  );
  
  static const TextStyle captionText = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppTheme.textTertiary,
    height: 1.3,
  );
}