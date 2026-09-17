import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand / fantasy palette
  static const primary = Color(0xFF20C96B);
  static const primaryDark = Color(0xFF087A55);
  static const primaryLight = Color(0xFF7BF0A6);
  static const skyTop = Color(0xFF117BD7);
  static const skyMid = Color(0xFF4CC8F5);
  static const skyBottom = Color(0xFFEAF9FF);
  static const deepBlue = Color(0xFF0E3B7D);
  static const gold = Color(0xFFFFC83D);
  static const goldDark = Color(0xFFD98609);
  static const pink = Color(0xFFFF6BA8);
  static const purple = Color(0xFF8266E8);
  static const cyan = Color(0xFF20C5D8);
  static const coral = Color(0xFFFF7474);

  // Backward-compatible names used across the project.
  static const background = Color(0xFFEFFBFF);
  static const bottomNavSelectedBg = Color(0xFFE7F9EA);
  static const danger = Color(0xFFFF5C68);
  static const star = gold;
  static const starBg = Color(0xFFFFF4CF);
  static const starText = Color(0xFF9A5B00);
  static const accentBlue = Color(0xFF4A9FF5);
  static const accentCoral = coral;
  static const accentTeal = Color(0xFF2AC5B3);
  static const accentPurple = purple;
  static const accentYellow = gold;
  static const textPrimary = Color(0xFF15315F);
  static const textSecondary = Color(0xFF5B6B87);
  static const textMuted = Color(0xFF98A5B8);
  static const surfaceWhite = Colors.white;
  static const trackGrey = Color(0xFFE7EEF7);
  static const lockedBg = Color(0xFFE6ECF3);

  static const magicGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0CA6E9), Color(0xFF176CD0)],
  );

  static const greenGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF43E77E), Color(0xFF11B75C)],
  );

  static const sunsetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD85A), Color(0xFFFF8D6A), Color(0xFFB77CF4)],
  );
}
