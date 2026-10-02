import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart' show Canvas, Color, Offset, Paint, Rect;

class InteriorGame extends FlameGame {
  InteriorGame({required this.kind, required this.reducedMotion});

  final String kind;
  final bool reducedMotion;
  double _time = 0;

  @override
  Color backgroundColor() => const Color(0xFF10151B);

  @override
  void update(double dt) {
    super.update(dt);
    if (!reducedMotion) _time += dt;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final w = size.x;
    final h = size.y;
    final wall = Paint()..color = const Color(0xFF35424C);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), wall);
    canvas.drawRect(
      Rect.fromLTWH(22, 24, w - 44, h - 48),
      Paint()..color = _floorColor,
    );
    canvas.drawRect(
      Rect.fromLTWH(22, 24, w - 44, 12),
      Paint()..color = const Color(0xFF9A6C4A),
    );
    canvas.drawRect(
      Rect.fromLTWH(22, h - 36, w - 44, 12),
      Paint()..color = const Color(0xFF9A6C4A),
    );
    _drawFurniture(canvas, w, h);
    final pulse = reducedMotion ? 0.0 : math.sin(_time * 2.4) * 2;
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.62),
      17 + pulse,
      Paint()..color = const Color(0xFFFFD166),
    );
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.60),
      10,
      Paint()..color = const Color(0xFFF3A35A),
    );
  }

  Color get _floorColor => switch (kind) {
    'bank' => const Color(0xFF274B50),
    'hospital' => const Color(0xFFD8E5E4),
    'campus' || 'library' => const Color(0xFF4B5872),
    'gym' || 'boxing_gym' => const Color(0xFF3E4B56),
    'cafe' || 'bar' => const Color(0xFF59433A),
    _ => const Color(0xFF53635F),
  };

  void _drawFurniture(Canvas canvas, double w, double h) {
    final furniture = Paint()
      ..color = switch (kind) {
        'bank' => const Color(0xFFCD9A4A),
        'hospital' => const Color(0xFFEAF4F3),
        'gym' || 'boxing_gym' => const Color(0xFFC44536),
        'cafe' || 'bar' => const Color(0xFFB67648),
        _ => const Color(0xFF8CA3A0),
      };
    canvas.drawRect(Rect.fromLTWH(w * 0.13, h * 0.2, w * 0.28, 24), furniture);
    canvas.drawRect(Rect.fromLTWH(w * 0.59, h * 0.28, w * 0.22, 46), furniture);
    canvas.drawRect(Rect.fromLTWH(w * 0.18, h * 0.72, w * 0.6, 20), furniture);
    if (kind == 'gym' || kind == 'boxing_gym') {
      canvas.drawRect(
        Rect.fromLTWH(w * 0.1, h * 0.42, w * 0.8, 8),
        Paint()..color = const Color(0xFFE6A93D),
      );
    }
  }
}
