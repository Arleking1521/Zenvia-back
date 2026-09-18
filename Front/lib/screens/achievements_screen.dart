import 'package:flutter/material.dart';

import '../data/app_repository.dart';
import '../models/achievement.dart';
import '../theme/app_colors.dart';
import '../widgets/achievement_card.dart';
import '../widgets/magic_ui.dart';

class AchievementsScreen extends StatefulWidget {
  final AppRepository repository;
  const AchievementsScreen({super.key, required this.repository});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late Future<List<Achievement>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.getAchievements();
  }

  @override
  void didUpdateWidget(covariant AchievementsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _future = widget.repository.getAchievements();
  }

  void _reload() => setState(() { _future = widget.repository.getAchievements(); });

  @override
  Widget build(BuildContext context) {
    return FantasyBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: MagicCard(
                padding: EdgeInsets.zero,
                gradient: AppColors.sunsetGradient,
                child: SizedBox(
                  height: 150,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.asset('assets/images/dragon_cheer.png', fit: BoxFit.cover),
                        ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: LinearGradient(colors: [AppColors.deepBlue.withValues(alpha: .78), Colors.transparent]),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: Material(
                          color: Colors.white.withValues(alpha: .20),
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            customBorder: const CircleBorder(),
                            child: const SizedBox(
                              width: 42,
                              height: 42,
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 64,
                        top: 20,
                        width: 185,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Твои награды ⭐', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
                            SizedBox(height: 6),
                            Text('Каждое достижение делает твоего дракона сильнее!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, height: 1.25)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Achievement>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  }
                  if (snapshot.hasError) return Center(child: MagicPrimaryButton(label: 'Повторить', onPressed: _reload));
                  final items = snapshot.data!;
                  if (items.isEmpty) return const Center(child: Text('Достижений пока нет'));
                  return RefreshIndicator(
                    onRefresh: () async {
                      _reload();
                      await _future;
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => AchievementCard(achievement: items[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
