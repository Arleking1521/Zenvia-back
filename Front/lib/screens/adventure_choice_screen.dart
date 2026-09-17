import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/app_repository.dart';

/// Экран-перекрёсток после выбора языка.
enum AdventureDestination { learn, play, smart }

class AdventureChoiceScreen extends StatefulWidget {
  final AppRepository repository;

  const AdventureChoiceScreen({
    super.key,
    required this.repository,
  });

  @override
  State<AdventureChoiceScreen> createState() => _AdventureChoiceScreenState();
}

class _AdventureChoiceScreenState extends State<AdventureChoiceScreen> {
  String? _levelDragonUrl;

  @override
  void initState() {
    super.initState();
    _loadDragon();
  }

  Future<void> _loadDragon() async {
    try {
      final url = await widget.repository.getLevelDragonUrl();
      if (!mounted) return;
      setState(() => _levelDragonUrl = url);
    } catch (_) {
      // Fallback asset ниже.
    }
  }

  void _select(AdventureDestination destination) {
    Navigator.of(context).pop(destination);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Image(
            image: AssetImage('assets/images/adventure_bg.png'),
            fit: BoxFit.cover,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0588DF).withValues(alpha: .10),
                  Colors.transparent,
                  const Color(0xFF0B315D).withValues(alpha: .05),
                ],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;

                // Масштабируем только числовые размеры конкретного экрана,
                // а не весь Flutter viewport.
                final widthScale = width / 390.0;
                final heightScale = height / 800.0;
                final uiScale = math.min(widthScale, heightScale)
                    .clamp(.86, 1.22)
                    .toDouble();

