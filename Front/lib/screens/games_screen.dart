import 'package:flutter/material.dart';

import '../data/app_repository.dart';
import '../data/game_repository.dart';
import '../models/game.dart';
import '../models/language.dart';
import '../models/topic.dart';
import '../theme/app_colors.dart';
import 'game_play_screen.dart';

class GamesScreen extends StatefulWidget {
  final AppRepository appRepository;
  final GameRepository gameRepository;

  const GamesScreen({
    super.key,
    required this.appRepository,
    required this.gameRepository,
  });

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  late Future<_GamesData> _future;
  bool _starting = false;

  static const _colors = <GameType, Color>{
    GameType.imageChoice: AppColors.accentYellow,
    GameType.wordChoice: AppColors.accentBlue,
    GameType.audioChoice: AppColors.accentCoral,
    GameType.matching: AppColors.accentTeal,
  };

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_GamesData> _load() async {
    final values = await Future.wait([
      widget.appRepository.getTopics(),
      widget.appRepository.getSelectedLanguage(),
    ]);
    return _GamesData(
      topics: values[0] as List<Topic>,
      language: values[1] as AppLanguage,
    );
  }

  Future<void> _chooseTopic(GameType gameType) async {
    if (_starting) return;

    _GamesData data;
    try {
      data = await _load();
      if (mounted) {
        setState(() {
          _future = Future.value(data);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      return;
    }

    if (data.topics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет доступных тем для игры.')),
      );
      return;
    }

    final topic = await showModalBottomSheet<Topic>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Выбери тему',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: data.topics.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = data.topics[index];
                      return ListTile(
                        tileColor: item.color.withValues(alpha: 0.12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        leading: _TopicIcon(topic: item),
                        title: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('${item.totalCount} слов'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).pop(item),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (topic == null || !mounted) return;
    await _startGame(gameType, topic, data.language);
  }

  Future<void> _startGame(
    GameType gameType,
    Topic topic,
    AppLanguage language,
  ) async {
    setState(() => _starting = true);
    try {
      final session = await widget.gameRepository.startGame(
        GameStartRequest(
          topicId: int.parse(topic.id),
          language: language,
          gameType: gameType,
          questionCount: gameType == GameType.matching ? 3 : 10,
        ),
      );

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GamePlayScreen(
            repository: widget.gameRepository,
            session: session,
            topicTitle: topic.title,
          ),
        ),
      );
      if (mounted) {
        setState(() {
          _future = _load();
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<_GamesData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 42),
                    const SizedBox(height: 8),
                    Text(
                      'Не удалось загрузить игры\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _future = _load();
                        });
                      },
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          return Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: Column(
                      children: [
                        Text(
                          'Игры',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Язык: ${data.language.flagEmoji} ${data.language.label}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.88,
                      ),
                      itemCount: GameType.values.length,
                      itemBuilder: (context, index) {
                        final type = GameType.values[index];
                        final color = _colors[type] ?? AppColors.primary;
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          child: InkWell(
                            onTap: () => _chooseTopic(type),
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: color, width: 1.5),
                              ),
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    type.emoji,
                                    style: const TextStyle(fontSize: 36),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    type.title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _description(type),
                                    textAlign: TextAlign.center,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      height: 1.25,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              if (_starting)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x55000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _description(GameType type) {
    switch (type) {
      case GameType.imageChoice:
        return 'Прочитай слово и найди картинку';
      case GameType.wordChoice:
        return 'Посмотри на картинку и выбери слово';
      case GameType.audioChoice:
        return 'Послушай слово и найди картинку';
      case GameType.matching:
        return 'Соедини картинки и слова';
    }
  }
}

class _GamesData {
  final List<Topic> topics;
  final AppLanguage language;

  const _GamesData({required this.topics, required this.language});
}

class _TopicIcon extends StatelessWidget {
  final Topic topic;

  const _TopicIcon({required this.topic});

  @override
  Widget build(BuildContext context) {
    final url = topic.iconUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Text(
            '📚',
            style: TextStyle(fontSize: 28),
          ),
        ),
      );
    }
    return const Text('📚', style: TextStyle(fontSize: 28));
  }
}
