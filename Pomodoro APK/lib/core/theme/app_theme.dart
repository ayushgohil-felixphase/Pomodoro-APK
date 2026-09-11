import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: AppColors.workPrimary,
      secondary: AppColors.shortBreakPrimary,
      tertiary: AppColors.longBreakPrimary,
      surface: AppColors.lightSurface,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.lightText,
    ),
    scaffoldBackgroundColor: AppColors.lightBackground,
    cardTheme: CardThemeData(
      color: AppColors.lightCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.06), width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.lightText,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
      iconTheme: IconThemeData(color: AppColors.lightText),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.workPrimary,
      thumbColor: AppColors.workPrimary,
      inactiveTrackColor: AppColors.workPrimary.withValues(alpha: 0.2),
      trackHeight: 6,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: AppColors.workPrimary,
      secondary: AppColors.shortBreakPrimary,
      tertiary: AppColors.longBreakPrimary,
      surface: AppColors.darkSurface,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.darkText,
    ),
    scaffoldBackgroundColor: AppColors.darkBackground,
    cardTheme: CardThemeData(
      color: AppColors.darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.06), width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.darkText,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
      iconTheme: IconThemeData(color: AppColors.darkText),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.workPrimary,
      thumbColor: AppColors.workPrimary,
      inactiveTrackColor: AppColors.workPrimary.withValues(alpha: 0.3),
      trackHeight: 6,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
    ),
  );
}