                final sidePadding = (12.0 * uiScale).clamp(10.0, 18.0);
                final topGap = (4.0 * uiScale).clamp(2.0, 7.0);
                final titleSize = (30.0 * uiScale).clamp(26.0, 36.0);
                final subtitleSize = (15.0 * uiScale).clamp(13.0, 18.0);
                final navSize = (48.0 * uiScale).clamp(44.0, 56.0);
                final mottoHeight = (48.0 * uiScale).clamp(44.0, 58.0);

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    sidePadding,
                    6 * uiScale,
                    sidePadding,
                    8 * uiScale,
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: navSize,
                        child: Row(
                          children: [
                            _CircleButton(
                              size: navSize,
                              icon: Icons.arrow_back_rounded,
                              onTap: () => Navigator.of(context).pop(),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                              size: (28 * uiScale).clamp(24.0, 34.0),
                              shadows: const [
                                Shadow(color: Color(0x66000000), blurRadius: 8),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: topGap),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Что будешь\nделать сегодня?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: titleSize,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                            shadows: const [
                              Shadow(
                                color: Color(0xBB0E5FA8),
                                blurRadius: 5,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 5 * uiScale),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 18 * uiScale,
                          vertical: 8 * uiScale,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB8752C).withValues(alpha: .92),
                          borderRadius: BorderRadius.circular(16 * uiScale),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Text(
                          'Выбери свою пещеру!',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: subtitleSize,
                          ),
                        ),
                      ),
                      SizedBox(height: 5 * uiScale),

                      // Верхние две пещеры занимают доступную высоту секции,
                      // поэтому на разных экранах остаются визуально крупными.
                      Expanded(
                        flex: 28,
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final maxByWidth = (width - sidePadding * 2 - 10 * uiScale) / 2;
                            final caveSize = math.min(
                              maxByWidth,
                              box.maxHeight,
                            ).clamp(135.0, 225.0).toDouble();

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _AdventureCave(
                                  size: caveSize,
                                  asset: 'assets/images/adventure_learn.png',
                                  title: 'Хочу\nУчиться',
                                  titleColor: const Color(0xFFFFF4DB),
                                  outlineColor: const Color(0xFF8E4A05),
                                  onTap: () => _select(AdventureDestination.learn),
                                ),
                                SizedBox(width: 10 * uiScale),
                                _AdventureCave(
                                  size: caveSize,
                                  asset: 'assets/images/adventure_play.png',
                                  title: 'Хочу\nИграть',
                                  titleColor: Colors.white,
                                  outlineColor: const Color(0xFF0647A8),
                                  onTap: () => _select(AdventureDestination.play),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      Expanded(
                        flex: 31,
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final smartSize = math.min(
                              width * .54,
                              box.maxHeight * 1.02,
                            ).clamp(165.0, 255.0).toDouble();

                            return Center(
                              child: _AdventureCave(
                                size: smartSize,
                                asset: 'assets/images/adventure_smart.png',
                                title: 'Хочу\nУмничать',
                                titleColor: Colors.white,
                                outlineColor: const Color(0xFF6F168E),
                                onTap: () => _select(AdventureDestination.smart),
                              ),
                            );
                          },
                        ),
                      ),

                      Expanded(
                        flex: 22,
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final dragonSize = math.min(
                              width * .34,
                              box.maxHeight * .95,
                            ).clamp(105.0, 175.0).toDouble();
                            // Табличка чуть компактнее, чтобы после поворота
                            // она полностью помещалась в экран.
                            final signWidth = math.min(
                              width * .25,
                              box.maxHeight * 1.05,
                            ).clamp(112.0, 175.0).toDouble();

                            final dragonLeft = width * .055;
                            final dragonRight = dragonLeft + dragonSize;
                            final gap = (5.0 * uiScale).clamp(1.0, 10.0);

                            // У Transform.rotate визуальная ширина больше обычной,
                            // поэтому оставляем запас справа и ставим знак чуть левее.
                            final desiredSignLeft = width * 0.33;
                            final maxSignLeft =
                                width - signWidth * 1.18 - width * .035;
                            final minSignLeft = dragonRight + gap;
                            final signLeft = math.min(
                              math.min(desiredSignLeft, minSignLeft),
                              maxSignLeft,
                            );

                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  left: dragonLeft,
                                  bottom: 15 * uiScale,
                                  width: dragonSize,
                                  height: dragonSize,
                                  child: _DragonImage(url: _levelDragonUrl),
                                ),
                                Positioned(
                                  left: signLeft,
                                  bottom: 18 * uiScale,
                                  width: signWidth,
                                  child: const _MotivationSign(),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 4 * uiScale),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: math.min(width * .78, 370),
                          minHeight: mottoHeight,
                        ),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 18 * uiScale,
                            vertical: 9 * uiScale,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .30),
                            borderRadius: BorderRadius.circular(28 * uiScale),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .45),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '✨ Учись  •  Играй  •  Развивайся ✨',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: (13.5 * uiScale).clamp(12.0, 16.0),
                                fontWeight: FontWeight.w900,
                                shadows: const [
                                  Shadow(color: Color(0x66000000), blurRadius: 5),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _AdventureCave extends StatefulWidget {
  final double size;
  final String asset;
  final String title;
  final Color titleColor;
  final Color outlineColor;
  final VoidCallback onTap;

  const _AdventureCave({
    required this.size,
    required this.asset,
    required this.title,
    required this.titleColor,
    required this.outlineColor,
    required this.onTap,
  });

  @override
  State<_AdventureCave> createState() => _AdventureCaveState();
}

class _AdventureCaveState extends State<_AdventureCave> {
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
        scale: _pressed ? .95 : 1,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Image.asset(widget.asset, fit: BoxFit.contain),
              ),
              Positioned(
                left: widget.size * .18,
                right: widget.size * .18,
                top: widget.size * .205,
                height: widget.size * .17,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _OutlinedCaveTitle(
                      text: widget.title,
                      fontSize: widget.size * .078,
                      color: widget.titleColor,
                      outlineColor: widget.outlineColor,
                    ),
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

class _OutlinedCaveTitle extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color color;
  final Color outlineColor;

  const _OutlinedCaveTitle({
    required this.text,
    required this.fontSize,
    required this.color,
    required this.outlineColor,
  });

  @override
  Widget build(BuildContext context) {
    const fontWeight = FontWeight.w900;
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize,
            height: .92,
            fontWeight: fontWeight,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = (fontSize * .12).clamp(2.0, 5.0).toDouble()
              ..strokeJoin = StrokeJoin.round
              ..color = outlineColor,
          ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            height: .92,
            fontWeight: fontWeight,
            shadows: const [
              Shadow(
                color: Color(0x66000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MotivationSign extends StatelessWidget {
  const _MotivationSign();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.52,
      alignment: Alignment.bottomCenter,
      child: Image.asset(
        'assets/images/adventure_sign.png',
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
      ),
    );
  }
}

class _DragonImage extends StatelessWidget {
  final String? url;

  const _DragonImage({this.url});

  @override
  Widget build(BuildContext context) {
    final value = url?.trim();
    if (value == null || value.isEmpty) {
      return Image.asset('assets/images/adventure_dragon.png', fit: BoxFit.contain);
    }

    return Image.network(
      value,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Image.asset(
        'assets/images/adventure_dragon.png',
        fit: BoxFit.contain,
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final double size;
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({
    required this.size,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .22),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            color: Colors.white,
            size: size * .62,
          ),
        ),
      ),
    );
  }
}
