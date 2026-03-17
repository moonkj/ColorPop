import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // 배경
  static const Color background = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF16161F);
  static const Color card = Color(0xFF1F1F2E);
  static const Color divider = Color(0xFF2D2D3E);

  // 브랜드
  static const Color primary = Color(0xFF7C3AED);      // Violet
  static const Color primaryLight = Color(0xFFA855F7);
  static const Color accent = Color(0xFFEC4899);        // Pink
  static const Color accentSecondary = Color(0xFF6366F1); // Indigo

  // 텍스트
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textTertiary = Color(0xFF4B5563);

  // 상태
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);

  // 오버레이
  static const Color overlayDark = Color(0xCC000000);
  static const Color overlayLight = Color(0x33FFFFFF);

  // 그라디언트
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardOverlay = LinearGradient(
    colors: [Colors.transparent, Color(0xCC000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
