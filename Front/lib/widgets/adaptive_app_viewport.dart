import 'package:flutter/material.dart';

/// Единый адаптивный viewport для всего приложения.
///
/// Все экраны верстаются относительно базовой ширины 390 logical px,
/// после чего весь UI равномерно масштабируется на фактический размер окна.
///
/// Важно: здесь используется FittedBox вместо Transform.scale. Так Flutter
/// корректно занимает всю область окна и не оставляет черные полосы справа
/// или снизу на устройствах с другими размерами / DPR.
class AdaptiveAppViewport extends StatelessWidget {
  final Widget child;

  const AdaptiveAppViewport({
    super.key,
    required this.child,
  });

  static const double designWidth = 390.0;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final realWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : media.size.width;
        final realHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : media.size.height;

        if (realWidth <= 0 || realHeight <= 0) {
          return child;
        }

        final scale = realWidth / designWidth;
        final designHeight = realHeight / scale;

        final designMedia = media.copyWith(
          size: Size(designWidth, designHeight),
          padding: _scaleInsetsDown(media.padding, scale),
          viewPadding: _scaleInsetsDown(media.viewPadding, scale),
          viewInsets: _scaleInsetsDown(media.viewInsets, scale),
          systemGestureInsets: _scaleInsetsDown(
            media.systemGestureInsets,
            scale,
          ),
          textScaler: media.textScaler.clamp(
            minScaleFactor: 0.90,
            maxScaleFactor: 1.15,
          ),
        );

        return SizedBox.expand(
          child: ClipRect(
            child: FittedBox(
              fit: BoxFit.fill,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: designWidth,
                height: designHeight,
                child: MediaQuery(
                  data: designMedia,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static EdgeInsets _scaleInsetsDown(EdgeInsets value, double scale) {
    if (scale <= 0) return value;

    return EdgeInsets.fromLTRB(
      value.left / scale,
      value.top / scale,
      value.right / scale,
      value.bottom / scale,
    );
  }
}
