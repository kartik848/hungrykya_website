import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Scattered hand-drawn food doodles used as a decorative background layer.
/// Each doodle is drawn in a 48×48 box with round-capped strokes.
class Doodles extends StatelessWidget {
  final Color color;
  final double opacity;
  final int seed;
  final double spacing;

  /// Fraction of grid cells left empty (0 = dense, 1 = none).
  final double skip;
  const Doodles({super.key, this.color = HK.amberDeep, this.opacity = .13, this.seed = 7, this.spacing = 128, this.skip = .25});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _DoodlePainter(color: color, opacity: opacity, seed: seed, spacing: spacing, skip: skip),
          ),
        ),
      );
}

/// A single doodle, e.g. as an accent next to a heading.
class Doodle extends StatelessWidget {
  final int index;
  final double size;
  final Color color;
  final double opacity;
  const Doodle(this.index, {super.key, this.size = 48, this.color = HK.amberDeep, this.opacity = .9});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(size: Size.square(size), painter: _SinglePainter(index, color.withOpacity(opacity))),
      );
}

typedef _Draw = void Function(Canvas c, Paint stroke, Paint fill);

final List<_Draw> _doodles = [
  // 0 pizza slice
  (c, s, f) {
    c.drawPath(
        Path()
          ..moveTo(8, 11)
          ..quadraticBezierTo(24, 2, 40, 11)
          ..lineTo(24, 44)
          ..close(),
        s);
    c.drawPath(
        Path()
          ..moveTo(11, 16)
          ..quadraticBezierTo(24, 9, 37, 16),
        s);
    c.drawCircle(const Offset(20, 21), 3, s);
    c.drawCircle(const Offset(29, 25), 2.4, s);
    c.drawCircle(const Offset(23, 32), 2.4, s);
  },
  // 1 burger
  (c, s, f) {
    c.drawPath(
        Path()
          ..moveTo(8, 22)
          ..cubicTo(8, 7, 40, 7, 40, 22)
          ..close(),
        s);
    for (final x in [17.0, 24.0, 31.0]) {
      c.drawLine(Offset(x, 14), Offset(x + 1.5, 15.5), s);
    }
    final lettuce = Path()..moveTo(7, 27);
    for (var i = 0; i < 6; i++) {
      final x = 7 + i * 5.7;
      lettuce.quadraticBezierTo(x + 2.8, i.isEven ? 23 : 31, x + 5.7, 27);
    }
    c.drawPath(lettuce, s);
    c.drawRRect(RRect.fromLTRBR(9, 30, 39, 35, const Radius.circular(3)), s);
    c.drawRRect(RRect.fromLTRBR(8, 37, 40, 43, const Radius.circular(4)), s);
  },
  // 2 chilli
  (c, s, f) {
    c.drawPath(
        Path()
          ..moveTo(14, 16)
          ..cubicTo(9, 31, 22, 43, 40, 42)
          ..cubicTo(27, 36, 22, 27, 22, 16)
          ..close(),
        s);
    c.drawPath(
        Path()
          ..moveTo(18, 16)
          ..quadraticBezierTo(17, 8, 26, 6),
        s);
    c.drawLine(const Offset(13, 16), const Offset(23, 16), s);
  },
  // 3 chai cup with steam
  (c, s, f) {
    c.drawPath(
        Path()
          ..moveTo(9, 20)
          ..lineTo(35, 20)
          ..lineTo(32, 40)
          ..quadraticBezierTo(31.5, 43, 28, 43)
          ..lineTo(16, 43)
          ..quadraticBezierTo(12.5, 43, 12, 40)
          ..close(),
        s);
    c.drawArc(const Rect.fromLTWH(29, 24, 11, 11), -math.pi / 2, math.pi, false, s);
    c.drawPath(
        Path()
          ..moveTo(17, 16)
          ..cubicTo(13, 12, 21, 9, 17, 4),
        s);
    c.drawPath(
        Path()
          ..moveTo(26, 16)
          ..cubicTo(22, 12, 30, 9, 26, 4),
        s);
  },
  // 4 noodle bowl with chopsticks
  (c, s, f) {
    c.drawLine(const Offset(5, 24), const Offset(43, 24), s);
    c.drawArc(const Rect.fromLTWH(5, 6, 38, 36), 0, math.pi, false, s);
    c.drawLine(const Offset(18, 44), const Offset(30, 44), s);
    c.drawLine(const Offset(27, 22), const Offset(43, 4), s);
    c.drawLine(const Offset(31, 23), const Offset(46, 8), s);
    c.drawPath(
        Path()
          ..moveTo(12, 24)
          ..cubicTo(14, 18, 18, 30, 20, 24),
        s);
  },
  // 5 leaf
  (c, s, f) {
    c.drawPath(
        Path()
          ..moveTo(8, 40)
          ..cubicTo(8, 19, 23, 8, 40, 8)
          ..cubicTo(40, 28, 28, 40, 8, 40)
          ..close(),
        s);
    c.drawPath(
        Path()
          ..moveTo(8, 40)
          ..quadraticBezierTo(22, 27, 34, 14),
        s);
  },
  // 6 fork & spoon
  (c, s, f) {
    for (final x in [10.0, 14.0, 18.0]) {
      c.drawLine(Offset(x, 4), Offset(x, 14), s);
    }
    c.drawPath(
        Path()
          ..moveTo(10, 14)
          ..quadraticBezierTo(14, 21, 18, 14),
        s);
    c.drawLine(const Offset(14, 18), const Offset(14, 44), s);
    c.drawOval(const Rect.fromLTWH(28, 4, 12, 17), s);
    c.drawLine(const Offset(34, 21), const Offset(34, 44), s);
  },
  // 7 sparkle
  (c, s, f) {
    c.drawPath(
        Path()
          ..moveTo(24, 6)
          ..quadraticBezierTo(26, 22, 42, 24)
          ..quadraticBezierTo(26, 26, 24, 42)
          ..quadraticBezierTo(22, 26, 6, 24)
          ..quadraticBezierTo(22, 22, 24, 6),
        s);
  },
  // 8 donut
  (c, s, f) {
    c.drawCircle(const Offset(24, 24), 17, s);
    c.drawCircle(const Offset(24, 24), 6, s);
    for (var i = 0; i < 7; i++) {
      final a = i * 2 * math.pi / 7 + .3;
      final p = Offset(24 + 11.5 * math.cos(a), 24 + 11.5 * math.sin(a));
      c.drawLine(p, p + Offset(2.6 * math.cos(a + 1.2), 2.6 * math.sin(a + 1.2)), s);
    }
  },
  // 9 ice-cream cone
  (c, s, f) {
    c.drawPath(
        Path()
          ..moveTo(14, 22)
          ..lineTo(24, 45)
          ..lineTo(34, 22),
        s);
    c.drawLine(const Offset(17, 28), const Offset(29, 34), s);
    c.drawLine(const Offset(31, 28), const Offset(20, 37), s);
    c.drawArc(Rect.fromCircle(center: const Offset(24, 16), radius: 11), 2.75, 3.9, false, s);
    c.drawLine(const Offset(13, 21), const Offset(35, 21), s);
  },
  // 10 squiggle
  (c, s, f) {
    c.drawPath(
        Path()
          ..moveTo(4, 28)
          ..cubicTo(12, 12, 20, 42, 28, 26)
          ..cubicTo(33, 16, 40, 32, 44, 20),
        s);
  },
  // 11 samosa
  (c, s, f) {
    c.drawPath(
        Path()
          ..moveTo(24, 7)
          ..lineTo(42, 40)
          ..quadraticBezierTo(24, 44, 6, 40)
          ..close(),
        s);
    c.drawPath(
        Path()
          ..moveTo(24, 7)
          ..quadraticBezierTo(21, 26, 24, 42),
        s);
    c.drawCircle(const Offset(15, 33), 1.3, f);
    c.drawCircle(const Offset(32, 31), 1.3, f);
  },
  // 12 dots trio
  (c, s, f) {
    c.drawCircle(const Offset(14, 30), 2.6, f);
    c.drawCircle(const Offset(24, 18), 2.6, f);
    c.drawCircle(const Offset(34, 30), 2.6, f);
  },
  // 13 heart
  (c, s, f) {
    c.drawPath(
        Path()
          ..moveTo(24, 40)
          ..cubicTo(4, 27, 8, 8, 24, 17)
          ..cubicTo(40, 8, 44, 27, 24, 40),
        s);
  },
];

