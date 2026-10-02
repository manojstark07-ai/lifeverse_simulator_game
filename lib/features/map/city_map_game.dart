import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' show Colors, TextStyle, FontWeight;

class MapPalette {
  const MapPalette({
    required this.background,
    required this.groundA,
    required this.groundB,
    required this.label,
    required this.labelBackground,
  });

  final Color background;
  final Color groundA;
  final Color groundB;
  final Color label;
  final Color labelBackground;
}

class MapSite {
  const MapSite({
    required this.id,
    required this.name,
    required this.kind,
    required this.gx,
    required this.gy,
  });

  final String id;
  final String name;
  final String kind;
  final int gx;
  final int gy;
}

/// A small isometric city rendered with Flame. Locations are tappable
/// buildings; everything else (menus, actions) stays in Flutter.
class CityMapGame extends FlameGame {
  CityMapGame({
    required this.sites,
    required this.palette,
    required this.onSiteTapped,
    required this.reducedMotion,
    this.gridSize = 5,
  });

  final List<MapSite> sites;
  final MapPalette palette;
  final void Function(String siteId) onSiteTapped;
  final bool reducedMotion;
  final int gridSize;

  final List<_Building> _buildings = [];
  late final _Ground _ground = _Ground(this);
  late final _Marker _marker = _Marker(reducedMotion);
  String markerAt = 'home';

  double tileW = 80;
  double get tileH => tileW / 2;
  Vector2 origin = Vector2.zero();

  @override
  Color backgroundColor() => palette.background;

  @override
  Future<void> onLoad() async {
    add(_ground);
    final ordered = [...sites]
      ..sort((a, b) => (a.gx + a.gy).compareTo(b.gx + b.gy));
    for (final s in ordered) {
      final b = _Building(this, s);
      _buildings.add(b);
      add(b);
    }
    add(_marker);
    add(_Labels(this));
    _layout();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) _layout();
  }

  Vector2 tileCenter(int gx, int gy) => Vector2(
    origin.x + (gx - gy) * tileW / 2,
    origin.y + (gx + gy) * tileH / 2,
  );

  void _layout() {
    // Fit the diamond grid plus the tallest building and a label row.
    tileW = math.min(
      size.x / (gridSize + 0.3),
      size.y / (gridSize * 0.5 + 1.6),
    );
    final gridHeight = gridSize * tileH;
    origin = Vector2(
      size.x / 2,
      (size.y - gridHeight) / 2 + tileH * 0.5 + tileW * 0.45,
    );
    for (final b in _buildings) {
      b.relayout();
    }
    moveMarker(markerAt);
  }

  void moveMarker(String siteId) {
    markerAt = siteId;
    final site = sites.where((s) => s.id == siteId).firstOrNull;
    if (site == null) return;
    final c = tileCenter(site.gx, site.gy);
    _marker.anchorPoint = c + Vector2(tileW * 0.32, -tileH * 0.1);
  }
}

class _Ground extends Component {
  _Ground(this.game);

  final CityMapGame game;

  @override
  void render(Canvas canvas) {
    final paint = Paint();
    for (var gx = 0; gx < game.gridSize; gx++) {
      for (var gy = 0; gy < game.gridSize; gy++) {
        final c = game.tileCenter(gx, gy);
        final w = game.tileW / 2;
        final h = game.tileH / 2;
        paint.color = (gx + gy).isEven
            ? game.palette.groundA
            : game.palette.groundB;
        canvas.drawPath(
          Path()
            ..moveTo(c.x, c.y - h)
            ..lineTo(c.x + w, c.y)
            ..lineTo(c.x, c.y + h)
            ..lineTo(c.x - w, c.y)
            ..close(),
          paint,
        );
      }
    }
  }
}

class _Building extends PositionComponent with TapCallbacks {
  _Building(this.game, this.site);

  final CityMapGame game;
  final MapSite site;

  static const _colors = {
    'house': Color(0xFFE07A5F),
    'library': Color(0xFF9C6B4E),
    'campus': Color(0xFF5B6CE0),
    'cafe': Color(0xFFF2A33A),
    'park': Color(0xFF4CAF6A),
    'bank': Color(0xFF1E9E8F),
    'hall': Color(0xFF8C5BD6),
    'office': Color(0xFF3F7CC4),
    'hospital': Color(0xFFECEFF4),
    'bar': Color(0xFFB0306A),
    'mall': Color(0xFF7B4FD6),
    'salon': Color(0xFFE5719B),
    'gym': Color(0xFF2E8BC0),
    'showroom': Color(0xFF5E6B7A),
    'casino': Color(0xFFC9A227),
    'alley': Color(0xFF4A4458),
    'coaching': Color(0xFF2FA37A),
    'police': Color(0xFF2B4C8C),
    'cyber': Color(0xFF222831),
    'clinic': Color(0xFF7D1F3F),
  };
  static const _heights = {
    'house': 0.45,
    'library': 0.55,
    'campus': 0.85,
    'cafe': 0.35,
    'park': 0.0,
    'bank': 0.6,
    'hall': 0.5,
    'office': 1.0,
    'hospital': 0.7,
    'bar': 0.4,
    'mall': 0.75,
    'salon': 0.35,
    'gym': 0.45,
    'showroom': 0.4,
    'casino': 0.65,
    'alley': 0.3,
    'coaching': 0.6,
    'police': 0.55,
    'cyber': 0.8,
    'clinic': 0.5,
  };

  double get _bh => game.tileW * (_heights[site.kind] ?? 0.5);

