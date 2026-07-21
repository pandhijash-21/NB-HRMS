import 'package:flutter/material.dart';

class AppColors {
  // Ultra-Professional Enterprise Palette
  
  // Primary Brand Colors (Cool Ambient Professional CRM Blue)
  static const Color primaryBlue = Color(0xFF2563EB); // Vibrant Cool Blue
  static const Color primaryBlueDark = Color(0xFF1D4ED8); // Deep Cool Blue
  
  // Light Mode Colors
  static const Color backgroundLight = Color(0xFFF4F4F4); // Very crisp light gray
  static const Color surfaceLight = Color(0xFFFFFFFF); // Pure white surfaces
  static const Color borderLight = Color(0xFFE0E0E0); // Subtle borders
  
  static const Color textPrimaryLight = Color(0xFF334155); // Deep slate (no black)
  static const Color textSecondaryLight = Color(0xFF64748B); // Mid slate
  
  // Dark Mode Colors
  static const Color backgroundDark = Color(0xFF161616); // Deep charcoal
  static const Color surfaceDark = Color(0xFF262626); // Elevated charcoal
  static const Color borderDark = Color(0xFF393939); // Dark borders
  
  static const Color textPrimaryDark = Color(0xFFF4F4F4); // Light text
  static const Color textSecondaryDark = Color(0xFFA8A8A8); // Dimmed text
  
  // Status Colors (WCAG compliant)
  static const Color success = Color(0xFF24A148);
  static const Color successSoft = Color(0xFFD1FAE5);
  static const Color error = Color(0xFFDA1E28);
  static const Color errorSoft = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFF1C21B);
  static const Color info = Color(0xFF0043CE);

  // Legacy variables mapped to new professional colors
  static const Color surface = surfaceLight;
  static const Color textPrimary = textPrimaryLight;
  static const Color textSecondary = textSecondaryLight;
  static const Color border = borderLight;
  
  static const Color bronze = Color(0xFFC5A059);
  static const Color bronzeDark = Color(0xFFA37F3E);
  static const Color sand = backgroundLight;
  static const Color mist = borderLight;
  static const Color midnight = backgroundDark;
  static const Color slate = surfaceDark;
}
