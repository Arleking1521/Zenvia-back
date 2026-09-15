import 'package:flutter/material.dart';

import '../models/topic.dart';
import '../theme/app_colors.dart';
import 'progress_bar.dart';

class TopicCard extends StatelessWidget {
  final Topic topic;
  final VoidCallback onTap;
  final bool compact;

  const TopicCard({
    super.key,
    required this.topic,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: topic.color.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: _TopicIcon(topic: topic),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    topic.number > 0
                        ? '${topic.number}. ${topic.title}'
                        : topic.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    topic.description,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 8),
                    AppProgressBar(progress: topic.progress),
                  ],
                ],
              ),
            ),
            if (compact) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 2),
              Text(
                '${topic.learnedCount}/${topic.totalCount}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopicIcon extends StatelessWidget {
  final Topic topic;

  const _TopicIcon({required this.topic});

  @override
  Widget build(BuildContext context) {
    final url = topic.iconUrl;

    if (url == null || url.isEmpty) {
      return Text(
        topic.emoji,
        style: const TextStyle(fontSize: 26),
      );
    }

    return Image.network(
      url,
      width: 52,
      height: 52,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Text(
        topic.emoji,
        style: const TextStyle(fontSize: 26),
      ),
    );
  }
}