void _setup(Canvas canvas, Paint stroke) {
  stroke
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
}

class _DoodlePainter extends CustomPainter {
  final Color color;
  final double opacity;
  final int seed;
  final double spacing;
  final double skip;
  _DoodlePainter({required this.color, required this.opacity, required this.seed, required this.spacing, required this.skip});

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(seed);
    final stroke = Paint()..color = color.withOpacity(opacity);
    _setup(canvas, stroke);
    final fill = Paint()..color = color.withOpacity(opacity);
    var row = 0;
    for (var y = spacing * .4; y < size.height + spacing * .3; y += spacing * .86, row++) {
      for (var x = (row.isOdd ? spacing * .5 : 0.0) + spacing * .3; x < size.width + spacing * .3; x += spacing) {
        final skipIt = r.nextDouble() < skip;
        final dx = x + (r.nextDouble() - .5) * spacing * .45;
        final dy = y + (r.nextDouble() - .5) * spacing * .45;
        final draw = _doodles[r.nextInt(_doodles.length)];
        final scale = .7 + r.nextDouble() * .55;
        final rot = (r.nextDouble() - .5) * 1.1;
        if (skipIt) continue;
        canvas.save();
        canvas.translate(dx, dy);
        canvas.rotate(rot);
        canvas.scale(scale);
        canvas.translate(-24, -24);
        draw(canvas, stroke, fill);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter o) =>
      o.color != color || o.opacity != opacity || o.seed != seed || o.spacing != spacing || o.skip != skip;
}

class _SinglePainter extends CustomPainter {
  final int index;
  final Color color;
  _SinglePainter(this.index, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()..color = color;
    _setup(canvas, stroke);
    canvas.scale(size.width / 48);
    _doodles[index % _doodles.length](canvas, stroke, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SinglePainter o) => o.index != index || o.color != color;
}
