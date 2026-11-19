// Decorative backdrop for the today card: a faded sun or moon on the right,
// with clouds by day and stars at night.
import 'package:flutter/material.dart';

import '../../core/time/part_of_day.dart';
import 'part_of_day_builder.dart';

class SkyBackdrop extends StatelessWidget {
  const SkyBackdrop({super.key});

  /// Share of the card width taken by the sun or moon.
  static const double emojiWidthFactor = 0.38;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: PartOfDayBuilder(
          builder: (context, period) => LayoutBuilder(
            builder: (context, constraints) =>
                _sky(constraints.biggest, period),
          ),
        ),
      ),
    );
  }

  Widget _sky(Size size, PartOfDay period) {
    final w = size.width;
    final h = size.height;
    final s = w * emojiWidthFactor;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (period.isDaytime) ..._clouds(w, h, s) else ..._stars(w, h),
        Positioned(
          key: const Key('sky.emoji'),
          right: w * 0.02,
          top: (h - s) / 2,
          width: s,
          height: s,
          child: _faded(period.emoji, 0.35),
        ),
        // A cloud drifting in front of the sun.
        if (period.isDaytime)
          Positioned(
            left: w - s * 1.05,
            top: h / 2 + s * 0.05,
            width: s * 0.5,
            height: s * 0.5,
            child: _faded('☁️', 0.55),
          ),
      ],
    );
  }

  List<Widget> _clouds(double w, double h, double s) => [
        for (final (dx, dy, size, alpha) in const [
          (1.55, 0.10, 0.28, 0.40),
          (0.50, 0.02, 0.34, 0.45),
        ])
          Positioned(
            left: w - s * dx,
            top: h * dy,
            width: s * size,
            height: s * size,
            child: _faded('☁️', alpha),
          ),
      ];

  List<Widget> _stars(double w, double h) => [
        for (final (x, y, size, alpha) in const [
          (0.52, 0.14, 10.0, 0.70),
          (0.60, 0.68, 8.0, 0.55),
          (0.68, 0.06, 12.0, 0.80),
          (0.57, 0.40, 7.0, 0.50),
          (0.80, 0.86, 9.0, 0.60),
          (0.93, 0.08, 8.0, 0.70),
          (0.97, 0.55, 10.0, 0.60),
        ])
          Positioned(
            left: w * x - size / 2,
            top: h * y - size / 2,
            child: Icon(
              Icons.star_rounded,
              size: size,
              color: Colors.white.withValues(alpha: alpha),
            ),
          ),
      ];

  // Color emoji ignore the text color's alpha, so fade them with Opacity.
  static Widget _faded(String emoji, double opacity) => Opacity(
        opacity: opacity,
        child: FittedBox(child: Text(emoji)),
      );
}
