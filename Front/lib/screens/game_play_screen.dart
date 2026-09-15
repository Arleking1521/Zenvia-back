import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/game_repository.dart';
import '../models/game.dart';
import '../theme/app_colors.dart';

class GamePlayScreen extends StatefulWidget {
  final GameRepository repository;
  final GameSessionData session;
  final String topicTitle;

  const GamePlayScreen({
    super.key,
    required this.repository,
    required this.session,
    required this.topicTitle,
  });

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Dio _audioDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 10),
    ),
  );
  final Map<String, Uint8List> _audioCache = <String, Uint8List>{};

  GameQuestionData? _question;
  GameAnswerResult? _answerResult;
  bool _loading = true;
  bool _sending = false;
  bool _loadingAudio = false;
  bool _playingAudio = false;
  String? _currentAudioUrl;
  int? _selectedAnswerId;
  int? _selectedConceptId;
  final Map<int, int> _matchingPairs = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNext();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadNext() async {
    await _audioPlayer.stop();
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
      _question = null;
      _answerResult = null;
      _selectedAnswerId = null;
      _selectedConceptId = null;
      _matchingPairs.clear();
      _loadingAudio = false;
      _playingAudio = false;
      _currentAudioUrl = null;
    });

    try {
      final next = await widget.repository.getNextQuestion(widget.session.id);
      if (!mounted) return;
      if (next.complete) {
        await _finish();
        return;
      }
      setState(() {
        _question = next.question;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _submitSingle(int answerId) async {
    final question = _question;
    if (question == null || _sending || _answerResult != null) return;
    setState(() {
      _selectedAnswerId = answerId;
      _sending = true;
    });
    try {
      final result = await widget.repository.answerSingle(
        sessionId: widget.session.id,
        questionId: question.id,
        answerId: answerId,
      );
      if (!mounted) return;
      setState(() => _answerResult = result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _submitMatching() async {
    final question = _question;
    if (question == null || _sending || _answerResult != null) return;
    if (_matchingPairs.length != question.left.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала соедини все пары.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final result = await widget.repository.answerMatching(
        sessionId: widget.session.id,
        questionId: question.id,
        pairs: Map<int, int>.from(_matchingPairs),
      );
      if (!mounted) return;
      setState(() => _answerResult = result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<Uint8List> _loadAudioBytes(String url) async {
    final cached = _audioCache[url];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final response = await _audioDio.get<List<int>>(
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

  Future<void> _playAudio() async {
    final url = _question?.prompt?.audioUrl?.trim();
    if (url == null || url.isEmpty || _loadingAudio) return;

    try {
      if (_playingAudio && _currentAudioUrl == url) {
        await _audioPlayer.stop();
        if (!mounted) return;
        setState(() {
          _playingAudio = false;
          _currentAudioUrl = null;
        });
        return;
      }

      setState(() {
        _loadingAudio = true;
      });

      await _audioPlayer.stop();
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

      if (!mounted) return;
      setState(() {
        _loadingAudio = false;
        _playingAudio = true;
        _currentAudioUrl = url;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingAudio = false;
        _playingAudio = false;
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
        _loadingAudio = false;
        _playingAudio = false;
        _currentAudioUrl = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось воспроизвести аудио: $e')),
      );
    }
  }

  Future<void> _finish() async {
    setState(() => _loading = true);
    try {
      final result = await widget.repository.finishGame(widget.session.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Игра завершена! 🎉'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ResultRow(
                  label: 'Правильных',
                  value: '${result.session.correctCount}',
                ),
                _ResultRow(
                  label: 'Ошибок',
                  value: '${result.session.wrongCount}',
                ),
                _ResultRow(
                  label: 'Получено XP',
                  value: '+${result.session.xpEarned}',
                ),
                const Divider(),
                _ResultRow(
                  label: 'Всего XP',
                  value: '${result.totalXp}',
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Готово'),
              ),
            ],
          );
        },
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(widget.topicTitle),
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorView(message: _error!, onRetry: _loadNext)
                : _buildQuestion(),
      ),
    );
  }

  Widget _buildQuestion() {
    final question = _question;
    if (question == null) {
      return const Center(child: Text('Нет задания.'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    minHeight: 10,
                    value: question.total == 0
                        ? 0
                        : question.sequence / question.total,
                    backgroundColor: AppColors.trackGrey,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${question.sequence}/${question.total}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: question.gameType == GameType.matching
                ? _buildMatching(question)
                : _buildSingleChoice(question),
          ),
        ),
        if (_answerResult != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loadNext,
                child: Text(
                  question.sequence >= question.total ? 'Завершить' : 'Далее',
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSingleChoice(GameQuestionData question) {
    return Column(
      children: [
        Text(
          _instruction(question.gameType),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 18),
        _buildPrompt(question),
        const SizedBox(height: 22),
        if (question.gameType == GameType.wordChoice)
          ...question.options.map(_wordOption)
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.05,
            ),
            itemCount: question.options.length,
            itemBuilder: (_, index) => _imageOption(question.options[index]),
          ),
        if (_sending) ...[
          const SizedBox(height: 16),
          const CircularProgressIndicator(),
        ],
        if (_answerResult != null) ...[
          const SizedBox(height: 18),
          _FeedbackBanner(result: _answerResult!),
        ],
      ],
    );
  }

  Widget _buildPrompt(GameQuestionData question) {
    final prompt = question.prompt;
    if (prompt == null) return const SizedBox.shrink();
    switch (prompt.kind) {
      case 'image':
        return _NetworkPicture(url: prompt.imageUrl, size: 180);
      case 'audio':
        final hasAudio = (prompt.audioUrl ?? '').trim().isNotEmpty;
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            onTap: hasAudio && !_loadingAudio ? _playAudio : null,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  if (_loadingAudio)
                    const SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(strokeWidth: 4),
                    )
                  else
                    Icon(
                      _playingAudio
                          ? Icons.stop_circle_rounded
                          : Icons.volume_up_rounded,
                      size: 64,
                      color: hasAudio
                          ? AppColors.primaryDark
                          : AppColors.textMuted,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    !hasAudio
                        ? 'Для этого слова нет аудио'
                        : _loadingAudio
                            ? 'Загружаем аудио...'
                            : _playingAudio
                                ? 'Нажми, чтобы остановить'
                                : 'Нажми, чтобы послушать',
                  ),
                ],
              ),
            ),
          ),
        );
      case 'word':
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            children: [
              Text(
                prompt.text ?? '',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if ((prompt.transcription ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  prompt.transcription!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ],
          ),
        );
    }
  }

  Widget _wordOption(GameOption option) {
    final state = _singleOptionState(option.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: state.background,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: _answerResult == null && !_sending
              ? () => _submitSingle(option.id)
              : null,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: state.border, width: 2),
            ),
            child: Column(
              children: [
                Text(
                  option.text ?? '',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if ((option.transcription ?? '').isNotEmpty)
                  Text(
                    option.transcription!,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _imageOption(GameOption option) {
    final state = _singleOptionState(option.id);
    return Material(
      color: state.background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: _answerResult == null && !_sending
            ? () => _submitSingle(option.id)
            : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: state.border, width: 2),
          ),
          child: _NetworkPicture(url: option.imageUrl, size: double.infinity),
        ),
      ),
    );
  }

  _OptionVisual _singleOptionState(int id) {
    const neutral = _OptionVisual(Colors.white, AppColors.trackGrey);
    final result = _answerResult;
    if (result == null) {
      if (_selectedAnswerId == id) {
        return const _OptionVisual(
          AppColors.bottomNavSelectedBg,
          AppColors.primaryDark,
        );
      }
      return neutral;
    }

    if (result.correctAnswerId == id) {
      return const _OptionVisual(Color(0xFFE1F5E1), AppColors.primary);
    }
    if (_selectedAnswerId == id && !result.correct) {
      return const _OptionVisual(Color(0xFFFFE7E7), AppColors.danger);
    }
    return neutral;
  }

  Widget _buildMatching(GameQuestionData question) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Найди пару',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Выбери картинку, затем подходящее слово',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.0,
          ),
          itemCount: question.left.length,
          itemBuilder: (_, index) {
            final concept = question.left[index];
            final selected = _selectedConceptId == concept.id;
            final assignedWordId = _matchingPairs[concept.id];
            final assigned = _findOption(question.right, assignedWordId);
            final result = _pairResult(concept.id);

            Color border = selected ? AppColors.accentBlue : AppColors.trackGrey;
            if (result != null) {
              border = result.correct ? AppColors.primary : AppColors.danger;
            }

            return Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: _answerResult == null
                    ? () => setState(() => _selectedConceptId = concept.id)
                    : null,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: border, width: 2),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: _NetworkPicture(
                          url: concept.imageUrl,
                          size: double.infinity,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        assigned?.text ?? 'Выбери слово',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: assigned == null
                              ? FontWeight.w400
                              : FontWeight.w700,
                          color: assigned == null
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: question.right.map((word) {
            final used = _matchingPairs.values.contains(word.id);
            return ChoiceChip(
              label: Text(word.text ?? ''),
              selected: used,
              onSelected: _answerResult == null && _selectedConceptId != null
                  ? (_) {
                      setState(() {
                        _matchingPairs.removeWhere(
                          (conceptId, wordId) => wordId == word.id,
                        );
                        _matchingPairs[_selectedConceptId!] = word.id;
                        _selectedConceptId = null;
                      });
                    }
                  : null,
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        if (_answerResult == null)
          FilledButton(
            onPressed: _sending ? null : _submitMatching,
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Проверить'),
          )
        else
          _FeedbackBanner(result: _answerResult!),
      ],
    );
  }

  GameOption? _findOption(List<GameOption> options, int? id) {
    if (id == null) return null;
    for (final option in options) {
      if (option.id == id) return option;
    }
    return null;
  }

  PairAnswerResult? _pairResult(int conceptId) {
    final rows = _answerResult?.pairResults ?? const [];
    for (final row in rows) {
      if (row.conceptId == conceptId) return row;
    }
    return null;
  }

  String _instruction(GameType type) {
    switch (type) {
      case GameType.imageChoice:
        return 'Выбери правильную картинку';
      case GameType.wordChoice:
        return 'Как называется эта картинка?';
      case GameType.audioChoice:
        return 'Послушай и выбери картинку';
      case GameType.matching:
        return 'Найди пару';
    }
  }
}

class _NetworkPicture extends StatelessWidget {
  final String? url;
  final double size;

  const _NetworkPicture({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return SizedBox(
        width: size.isFinite ? size : null,
        height: size.isFinite ? size : null,
        child: const Center(
          child: Text('🖼️', style: TextStyle(fontSize: 52)),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        url!,
        width: size.isFinite ? size : null,
        height: size.isFinite ? size : null,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Text('🖼️', style: TextStyle(fontSize: 52)),
        ),
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  final GameAnswerResult result;

  const _FeedbackBanner({required this.result});

  @override
  Widget build(BuildContext context) {
    final fullyCorrect = result.correct;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fullyCorrect ? const Color(0xFFE1F5E1) : const Color(0xFFFFE7E7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Text(
            fullyCorrect ? '✅' : '💪',
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fullyCorrect
                  ? 'Правильно!'
                  : result.correctItems > 0
                      ? 'Правильно: ${result.correctItems}, ошибок: ${result.wrongItems}'
                      : 'Попробуем ещё — ответ сохранён.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;

  const _ResultRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 44),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}

class _OptionVisual {
  final Color background;
  final Color border;

  const _OptionVisual(this.background, this.border);
}
