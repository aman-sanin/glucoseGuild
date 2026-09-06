import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/tokens.dart';

enum CgmPetMood {
  /// In-range and calm volatility — the serenest state.
  serene,

  /// Above the target band (neutral amber/copper, never red).
  highAlert,

  /// Below the target band (neutral blue, never red).
  lowWatch,

  /// Logging but volatile — alert but neutral.
  vigilant,

  /// No glucose data yet this day.
  sleeping,
}

/// Pure mood classifier for the CGM pet (testable, no Flutter deps).
CgmPetMood cgmPetMoodFor({
  required bool hasData,
  required double? latestValue,
  required double sd,
  required bool hadHypo,
}) {
  if (!hasData || latestValue == null) return CgmPetMood.sleeping;
  if (hadHypo || latestValue < 70) return CgmPetMood.lowWatch;
  if (latestValue > 180) return CgmPetMood.highAlert;
  if (sd < 30) return CgmPetMood.serene;
  return CgmPetMood.vigilant;
}

/// Simple animated companion that mirrors the day's glucose mood.
///
/// Bobs gently on the idle lull; eyes/mouth render per [CgmPetMood].
/// Neutral palette only — the app never paints glucose as "bad (red)".
class CgmPetWidget extends StatefulWidget {
  final CgmPetMood mood;
  final double size;

  const CgmPetWidget({super.key, required this.mood, this.size = 84});

  @override
  State<CgmPetWidget> createState() => _CgmPetWidgetState();
}

class _CgmPetWidgetState extends State<CgmPetWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  late final Animation<double> _bob = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final size = widget.size;

    final (body, eye) = _palette(tokens, widget.mood);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dy = -6.0 * math.sin(_bob.value * math.pi);
        return Transform.translate(
          offset: Offset(0, dy),
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _CgmPetPainter(
                mood: widget.mood,
                bodyColor: body,
                eyeColor: eye,
                particles: math.sin(_bob.value * math.pi * 2),
              ),
            ),
          ),
        );
      },
    );
  }

  (Color, Color) _palette(AppTokens tokens, CgmPetMood mood) {
    switch (mood) {
      case CgmPetMood.serene:
        return (tokens.hero.withOpacity(0.85), tokens.onSolid);
      case CgmPetMood.highAlert:
        return (tokens.accent, tokens.onSolid);
      case CgmPetMood.lowWatch:
        return (tokens.accent.withOpacity(0.6), tokens.onSolid);
      case CgmPetMood.vigilant:
        return (tokens.hero.withOpacity(0.55), tokens.onSolid);
      case CgmPetMood.sleeping:
        return (tokens.textSecondary.withOpacity(0.35), tokens.bg);
    }
  }
}

class _CgmPetPainter extends CustomPainter {
  final CgmPetMood mood;
  final Color bodyColor;
  final Color eyeColor;
  final double particles;

  _CgmPetPainter({
    required this.mood,
    required this.bodyColor,
    required this.eyeColor,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r = w * 0.34;

    final bodyPaint = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Blob body (rounded squircle-ish).
    final bodyPath = Path()
      ..moveTo(cx - r, cy - r * 0.2)
      ..quadraticBezierTo(cx - r * 1.1, cy - r * 0.7, cx - r * 0.45, cy - r * 0.95)
      ..quadraticBezierTo(cx, cy - r * 1.1, cx + r * 0.45, cy - r * 0.95)
      ..quadraticBezierTo(cx + r * 1.1, cy - r * 0.7, cx + r, cy - r * 0.2)
      ..quadraticBezierTo(cx + r * 1.15, cy + r * 0.4, cx + r * 0.55, cy + r * 0.8)
      ..quadraticBezierTo(cx, cy + r * 1.05, cx - r * 0.55, cy + r * 0.8)
      ..quadraticBezierTo(cx - r * 1.15, cy + r * 0.4, cx - r, cy - r * 0.2);
    canvas.drawPath(bodyPath, bodyPaint);
    canvas.drawPath(bodyPath, strokePaint);

    if (mood != CgmPetMood.sleeping) {
      // Eyes.
      final eyeY = cy - r * 0.35;
      final eyeDx = r * 0.42;
      final eyeR = r * 0.16;
      final eyePaint = Paint()..color = eyeColor;

      final lidClosed = mood == CgmPetMood.serene;
      for (final dir in [-1.0, 1.0]) {
        final ex = cx + dir * eyeDx;
        if (lidClosed) {
          canvas.drawLine(
            Offset(ex - eyeR, eyeY),
            Offset(ex + eyeR, eyeY),
            eyePaint..strokeWidth = 2.5,
          );
        } else {
          canvas.drawCircle(Offset(ex, eyeY), eyeR, eyePaint);
          final pupilR = eyeR * (mood == CgmPetMood.highAlert ? 0.65 : 0.45);
          canvas.drawCircle(
            Offset(ex, eyeY),
            pupilR,
            Paint()..color = Colors.black.withOpacity(0.35),
          );
        }
      }

      // Mouth.
      final mouthDx = r * 0.55;
      final mouthY = cy + r * 0.15;
      final mouthPaint = Paint()
        ..color = eyeColor.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      if (mood == CgmPetMood.highAlert || mood == CgmPetMood.vigilant) {
        canvas.drawLine(
          Offset(cx - mouthDx, mouthY),
          Offset(cx + mouthDx, mouthY),
          mouthPaint,
        );
      } else if (mood == CgmPetMood.lowWatch) {
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(cx, mouthY - r * 0.05),
            width: mouthDx * 2,
            height: r * 0.34,
          ),
          0.15 * math.pi,
          0.7 * math.pi,
          false,
          mouthPaint,
        );
      } else {
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(cx, mouthY),
            width: mouthDx * 2,
            height: r * 0.3,
          ),
          0.05 * math.pi,
          0.9 * math.pi,
          false,
          mouthPaint,
        );
      }
    } else {
      // Sleeping: closed eyelids as gentle curves.
      final eyeY = cy - r * 0.35;
      final eyeDx = r * 0.42;
      final stroke = Paint()
        ..color = eyeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (final dir in [-1.0, 1.0]) {
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(cx + dir * eyeDx, eyeY),
            width: r * 0.34,
            height: r * 0.22,
          ),
          0.15 * math.pi,
          0.7 * math.pi,
          false,
          stroke,
        );
      }
      // zzz particles.
      final zzPaint = TextPainter(
        text: TextSpan(
          text: 'z',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: eyeColor.withOpacity(0.6),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final zFloat = -particles * 6;
      zzPaint.paint(
        canvas,
        Offset(cx + r * 1.1, cy - r * 0.8 + zFloat),
      );
      zzPaint.paint(
        canvas,
        Offset(cx + r * 1.45, cy - r * 1.2 + zFloat),
      );
    }
  }

  @override
  bool shouldRepaint(_CgmPetPainter oldDelegate) =>
      oldDelegate.mood != mood ||
      oldDelegate.particles != particles ||
      oldDelegate.bodyColor != bodyColor;
}