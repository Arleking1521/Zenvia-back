import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    (Icons.home_outlined, 'Главная'),
    (Icons.menu_book_outlined, 'Темы'),
    (Icons.sports_esports_outlined, 'Игры'),
    (Icons.emoji_events_outlined, 'Достижения'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(4, 0, 4, 4),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF2FAEE),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFBFD9B8)),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepBlue.withValues(alpha: .08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: List.generate(_items.length, (index) {
            final item = _items[index];
            final selected = index == currentIndex;

            return Expanded(
              child: InkWell(
                onTap: () => onTap(index),
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 42,
                        height: 34,
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFFE4F5DE) : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          border: selected
                              ? Border.all(color: const Color(0xFFA9D19E))
                              : null,
                        ),
                        child: Icon(
                          item.$1,
                          size: 23,
                          color: selected
                              ? const Color(0xFF477C46)
                              : const Color(0xFF68766A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFF477C46)
                              : const Color(0xFF68766A),
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
