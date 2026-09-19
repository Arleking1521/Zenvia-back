import 'package:flutter/material.dart';

import '../data/app_repository.dart';
import '../models/dragon_evolution.dart';
import '../theme/app_colors.dart';

class DragonEvolutionScreen extends StatefulWidget {
  final AppRepository repository;

  const DragonEvolutionScreen({
    super.key,
    required this.repository,
  });

  @override
  State<DragonEvolutionScreen> createState() => _DragonEvolutionScreenState();
}

class _DragonEvolutionScreenState extends State<DragonEvolutionScreen> {
  late Future<DragonEvolutionData> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.getDragonEvolution();
  }

  Future<void> _reload() async {
    setState(() => _future = widget.repository.getDragonEvolution());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5DBFEF),
      body: FutureBuilder<DragonEvolutionData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _Background(
              child: SafeArea(
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return _Background(
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .94),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🐉', style: TextStyle(fontSize: 58)),
                          const SizedBox(height: 12),
                          const Text(
                            'Не удалось загрузить эволюцию дракона',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.deepBlue,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _reload,
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          return _EvolutionBody(
            data: snapshot.data!,
            onRefresh: _reload,
          );
        },
      ),
    );
  }
}

class _EvolutionBody extends StatelessWidget {
  final DragonEvolutionData data;
  final Future<void> Function() onRefresh;

