import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

import 'catch_stars_game_screen.dart';
import 'firefly_sequence_game_screen.dart';
import 'memory_match_game_screen.dart';

class PlayCaveScreen extends StatelessWidget {
  const PlayCaveScreen({super.key});

  static const String _fireflyAsset = 'assets/images/firefly.png';
  static const String _starAsset = 'assets/images/star_cute.png';
  static const String _cloudAsset = 'assets/images/cloud_cute.png';
  static const String _eggAsset = 'assets/images/dragon_egg_cute.png';

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
                          tooltip: context.tr('back'),
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
                Text(
                  context.tr('playCaveTitle'),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    context.tr('chooseGameFun'),
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
                              title: context.tr('findPair'),
                              subtitle: context.tr('findPairHint'),
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
                              title: context.tr('repeatFireflies'),
                              subtitle: context.tr('repeatFirefliesHint'),
                              preview: const _MiniFireflyPreview(
                                assetPath: _fireflyAsset,
                              ),
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
                            const SizedBox(height: 18),
                            _GameTile(
                              title: context.tr('catchStars'),
                              subtitle: context.tr('catchStarsHint'),
                              preview: const _MiniCatchStarsPreview(
                                starAsset: _starAsset,
                                cloudAsset: _cloudAsset,
                                eggAsset: _eggAsset,
                              ),
                              buttonColor: const Color(0xFFF4A62A),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const CatchStarsGameScreen(),
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
                child: Text(
                  context.tr('play'),
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
  final String assetPath;

  const _MiniFireflyPreview({
    required this.assetPath,
  });

  @override
  Widget build(BuildContext context) {
    Widget previewFirefly({
      required double size,
      required Alignment alignment,
      required bool glowing,
      required double rotation,
    }) {
      return Align(
        alignment: alignment,
        child: Transform.rotate(
          angle: rotation,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: glowing ? size * 1.05 : size * .78,
                  height: glowing ? size * 1.05 : size * .78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: glowing
                        ? const Color(0x66FFF36A)
                        : const Color(0x22D5FF80),
                    boxShadow: glowing
                        ? const [
                            BoxShadow(
                              color: Color(0xAAFFF36A),
                              blurRadius: 22,
                              spreadRadius: 5,
                            ),
                          ]
                        : const [],
                  ),
                ),
                Image.asset(
                  assetPath,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: 112,
      width: 210,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF123B50),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          previewFirefly(
            size: 42,
            alignment: const Alignment(-.92, -.65),
            glowing: false,
            rotation: -.18,
          ),
          previewFirefly(
            size: 56,
            alignment: const Alignment(.02, -.82),
            glowing: true,
            rotation: 0,
          ),
          previewFirefly(
            size: 44,
            alignment: const Alignment(.92, -.50),
            glowing: false,
            rotation: .15,
          ),
          previewFirefly(
            size: 40,
            alignment: const Alignment(-.68, .78),
            glowing: false,
            rotation: -.08,
          ),
          previewFirefly(
            size: 43,
            alignment: const Alignment(.70, .72),
            glowing: false,
            rotation: .09,
          ),
        ],
      ),
    );
  }
}

class _MiniCatchStarsPreview extends StatelessWidget {
  final String starAsset;
  final String cloudAsset;
  final String eggAsset;

  const _MiniCatchStarsPreview({
    required this.starAsset,
    required this.cloudAsset,
    required this.eggAsset,
  });

  @override
  Widget build(BuildContext context) {
    Widget fallingGlow({
      required double size,
      required Color color,
      required Alignment alignment,
      required Widget child,
      required double rotation,
    }) {
      return Align(
        alignment: alignment,
        child: Transform.rotate(
          angle: rotation,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: size * .72,
                  height: size * .72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color,
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      );
    }

    Widget streak(double height, Alignment alignment) {
      return Align(
        alignment: alignment,
        child: Container(
          width: 5,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: .28),
                Colors.white.withValues(alpha: .02),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: 118,
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF203B74),
            Color(0xFF253668),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          streak(34, const Alignment(-.58, -.66)),
          streak(30, const Alignment(.06, -.60)),
          streak(32, const Alignment(.68, -.52)),
          fallingGlow(
            size: 46,
            color: const Color(0x55FFE16A),
            alignment: const Alignment(-.58, -.12),
            rotation: -.10,
            child: Image.asset(
              starAsset,
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
          ),
          fallingGlow(
            size: 58,
            color: const Color(0x77FFE16A),
            alignment: const Alignment(.02, .14),
            rotation: .08,
            child: Image.asset(
              starAsset,
              width: 50,
              height: 50,
              fit: BoxFit.contain,
            ),
          ),
          Align(
            alignment: const Alignment(.70, -.20),
            child: Transform.rotate(
              angle: .08,
              child: Image.asset(
                cloudAsset,
                width: 42,
                height: 42,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Align(
            alignment: const Alignment(.74, .56),
            child: Transform.rotate(
              angle: .12,
              child: Image.asset(
                eggAsset,
                width: 34,
                height: 34,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Align(
            alignment: const Alignment(-.80, .66),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                '+1',
                style: TextStyle(
                  color: Color(0xFFFFE89A),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
