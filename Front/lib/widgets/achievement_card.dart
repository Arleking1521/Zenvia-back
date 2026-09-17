import 'package:flutter/material.dart';
import '../models/achievement.dart';
import '../theme/app_colors.dart';

class AchievementCard extends StatelessWidget {
  final Achievement achievement;
  const AchievementCard({super.key, required this.achievement});

  @override
  Widget build(BuildContext context) {
    final completed = achievement.isCompleted;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: completed
            ? const LinearGradient(colors: [Color(0xFFFFF7CF), Colors.white])
            : null,
        color: completed ? null : Colors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: completed ? AppColors.gold : achievement.iconBg.withValues(alpha: .35), width: 1.5),
        boxShadow: [BoxShadow(color: AppColors.deepBlue.withValues(alpha: .08), blurRadius: 18, offset: const Offset(0, 7))],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(color: achievement.iconBg, borderRadius: BorderRadius.circular(20)),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: _AchievementIcon(achievement: achievement),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(achievement.title, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.deepBlue, fontSize: 15)),
                const SizedBox(height: 3),
                Text(achievement.description, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: achievement.progress,
                    minHeight: 8,
                    backgroundColor: AppColors.trackGrey,
                    valueColor: AlwaysStoppedAnimation(completed ? AppColors.gold : AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              Icon(completed ? Icons.star_rounded : Icons.auto_awesome_rounded, color: completed ? AppColors.goldDark : AppColors.purple),
              Text('+${achievement.xpReward}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.deepBlue)),
              const Text('XP', style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AchievementIcon extends StatelessWidget {
  final Achievement achievement;
  const _AchievementIcon({required this.achievement});
  @override
  Widget build(BuildContext context) {
    final url = achievement.iconUrl;
    if (url == null || url.isEmpty) return Text(achievement.emoji, style: const TextStyle(fontSize: 30));
    return Image.network(url, fit: BoxFit.cover, width: 62, height: 62, errorBuilder: (_, __, ___) => Text(achievement.emoji, style: const TextStyle(fontSize: 30)));
  }
}
