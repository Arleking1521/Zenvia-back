import 'package:flutter/material.dart';

import '../models/subscription.dart';
import '../l10n/app_strings.dart';

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

  String _title(BuildContext context) {
    switch (widget.access.reason) {
      case 'expired':
        return context.tr('subscriptionPausedTitle');
      case 'pending':
        return context.tr('almostReady');
      case 'connection_error':
        return context.tr('accessCheckFailed');
      case 'cancelled':
        return context.tr('adventureResting');
      default:
        return context.tr('newAdventures');
    }
  }

  String _message(BuildContext context) {
    switch (widget.access.reason) {
      case 'expired':
        return context.tr('subscriptionExpiredMessage');
      case 'pending':
        return context.tr('subscriptionPendingMessage');
      case 'connection_error':
        return context.tr('connectionErrorMessage');
      case 'cancelled':
        return context.tr('subscriptionCancelledMessage');
      default:
        return context.tr('subscriptionNeededMessage');
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
                        height: 280,
                        child: Image.asset(
                          'assets/images/subscription_blocked_sleep_dragon.png',
                          height: 272,
                          fit: BoxFit.contain,
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -18),
                        child: Container(
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
                              _title(context),
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
                              _message(context),
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
                              label: context.tr('freePlay'),
                              color: const Color(0xFF49A8FF),
                              onTap: widget.onPlay,
                            ),
                            const SizedBox(height: 12),
                            _ActionButton(
                              icon: Icons.lock_rounded,
                              label: _openingParent
                                  ? context.tr('opening')
                                  : context.tr('callAdult'),
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
                                _retrying ? context.tr('checking') : context.tr('checkAgain'),
                              ),
                            ),
                          ],
                        ),
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
