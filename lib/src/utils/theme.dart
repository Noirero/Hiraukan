import 'dart:io';
import 'package:flutter/material.dart';
import '../providers/theme_provider.dart';

/// Hiraukan's shared visual system.
///
/// Light and dark are a matched pair: the same hierarchy, spacing, radii and
/// component treatment are used in both modes. Light mode is intentionally a
/// warm lavender-tinted surface rather than stark white; dark mode is a deep
/// navy-black with the same lavender identity.
class AppTheme {
  static const _pageTransitionsTheme = PageTransitionsTheme();

  @visibleForTesting
  static List<String> iosFontFamilyFallback(Locale locale) {
    if (locale.languageCode == 'zh') {
      final isTraditional = locale.scriptCode == 'Hant' ||
          locale.countryCode == 'TW' ||
          locale.countryCode == 'HK' ||
          locale.countryCode == 'MO';
      return isTraditional
          ? const ['PingFang TC', 'PingFang HK', 'Hiragino Sans']
          : const ['PingFang SC', 'PingFang TC', 'Hiragino Sans'];
    }
    return const ['Hiragino Sans', 'PingFang SC', 'PingFang TC'];
  }

  static List<String>? _platformFontFamilyFallback(Locale locale) =>
      Platform.isIOS ? iosFontFamilyFallback(locale) : null;

