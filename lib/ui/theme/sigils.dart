import 'dart:math' as math;
import 'package:flutter/material.dart';

class SigilPaths {
  /// Returns a canonical Path drawn on a 24x24 unit grid based on the
  /// Glucose Guild crest construction law:
  /// - Warrior  : Shield  (The Stabilizer)  🛡️
  /// - Sage     : Scales (The Counter)      ⚖️
  /// - Monk     : Droplet (The Hydrator)    💧
  /// - Bard     : Gear (The Rotator)        ⚙️
  /// - Ranger   : Eye (The Analyst)         👁️
  /// - Artificer: Flask (The Alchemist)     🧪
  static Path getPath(String domain) {
    final path = Path();
    switch (domain.toLowerCase()) {
      case 'warrior':
        // Shield: bulletproof gluttony stop, guarded line
        path.moveTo(4, 4);
        path.lineTo(20, 4);
        path.lineTo(20, 13);
        path.quadraticBezierTo(20, 19, 12, 22);
        path.quadraticBezierTo(4, 19, 4, 13);
        path.close();
        // Shield vertical mid-ridge (the guarded line)
        path.moveTo(12, 4);
        path.lineTo(12, 22);
        break;

      case 'sage':
        // Scales: balanced ledger of measurement
        // Beam
        path.moveTo(4, 6);
        path.lineTo(20, 6);
        // Center pillar + pivot mount
        path.moveTo(12, 6);
        path.lineTo(12, 11);
        path.moveTo(12, 11);
        path.lineTo(8, 16);
        path.lineTo(16, 16);
        path.close();
        // Left chain + pan
        path.moveTo(5, 6);
        path.lineTo(5, 15);
        path.moveTo(2, 18);
        path.lineTo(8, 18);
        path.moveTo(2, 18);
        path.quadraticBezierTo(5, 16.5, 8, 18);
        // Right chain + pan
        path.moveTo(19, 6);
        path.lineTo(19, 15);
        path.moveTo(16, 18);
        path.lineTo(22, 18);
        path.moveTo(16, 18);
        path.quadraticBezierTo(19, 16.5, 22, 18);
        break;

      case 'monk':
        // Droplet: hydration flow
        path.moveTo(12, 3);
        path.quadraticBezierTo(21, 12, 12, 20);
        path.quadraticBezierTo(3, 12, 12, 3);
        path.close();
        // Ripple beneath the droplet
        path.moveTo(8.5, 22.5);
        path.quadraticBezierTo(12, 21, 15.5, 22.5);
        break;

      case 'bard':
        // Gear: rotation discipline
        final double outer = 9.2;
        final double inner = 6.4;
        final Offset c = const Offset(12, 12);
        for (int i = 0; i < 16; i++) {
          final double r = i.isOdd ? outer : inner;
          final double a = i * math.pi / 8 - math.pi / 2;
          final Offset p = c + Offset(math.cos(a) * r, math.sin(a) * r);
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        path.close();
        // Center hub
        path.addOval(Rect.fromCircle(center: c, radius: 3.6));
        break;

      case 'ranger':
        // Eye: the long-game watch (dawn patterns, trends)
        path.moveTo(3, 12);
        path.quadraticBezierTo(7, 4, 12, 4);
        path.quadraticBezierTo(17, 4, 21, 12);
        path.quadraticBezierTo(17, 20, 12, 20);
        path.quadraticBezierTo(7, 20, 3, 12);
        path.close();
        // Iris + pupil
        path.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 4));
        path.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 1.4));
        break;

      case 'artificer':
      default:
        // Flask: precise dosing craft
        // Neck
        path.moveTo(9, 3);
        path.lineTo(9, 9);
        // Left flare
        path.quadraticBezierTo(5, 13, 4, 19);
        // Bottom
        path.lineTo(20, 19);
        // Right flare
        path.quadraticBezierTo(19, 13, 15, 9);
        // Right neck + rim
        path.lineTo(15, 3);
        path.close();
        // Liquid meniscus
        path.moveTo(5, 16);
        path.lineTo(19, 16);
        // Rising bubble
        path.addOval(Rect.fromCircle(center: const Offset(14, 12), radius: 1));
        break;
    }
    return path;
  }
}

class SigilPainter extends CustomPainter {
  final String domain;
  final Color color;
  final double strokeWidth;
  final double progress; // For draw-on animation (0.0 to 1.0)

  SigilPainter({
    required this.domain,
    required this.color,
    this.strokeWidth = 2.0,
    this.progress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final baseRawPath = SigilPaths.getPath(domain);

    // Scale path from 24x24 to widget size
    final matrix = Matrix4.identity()
      ..scale(size.width / 24.0, size.height / 24.0);
    final scaledPath = baseRawPath.transform(matrix.storage);

    if (progress >= 1.0) {
      canvas.drawPath(scaledPath, paint);
    } else if (progress > 0.0) {
      // Draw partially for the animation
      for (final pathMetric in scaledPath.computeMetrics()) {
        final extractPath = pathMetric.extractPath(0.0, pathMetric.length * progress);
        canvas.drawPath(extractPath, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SigilPainter oldDelegate) {
    return oldDelegate.domain != domain ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.progress != progress;
  }
}
