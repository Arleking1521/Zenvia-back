import 'package:flutter/material.dart';

import '../data/app_repository.dart';
import '../models/language.dart';
import '../models/topic.dart';
import '../theme/app_colors.dart';
import '../widgets/topic_card.dart';
import 'topic_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppRepository repository;
  final VoidCallback onOpenSettings;
  final VoidCallback onSeeAllTopics;

  const HomeScreen({
    super.key,
    required this.repository,
    required this.onOpenSettings,
    required this.onSeeAllTopics,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> _future;
  AppLanguage _selectedLanguage = AppLanguage.english;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final lang = await widget.repository.getSelectedLanguage();
    _selectedLanguage = lang;

    final results = await Future.wait<dynamic>([
      widget.repository.getTopics(),
      widget.repository.getChildName(),
      widget.repository.getLevel(),
      widget.repository.getXp(),
    ]);

    return _HomeData(
      topics: results[0] as List<Topic>,
      name: results[1] as String,
      level: results[2] as int,
      xp: results[3] as int,
    );
  }

  Future<void> _selectLanguage(AppLanguage lang) async {
    await widget.repository.setSelectedLanguage(lang);

    if (!mounted) return;

    setState(() {
      _selectedLanguage = lang;
      _future = _load();
    });
  }

  void _retry() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (snapshot.hasError) {
          return _ApiErrorState(
            message: snapshot.error.toString(),
            onRetry: _retry,
          );
        }

        final data = snapshot.data!;

        return SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _future = _load();
              });
              await _future;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _TopBar(
                  level: data.level,
                  xp: data.xp,
                  onSettings: widget.onOpenSettings,
                ),
                const SizedBox(height: 16),
                Text(
                  'Привет, ${data.name}!',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Давай сегодня попробуем что-то новое!',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _LanguagePicker(
                  selected: _selectedLanguage,
                  onSelect: _selectLanguage,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Продолжить обучение',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextButton(
                      onPressed: widget.onSeeAllTopics,
                      child: const Text('Смотреть всё'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (data.topics.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'Для этого языка пока нет тем',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ...data.topics.map(
                  (topic) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TopicCard(
                      topic: topic,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TopicDetailScreen(
                            topic: topic,
                            language: _selectedLanguage,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeData {
  final List<Topic> topics;
  final String name;
  final int level;
  final int xp;

  _HomeData({
    required this.topics,
    required this.name,
    required this.level,
    required this.xp,
  });
}

class _TopBar extends StatelessWidget {
  final int level;
  final int xp;
  final VoidCallback onSettings;

  const _TopBar({
    required this.level,
    required this.xp,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _RoundIconButton(
          icon: Icons.settings_rounded,
          onTap: onSettings,
        ),
        Text(
          'Уровень $level',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.bolt_rounded,
                color: AppColors.star,
                size: 17,
              ),
              const SizedBox(width: 3),
              Text(
                '$xp XP',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  final AppLanguage selected;
  final ValueChanged<AppLanguage> onSelect;

  const _LanguagePicker({
    required this.selected,
    required this.onSelect,
  });

  static const _colors = {
    AppLanguage.english: AppColors.accentBlue,
    AppLanguage.chinese: AppColors.accentCoral,
    AppLanguage.kazakh: AppColors.accentTeal,
    AppLanguage.russian: AppColors.accentPurple,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Какой язык изучаем сегодня?',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: AppLanguage.values.map((lang) {
              final isSelected = lang == selected;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => onSelect(lang),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      height: 84,
                      decoration: BoxDecoration(
                        color: _colors[lang],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                lang.flagEmoji,
                                style: const TextStyle(fontSize: 22),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                lang.label,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (isSelected)
                            const Positioned(
                              top: -4,
                              right: -4,
                              child: CircleAvatar(
                                radius: 9,
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.check,
                                  size: 12,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ApiErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ApiErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: AppColors.danger,
              ),
              const SizedBox(height: 12),
              const Text(
                'Не удалось загрузить данные',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
