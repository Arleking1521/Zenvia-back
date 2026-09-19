import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/app_repository.dart';
import '../models/language.dart';
import '../models/learned_word.dart';
import '../services/audio_settings_service.dart';
import '../services/background_music_service.dart';
import '../theme/app_colors.dart';
import '../widgets/magic_ui.dart';

enum MixedLearnedGameType {
  imageChoice,
  wordChoice,
  audioChoice,
  matching,
}

extension MixedLearnedGameTypeX on MixedLearnedGameType {
  String get title {
    switch (this) {
      case MixedLearnedGameType.imageChoice:
        return 'Найди картинку';
      case MixedLearnedGameType.wordChoice:
        return 'Выбери слово';
      case MixedLearnedGameType.audioChoice:
        return 'Послушай';
      case MixedLearnedGameType.matching:
        return 'Найди пару';
    }
  }

  String get subtitle {
    switch (this) {
      case MixedLearnedGameType.imageChoice:
        return 'Слово → картинка';
      case MixedLearnedGameType.wordChoice:
        return 'Картинка → слово';
      case MixedLearnedGameType.audioChoice:
        return 'Аудио → картинка';
      case MixedLearnedGameType.matching:
        return 'Соедини пары';
    }
  }

  String get emoji {
    switch (this) {
      case MixedLearnedGameType.imageChoice:
        return '🖼️';
      case MixedLearnedGameType.wordChoice:
        return '🔤';
      case MixedLearnedGameType.audioChoice:
        return '🔊';
      case MixedLearnedGameType.matching:
        return '🧩';
    }
  }
}

class LearnedWordsGamesScreen extends StatefulWidget {
  final AppRepository repository;

  const LearnedWordsGamesScreen({
    super.key,
    required this.repository,
  });

  @override
  State<LearnedWordsGamesScreen> createState() => _LearnedWordsGamesScreenState();
}

class _LearnedWordsGamesScreenState extends State<LearnedWordsGamesScreen> {
  final Object _musicSilenceToken = Object();
  late Future<List<LearnedWord>> _future;

  @override
  void initState() {
    super.initState();
    BackgroundMusicService.instance.silence(_musicSilenceToken);
    _future = widget.repository.getLearnedWordsAllLanguages();
  }

