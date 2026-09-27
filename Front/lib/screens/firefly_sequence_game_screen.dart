import 'dart:math' as math;

import 'package:flutter/material.dart';

class FireflySequenceGameScreen extends StatefulWidget {
  const FireflySequenceGameScreen({super.key});

  @override
  State<FireflySequenceGameScreen> createState() =>
      _FireflySequenceGameScreenState();
}

class _FireflySequenceGameScreenState
    extends State<FireflySequenceGameScreen> {
  static const int _fireflyCount = 6;
  static const int _maxRounds = 6;

  final math.Random _random = math.Random();

  final List<int> _sequence = <int>[];
  int _round = 1;
  int _playerStep = 0;
  int? _activeFirefly;
  int? _pressedFirefly;
  bool _showingSequence = false;
  bool _waitingForPlayer = false;
  bool _started = false;
  String _message = 'Запомни, как загораются светлячки';
  int _sessionToken = 0;

  @override
  void initState() {
    super.initState();
    _resetGameState();
  }

  void _resetGameState() {
    _sessionToken += 1;
    _sequence
      ..clear()
      ..addAll(List<int>.generate(3, (_) => _random.nextInt(_fireflyCount)));
    _round = 1;
    _playerStep = 0;
    _activeFirefly = null;
    _pressedFirefly = null;
    _showingSequence = false;
    _waitingForPlayer = false;
    _started = false;
    _message = 'Запомни, как загораются светлячки';
  }

  void _restartGame() {
    setState(_resetGameState);
  }

  Future<void> _startGame() async {
    if (_showingSequence) return;

    setState(() {
      _started = true;
    });

    await _playSequence();
  }

  Future<void> _playSequence() async {
    if (!mounted) return;

    final token = ++_sessionToken;

    setState(() {
      _showingSequence = true;
      _waitingForPlayer = false;
      _playerStep = 0;
      _pressedFirefly = null;
      _message = 'Смотри внимательно...';
    });

    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted || token != _sessionToken) return;

    for (final fireflyIndex in _sequence) {
      setState(() {
        _activeFirefly = fireflyIndex;
      });

      await Future<void>.delayed(const Duration(milliseconds: 560));
      if (!mounted || token != _sessionToken) return;

      setState(() {
        _activeFirefly = null;
      });

      await Future<void>.delayed(const Duration(milliseconds: 260));
      if (!mounted || token != _sessionToken) return;
    }

    setState(() {
      _showingSequence = false;
      _waitingForPlayer = true;
      _message = 'Теперь повтори!';
    });
  }

  Future<void> _onFireflyTap(int index) async {
    if (!_waitingForPlayer || _showingSequence) return;

    final token = _sessionToken;

    setState(() {
      _pressedFirefly = index;
    });

    await Future<void>.delayed(const Duration(milliseconds: 190));
    if (!mounted || token != _sessionToken) return;

    setState(() {
      _pressedFirefly = null;
    });

    if (index != _sequence[_playerStep]) {
      setState(() {
        _waitingForPlayer = false;
        _playerStep = 0;
        _message = 'Почти! Посмотри ещё раз';
      });

      await Future<void>.delayed(const Duration(milliseconds: 850));
      if (!mounted || token != _sessionToken) return;
      await _playSequence();
      return;
    }

    _playerStep += 1;

    if (_playerStep < _sequence.length) {
      setState(() {
        _message = 'Отлично, продолжай!';
      });
      return;
    }

    setState(() {
      _waitingForPlayer = false;
      _message = 'Правильно! ✨';
    });

    if (_round >= _maxRounds) {
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted || token != _sessionToken) return;
      await _showFinishedDialog();
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted || token != _sessionToken) return;

    setState(() {
      _round += 1;
      _sequence.add(_random.nextInt(_fireflyCount));
      _playerStep = 0;
      _message = 'Раунд $_round';
    });

    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted || token != _sessionToken) return;
    await _playSequence();
  }

  Future<void> _showFinishedDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '✨🪲✨',
                style: TextStyle(fontSize: 48),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ты повторил всё!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF124C89),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Светлячки очень довольны!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF5C6F88),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _restartGame();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF5AAE63),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text(
                    'Сыграть ещё',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'В пещеру',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sequenceLength = _sequence.length;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Image(
            image: AssetImage('assets/images/adventure_bg.webp'),
            fit: BoxFit.cover,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xB8123455),
                  Color(0x99112D4A),
                  Color(0xC9082440),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _CircleHeaderButton(
                        tooltip: 'Назад',
                        icon: Icons.arrow_back_rounded,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Повтори за светлячками',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(
                                color: Color(0x88000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _CircleHeaderButton(
                        tooltip: 'Начать заново',
                        icon: Icons.refresh_rounded,
                        onPressed: _restartGame,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 13),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .90),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Раунд $_round/$_maxRounds',
                                style: const TextStyle(
                                  color: Color(0xFF274B73),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              '$sequenceLength ${_signalWord(sequenceLength)}',
                              style: const TextStyle(
                                color: Color(0xFF5C6F88),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF174F86),
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final boardSize = math.min(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        final fireflySize =
                            (boardSize * .205).clamp(64.0, 94.0).toDouble();

                        return Center(
                          child: SizedBox(
                            width: boardSize,
                            height: boardSize,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Container(
                                    margin: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF082B43)
                                          .withValues(alpha: .38),
                                      borderRadius: BorderRadius.circular(42),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: .13),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                ...List<Widget>.generate(
                                  _fireflyCount,
                                  (index) {
                                    final alignment = _fireflyAlignments[index];
                                    final glowing = _activeFirefly == index ||
                                        _pressedFirefly == index;

                                    return Align(
                                      alignment: alignment,
                                      child: _FireflyButton(
                                        size: fireflySize,
                                        glowing: glowing,
                                        enabled: _waitingForPlayer,
                                        onTap: () => _onFireflyTap(index),
                                      ),
                                    );
                                  },
                                ),
                                if (!_started)
                                  Center(
                                    child: FilledButton.icon(
                                      onPressed: _startGame,
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF5AAE63),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 28,
                                          vertical: 15,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(24),
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.play_arrow_rounded,
                                        size: 28,
                                      ),
                                      label: const Text(
                                        'Начать',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _showingSequence
                        ? 'Сейчас только смотри 👀'
                        : _waitingForPlayer
                            ? 'Нажимай на светлячков по порядку 👆'
                            : 'Готов? Светлячки покажут последовательность',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .92),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      shadows: const [
                        Shadow(
                          color: Color(0x99000000),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _signalWord(int count) {
    if (count == 3 || count == 4) return 'сигнала';
    return 'сигналов';
  }

  static const List<Alignment> _fireflyAlignments = [
    Alignment(-.62, -.58),
    Alignment(.02, -.76),
    Alignment(.64, -.48),
    Alignment(-.66, .32),
    Alignment(.02, .62),
    Alignment(.66, .26),
  ];
}

class _FireflyButton extends StatelessWidget {
  final double size;
  final bool glowing;
  final bool enabled;
  final VoidCallback onTap;

  const _FireflyButton({
    required this.size,
    required this.glowing,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Светлячок',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          scale: glowing ? 1.16 : 1,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 170),
                  width: size * .86,
                  height: size * .86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: glowing
                        ? const Color(0x55FFF68A)
                        : Colors.transparent,
                    boxShadow: glowing
                        ? const [
                            BoxShadow(
                              color: Color(0xCCFFF36A),
                              blurRadius: 28,
                              spreadRadius: 8,
                            ),
                          ]
                        : const [],
                  ),
                ),
                Transform.translate(
                  offset: Offset(-size * .20, -size * .03),
                  child: Transform.rotate(
                    angle: -.65,
                    child: Container(
                      width: size * .30,
                      height: size * .48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .62),
                        borderRadius: BorderRadius.circular(size),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .65),
                        ),
                      ),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(size * .20, -size * .03),
                  child: Transform.rotate(
                    angle: .65,
                    child: Container(
                      width: size * .30,
                      height: size * .48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .62),
                        borderRadius: BorderRadius.circular(size),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .65),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: size * .31,
                  height: size * .45,
                  decoration: BoxDecoration(
                    color: const Color(0xFF293C35),
                    borderRadius: BorderRadius.circular(size),
                    border: Border.all(
                      color: const Color(0xFF10241E),
                      width: 2,
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, size * .16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 170),
                    width: size * .27,
                    height: size * .25,
                    decoration: BoxDecoration(
                      color: glowing
                          ? const Color(0xFFFFF36A)
                          : const Color(0xFF92B95A),
                      shape: BoxShape.circle,
                      boxShadow: glowing
                          ? const [
                              BoxShadow(
                                color: Color(0xFFFFF36A),
                                blurRadius: 18,
                                spreadRadius: 5,
                              ),
                            ]
                          : const [],
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(-size * .065, -size * .14),
                  child: Container(
                    width: size * .045,
                    height: size * .045,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(size * .065, -size * .14),
                  child: Container(
                    width: size * .045,
                    height: size * .045,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleHeaderButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _CircleHeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .20),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: Colors.white,
        ),
      ),
    );
  }
}
