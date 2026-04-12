import 'package:flutter/material.dart';

class AppColors {
  /// Matches the first Clinix splash gradient (slate).
  static const Color splashSlate900 = Color(0xFF0F172A);
  static const Color splashSlate800 = Color(0xFF1E293B);

  static const LinearGradient splashBackgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      splashSlate900,
      splashSlate800,
      splashSlate900,
    ],
  );

  // Primary Dark Blue Palette
  static const Color darkBlue900 = Color(0xFF0A1628);
  static const Color darkBlue800 = Color(0xFF0D1F3C);
  static const Color darkBlue700 = Color(0xFF102A50);
  static const Color darkBlue600 = Color(0xFF163563);
  static const Color darkBlue500 = Color(0xFF1B4080);
  static const Color darkBlue400 = Color(0xFF2255A4);

  // Sky Blue Palette
  static const Color sky100 = Color(0xFFE0F4FF);
  static const Color sky200 = Color(0xFFB3E4FF);
  static const Color sky300 = Color(0xFF7DD3FC);
  static const Color sky400 = Color(0xFF38BDF8);
  static const Color sky500 = Color(0xFF0EA5E9);
  static const Color sky600 = Color(0xFF0284C7);

  // Accent
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentOrange = Color(0xFFF97316);
  static const Color accentRed = Color(0xFFEF4444);

  // Neutrals
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey50 = Color(0xFFF8FAFC);
  static const Color grey100 = Color(0xFFF1F5F9);
  static const Color grey200 = Color(0xFFE2E8F0);
  static const Color grey400 = Color(0xFF94A3B8);
  static const Color grey500 = Color(0xFF64748B);
  static const Color grey700 = Color(0xFF334155);
  static const Color grey900 = Color(0xFF0F172A);
  static const Color slate = Color(0xFF0F172A);

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF0EA5E9);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [darkBlue800, darkBlue600, sky600],
  );

  static const LinearGradient skyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [sky500, sky600],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B4080), Color(0xFF0EA5E9)],
  );
}