  const _EvolutionBody({
    required this.data,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final current = data.currentLevel;
    final currentNumber = current?.number ?? 0;

    return _Background(
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: onRefresh,
          color: AppColors.primary,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final horizontal = (width * .055).clamp(16.0, 26.0);
              final dragonSize = (width * .66).clamp(235.0, 330.0);

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 30),
                child: Column(
                  children: [
                    _TopBar(onBack: () => Navigator.of(context).pop()),
                    const SizedBox(height: 10),
                    const Text(
                      'Твой дракон растёт\nвместе с тобой!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: Color(0x660B4A83),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _EvolutionStrip(
                      levels: data.levels,
                      currentLevelNumber: currentNumber,
                    ),
                    const SizedBox(height: 14),
                    _LevelProgress(data: data),
                    const SizedBox(height: 14),
                    Text(
                      current == null ? 'Твой путь начинается' : 'Уровень ${current.number}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .5,
                        shadows: [
                          Shadow(
                            color: Color(0x770B4A83),
                            blurRadius: 7,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    _LevelTitle(
                      title: current == null || current.title.trim().isEmpty
                          ? 'Юный дракон'
                          : current.title.trim(),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: dragonSize + 50,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Positioned(
                            top: 0,
                            right: 0,
                            child: _SpeechBubble(
                              text: data.isMaxLevel
                                  ? 'Ты достиг\nмаксимума!'
                                  : 'Ты делаешь\nуспехи!',
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Center(
                              child: _CurrentDragon(
                                imageUrl: current?.iconUrl,
                                size: dragonSize,
                              ),
                            ),
                          ),
                        ],
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


class _LevelTitle extends StatelessWidget {
  final String title;

  const _LevelTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF176FD1).withValues(alpha: .94),
            const Color(0xFF0E4E9C).withValues(alpha: .94),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: .95),
          width: 2.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF073A78).withValues(alpha: .35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: const Color(0xFFFFD54F).withValues(alpha: .22),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 34,
              height: 1.0,
              fontWeight: FontWeight.w900,
              letterSpacing: .3,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 5
                ..strokeJoin = StrokeJoin.round
                ..color = const Color(0xFF783B00),
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFFFD54F),
              fontSize: 34,
              height: 1.0,
              fontWeight: FontWeight.w900,
              letterSpacing: .3,
              shadows: [
                Shadow(
                  color: Color(0xFFFFF2A3),
                  blurRadius: 7,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.white.withValues(alpha: .20),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onBack,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 42,
              height: 42,
              child: Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
        const Spacer(),
        const Icon(
          Icons.auto_awesome_rounded,
          color: Colors.white,
          size: 24,
          shadows: [Shadow(color: Color(0x770E3B7D), blurRadius: 8)],
        ),
      ],
    );
  }
}

class _EvolutionStrip extends StatelessWidget {
  final List<DragonLevel> levels;
  final int currentLevelNumber;

  const _EvolutionStrip({
    required this.levels,
    required this.currentLevelNumber,
  });

  @override
  Widget build(BuildContext context) {
    if (levels.isEmpty) {
      return const SizedBox(height: 110);
    }

    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: levels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final level = levels[index];
          final unlocked = level.number <= currentLevelNumber;
          final current = level.number == currentLevelNumber;
          return _EvolutionItem(
            level: level,
            unlocked: unlocked,
            current: current,
          );
        },
      ),
    );
  }
}

class _EvolutionItem extends StatelessWidget {
  final DragonLevel level;
  final bool unlocked;
  final bool current;

  const _EvolutionItem({
    required this.level,
    required this.unlocked,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      child: Column(
        children: [
          SizedBox(
            width: 72,
            height: 82,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(2),
                  child: _EvolutionDragonImage(
                    imageUrl: level.iconUrl,
                    unlocked: unlocked,
                  ),
                ),
                if (!unlocked)
                  const Positioned(
                    right: 0,
                    bottom: 0,
                    child: Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 21,
                      shadows: [
                        Shadow(
                          color: Color(0x99000000),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(minWidth: 31),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: unlocked
                  ? const Color(0xFFFFC83D)
                  : const Color(0xFF75838D).withValues(alpha: .92),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: Colors.white, width: 1.2),
            ),
            child: Text(
              '${level.number}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvolutionDragonImage extends StatelessWidget {
  final String? imageUrl;
  final bool unlocked;

  const _EvolutionDragonImage({
    required this.imageUrl,
    required this.unlocked,
  });

  static const _greyMatrix = <double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    Widget image;
    final url = imageUrl;
    if (url == null || url.isEmpty) {
      image = const Center(
        child: Text('🐉', style: TextStyle(fontSize: 38)),
      );
    } else {
      image = Image.network(
        url,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const Center(
          child: Text('🐉', style: TextStyle(fontSize: 38)),
        ),
      );
    }

    if (unlocked) return image;

    return Opacity(
      opacity: .72,
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(_greyMatrix),
        child: image,
      ),
    );
  }
}

class _LevelProgress extends StatelessWidget {
  final DragonEvolutionData data;

  const _LevelProgress({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF2C77A6).withValues(alpha: .88),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E3B7D).withValues(alpha: .25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: Stack(
          children: [
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: data.levelProgress,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF25E968),
                        Color(0xFF0FCB68),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (data.levelProgress > .05)
              Positioned(
                left: 12,
                top: 4,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.white, blurRadius: 6),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CurrentDragon extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const _CurrentDragon({
    required this.imageUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return SizedBox(
      width: size,
      height: size,
      child: url == null || url.isEmpty
          ? Center(
              child: Text(
                '🐉',
                style: TextStyle(fontSize: size * .45),
              ),
            )
          : Image.network(
              url,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  '🐉',
                  style: TextStyle(fontSize: size * .45),
                ),
              ),
            ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  final String text;

  const _SpeechBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 128,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .96),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepBlue.withValues(alpha: .12),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.deepBlue,
              fontSize: 16,
              height: 1.05,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Positioned(
          left: 18,
          bottom: -11,
          child: Transform.rotate(
            angle: .55,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .96),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Background extends StatelessWidget {
  final Widget child;

  const _Background({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Image(
          image: AssetImage('assets/images/dragon_evolution_bg.webp'),
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF006DAE).withValues(alpha: .40),
                const Color(0xFF59C6F2).withValues(alpha: .10),
                Colors.transparent,
              ],
              stops: const [0, .36, 1],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
