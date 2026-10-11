import 'package:flutter/material.dart';

import 'colors.dart';

/// Single dark-only Material 3 theme for Saldo — "Ruled Saldo":
/// green-cast charcoal surfaces, restrained emerald accent. Inter
/// throughout with tabular figures for amounts. Flat solids only,
/// generous spacing, no gradients or glows.
abstract final class SaldoTheme {
  static const String bodyFamily = 'Inter';

  /// Kept for test/font-loader compatibility; theme no longer uses it.
  static const String displayFamily = 'Inter';

  static ThemeData dark() {
    final colorScheme = const ColorScheme.dark(
      primary: SaldoColors.primary,
      secondary: SaldoColors.primary,
      surface: SaldoColors.surface,
      error: SaldoColors.expense,
      onPrimary: SaldoColors.background,
      onSecondary: SaldoColors.background,
      onSurface: SaldoColors.textPrimary,
      onSurfaceVariant: SaldoColors.textSecondary,
      outline: SaldoColors.border,
      outlineVariant: SaldoColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: bodyFamily,
      scaffoldBackgroundColor: SaldoColors.background,
      colorScheme: colorScheme,
      canvasColor: SaldoColors.background,
      cardColor: SaldoColors.surface,
      dividerColor: SaldoColors.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: SaldoColors.background,
        foregroundColor: SaldoColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: bodyFamily,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: SaldoColors.textPrimary,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: SaldoColors.surface,
        selectedItemColor: SaldoColors.primary,
        unselectedItemColor: SaldoColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: SaldoColors.primary,
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
              color: SaldoColors.background,
              size: 22,
            );
          }
          return const IconThemeData(
            color: SaldoColors.textSecondary,
            size: 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: bodyFamily,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: SaldoColors.primary,
            );
          }
          return const TextStyle(
            fontFamily: bodyFamily,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: SaldoColors.textSecondary,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: SaldoColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: SaldoColors.border, width: 1),
        ),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: SaldoColors.elevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: SaldoColors.border, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: SaldoColors.surface,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          side: BorderSide(color: SaldoColors.border, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: SaldoColors.elevated,
        selectedColor: SaldoColors.elevated,
        labelStyle: const TextStyle(
          fontFamily: bodyFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: SaldoColors.textSecondary,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: bodyFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: SaldoColors.primary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: SaldoColors.border, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: SaldoColors.primary,
        foregroundColor: SaldoColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: SaldoColors.elevated,
        contentTextStyle: const TextStyle(
          fontFamily: bodyFamily,
          fontSize: 14,
          color: SaldoColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: SaldoColors.border, width: 1),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: SaldoColors.primary,
        linearTrackColor: SaldoColors.elevated,
        circularTrackColor: SaldoColors.elevated,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return SaldoColors.elevated;
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return SaldoColors.primary;
            }
            return SaldoColors.textSecondary;
          }),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SaldoColors.elevated,
        hintStyle: const TextStyle(color: SaldoColors.textSecondary),
        labelStyle: const TextStyle(color: SaldoColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SaldoColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SaldoColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SaldoColors.primary, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SaldoColors.expense),
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: const WidgetStatePropertyAll(SaldoColors.elevated),
        elevation: const WidgetStatePropertyAll(0),
        overlayColor: const WidgetStatePropertyAll(SaldoColors.primaryDim),
        hintStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: bodyFamily,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: SaldoColors.textSecondary,
          ),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: bodyFamily,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: SaldoColors.textPrimary,
          ),
        ),
        side: const WidgetStatePropertyAll(
          BorderSide(color: SaldoColors.border, width: 1),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        constraints: const BoxConstraints(minHeight: 48, minWidth: 320),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SaldoColors.primary,
          foregroundColor: SaldoColors.background,
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: bodyFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SaldoColors.primary,
          textStyle: const TextStyle(
            fontFamily: bodyFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textTheme: const TextTheme(
        // Hero balance — Inter Bold, tabular for alignment.
        displaySmall: TextStyle(
          fontFamily: bodyFamily,
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: SaldoColors.textPrimary,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        // Screen title — Inter SemiBold.
        headlineSmall: TextStyle(
          fontFamily: bodyFamily,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: SaldoColors.textPrimary,
        ),
        // Section heading — 18 SemiBold.
        titleLarge: TextStyle(
          fontFamily: bodyFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: SaldoColors.textPrimary,
        ),
        // Transaction title — 15 Medium.
        titleMedium: TextStyle(
          fontFamily: bodyFamily,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: SaldoColors.textPrimary,
        ),
        // Body and amounts — 14 Regular/Medium, tabular for amounts.
        bodyLarge: TextStyle(
          fontFamily: bodyFamily,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: SaldoColors.textPrimary,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        bodyMedium: TextStyle(
          fontFamily: bodyFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: SaldoColors.textPrimary,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        // Labels and metadata — 12 Regular.
        labelSmall: TextStyle(
          fontFamily: bodyFamily,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: SaldoColors.textSecondary,
        ),
        labelMedium: TextStyle(
          fontFamily: bodyFamily,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: SaldoColors.textSecondary,
        ),
      ),
    );
  }
}
