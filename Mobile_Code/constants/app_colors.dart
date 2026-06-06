import 'package:flutter/material.dart';

class AppColors {
  // Light theme
  static const Color lightBackground = Color(0xFFF3EFE8);
  static const Color gradientStart = Color(0xFFF8C399);
  static const Color gradientEnd = Color(0xFFF37E94);
  
  // Dark theme
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color grey = Colors.grey;
  
  static LinearGradient get primaryGradient => const LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Theme-aware background color
  static Color background(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkBackground : lightBackground;
  }
}