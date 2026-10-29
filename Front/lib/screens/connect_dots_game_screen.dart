import 'dart:math' as math;

import 'package:flutter/material.dart';

class ConnectDotsGameScreen extends StatefulWidget {
  const ConnectDotsGameScreen({super.key});

  @override
  State<ConnectDotsGameScreen> createState() => _ConnectDotsGameScreenState();
}

class _ConnectDotsGameScreenState extends State<ConnectDotsGameScreen> {
  static const List<_DotPicture> _pictures = [
    _DotPicture(
      name: 'Звёздочка',
      color: Color(0xFFFFC83D),
      points: [
        Offset(.50, .08),
        Offset(.61, .36),
        Offset(.91, .37),
        Offset(.67, .55),
        Offset(.76, .86),
        Offset(.50, .68),
        Offset(.24, .86),
        Offset(.33, .55),
        Offset(.09, .37),
        Offset(.39, .36),
      ],
    ),
    _DotPicture(
      name: 'Рыбка',
      color: Color(0xFF55B9E8),
      points: [
        Offset(.12, .50),
        Offset(.28, .32),
        Offset(.52, .23),
        Offset(.74, .31),
        Offset(.88, .18),
        Offset(.84, .45),
        Offset(.90, .72),
        Offset(.73, .59),
        Offset(.52, .70),
        Offset(.28, .66),
      ],
    ),
    _DotPicture(
      name: 'Домик',
      color: Color(0xFFE9855C),
      points: [
        Offset(.18, .46),
        Offset(.50, .14),
        Offset(.82, .46),
        Offset(.75, .46),
        Offset(.75, .84),
        Offset(.55, .84),
        Offset(.55, .63),
        Offset(.39, .63),
        Offset(.39, .84),
        Offset(.24, .84),
        Offset(.24, .46),
      ],
    ),
    _DotPicture(
      name: 'Бабочка',
      color: Color(0xFF9D67D9),
      points: [
        Offset(.50, .20),
        Offset(.37, .08),
        Offset(.18, .20),
        Offset(.15, .43),
        Offset(.32, .50),
        Offset(.18, .72),
        Offset(.38, .83),
        Offset(.50, .62),
        Offset(.62, .83),
        Offset(.82, .72),
        Offset(.68, .50),
        Offset(.85, .43),
        Offset(.82, .20),
        Offset(.63, .08),
      ],
    ),
  ];

  int _pictureIndex = 0;
  int _connectedCount = 0;
  int? _wrongPoint;
  bool _completed = false;
  int _sessionToken = 0;

  _DotPicture get _picture => _pictures[_pictureIndex];

  void _restartPicture() {
    setState(() {
      _sessionToken += 1;
      _connectedCount = 0;
      _wrongPoint = null;
      _completed = false;
    });
  }

  Future<void> _onPointTap(int index) async {
    if (_completed) return;

    if (index != _connectedCount) {
      final token = ++_sessionToken;
      setState(() {
        _wrongPoint = index;
      });

      await Future<void>.delayed(const Duration(milliseconds: 420));
      if (!mounted || token != _sessionToken) return;

      setState(() {
        _wrongPoint = null;
      });
      return;
    }

    setState(() {
      _wrongPoint = null;
      _connectedCount += 1;
      if (_connectedCount == _picture.points.length) {
        _completed = true;
      }
    });
  }

