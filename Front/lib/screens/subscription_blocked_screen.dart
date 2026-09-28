import 'package:flutter/material.dart';

import '../models/subscription.dart';

class SubscriptionBlockedScreen extends StatefulWidget {
  final SubscriptionAccessStatus access;
  final VoidCallback onPlay;
  final Future<void> Function() onParent;
  final Future<void> Function() onRetry;

  const SubscriptionBlockedScreen({
    super.key,
    required this.access,
    required this.onPlay,
    required this.onParent,
    required this.onRetry,
  });

  @override
  State<SubscriptionBlockedScreen> createState() =>
      _SubscriptionBlockedScreenState();
}

class _SubscriptionBlockedScreenState extends State<SubscriptionBlockedScreen> {
  bool _retrying = false;
  bool _openingParent = false;

  String get _title {
    switch (widget.access.reason) {
      case 'expired':
        return 'Ой, приключение\nпоставлено на паузу...';
      case 'pending':
        return 'Почти готово!';
      case 'connection_error':
        return 'Не получилось\nпроверить доступ';
      case 'cancelled':
        return 'Приключение\nпока отдыхает';
      default:
        return 'Новые приключения\nждут тебя!';
    }
  }

  String get _message {
    switch (widget.access.reason) {
      case 'expired':
        return 'Попроси взрослого помочь продолжить путешествие 💛';
      case 'pending':
        return 'Попроси взрослого завершить оплату, и обучение снова откроется.';
      case 'connection_error':
        return 'Попроси взрослого проверить интернет и попробуй ещё раз.';
      case 'cancelled':
        return 'Попроси взрослого снова открыть доступ к обучению.';
      default:
        return 'Попроси взрослого открыть доступ к обучению.';
    }
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<void> _parent() async {
    if (_openingParent) return;
    setState(() => _openingParent = true);
    try {
      await widget.onParent();
    } finally {
      if (mounted) setState(() => _openingParent = false);
    }
  }

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
                  const Color(0xFF075DAA).withValues(alpha: .18),
                  Colors.transparent,
                  const Color(0xFF163663).withValues(alpha: .22),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 230,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ColorFiltered(
                              colorFilter: const ColorFilter.matrix([
                                .86, .08, .06, 0, 0,
                                .06, .88, .06, 0, 0,
                                .06, .10, .84, 0, 0,
                                0, 0, 0, 1, 0,
                              ]),
                              child: Image.asset(
                                'assets/images/adventure_dragon.webp',
                                height: 215,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const Positioned(
                              right: 50,
                              top: 34,
                              child: Text(
                                '😢',
                                style: TextStyle(fontSize: 40),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .94),
                          borderRadius: BorderRadius.circular(34),
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 22,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              _title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF174E93),
                                fontSize: 27,
                                height: 1.08,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF536783),
                                fontSize: 15,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 22),
                            _ActionButton(
                              icon: Icons.sports_esports_rounded,
                              label: 'Пока можно поиграть',
                              color: const Color(0xFF49A8FF),
                              onTap: widget.onPlay,
                            ),
                            const SizedBox(height: 12),
                            _ActionButton(
                              icon: Icons.lock_rounded,
                              label: _openingParent
                                  ? 'Открываем...'
                                  : 'Позвать взрослого',
                              color: const Color(0xFF36BF70),
                              onTap: _openingParent ? null : _parent,
                            ),
                            const SizedBox(height: 4),
                            TextButton.icon(
                              onPressed: _retrying ? null : _retry,
                              icon: _retrying
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                      ),
                                    )
                                  : const Icon(Icons.refresh_rounded),
                              label: Text(
                                _retrying ? 'Проверяем...' : 'Проверить снова',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 9),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
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