  static TextTheme? _getTextTheme() {
    if (Platform.isWindows) {
      const fontFamily = 'Microsoft YaHei';
      return const TextTheme(
        displayLarge: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w400),
        displayMedium: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w400),
        displaySmall: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w400),
        headlineLarge: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w500),
        headlineMedium: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w500),
        headlineSmall: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w500),
        titleLarge: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w400),
        bodySmall: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w400),
        labelLarge: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        labelSmall: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
      );
    }
    if (Platform.isLinux) {
      const fallback = [
        'Noto Sans CJK SC',
        'Noto Sans CJK TC',
        'Noto Sans CJK JP',
        'Source Han Sans SC',
        'WenQuanYi Micro Hei',
        'Droid Sans Fallback',
      ];
      return const TextTheme(
        displayLarge: TextStyle(fontFamilyFallback: fallback, fontWeight: FontWeight.w400),
        displayMedium: TextStyle(fontFamilyFallback: fallback, fontWeight: FontWeight.w400),
        displaySmall: TextStyle(fontFamilyFallback: fallback, fontWeight: FontWeight.w400),
        headlineLarge: TextStyle(fontFamilyFallback: fallback, fontWeight: FontWeight.w500),
        headlineMedium: TextStyle(fontFamilyFallback: fallback, fontWeight: FontWeight.w500),
        headlineSmall: TextStyle(fontFamilyFallback: fallback, fontWeight: FontWeight.w500),
        titleLarge: TextStyle(fontFamilyFallback: fallback, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontFamilyFallback: fallback, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(fontFamilyFallback: fallback, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontFamilyFallback: fallback, fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(fontFamilyFallback: fallback, fontWeight: FontWeight.w400),
        bodySmall: TextStyle(fontFamilyFallback: fallback, fontWeight: FontWeight.w400),
        labelLarge: TextStyle(fontFamilyFallback: fallback, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(fontFamilyFallback: fallback, fontWeight: FontWeight.w600),
        labelSmall: TextStyle(fontFamilyFallback: fallback, fontWeight: FontWeight.w600),
      );
    }
    return null;
  }

  static ThemeData lightTheme(
    ColorScheme? lightDynamic, [
    ColorSchemeType? themeType,
    Locale? locale,
  ]) {
    final scheme = lightDynamic ??
        _getColorScheme(themeType ?? ColorSchemeType.lavenderPurple, false);
    return _buildTheme(scheme, locale);
  }

  static ThemeData darkTheme(
    ColorScheme? darkDynamic, [
    ColorSchemeType? themeType,
    Locale? locale,
  ]) {
    final scheme = darkDynamic ??
        _getColorScheme(themeType ?? ColorSchemeType.lavenderPurple, true);
    return _buildTheme(scheme, locale);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme, Locale? locale) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final borderColor = colorScheme.outlineVariant.withValues(
      alpha: isDark ? 0.34 : 0.52,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
      textTheme: _getTextTheme(),
      fontFamilyFallback: _platformFontFamilyFallback(
        locale ?? WidgetsBinding.instance.platformDispatcher.locale,
      ),
      pageTransitionsTheme: _pageTransitionsTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: borderColor, width: 0.7),
          borderRadius: const BorderRadius.all(Radius.circular(20)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        indicatorColor: colorScheme.primaryContainer,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            size: selected ? 24 : 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        iconColor: colorScheme.onSurfaceVariant,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh.withValues(
          alpha: isDark ? 0.72 : 0.78,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor, width: 0.7),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: isDark ? 0.32 : 0.48),
        thickness: 0.7,
        space: 1,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 1,
        highlightElevation: 0,
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          elevation: const WidgetStatePropertyAll(0),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          elevation: const WidgetStatePropertyAll(0),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll(BorderSide(color: borderColor)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHighest,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.surfaceContainerHighest,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withValues(alpha: 0.12),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static ColorScheme getColorScheme(ColorSchemeType type, bool isDark) =>
      _getColorScheme(type, isDark);

  static ColorScheme _getColorScheme(ColorSchemeType type, bool isDark) {
    switch (type) {
      case ColorSchemeType.lavenderPurple:
      case ColorSchemeType.dynamic:
        return isDark ? _hiraukanDark : _hiraukanLight;
      case ColorSchemeType.oceanBlue:
        return _seededScheme(
          const Color(0xFF146683),
          isDark,
          darkSurface: const Color(0xFF0F1417),
          lightSurface: const Color(0xFFFAFCFF),
        );
      case ColorSchemeType.forestGreen:
        return _seededScheme(
          const Color(0xFF3A6F41),
          isDark,
          darkSurface: const Color(0xFF171B18),
          lightSurface: const Color(0xFFF8FBF7),
        );
      case ColorSchemeType.sunsetOrange:
        return _seededScheme(
          const Color(0xFF904D00),
          isDark,
          darkSurface: const Color(0xFF18130E),
          lightSurface: const Color(0xFFFFF9F4),
        );
      case ColorSchemeType.sakuraPink:
        return _seededScheme(
          const Color(0xFFB4276E),
          isDark,
          darkSurface: const Color(0xFF1A1518),
          lightSurface: const Color(0xFFFFF8FB),
        );
    }
  }

  static ColorScheme _seededScheme(
    Color seed,
    bool isDark, {
    required Color darkSurface,
    required Color lightSurface,
  }) {
    return ColorScheme.fromSeed(
      seedColor: seed,
      brightness: isDark ? Brightness.dark : Brightness.light,
    ).copyWith(surface: isDark ? darkSurface : lightSurface);
  }

  static const _hiraukanLight = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF8F67BC),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE9DDF4),
    onPrimaryContainer: Color(0xFF2B183B),
    secondary: Color(0xFF74627E),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE8DEE9),
    onSecondaryContainer: Color(0xFF2A202F),
    tertiary: Color(0xFF865F76),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFF3DAE7),
    onTertiaryContainer: Color(0xFF351D2B),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFF5F1F3),
    onSurface: Color(0xFF25202B),
    onSurfaceVariant: Color(0xFF5E5663),
  );

  static const _hiraukanDark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFC9A7FF),
    onPrimary: Color(0xFF35204D),
    primaryContainer: Color(0xFF4B3863),
    onPrimaryContainer: Color(0xFFF0E5FF),
    secondary: Color(0xFFCDBED8),
    onSecondary: Color(0xFF352E3D),
    secondaryContainer: Color(0xFF463D4E),
    onSecondaryContainer: Color(0xFFEBDDF2),
    tertiary: Color(0xFFE5B7D1),
    onTertiary: Color(0xFF45283A),
    tertiaryContainer: Color(0xFF5D3D50),
    onTertiaryContainer: Color(0xFFFFD9EC),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF0C111B),
    onSurface: Color(0xFFF4F0F7),
    onSurfaceVariant: Color(0xFFC8BDC9),
  );
}
