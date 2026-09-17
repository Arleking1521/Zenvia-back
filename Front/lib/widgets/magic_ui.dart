import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class FantasyBackground extends StatelessWidget {
  final Widget child;
  final bool light;
  final EdgeInsetsGeometry? padding;

  const FantasyBackground({
    super.key,
    required this.child,
    this.light = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: light
              ? const [Color(0xFFDDF5FF), Color(0xFFF3FFF1)]
              : const [AppColors.skyTop, AppColors.skyMid, Color(0xFFDDF8F2)],
          stops: light ? null : const [0, .45, 1],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(top: 24, left: -18, child: _Cloud(scale: 1.1)),
          const Positioned(top: 92, right: -34, child: _Cloud(scale: .8)),
          const Positioned(bottom: 70, left: -48, child: _GlowBubble(size: 150)),
          const Positioned(bottom: 180, right: -55, child: _GlowBubble(size: 125)),
          Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ],
      ),
    );
  }
}

class _Cloud extends StatelessWidget {
  final double scale;
  const _Cloud({required this.scale});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: SizedBox(
        width: 150,
        height: 60,
        child: Stack(
          children: [
            Positioned(left: 12, bottom: 2, child: _bubble(84, 36)),
            Positioned(left: 38, bottom: 7, child: _bubble(52, 48)),
            Positioned(left: 73, bottom: 4, child: _bubble(65, 39)),
          ],
        ),
      ),
    );
  }

  Widget _bubble(double width, double height) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .42),
          borderRadius: BorderRadius.circular(50),
        ),
      );
}

class _GlowBubble extends StatelessWidget {
  final double size;
  const _GlowBubble({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: .18),
      ),
    );
  }
}

class MagicCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final Color? color;
  final double radius;
  final Border? border;

  const MagicCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.gradient,
    this.color,
    this.radius = 28,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? Colors.white.withValues(alpha: .96)) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: [
          BoxShadow(
            color: AppColors.deepBlue.withValues(alpha: .10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class MagicPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool compact;

  const MagicPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.greenGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .35),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(26),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 18 : 24,
              vertical: compact ? 12 : 16,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 14 : 17,
                    fontWeight: FontWeight.w900,
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

class ZenviaLogo extends StatelessWidget {
  final double scale;
  const ZenviaLogo({super.key, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [Color(0xFFFFD94F), Color(0xFFFF8D3C), Color(0xFFFF62A5)],
          ).createShader(rect),
          child: Text(
            'Zenvia',
            style: TextStyle(
              fontSize: 44 * scale,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1.5,
              shadows: const [
                Shadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 3)),
              ],
            ),
          ),
        ),
        Text(
          'Kids',
          style: TextStyle(
            fontSize: 31 * scale,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFFF64C2),
            height: .8,
          ),
        ),
      ],
    );
  }
}

class DragonImage extends StatelessWidget {
  final String asset;
  final double height;
  final BoxFit fit;
  final BorderRadius? radius;

  const DragonImage({
    super.key,
    required this.asset,
    this.height = 180,
    this.fit = BoxFit.cover,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: radius ?? BorderRadius.circular(28),
      child: Image.asset(asset, height: height, width: double.infinity, fit: fit),
    );
  }
}

class MagicSectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const MagicSectionTitle({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.deepBlue,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    );
  }
}
