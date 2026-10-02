import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/character/player_profile.dart';

/// Palettes for the procedurally drawn avatar. Indices are stored in saves.
class AvatarPalette {
  const AvatarPalette._();

  static const skin = [
    Color(0xFFF3CFAE), Color(0xFFE2B08A), Color(0xFFC98E66),
    Color(0xFFA9714D), Color(0xFF8A5638), Color(0xFF6A3F27),
  ];
  static const hair = [
    Color(0xFF1C1818), Color(0xFF3B2A20), Color(0xFF6A4630), Color(0xFFA0A0A0), Color(0xFF6D1F3A),
  ];
  static const outfit = [
    Color(0xFF4B3FB5), Color(0xFFF2A33A), Color(0xFF1E9E8F),
    Color(0xFFD9546E), Color(0xFF6F7D3B), Color(0xFF3A3A48),
  ];
  static const hairStyles = ['Short', 'Side part', 'Long', 'Bun', 'Curly'];
  static const expressions = ['Smile', 'Calm', 'Determined'];
  static const accessories = ['None', 'Glasses', 'Earrings', 'Cap'];
}

class AvatarView extends StatelessWidget {
  const AvatarView({super.key, required this.appearance, this.size = 96, this.background});

  final Appearance appearance;
  final double size;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Player avatar',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: AvatarPainter(appearance, background ?? Theme.of(context).colorScheme.primaryContainer),
        ),
      ),
    );
  }
}

class AvatarPainter extends CustomPainter {
  AvatarPainter(this.a, this.bg);

  final Appearance a;
  final Color bg;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.save();
    canvas.scale(s);
    final skin = AvatarPalette.skin[a.skinTone % AvatarPalette.skin.length];
    final hair = AvatarPalette.hair[a.hairColor % AvatarPalette.hair.length];
    final outfit = AvatarPalette.outfit[a.outfit % AvatarPalette.outfit.length];
    final p = Paint()..isAntiAlias = true;

    // Background disc.
    canvas.drawCircle(const Offset(50, 50), 50, p..color = bg);
    canvas.clipPath(Path()..addOval(const Rect.fromLTWH(0, 0, 100, 100)));

    // Long hair behind the shoulders.
    if (a.hairStyle == 2) {
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(26, 30, 48, 52), const Radius.circular(20)),
          p..color = hair);
    }

    // Shoulders and outfit.
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(16, 76, 68, 40), const Radius.circular(26)),
        p..color = outfit);
    canvas.drawPath(Path()..moveTo(42, 76)..lineTo(50, 86)..lineTo(58, 76)..close(), p..color = skin);

    // Neck and head.
    canvas.drawRect(const Rect.fromLTWH(44, 62, 12, 16), p..color = skin);
    canvas.drawOval(const Rect.fromLTWH(30, 24, 40, 46), p..color = skin);
    canvas.drawCircle(const Offset(30.5, 49), 4, p..color = skin);
    canvas.drawCircle(const Offset(69.5, 49), 4, p..color = skin);

    _hair(canvas, p..color = hair);

    // Eyes and brows.
    final ink = Paint()..color = const Color(0xFF231A1A);
    final eyeY = 47.0;
    canvas.drawCircle(Offset(42, eyeY), 2.4, ink);
    canvas.drawCircle(Offset(58, eyeY), 2.4, ink);
    final brow = Paint()
      ..color = hair
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final tilt = a.expression == 2 ? 2.0 : 0.0;
    canvas.drawLine(Offset(38, 41 - tilt), Offset(45, 41 + tilt / 2), brow);
    canvas.drawLine(Offset(55, 41 + tilt / 2), Offset(62, 41 - tilt), brow);

    // Mouth.
    final mouth = Paint()
      ..color = const Color(0xFF8E3B3B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    switch (a.expression) {
      case 0:
        canvas.drawArc(const Rect.fromLTWH(43, 52, 14, 9), 0.2, math.pi - 0.4, false, mouth);
      case 1:
        canvas.drawLine(const Offset(45, 58), const Offset(55, 58), mouth);
      default:
        canvas.drawArc(const Rect.fromLTWH(44, 56, 12, 5), 0.1, math.pi - 0.2, false, mouth);
    }

    _accessory(canvas, hair);
    canvas.restore();
  }

  void _hair(Canvas canvas, Paint p) {
    switch (a.hairStyle) {
      case 0: // short
        canvas.drawPath(
            Path()
              ..moveTo(29, 44)
              ..quadraticBezierTo(28, 20, 50, 20)
              ..quadraticBezierTo(72, 20, 71, 44)
              ..quadraticBezierTo(66, 30, 50, 31)
              ..quadraticBezierTo(34, 30, 29, 44),
            p);
      case 1: // side part
        canvas.drawPath(
            Path()
              ..moveTo(29, 46)
              ..quadraticBezierTo(27, 19, 52, 20)
              ..quadraticBezierTo(73, 22, 71, 46)
              ..quadraticBezierTo(70, 32, 58, 30)
              ..quadraticBezierTo(42, 36, 29, 46),
            p);
      case 2: // long
        canvas.drawPath(
            Path()
              ..moveTo(28, 50)
              ..quadraticBezierTo(26, 19, 50, 19)
              ..quadraticBezierTo(74, 19, 72, 50)
              ..quadraticBezierTo(66, 31, 50, 32)
              ..quadraticBezierTo(34, 31, 28, 50),
            p);
      case 3: // bun
        canvas.drawCircle(const Offset(50, 17), 8, p);
        canvas.drawPath(
            Path()
              ..moveTo(29, 44)
              ..quadraticBezierTo(29, 21, 50, 21)
              ..quadraticBezierTo(71, 21, 71, 44)
              ..quadraticBezierTo(64, 29, 50, 30)
              ..quadraticBezierTo(36, 29, 29, 44),
            p);
      default: // curly
        for (final (x, y) in [(33.0, 30.0), (41.0, 23.0), (50.0, 21.0), (59.0, 23.0), (67.0, 30.0), (30.0, 39.0), (70.0, 39.0)]) {
          canvas.drawCircle(Offset(x, y), 7.5, p);
        }
    }
  }

  void _accessory(Canvas canvas, Color hair) {
    final stroke = Paint()
      ..color = const Color(0xFF2B2B33)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    switch (a.accessory) {
      case 1:
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(36, 43, 12, 9), const Radius.circular(3)), stroke);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(52, 43, 12, 9), const Radius.circular(3)), stroke);
        canvas.drawLine(const Offset(48, 47), const Offset(52, 47), stroke);
      case 2:
        final gold = Paint()..color = const Color(0xFFE8B931);
        canvas.drawCircle(const Offset(30.5, 54), 2.2, gold);
        canvas.drawCircle(const Offset(69.5, 54), 2.2, gold);
      case 3:
        final cap = Paint()..color = AvatarPalette.outfit[(a.outfit + 2) % AvatarPalette.outfit.length];
        canvas.drawArc(const Rect.fromLTWH(28, 16, 44, 30), math.pi, math.pi, true, cap);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(46, 28, 32, 5), const Radius.circular(3)), cap);
    }
  }

  @override
  bool shouldRepaint(AvatarPainter old) => old.a != a || old.bg != bg;
}
