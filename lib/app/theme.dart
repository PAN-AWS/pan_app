// lib/app/theme.dart
import 'package:flutter/material.dart';

ThemeData buildLightTheme() => _baseTheme(Brightness.light);
ThemeData buildDarkTheme() => _baseTheme(Brightness.dark);

ThemeData _baseTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2E7D32), // verde PAN
    brightness: brightness,
  );

  final textTheme = Typography.material2021(platform: TargetPlatform.android)
      .black
      .apply(
    fontSizeFactor: 1.0,
    displayColor: colorScheme.onBackground,
    bodyColor: colorScheme.onBackground,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor:
    isDark ? const Color(0xFF101214) : const Color(0xFFF8FAF9),
    textTheme: textTheme,

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle:
      textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    ),

    // Cards (Flutter 3.22+ usa CardThemeData)
    cardTheme: CardThemeData(
      elevation: 0,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isDark ? const Color(0xFF15181A) : Colors.white,
    ),

    // ListTile
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      iconColor: colorScheme.onSurfaceVariant,
    ),

    // Bottoni
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const MaterialStatePropertyAll(Size(48, 44)),
        shape: MaterialStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const MaterialStatePropertyAll(Size(48, 44)),
        side:
        MaterialStatePropertyAll(BorderSide(color: colorScheme.outline)),
        shape: MaterialStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        shape: MaterialStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    // Input
    inputDecorationTheme: InputDecorationTheme(
      isDense: false,
      filled: !isDark,
      fillColor: isDark ? null : const Color(0xFFF1F3F2),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),

    // NavigationBar (bottom)
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      backgroundColor: colorScheme.surface,
      indicatorColor: colorScheme.primary.withOpacity(0.15),
      labelTextStyle: MaterialStatePropertyAll(
        textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),

    // SnackBar
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor:
      isDark ? const Color(0xFF1D2123) : const Color(0xFF2F3B37),
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    // Divider/Popup/Menu
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant.withOpacity(0.6),
      thickness: 1,
      space: 1,
    ),
    popupMenuTheme: PopupMenuThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(color: colorScheme.outlineVariant),
      labelStyle: textTheme.labelLarge,
      backgroundColor:
      isDark ? const Color(0xFF171A1C) : const Color(0xFFEFF3F0),
      selectedColor: colorScheme.primary.withOpacity(0.15),
      secondarySelectedColor:
      colorScheme.secondary.withOpacity(0.15),
    ),
  );
}

/// Spaziatura rapida
extension Gaps on num {
  SizedBox get h => SizedBox(height: toDouble());
  SizedBox get w => SizedBox(width: toDouble());
}
