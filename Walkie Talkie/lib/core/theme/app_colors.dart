import 'package:flutter/material.dart';

/// Semantic Design Tokens for ConnectX Tactical Push-to-Talk Console
class AppColors {
  // Dark Console Backgrounds
  static const Color bgDark = Color(0xFF0B0E14);
  static const Color surfaceDark = Color(0xFF131822);
  static const Color surfaceDarkElevated = Color(0xFF1A2130);
  static const Color surfaceDarkBorder = Color(0xFF26334D);

  // Light Console Backgrounds (High Legibility for daylight/outdoors)
  static const Color bgLight = Color(0xFFF4F6F9);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceLightElevated = Color(0xFFE5E9F0);
  static const Color surfaceLightBorder = Color(0xFFCCD5E2);

  // Status & Transmission Colors
  // Green: Connected / Granted / Live Speaking
  static const Color liveGreen = Color(0xFF10B981);
  static const Color liveGreenDark = Color(0xFF059669);
  static const Color liveGreenGlow = Color(0x6610B981);

  // Orange/Amber: Offline Mode / Nearby Mesh / Floor Requesting
  static const Color meshAmber = Color(0xFFF59E0B);
  static const Color meshAmberDark = Color(0xFFD97706);
  static const Color meshAmberGlow = Color(0x66F59E0B);

  // Red: Emergency / Distressed / Hot Floor Collision / Denied
  static const Color emergencyRed = Color(0xFFEF4444);
  static const Color emergencyRedDark = Color(0xFFB91C1C);
  static const Color emergencyRedGlow = Color(0x66EF4444);

  // Blue: Primary Interactive Action / Tactical Selection
  static const Color tacticalBlue = Color(0xFF2563EB);
  static const Color tacticalBlueLight = Color(0xFF3B82F6);
  static const Color tacticalBlueGlow = Color(0x662563EB);

  // Neutrals & Text
  static const Color textWhite = Color(0xFFF9FAFB);
  static const Color textMutedDark = Color(0xFF94A3B8);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMutedLight = Color(0xFF64748B);

  // PTT Physical Button Gradients & Shading
  static const Color pttBezelDark = Color(0xFF1E293B);
  static const Color pttBezelLight = Color(0xFFE2E8F0);
  static const Color pttCoreIdle = Color(0xFF1E293B);
  static const Color pttCoreActive = Color(0xFF059669);
  static const Color pttCoreBusy = Color(0xFF991B1B);
  static const Color pttCoreOffline = Color(0xFFB45309);
}
