import 'dart:io';
import 'package:flutter/material.dart';
import '../providers/theme_provider.dart';

/// Hiraukan's application theme.
///
/// The default lavender pair is deliberately designed as one identity across
/// light and dark mode: same hierarchy, radii and components, with only the
/// luminance/surface treatment changing. This keeps light mode from feeling
/// like a separate white application while preserving the calmer night look.
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
    final subtleShadow = colorScheme.shadow.withValues(
      alpha: isDark ? 0.24 : 0.08,
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
        shadowColor: subtleShadow,
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
        fillColor: colorScheme.surfaceContainerHigh.withValues(alpha: isDark ? 0.72 : 0.78),
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

  static ColorScheme getColorScheme(ColorSchemeType type, bool isDark) {
    switch (type) {
      case ColorSchemeType.oceanBlue:
        return isDark ? _oceanBlueDark : _oceanBlueLight;
      case ColorSchemeType.forestGreen:
        return isDark ? _forestGreenDark : _forestGreenLight;
      case ColorSchemeType.sunsetOrange:
        return isDark ? _sunsetOrangeDark : _sunsetOrangeLight;
      case ColorSchemeType.lavenderPurple:
        return isDark ? _hiraukanDark : _hiraukanLight;
      case ColorSchemeType.sakuraPink:
        return isDark ? _sakuraPinkDark : _sakuraPinkLight;
      case ColorSchemeType.dynamic:
        return isDark ? _hiraukanDark : _hiraukanLight;
    }
  }

  static ColorScheme _getColorScheme(ColorSchemeType type, bool isDark) =>
      getColorScheme(type, isDark);

  // Hiraukan signature pair. Light is warm/lavender-tinted rather than stark
  // white; dark is a deep blue-black rather than neutral black.
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
    onSecondaryContainer: Color(0xFFEBDD F2),
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

  static const _oceanBlueLight = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF146683),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFBFE9FF),
    onPrimaryContainer: Color(0xFF001F2A),
    secondary: Color(0xFF4D616C),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFD0E6F2),
    onSecondaryContainer: Color(0xFF081E27),
    tertiary: Color(0xFF5E5B7D),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFE4DFFF),
    onTertiaryContainer: Color(0xFF1A1836),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFFAFCFF),
    onSurface: Color(0xFF171C1F),
    onSurfaceVariant: Color(0xFF40484C),
  );

  static const _oceanBlueDark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF8CCFF0),
    onPrimary: Color(0xFF003547),
    primaryContainer: Color(0xFF004D65),
    onPrimaryContainer: Color(0xFFBFE9FF),
    secondary: Color(0xFFB4CAD6),
    onSecondary: Color(0xFF1F333D),
    secondaryContainer: Color(0xFF364954),
    onSecondaryContainer: Color(0xFFD0E6F2),
    tertiary: Color(0xFFC7C2EA),
    onTertiary: Color(0xFF2F2D4C),
    tertiaryContainer: Color(0xFF464364),
    onTertiaryContainer: Color(0xFFE4DFFF),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFB4AB),
    surface: Color(0xFF0F1417),
    onSurface: Color(0xFFDFE3E7),
    onSurfaceVariant: Color(0xFFC0C8CD),
  );

  static const _forestGreenLight = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF3A6F41),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFBBF6BD),
    onPrimaryContainer: Color(0xFF00210A),
    secondary: Color(0xFF52634F),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFD5E8CF),
    onSecondaryContainer: Color(0xFF101F10),
    tertiary: Color(0xFF38656A),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFBCEBF0),
    onTertiaryContainer: Color(0xFF002023),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFFFFBFF),
    onSurface: Color(0xFF1A1C19),
    onSurfaceVariant: Color(0xFF424940),
  );

  static const _forestGreenDark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFA0D9A3),
    onPrimary: Color(0xFF0A3917),
    primaryContainer: Color(0xFF22522A),
    onPrimaryContainer: Color(0xFFBBF6BD),
    secondary: Color(0xFFB9CCB4),
    onSecondary: Color(0xFF243423),
    secondaryContainer: Color(0xFF3A4B38),
    onSecondaryContainer: Color(0xFFD5E8CF),
    tertiary: Color(0xFFA0CFD4),
    onTertiary: Color(0xFF00363B),
    tertiaryContainer: Color(0xFF1F4D52),
    onTertiaryContainer: Color(0xFFBCEBF0),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFB4AB),
    surface: Color(0xFF1A1C19),
    onSurface: Color(0xFFE1E3DF),
    onSurfaceVariant: Color(0xFFC1C9BF),
  );

  static const _sunsetOrangeLight = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF904D00),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFFFDCC2),
    onPrimaryContainer: Color(0xFF2E1500),
    secondary: Color(0xFF735A48),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFFDCC2),
    onSecondaryContainer: Color(0xFF2A150A),
    tertiary: Color(0xFF5D5F2E),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFE2E4A6),
    onTertiaryContainer: Color(0xFF1A1C00),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFFFFBFF),
    onSurface: Color(0xFF201B16),
    onSurfaceVariant: Color(0xFF50453A),
  );

  static const _sunsetOrangeDark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFFB871),
    onPrimary: Color(0xFF4D2700),
    primaryContainer: Color(0xFF6E3900),
    onPrimaryContainer: Color(0xFFFFDCC2),
    secondary: Color(0xFFE3C1A8),
    onSecondary: Color(0xFF42291C),
    secondaryContainer: Color(0xFF5A3F31),
    onSecondaryContainer: Color(0xFFFFDCC2),
    tertiary: Color(0xFFC6C88C),
    onTertiary: Color(0xFF2F3104),
    tertiaryContainer: Color(0xFF454819),
    onTertiaryContainer: Color(0xFFE2E4A6),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFB4AB),
    surface: Color(0xFF18130E),
    onSurface: Color(0xFFEDE0D8),
    onSurfaceVariant: Color(0xFFD3C4B8),
  );

  static const _sakuraPinkLight = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFFB4276E),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFFFD8E8),
    onPrimaryContainer: Color(0xFF3E0025),
    secondary: Color(0xFF73565E),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFFD8E1),
    onSecondaryContainer: Color(0xFF2A151C),
    tertiary: Color(0xFF7C5635),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFFDCC1),
    onTertiaryContainer: Color(0xFF2E1500),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFFFFBFF),
    onSurface: Color(0xFF201A1B),
    onSurfaceVariant: Color(0xFF514347),
  );

  static const _sakuraPinkDark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFFB0CB),
    onPrimary: Color(0xFF64003E),
    primaryContainer: Color(0xFF8E0056),
    onPrimaryContainer: Color(0xFFFFD8E8),
    secondary: Color(0xFFE3BDC6),
    onSecondary: Color(0xFF422930),
    secondaryContainer: Color(0xFF5A3F47),
    onSecondaryContainer: Color(0xFFFFD8E1),
    tertiary: Color(0xFFEDBD94),
    onTertiary: Color(0xFF48290C),
    tertiaryContainer: Color(0xFF623F20),
    onTertiaryContainer: Color(0xFFFFDCC1),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFB4AB),
    surface: Color(0xFF1A1A1A),
    onSurface: Color(0xFFEBE0E1),
    onSurfaceVariant: Color(0xFFD5C2C6),
  );
}
