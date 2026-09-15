import 'dart:async';
import 'dart:typed_data';


import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../models/language.dart';
import '../models/topic.dart';
import '../theme/app_colors.dart';
import '../widgets/progress_bar.dart';

class TopicDetailScreen extends StatefulWidget {
  final Topic topic;
  final AppLanguage language;

  const TopicDetailScreen({
    super.key,
    required this.topic,
    required this.language,
  });

  @override
  State<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends State<TopicDetailScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 10),
    ),
  );

  final Map<String, Uint8List> _audioCache = <String, Uint8List>{};
  String? _currentAudioUrl;

  int _wordIndex = 0;
  bool _isPlayingAudio = false;
  bool _isLoadingAudio = false;

  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<void>? _playerCompleteSubscription;

  @override
  void initState() {
    super.initState();

    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlayingAudio = state == PlayerState.playing;
      });
    });

    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlayingAudio = false;
        _isLoadingAudio = false;
        _currentAudioUrl = null;
      });
    });
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<Uint8List> _loadAudioBytes(String url) async {
    final cached = _audioCache[url];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final response = await _dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
        headers: const {
          'Accept': 'audio/mpeg,audio/*;q=0.9,*/*;q=0.8',
        },
      ),
    );

    final raw = response.data;
    if (raw == null || raw.isEmpty) {
      throw StateError('Сервер вернул пустой аудиофайл');
    }

    final bytes = Uint8List.fromList(raw);
    _audioCache[url] = bytes;
    return bytes;
  }

  Future<void> _playAudio(String? audioUrl) async {
    final url = audioUrl?.trim();
    if (url == null || url.isEmpty || _isLoadingAudio) {
      return;
    }

    try {
      // Повторное нажатие на текущее аудио останавливает воспроизведение.
      if (_isPlayingAudio && _currentAudioUrl == url) {
        await _audioPlayer.stop();
        if (mounted) {
          setState(() {
            _isPlayingAudio = false;
            _currentAudioUrl = null;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isLoadingAudio = true;
        });
      }

      await _audioPlayer.stop();

      // Не отдаём Django URL напрямую нативному медиаплееру.
      // Сначала скачиваем файл через Dio, затем проигрываем локальные байты.
      final bytes = await _loadAudioBytes(url);

      final lower = url.toLowerCase();
      final mimeType = lower.endsWith('.wav')
          ? 'audio/wav'
          : lower.endsWith('.m4a')
              ? 'audio/mp4'
              : lower.endsWith('.ogg')
                  ? 'audio/ogg'
                  : 'audio/mpeg';

      await _audioPlayer.play(
        BytesSource(
          bytes,
          mimeType: mimeType,
        ),
      );

      if (mounted) {
        setState(() {
          _currentAudioUrl = url;
          _isLoadingAudio = false;
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingAudio = false;
        _isPlayingAudio = false;
        _currentAudioUrl = null;
      });

      final status = e.response?.statusCode;
      final message = status == null
          ? 'Не удалось скачать аудио с сервера'
          : 'Сервер не отдал аудио (HTTP $status)';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingAudio = false;
        _isPlayingAudio = false;
        _currentAudioUrl = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось воспроизвести аудио: $e'),
        ),
      );
    }
  }

  Future<void> _changeWord(int newIndex) async {
    await _audioPlayer.stop();

    if (!mounted) return;

    setState(() {
      _wordIndex = newIndex;
      _isPlayingAudio = false;
      _isLoadingAudio = false;
      _currentAudioUrl = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final topic = widget.topic;

    if (topic.words.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(topic.title),
          backgroundColor: AppColors.background,
        ),
        body: const Center(
          child: Text('В этой теме пока нет слов'),
        ),
      );
    }

    final word = topic.words[_wordIndex];
    final transcription = word.transcriptionFor(widget.language);
    final audioUrl = word.audioFor(widget.language);
    final hasAudio = audioUrl != null && audioUrl.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () async {
                        await _audioPlayer.stop();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(
                          Icons.chevron_left_rounded,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      topic.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    '${_wordIndex + 1}/${topic.words.length}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AppProgressBar(
                progress: (_wordIndex + 1) / topic.words.length,
                color: topic.color,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _WordImage(
                        imageUrl: word.imageUrl,
                        fallbackEmoji: word.emoji,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        word.translationFor(widget.language),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (transcription != null &&
                          transcription.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          transcription,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: hasAudio && !_isLoadingAudio
                              ? () => _playAudio(audioUrl)
                              : null,
                          customBorder: const CircleBorder(),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: hasAudio
                                  ? topic.color
                                  : AppColors.trackGrey,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: _isLoadingAudio
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(
                                      _isPlayingAudio
                                          ? Icons.stop_rounded
                                          : Icons.volume_up_rounded,
                                      color: hasAudio
                                          ? Colors.white
                                          : AppColors.textMuted,
                                      size: 30,
                                    ),
                            ),
                          ),
                        ),
                      ),
                      if (!hasAudio) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Аудио для этого слова пока не добавлено',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_wordIndex > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _changeWord(_wordIndex - 1),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: const Text('Назад'),
                      ),
                    ),
                  if (_wordIndex > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_wordIndex < topic.words.length - 1) {
                          await _changeWord(_wordIndex + 1);
                        } else {
                          await _audioPlayer.stop();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        }
                      },
                      child: Text(
                        _wordIndex < topic.words.length - 1
                            ? 'Дальше'
                            : 'Готово',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordImage extends StatelessWidget {
  final String? imageUrl;
  final String fallbackEmoji;

  const _WordImage({
    required this.imageUrl,
    required this.fallbackEmoji,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Text(
        fallbackEmoji,
        style: const TextStyle(fontSize: 80),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.network(
        imageUrl!,
        width: 220,
        height: 220,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const SizedBox(
            width: 220,
            height: 220,
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => SizedBox(
          width: 220,
          height: 220,
          child: Center(
            child: Text(
              fallbackEmoji,
              style: const TextStyle(fontSize: 80),
            ),
          ),
        ),
      ),
    );
  }
}