  void _nextPicture() {
    if (_pictureIndex == _pictures.length - 1) {
      _showFinishedDialog();
      return;
    }

    setState(() {
      _pictureIndex += 1;
      _connectedCount = 0;
      _wrongPoint = null;
      _completed = false;
      _sessionToken += 1;
    });
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
              const Text('🎉', style: TextStyle(fontSize: 58)),
              const SizedBox(height: 6),
              const Text(
                'Все картинки готовы!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF124C89),
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ты отлично соединил все точки по порядку.',
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
                    setState(() {
                      _pictureIndex = 0;
                      _connectedCount = 0;
                      _wrongPoint = null;
                      _completed = false;
                      _sessionToken += 1;
                    });
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4E7DDE),
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
                    style: TextStyle(fontWeight: FontWeight.w800),
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
    final nextNumber = math.min(_connectedCount + 1, _picture.points.length);

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
                  const Color(0xFF163774).withValues(alpha: .35),
                  const Color(0xFF305997).withValues(alpha: .18),
                  const Color(0xFF10294F).withValues(alpha: .40),
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
                      _CircleButton(
                        tooltip: 'Назад',
                        icon: Icons.arrow_back_rounded,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Соедини точки',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 23,
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
                      _CircleButton(
                        tooltip: 'Начать заново',
                        icon: Icons.refresh_rounded,
                        onPressed: _restartPicture,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 13),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .92),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Картинка ${_pictureIndex + 1}/${_pictures.length}',
                                style: const TextStyle(
                                  color: Color(0xFF274B73),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              _picture.name,
                              style: TextStyle(
                                color: _picture.color,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _completed
                              ? 'Готово! Картинка получилась ✨'
                              : 'Найди точку $nextNumber',
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
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FBFF).withValues(alpha: .95),
                        borderRadius: BorderRadius.circular(38),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .7),
                          width: 2,
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final boardSize = math.min(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );

                          return Center(
                            child: SizedBox(
                              width: boardSize,
                              height: boardSize,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _DotsLinePainter(
                                        picture: _picture,
                                        connectedCount: _connectedCount,
                                        completed: _completed,
                                      ),
                                    ),
                                  ),
                                  ...List<Widget>.generate(
                                    _picture.points.length,
                                    (index) {
                                      final point = _picture.points[index];
                                      final left = point.dx * boardSize;
                                      final top = point.dy * boardSize;
                                      final isDone = index < _connectedCount;
                                      final isNext = index == _connectedCount;
                                      final isWrong = index == _wrongPoint;

                                      return Positioned(
                                        left: left - 22,
                                        top: top - 22,
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => _onPointTap(index),
                                          child: AnimatedScale(
                                            duration: const Duration(milliseconds: 140),
                                            scale: isWrong
                                                ? .86
                                                : isNext
                                                    ? 1.08
                                                    : 1,
                                            child: Container(
                                              width: 44,
                                              height: 44,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: isDone
                                                    ? _picture.color
                                                    : isWrong
                                                        ? const Color(0xFFFFD4D4)
                                                        : Colors.white,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isWrong
                                                      ? const Color(0xFFE35B5B)
                                                      : isNext
                                                          ? _picture.color
                                                          : const Color(0xFF9CB2D0),
                                                  width: isNext ? 4 : 2.5,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: isNext
                                                        ? _picture.color.withValues(alpha: .28)
                                                        : const Color(0x22000000),
                                                    blurRadius: isNext ? 12 : 6,
                                                    spreadRadius: isNext ? 2 : 0,
                                                    offset: const Offset(0, 3),
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                '${index + 1}',
                                                style: TextStyle(
                                                  color: isDone
                                                      ? Colors.white
                                                      : isWrong
                                                          ? const Color(0xFFB83D3D)
                                                          : const Color(0xFF315B8C),
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (_completed) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _nextPicture,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF4E7DDE),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        icon: Icon(
                          _pictureIndex == _pictures.length - 1
                              ? Icons.celebration_rounded
                              : Icons.arrow_forward_rounded,
                        ),
                        label: Text(
                          _pictureIndex == _pictures.length - 1
                              ? 'Готово'
                              : 'Следующая картинка',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DotsLinePainter extends CustomPainter {
  final _DotPicture picture;
  final int connectedCount;
  final bool completed;

  const _DotsLinePainter({
    required this.picture,
    required this.connectedCount,
    required this.completed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Offset p(int index) => Offset(
          picture.points[index].dx * size.width,
          picture.points[index].dy * size.height,
        );

    if (completed && picture.points.length >= 3) {
      final path = Path()..moveTo(p(0).dx, p(0).dy);
      for (var i = 1; i < picture.points.length; i++) {
        path.lineTo(p(i).dx, p(i).dy);
      }
      path.close();

      canvas.drawPath(
        path,
        Paint()
          ..color = picture.color.withValues(alpha: .18)
          ..style = PaintingStyle.fill,
      );
    }

    final linePaint = Paint()
      ..color = picture.color
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (connectedCount >= 2) {
      final path = Path()..moveTo(p(0).dx, p(0).dy);
      for (var i = 1; i < connectedCount; i++) {
        path.lineTo(p(i).dx, p(i).dy);
      }
      canvas.drawPath(path, linePaint);
    }

    if (completed && picture.points.isNotEmpty) {
      canvas.drawLine(p(picture.points.length - 1), p(0), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DotsLinePainter oldDelegate) {
    return oldDelegate.connectedCount != connectedCount ||
        oldDelegate.completed != completed ||
        oldDelegate.picture != picture;
  }
}

class _DotPicture {
  final String name;
  final Color color;
  final List<Offset> points;

  const _DotPicture({
    required this.name,
    required this.color,
    required this.points,
  });
}

class _CircleButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _CircleButton({
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
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}