  @override
  void dispose() {
    BackgroundMusicService.instance.unsilence(_musicSilenceToken);
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _future = widget.repository.getLearnedWordsAllLanguages());
    await _future;
  }

  Future<void> _openGame(
    MixedLearnedGameType type,
    List<LearnedWord> words,
  ) async {
    final usable = _usableWords(type, words);
    final uniqueConcepts = usable.map((word) => word.conceptId).toSet();

    if (uniqueConcepts.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            type == MixedLearnedGameType.audioChoice
                ? 'Для этой игры нужно минимум 2 изученных слова с аудио.'
                : 'Сначала выучи минимум 2 слова.',
          ),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MixedLearnedGameScreen(
          type: type,
          words: usable,
        ),
      ),
    );
  }

  List<LearnedWord> _usableWords(
    MixedLearnedGameType type,
    List<LearnedWord> words,
  ) {
    return words.where((word) {
      final hasImage = word.imageUrl != null && word.imageUrl!.trim().isNotEmpty;
      if (!hasImage) return false;
      if (type == MixedLearnedGameType.audioChoice) {
        return word.audioUrl != null && word.audioUrl!.trim().isNotEmpty;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FantasyBackground(
        child: SafeArea(
          child: FutureBuilder<List<LearnedWord>>(
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
                          const Text('🎮', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 10),
                          const Text(
                            'Не удалось загрузить изученные слова',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.deepBlue,
                            ),
                          ),
                          const SizedBox(height: 14),
                          MagicPrimaryButton(
                            label: 'Повторить',
                            onPressed: _refresh,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final words = snapshot.data ?? const <LearnedWord>[];
              final counts = <AppLanguage, int>{};
              for (final word in words) {
                counts.update(word.language, (value) => value + 1, ifAbsent: () => 1);
              }

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
                  children: [
                    Row(
                      children: [
                        _RoundBackButton(onTap: () => Navigator.of(context).pop()),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Игровая пещера',
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
                      gradient: AppColors.magicGradient,
                      child: Column(
                        children: [
                          const Text('🎮', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 5),
                          const Text(
                            'Играем со всеми\nизученными словами!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${words.length} слов · разные языки',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (counts.isNotEmpty)
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: counts.entries
                            .map(
                              (entry) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .92),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: .20)),
                                ),
                                child: Text(
                                  '${entry.key.flagEmoji} ${entry.key.label}: ${entry.value}',
                                  style: const TextStyle(
                                    color: AppColors.deepBlue,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    const SizedBox(height: 18),
                    const Text(
                      'Выбери игру',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: AppColors.deepBlue,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (words.length < 2)
                      const MagicCard(
                        child: Text(
                          'Сначала выучи хотя бы 2 слова. После этого здесь появятся игры по уже изученному материалу.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: MixedLearnedGameType.values.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.03,
                        ),
                        itemBuilder: (_, index) {
                          final type = MixedLearnedGameType.values[index];
                          return _MixedGameCard(
                            type: type,
                            onTap: () => _openGame(type, words),
                          );
                        },
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

class _MixedGameCard extends StatelessWidget {
  final MixedLearnedGameType type;
  final VoidCallback onTap;

  const _MixedGameCard({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .94),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: AppColors.primary.withValues(alpha: .18)),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepBlue.withValues(alpha: .08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(type.emoji, style: const TextStyle(fontSize: 42)),
              const SizedBox(height: 7),
              Text(
                type.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.deepBlue,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                type.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MixedLearnedGameScreen extends StatefulWidget {
  final MixedLearnedGameType type;
  final List<LearnedWord> words;

  const MixedLearnedGameScreen({
    super.key,
    required this.type,
    required this.words,
  });

  @override
  State<MixedLearnedGameScreen> createState() => _MixedLearnedGameScreenState();
}

class _MixedLearnedGameScreenState extends State<MixedLearnedGameScreen> {
  final Random _random = Random();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Dio _dio = Dio();
  final Map<String, Uint8List> _audioCache = <String, Uint8List>{};

  late List<LearnedWord> _pool;
  LearnedWord? _target;
  List<LearnedWord> _options = const [];
  int _round = 0;
  int _score = 0;
  bool _answerLocked = false;
  bool _audioLoading = false;

  List<LearnedWord> _matchingWords = const [];
  List<LearnedWord> _matchingTextWords = const [];
  LearnedWord? _selectedImage;
  LearnedWord? _selectedText;
  final Set<String> _matched = <String>{};

  int get _totalRounds => min(10, max(4, _pool.length));

  @override
  void initState() {
    super.initState();
    _pool = List<LearnedWord>.from(widget.words)..shuffle(_random);
    if (widget.type == MixedLearnedGameType.matching) {
      _prepareMatching();
    } else {
      _nextQuestion(first: true);
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // В mixed-играх один concept = один визуальный ответ, независимо от языка.
  // Это не даёт одной и той же картинке появляться несколько раз в вариантах.
  String _key(LearnedWord word) => word.conceptId.toString();

  String _imageKey(LearnedWord word) {
    final image = word.imageUrl?.trim();
    return (image == null || image.isEmpty) ? 'concept:${word.conceptId}' : image;
  }

  void _nextQuestion({bool first = false}) {
    if (!first && _round >= _totalRounds) {
      _finish();
      return;
    }

    final target = _pool[_random.nextInt(_pool.length)];

    // Сначала берём отвлекающие варианты на том же языке, затем при
    // необходимости добираем их из других изученных языков. При этом один
    // concept никогда не добавляется дважды.
    final sameLanguage = _pool
        .where(
          (word) =>
              word.language == target.language && word.conceptId != target.conceptId,
        )
        .toList()
      ..shuffle(_random);
    final fallback = _pool
        .where((word) => word.conceptId != target.conceptId)
        .toList()
      ..shuffle(_random);

    final chosen = <LearnedWord>[target];
    final usedConcepts = <int>{target.conceptId};
    final usedImages = <String>{_imageKey(target)};

    for (final word in [...sameLanguage, ...fallback]) {
      if (!usedConcepts.add(word.conceptId)) continue;

      // Для игр с картинками дополнительно исключаем одинаковые URL картинок,
      // даже если в данных они случайно привязаны к разным concept.
      if (widget.type != MixedLearnedGameType.wordChoice) {
        final imageKey = _imageKey(word);
        if (!usedImages.add(imageKey)) {
          usedConcepts.remove(word.conceptId);
          continue;
        }
      }

      chosen.add(word);
      if (chosen.length == 4) break;
    }
    chosen.shuffle(_random);

    setState(() {
      if (first) {
        _round = 1;
      } else {
        _round++;
      }
      _target = target;
      _options = chosen;
      _answerLocked = false;
    });
  }

  Future<void> _answer(LearnedWord selected) async {
    if (_answerLocked || _target == null) return;
    final correct = _key(selected) == _key(_target!);
    setState(() {
      _answerLocked = true;
      if (correct) _score++;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 650),
        backgroundColor: correct ? AppColors.primary : AppColors.coral,
        content: Text(correct ? 'Верно! 🌟' : 'Попробуем следующее слово 💪'),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    _nextQuestion();
  }

  Future<void> _playAudio() async {
    final url = _target?.audioUrl?.trim();
    if (url == null || url.isEmpty || _audioLoading) return;
    setState(() => _audioLoading = true);
    try {
      var bytes = _audioCache[url];
      if (bytes == null) {
        final response = await _dio.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        bytes = Uint8List.fromList(response.data ?? const <int>[]);
        if (bytes.isNotEmpty) _audioCache[url] = bytes;
      }
      if (bytes.isEmpty) throw Exception('Пустой аудиофайл');
      await _audioPlayer.stop();
      await AudioSettingsService.instance.load();
      await _audioPlayer.play(
        BytesSource(bytes),
        volume: AudioSettingsService.instance.voiceVolume,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось воспроизвести аудио.')),
        );
      }
    } finally {
      if (mounted) setState(() => _audioLoading = false);
    }
  }

  void _prepareMatching() {
    final shuffled = List<LearnedWord>.from(_pool)..shuffle(_random);
    final unique = <LearnedWord>[];
    final usedConcepts = <int>{};
    final usedImages = <String>{};

    for (final word in shuffled) {
      final image = word.imageUrl?.trim();
      if (image == null || image.isEmpty) continue;
      if (!usedConcepts.add(word.conceptId)) continue;
      if (!usedImages.add(_imageKey(word))) {
        usedConcepts.remove(word.conceptId);
        continue;
      }
      unique.add(word);
    }

    _matchingWords = unique.take(min(4, unique.length)).toList();
    _matchingTextWords = List<LearnedWord>.from(_matchingWords)..shuffle(_random);
  }

  Future<void> _matchingTap(LearnedWord word, bool isImage) async {
    if (_matched.contains(_key(word))) return;
    setState(() {
      if (isImage) {
        _selectedImage = word;
      } else {
        _selectedText = word;
      }
    });

    if (_selectedImage == null || _selectedText == null) return;
    final correct = _key(_selectedImage!) == _key(_selectedText!);
    if (correct) {
      setState(() {
        _matched.add(_key(_selectedImage!));
        _score++;
        _selectedImage = null;
        _selectedText = null;
      });
      if (_matched.length == _matchingWords.length) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (mounted) _finish(totalOverride: _matchingWords.length);
      }
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      setState(() {
        _selectedImage = null;
        _selectedText = null;
      });
    }
  }

  Future<void> _finish({int? totalOverride}) async {
    final total = totalOverride ?? _totalRounds;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text(
          'Отличная игра! 🎉',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Правильных ответов: $_score из $total',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Готово'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.type == MixedLearnedGameType.matching) {
      return _buildMatching();
    }

    final target = _target;
    if (target == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: FantasyBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                child: Row(
                  children: [
                    _RoundBackButton(onTap: () => Navigator.of(context).pop()),
                    Expanded(
                      child: Text(
                        '${widget.type.emoji} ${widget.type.title}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: AppColors.deepBlue,
                        ),
                      ),
                    ),
                    Text(
                      '$_round/$_totalRounds',
                      style: const TextStyle(
                        color: AppColors.deepBlue,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: _round / _totalRounds,
                    minHeight: 9,
                    backgroundColor: AppColors.trackGrey,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    _QuestionPrompt(
                      type: widget.type,
                      target: target,
                      audioLoading: _audioLoading,
                      onAudio: _playAudio,
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _options.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: widget.type == MixedLearnedGameType.wordChoice ? 1 : 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: widget.type == MixedLearnedGameType.wordChoice ? 4.2 : 1.05,
                      ),
                      itemBuilder: (_, index) {
                        final option = _options[index];
                        return _AnswerOption(
                          type: widget.type,
                          word: option,
                          onTap: () => _answer(option),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatching() {
    final imageItems = List<LearnedWord>.from(_matchingWords);
    final textItems = _matchingTextWords;

    return Scaffold(
      body: FantasyBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
            children: [
              Row(
                children: [
                  _RoundBackButton(onTap: () => Navigator.of(context).pop()),
                  const Expanded(
                    child: Text(
                      '🧩 Найди пару',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: AppColors.deepBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Соедини картинку и слово',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: imageItems.map((word) {
                        final key = _key(word);
                        final selected = _selectedImage != null && _key(_selectedImage!) == key;
                        final matched = _matched.contains(key);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _MatchingImageCard(
                            word: word,
                            selected: selected,
                            matched: matched,
                            onTap: () => _matchingTap(word, true),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      children: textItems.map((word) {
                        final key = _key(word);
                        final selected = _selectedText != null && _key(_selectedText!) == key;
                        final matched = _matched.contains(key);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _MatchingTextCard(
                            word: word,
                            selected: selected,
                            matched: matched,
                            onTap: () => _matchingTap(word, false),
                          ),
                        );
                      }).toList(),
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

class _QuestionPrompt extends StatelessWidget {
  final MixedLearnedGameType type;
  final LearnedWord target;
  final bool audioLoading;
  final VoidCallback onAudio;

  const _QuestionPrompt({
    required this.type,
    required this.target,
    required this.audioLoading,
    required this.onAudio,
  });

  @override
  Widget build(BuildContext context) {
    return MagicCard(
      child: Column(
        children: [
          Text(
            '${target.language.flagEmoji} ${target.language.label}',
            style: const TextStyle(
              color: AppColors.accentBlue,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          if (type == MixedLearnedGameType.wordChoice)
            _NetworkWordImage(url: target.imageUrl, height: 180)
          else if (type == MixedLearnedGameType.audioChoice)
            GestureDetector(
              onTap: audioLoading ? null : onAudio,
              child: Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  color: Color(0xFFE5F6FF),
                  shape: BoxShape.circle,
                ),
                child: audioLoading
                    ? const Padding(
                        padding: EdgeInsets.all(42),
                        child: CircularProgressIndicator(strokeWidth: 4),
                      )
                    : const Icon(
                        Icons.volume_up_rounded,
                        size: 58,
                        color: AppColors.accentBlue,
                      ),
              ),
            )
          else
            Text(
              target.text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.deepBlue,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
          if (type != MixedLearnedGameType.audioChoice &&
              target.transcription != null) ...[
            const SizedBox(height: 6),
            Text(
              target.transcription!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnswerOption extends StatelessWidget {
  final MixedLearnedGameType type;
  final LearnedWord word;
  final VoidCallback onTap;

  const _AnswerOption({
    required this.type,
    required this.word,
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .96),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.primary.withValues(alpha: .18)),
          ),
          child: type == MixedLearnedGameType.wordChoice
              ? Row(
                  children: [
                    Text(word.language.flagEmoji, style: const TextStyle(fontSize: 25)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        word.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.deepBlue,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                )
              : _NetworkWordImage(url: word.imageUrl, height: 130),
        ),
      ),
    );
  }
}

class _NetworkWordImage extends StatelessWidget {
  final String? url;
  final double height;

  const _NetworkWordImage({required this.url, required this.height});

  @override
  Widget build(BuildContext context) {
    final value = url?.trim();
    if (value == null || value.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('🖼️', style: TextStyle(fontSize: 55))),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        value,
        height: height,
        width: double.infinity,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => SizedBox(
          height: height,
          child: const Center(child: Text('🖼️', style: TextStyle(fontSize: 55))),
        ),
      ),
    );
  }
}

class _MatchingImageCard extends StatelessWidget {
  final LearnedWord word;
  final bool selected;
  final bool matched;
  final VoidCallback onTap;

  const _MatchingImageCard({
    required this.word,
    required this.selected,
    required this.matched,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: matched ? .35 : 1,
      child: GestureDetector(
        onTap: matched ? null : onTap,
        child: Container(
          height: 105,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.accentBlue : AppColors.trackGrey,
              width: selected ? 3 : 1,
            ),
          ),
          child: _NetworkWordImage(url: word.imageUrl, height: 88),
        ),
      ),
    );
  }
}

class _MatchingTextCard extends StatelessWidget {
  final LearnedWord word;
  final bool selected;
  final bool matched;
  final VoidCallback onTap;

  const _MatchingTextCard({
    required this.word,
    required this.selected,
    required this.matched,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: matched ? .35 : 1,
      child: GestureDetector(
        onTap: matched ? null : onTap,
        child: Container(
          height: 105,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.purple : AppColors.trackGrey,
              width: selected ? 3 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(word.language.flagEmoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(
                word.text,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.deepBlue,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RoundBackButton({required this.onTap});

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
