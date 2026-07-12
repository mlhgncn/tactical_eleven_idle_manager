import 'package:flutter/material.dart';

/// Colors lifted directly from the "Maç Gecesi" (Match Night) design spec -
/// the dark navy/gold stadium-at-night style the asset pack (badges,
/// buttons, player card frame) was already drawn in. Previously the app had
/// no real theme at all (just the Flutter template's default deep-purple
/// seed color), so every screen fell back to Material's light defaults
/// except the handful this session hand-styled directly.
class AppColors {
  AppColors._();

  static const background = Color(0xFF0B111D);
  static const cardTop = Color(0xFF131C30);
  static const cardBottom = Color(0xFF0F1728);
  static const cardBorder = Color(0xFF1E2A44);
  static const navBackground = Color(0xFF0D1424);

  static const textPrimary = Color(0xFFEAEFF7);
  static const textMuted = Color(0xFF93A2BC);
  static const navInactive = Color(0xFF8393AD);

  static const gold = Color(0xFFD9A93F);
  static const goldLight = Color(0xFFF0C860);
  static const goldOnGoldText = Color(0xFF2B2008);

  static const blue = Color(0xFF61BEFF);
  static const green = Color(0xFF3FBF7A);
  static const red = Color(0xFFE06A6B);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      // Kills Material's default gray/white press overlay (ripple +
      // highlight) app-wide, since the hand-drawn gold/glass button assets
      // already convey a pressed state visually and the stock overlay just
      // muddies them - a cleaner touch feel per the design spec.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      colorScheme: base.colorScheme.copyWith(
        surface: AppColors.background,
        primary: AppColors.gold,
        secondary: AppColors.blue,
        error: AppColors.red,
        onPrimary: AppColors.goldOnGoldText,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardTop,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
      ),
      dividerColor: AppColors.cardBorder,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardTop,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        labelStyle: const TextStyle(color: AppColors.textMuted),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.navBackground,
        selectedItemColor: AppColors.goldLight,
        unselectedItemColor: AppColors.navInactive,
        type: BottomNavigationBarType.fixed,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.goldOnGoldText,
        ).copyWith(
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom().copyWith(
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom().copyWith(
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom().copyWith(
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.cardTop,
        labelStyle: const TextStyle(color: AppColors.textPrimary),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(AppColors.cardTop),
        dataRowColor: WidgetStateProperty.all(AppColors.background),
      ),
    );
  }
}
