import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppProgressBar extends StatelessWidget {
  final double progress; // 0..1
  final Color color;
  final double height;

  const AppProgressBar({
    super.key,
    required this.progress,
    this.color = AppColors.primary,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: progress.clamp(0, 1),
        minHeight: height,
        backgroundColor: AppColors.trackGrey,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}
