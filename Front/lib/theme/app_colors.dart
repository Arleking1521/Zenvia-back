import 'package:flutter/material.dart';

/// Единая цветовая система приложения — соответствует Figma-макету.
class AppColors {
  AppColors._();

  // Основной зелёный — кнопки, активные состояния, прогресс-бары
  static const primary = Color(0xFF4CC94D);
  static const primaryDark = Color(0xFF3B6D11);

  // Фон экранов
  static const background = Color(0xFFE8F6E8);
  static const bottomNavSelectedBg = Color(0xFFEAF3DE);

  // Опасное действие / предупреждение
  static const danger = Color(0xFFFF5C5C);

  // Награда (звёзды)
  static const star = Color(0xFFEF9F27);
  static const starBg = Color(0xFFFAEEDA);
  static const starText = Color(0xFF854F0B);

  // Акцентная палитра для тем/языков/игр (используется по одному цвету на сущность,
  // не хаотично — синий, коралл, бирюза, фиолетовый, жёлтый)
  static const accentBlue = Color(0xFF4DA6FF);
  static const accentCoral = Color(0xFFFF6F6F);
  static const accentTeal = Color(0xFF2EC4B6);
  static const accentPurple = Color(0xFFA66DE0);
  static const accentYellow = Color(0xFFFFC93C);

  // Нейтральные
  static const textPrimary = Color(0xFF2C2C2A);
  static const textSecondary = Color(0xFF5F5E5A);
  static const textMuted = Color(0xFF888780);
  static const surfaceWhite = Colors.white;
  static const trackGrey = Color(0xFFEFEFE8);
  static const lockedBg = Color(0xFFF1EFE8);
}
