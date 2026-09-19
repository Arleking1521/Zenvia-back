import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/app_repository.dart';
import '../models/language.dart';
import '../models/literary_content.dart';
import '../services/audio_settings_service.dart';
import '../theme/app_colors.dart';
import '../widgets/magic_ui.dart';

class SmartContentScreen extends StatefulWidget {
  final AppRepository repository;
  final AppLanguage language;

  const SmartContentScreen({
    super.key,
    required this.repository,
    required this.language,
  });

  @override
  State<SmartContentScreen> createState() => _SmartContentScreenState();
}

class _SmartContentScreenState extends State<SmartContentScreen> {
  late Future<List<LiteraryContentItem>> _future;
  LiteraryContentType? _filter;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Dio _dio = Dio();
  final Map<String, Uint8List> _cache = <String, Uint8List>{};
  int? _playingId;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.getLiteraryContent(widget.language);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = widget.repository.getLiteraryContent(widget.language);
    });
    await _future;
  }

  Future<void> _play(LiteraryContentItem item) async {
    final url = item.audioUrl?.trim();
    if (url == null || url.isEmpty) return;

    setState(() => _playingId = item.id);
    try {
      var bytes = _cache[url];
      if (bytes == null) {
        final response = await _dio.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        bytes = Uint8List.fromList(response.data ?? const <int>[]);
        if (bytes.isNotEmpty) _cache[url] = bytes;
      }
      if (bytes.isEmpty) throw Exception('Пустой аудиофайл');
      await _audioPlayer.stop();
      await AudioSettingsService.instance.load();
      await _audioPlayer.play(
        BytesSource(bytes),
        volume: AudioSettingsService.instance.voiceVolume,
      );
      try {
        await widget.repository.markLiteraryContentListened(item.id);
      } catch (_) {
        // Прослушивание не должно ломаться из-за статистики.
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось воспроизвести аудио.')),
        );
      }
    } finally {
      if (mounted) setState(() => _playingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FantasyBackground(
        child: SafeArea(
          child: FutureBuilder<List<LiteraryContentItem>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: MagicCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('💡', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 10),
                          const Text(
                            'Не удалось загрузить умные материалы',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.deepBlue,
                            ),
                          ),
                          const SizedBox(height: 14),
                          MagicPrimaryButton(label: 'Повторить', onPressed: _refresh),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final allItems = snapshot.data ?? const <LiteraryContentItem>[];
              final items = _filter == null
                  ? allItems
                  : allItems.where((item) => item.type == _filter).toList();

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                  children: [
                    Row(
                      children: [
                        _BackButton(onTap: () => Navigator.of(context).pop()),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Пещера знаний',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              color: AppColors.deepBlue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 12),
                    MagicCard(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF9B5DE5), Color(0xFF6A4BC6)],
                      ),
                      child: Column(
                        children: [
                          const Text('💡', style: TextStyle(fontSize: 50)),
                          const SizedBox(height: 5),
                          const Text(
                            'Я хочу умничать!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${widget.language.flagEmoji} ${widget.language.label}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: '✨ Всё',
                            selected: _filter == null,
                            onTap: () => setState(() => _filter = null),
                          ),
                          ...LiteraryContentType.values
                              .where((type) => type != LiteraryContentType.other)
                              .map(
                                (type) => Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: _FilterChip(
                                    label: '${type.emoji} ${type.title}',
                                    selected: _filter == type,
                                    onTap: () => setState(() => _filter = type),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (items.isEmpty)
                      MagicCard(
                        child: Column(
                          children: [
                            const Text('📚', style: TextStyle(fontSize: 46)),
                            const SizedBox(height: 8),
                            Text(
                              allItems.isEmpty
                                  ? 'Для этого языка пока нет стихов, пословиц, загадок и скороговорок.'
                                  : 'В этой категории пока ничего нет.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ContentCard(
                            item: item,
                            loadingAudio: _playingId == item.id,
                            onPlay: item.audioUrl == null ? null : () => _play(item),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  final LiteraryContentItem item;
  final bool loadingAudio;
  final VoidCallback? onPlay;

  const _ContentCard({
    required this.item,
    required this.loadingAudio,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return MagicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2E9FF),
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: Text(item.type.emoji, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: AppColors.deepBlue,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      item.author == null
                          ? item.type.title
                          : '${item.type.title} · ${item.author}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onPlay != null)
                IconButton.filledTonal(
                  onPressed: loadingAudio ? null : onPlay,
                  icon: loadingAudio
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.volume_up_rounded),
                ),
            ],
          ),
          if (item.imageUrl != null && item.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                item.imageUrl!,
                width: double.infinity,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            item.text,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.45,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF8F65D8) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? const Color(0xFF8F65D8) : AppColors.trackGrey,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.deepBlue,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .92),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.arrow_back_rounded, color: AppColors.deepBlue),
        ),
      ),
    );
  }
}