  void relayout() {
    final c = game.tileCenter(site.gx, site.gy);
    size = Vector2(game.tileW, _bh + game.tileH);
    position = Vector2(c.x - game.tileW / 2, c.y - game.tileH / 2 - _bh);
  }

  @override
  void onTapUp(TapUpEvent event) {
    game.moveMarker(site.id);
    game.onSiteTapped(site.id);
  }

  @override
  void render(Canvas canvas) {
    final base = _colors[site.kind] ?? const Color(0xFF888888);
    final g = Offset(size.x / 2, _bh + game.tileH / 2);
    final fw = game.tileW * 0.36;
    final fh = fw / 2;
    final p = Paint();
    if (site.kind == 'park') {
      for (final (dx, dy, r) in [
        (-0.18, -0.05, 0.14),
        (0.12, -0.12, 0.12),
        (0.05, 0.08, 0.16),
      ]) {
        final center = g + Offset(dx * game.tileW, dy * game.tileW);
        canvas.drawRect(
          Rect.fromCenter(
            center: center + Offset(0, r * game.tileW * 0.6),
            width: 4,
            height: r * game.tileW,
          ),
          p..color = const Color(0xFF7A5230),
        );
        canvas.drawCircle(center, r * game.tileW * 0.7, p..color = base);
      }
    } else {
      final bh = _bh;
      final left = Path()
        ..moveTo(g.dx - fw, g.dy)
        ..lineTo(g.dx, g.dy + fh)
        ..lineTo(g.dx, g.dy + fh - bh)
        ..lineTo(g.dx - fw, g.dy - bh)
        ..close();
      final right = Path()
        ..moveTo(g.dx + fw, g.dy)
        ..lineTo(g.dx, g.dy + fh)
        ..lineTo(g.dx, g.dy + fh - bh)
        ..lineTo(g.dx + fw, g.dy - bh)
        ..close();
      final top = Path()
        ..moveTo(g.dx, g.dy - bh - fh)
        ..lineTo(g.dx + fw, g.dy - bh)
        ..lineTo(g.dx, g.dy - bh + fh)
        ..lineTo(g.dx - fw, g.dy - bh)
        ..close();
      canvas.drawPath(left, p..color = _shade(base, 0.78));
      canvas.drawPath(right, p..color = _shade(base, 0.62));
      canvas.drawPath(top, p..color = _shade(base, 1.1));
      // Windows.
      final win = Paint()
        ..color = const Color(0xFFFFF3C4).withValues(alpha: 0.85);
      final rows = math.max(1, (bh / (game.tileW * 0.22)).floor());
      for (var r = 0; r < rows; r++) {
        final y = g.dy - bh + (r + 0.6) * bh / (rows + 0.4);
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(g.dx - fw * 0.5, y + fh * 0.3),
            width: fw * 0.22,
            height: fw * 0.22,
          ),
          win,
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(g.dx + fw * 0.5, y + fh * 0.3),
            width: fw * 0.22,
            height: fw * 0.22,
          ),
          win,
        );
      }
      if (site.kind == 'hospital') {
        final cross = Paint()..color = const Color(0xFFD9546E);
        final tc = Offset(g.dx, g.dy - bh);
        canvas.drawRect(
          Rect.fromCenter(center: tc, width: fw * 0.5, height: fh * 0.35),
          cross,
        );
        canvas.drawRect(
          Rect.fromCenter(center: tc, width: fw * 0.18, height: fh * 0.9),
          cross,
        );
      }
    }
  }

  static Color _shade(Color c, double f) => Color.from(
    alpha: c.a,
    red: (c.r * f).clamp(0, 1).toDouble(),
    green: (c.g * f).clamp(0, 1).toDouble(),
    blue: (c.b * f).clamp(0, 1).toDouble(),
  );
}

/// Site names, drawn after every building so no label is ever hidden.
class _Labels extends Component {
  _Labels(this.game);

  final CityMapGame game;

  @override
  void render(Canvas canvas) {
    final fontSize = math.max(10.0, math.min(13.0, game.tileW * 0.16));
    final paint = TextPaint(
      style: TextStyle(
        color: game.palette.label,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
      ),
    );
    final bg = Paint()..color = game.palette.labelBackground;
    for (final s in game.sites) {
      final c = game.tileCenter(s.gx, s.gy);
      final w = paint.getLineMetrics(s.name).width;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(c.x, c.y + game.tileH * 0.42),
          width: w + 10,
          height: fontSize + 6,
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, bg);
      paint.render(
        canvas,
        s.name,
        Vector2(c.x, c.y + game.tileH * 0.42),
        anchor: Anchor.center,
      );
    }
  }
}

/// The player's position marker; gently bobs unless reduced motion is on.
class _Marker extends Component {
  _Marker(this.reducedMotion);

  final bool reducedMotion;
  Vector2 anchorPoint = Vector2.zero();
  double _t = 0;

  @override
  void update(double dt) {
    if (!reducedMotion) _t += dt;
  }

  @override
  void render(Canvas canvas) {
    final bob = reducedMotion ? 0.0 : math.sin(_t * 3) * 3;
    final c = Offset(anchorPoint.x, anchorPoint.y - 18 + bob);
    canvas.drawCircle(
      Offset(anchorPoint.x, anchorPoint.y),
      5,
      Paint()..color = Colors.black.withValues(alpha: 0.2),
    );
    canvas.drawCircle(c, 9, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawCircle(c, 6.5, Paint()..color = const Color(0xFF4B3FB5));
  }
}
