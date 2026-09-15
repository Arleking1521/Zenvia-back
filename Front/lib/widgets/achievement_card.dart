import 'package:flutter/material.dart';

import '../models/achievement.dart';
import '../theme/app_colors.dart';
import 'progress_bar.dart';

class AchievementCard extends StatelessWidget {
  final Achievement achievement;

  const AchievementCard({
    super.key,
    required this.achievement,
  });

  @override
  Widget build(BuildContext context) {
    final completed = achievement.isCompleted;
    final locked = achievement.current == 0;

    return Opacity(
      opacity: locked ? 0.75 : 1,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(20),
          border: completed
              ? Border.all(
                  color: AppColors.primary,
                  width: 1.5,
                )
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: achievement.iconBg,
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: _AchievementIcon(achievement: achievement),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    achievement.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    achievement.description,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (!completed) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: AppProgressBar(
                            progress: achievement.progress,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${achievement.current}/${achievement.target}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            completed
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '+${achievement.xpReward} XP',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: locked
                          ? AppColors.lockedBg
                          : AppColors.starBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '+${achievement.xpReward} XP',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: locked
                            ? AppColors.textMuted
                            : AppColors.starText,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _AchievementIcon extends StatelessWidget {
  final Achievement achievement;

  const _AchievementIcon({
    required this.achievement,
  });

  @override
  Widget build(BuildContext context) {
    final url = achievement.iconUrl;

    if (url == null || url.isEmpty) {
      return Text(
        achievement.emoji,
        style: const TextStyle(fontSize: 24),
      );
    }

    return Image.network(
      url,
      width: 52,
      height: 52,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Text(
        achievement.emoji,
        style: const TextStyle(fontSize: 24),
      ),
    );
  }
}
