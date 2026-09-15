import 'package:flutter/material.dart';

import '../data/app_repository.dart';
import '../models/language.dart';
import '../models/topic.dart';
import '../theme/app_colors.dart';
import '../widgets/topic_card.dart';
import 'topic_detail_screen.dart';

enum _Filter { all, learning, completed }

class TopicsScreen extends StatefulWidget {
  final AppRepository repository;

  const TopicsScreen({
    super.key,
    required this.repository,
  });

  @override
  State<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends State<TopicsScreen> {
  late Future<List<Topic>> _future;
  _Filter _filter = _Filter.all;
  AppLanguage _language = AppLanguage.english;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant TopicsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reload();
  }

  void _reload() {
    _future = widget.repository.getTopics();
    widget.repository.getSelectedLanguage().then((language) {
      if (!mounted) return;
      setState(() => _language = language);
    });
  }

  void _retry() {
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                const SizedBox(width: 40),
                Expanded(
                  child: Text(
                    'Темы',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Все темы',
                  selected: _filter == _Filter.all,
                  onTap: () => setState(() => _filter = _Filter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Изучаю',
                  selected: _filter == _Filter.learning,
                  onTap: () => setState(() => _filter = _Filter.learning),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Пройдено',
                  selected: _filter == _Filter.completed,
                  onTap: () => setState(() => _filter = _Filter.completed),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Topic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _retry,
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final topics = snapshot.data!.where((topic) {
                  switch (_filter) {
                    case _Filter.all:
                      return true;
                    case _Filter.learning:
                      return !topic.isCompleted;
                    case _Filter.completed:
                      return topic.isCompleted;
                  }
                }).toList();

                if (topics.isEmpty) {
                  return const Center(
                    child: Text(
                      'Тем пока нет',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(_reload);
                    await _future;
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: topics.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => TopicCard(
                      topic: topics[i],
                      compact: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TopicDetailScreen(
                            topic: topics[i],
                            language: _language,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
