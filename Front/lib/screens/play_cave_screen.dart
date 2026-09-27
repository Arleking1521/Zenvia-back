import 'package:flutter/material.dart';

import 'firefly_sequence_game_screen.dart';
import 'memory_match_game_screen.dart';

class PlayCaveScreen extends StatelessWidget {
  const PlayCaveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Image(
            image: AssetImage('assets/images/adventure_bg.webp'),
            fit: BoxFit.cover,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF063B7A).withValues(alpha: .10),
                  Colors.transparent,
                  const Color(0xFF052F63).withValues(alpha: .20),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Row(
                    children: [
                      Material(
                        color: Colors.white.withValues(alpha: .24),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Назад',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        '🎮',
                        style: TextStyle(fontSize: 30),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Хочу играть',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: Color(0x66000000),
                        blurRadius: 7,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Выбирай игру и просто веселись!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 6, 22, 28),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 390),
                        child: Column(
                          children: [
                            _GameTile(
                              title: 'Найди пару',
                              subtitle:
                                  'Переворачивай карточки и находи одинаковые картинки',
                              preview: const _MiniMemoryPreview(),
                              buttonColor: const Color(0xFF2F9BFF),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const MemoryMatchGameScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 18),
                            _GameTile(
                              title: 'Повтори за светлячками',
                              subtitle:
                                  'Запоминай, кто загорелся, и повторяй последовательность',
                              preview: const _MiniFireflyPreview(),
                              buttonColor: const Color(0xFF5AAE63),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const FireflySequenceGameScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GameTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final Widget preview;
  final Color buttonColor;
  final VoidCallback onTap;

  const _GameTile({
    required this.title,
    required this.subtitle,
    required this.preview,
    required this.buttonColor,
    required this.onTap,
  });

  @override
  State<_GameTile> createState() => _GameTileState();
}

class _GameTileState extends State<_GameTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 110),
        scale: _pressed ? .97 : 1,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .94),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white,
              width: 3,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 18,
                offset: Offset(0, 9),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              widget.preview,
              const SizedBox(height: 14),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.title,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Color(0xFF104C91),
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF4F6280),
                  fontSize: 14,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: widget.buttonColor,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Text(
                  'Играть',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniMemoryPreview extends StatelessWidget {
  const _MiniMemoryPreview();

  @override
  Widget build(BuildContext context) {
    Widget card(String value, Color color) {
      return Container(
        width: 72,
        height: 84,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 7,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          value,
          style: const TextStyle(fontSize: 38),
        ),
      );
    }

    return SizedBox(
      height: 102,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -.12,
            child: Transform.translate(
              offset: const Offset(-42, 4),
              child: card('🐼', const Color(0xFFFFE9A8)),
            ),
          ),
          Transform.rotate(
            angle: .12,
            child: Transform.translate(
              offset: const Offset(42, 4),
              child: card('🐼', const Color(0xFFFFE9A8)),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -8),
            child: Container(
              width: 58,
              height: 68,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF79C9FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: const Icon(
                Icons.question_mark_rounded,
                size: 36,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniFireflyPreview extends StatelessWidget {
  const _MiniFireflyPreview();

  @override
  Widget build(BuildContext context) {
    Widget glowDot({required bool active}) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: active ? 40 : 31,
        height: active ? 40 : 31,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? const Color(0xFFFFF36A)
              : const Color(0xFF85A957),
          border: Border.all(
            color: Colors.white,
            width: 2.5,
          ),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0xAAFFF36A),
                    blurRadius: 18,
                    spreadRadius: 5,
                  ),
                ]
              : const [],
        ),
        child: const Center(
          child: Text(
            '•',
            style: TextStyle(
              color: Color(0xFF2B4434),
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }

    return Container(
      height: 102,
      width: 190,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF123B50),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(-.9, -.65),
            child: glowDot(active: false),
          ),
          Align(
            alignment: const Alignment(.05, -.9),
            child: glowDot(active: true),
          ),
          Align(
            alignment: const Alignment(.9, -.55),
            child: glowDot(active: false),
          ),
          Align(
            alignment: const Alignment(-.65, .85),
            child: glowDot(active: false),
          ),
          Align(
            alignment: const Alignment(.7, .75),
            child: glowDot(active: false),
          ),
        ],
      ),
    );
  }
}
