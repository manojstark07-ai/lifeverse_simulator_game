import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart'
    show Canvas, Color, Offset, Paint, Path, Rect;

class WorldSpot {
  const WorldSpot({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
  });

  final String id;
  final String kind;
  final double x;
  final double y;
}

class WorldNpc {
  const WorldNpc({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.color,
  });

  final String id;
  final String name;
  final double x;
  final double y;
  final Color color;
}

/// A small direct-control city layer. Narrative and finance remain in the
/// engine; this mode is deliberately a physical way to enter the same places.
class LifeWorldGame extends FlameGame {
  LifeWorldGame({
    required this.spots,
    required this.npcs,
    required this.onInteract,
    required this.onNpcInteract,
    required this.reducedMotion,
  });

  final List<WorldSpot> spots;
  final List<WorldNpc> npcs;
  final void Function(String spotId) onInteract;
  final void Function(String npcId) onNpcInteract;
  final bool reducedMotion;
  final List<_WorldSpot> _spots = [];
  final List<_WorldNpc> _npcs = [];
  late final _WorldPlayer _player = _WorldPlayer(this);

  @override
  Color backgroundColor() => const Color(0xFF101A22);

  @override
  Future<void> onLoad() async {
    add(_WorldBackdrop(this));
    for (final spot in spots) {
      final component = _WorldSpot(this, spot);
      _spots.add(component);
      add(component);
    }
    for (final npc in npcs) {
      final component = _WorldNpc(this, npc);
      _npcs.add(component);
      add(component);
    }
    add(_player);
    _player.position = Vector2(size.x * 0.5, size.y * 0.58);
    _layout();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) _layout();
  }

  void _layout() {
    for (final spot in _spots) spot.relayout();
    for (final npc in _npcs) npc.relayout();
    _player.position.x = _player.position.x.clamp(
      28,
      math.max(28, size.x - 28),
    );
    _player.position.y = _player.position.y.clamp(
      70,
      math.max(70, size.y - 40),
    );
  }

  void nudge(Vector2 direction) {
    if (!isLoaded) return;
    final step = direction.normalized() * 54;
    final target = Vector2(
      (_player.position.x + step.x).clamp(28, math.max(28, size.x - 28)),
      (_player.position.y + step.y).clamp(70, math.max(70, size.y - 40)),
    );
    if (!_blocked(target)) _player.target = target;
  }

  bool _blocked(Vector2 point) => _spots.any(
    (spot) => spot.worldBounds.inflate(8).contains(Offset(point.x, point.y)),
  );

  String? get nearestSpot {
    if (_spots.isEmpty) return null;
    _WorldSpot? nearest;
    var distance = double.infinity;
    for (final spot in _spots) {
      final d = _player.position.distanceTo(spot.position);
      if (d < distance) {
        distance = d;
        nearest = spot;
      }
    }
    return distance <= 84 ? nearest?.data.id : null;
  }

  String? get nearestNpc {
    _WorldNpc? nearest;
    var distance = double.infinity;
    for (final npc in _npcs) {
      final d = _player.position.distanceTo(npc.position);
      if (d < distance) {
        distance = d;
        nearest = npc;
      }
    }
    return distance <= 74 ? nearest?.data.id : null;
  }

  void interact() {
    final npc = nearestNpc;
    if (npc != null) {
      onNpcInteract(npc);
      return;
    }
    final id = nearestSpot;
    if (id != null) onInteract(id);
  }
}

class _WorldBackdrop extends Component {
  _WorldBackdrop(this.game);

  final LifeWorldGame game;

  @override
  void render(Canvas canvas) {
    final p = Paint()..color = const Color(0xFF172631);
    canvas.drawRect(Rect.fromLTWH(0, 0, game.size.x, game.size.y), p);
    p.color = const Color(0xFF203B38);
    canvas.drawRect(
      Rect.fromLTWH(0, game.size.y * 0.58, game.size.x, game.size.y * 0.42),
      p,
    );
    p.color = const Color(0xFF33464D);
    canvas.drawRect(Rect.fromLTWH(0, game.size.y * 0.42, game.size.x, 36), p);
    canvas.drawRect(Rect.fromLTWH(game.size.x * 0.47, 0, 36, game.size.y), p);
  }
}

class _WorldSpot extends PositionComponent {
  _WorldSpot(this.game, this.data) : super(anchor: Anchor.center);

  final LifeWorldGame game;
  final WorldSpot data;

  static const _colors = {
    'house': Color(0xFFE38B68),
    'campus': Color(0xFF5B6CE0),
    'bank': Color(0xFF1E9E8F),
    'hospital': Color(0xFFBCE5E5),
    'office': Color(0xFF4D82B8),
    'gym': Color(0xFF2E9AC0),
    'park': Color(0xFF55B86C),
    'cafe': Color(0xFFE8A142),
    'mall': Color(0xFF8A63D2),
  };

  void relayout() {
    size = Vector2(82, 66);
    position = Vector2(game.size.x * data.x, game.size.y * data.y);
  }

  Rect get worldBounds => Rect.fromCenter(
    center: Offset(position.x, position.y),
    width: size.x,
    height: size.y,
  );

  @override
  void render(Canvas canvas) {
    final color = _colors[data.kind] ?? const Color(0xFF7E8B92);
    final p = Paint()..color = color;
    canvas.drawRect(
      Rect.fromLTWH(-size.x / 2, -size.y / 2 + 12, size.x, size.y - 12),
      p,
    );
    final roof = Path()
      ..moveTo(-size.x / 2 - 6, -size.y / 2 + 12)
      ..lineTo(0, -size.y / 2 - 10)
      ..lineTo(size.x / 2 + 6, -size.y / 2 + 12)
      ..close();
    canvas.drawPath(roof, Paint()..color = color.withValues(alpha: 0.78));
    canvas.drawRect(
      Rect.fromLTWH(-8, 10, 16, 20),
      Paint()..color = const Color(0xCCF7E6B5),
    );
  }
}

class _WorldNpc extends PositionComponent {
  _WorldNpc(this.game, this.data)
    : super(size: Vector2.all(26), anchor: Anchor.center);

  final LifeWorldGame game;
  final WorldNpc data;
  double _time = 0;
  Vector2? _target;

  void relayout() {
    position = Vector2(game.size.x * data.x, game.size.y * data.y);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.reducedMotion) return;
    _time += dt;
    if (_target == null && _time > 2.5) {
      _time = 0;
      _target =
          position +
          Vector2(
            math.sin(position.x + _time) * 18,
            math.cos(position.y + _time) * 12,
          );
    }
    final target = _target;
    if (target == null) return;
    final delta = target - position;
    if (delta.length < 2) {
      _target = null;
    } else {
      position += delta.normalized() * math.min(delta.length, dt * 24);
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      10,
      Paint()..color = data.color,
    );
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2 - 8),
      6,
      Paint()..color = const Color(0xFFF1B27C),
    );
    canvas.drawCircle(
      Offset(size.x / 2 - 2, size.y / 2 - 9),
      1,
      Paint()..color = const Color(0xFF17212A),
    );
    canvas.drawCircle(
      Offset(size.x / 2 + 2, size.y / 2 - 9),
      1,
      Paint()..color = const Color(0xFF17212A),
    );
  }
}

class _WorldPlayer extends PositionComponent {
  _WorldPlayer(this.game) : super(size: Vector2.all(30), anchor: Anchor.center);

  final LifeWorldGame game;
  Vector2? target;

  @override
  void update(double dt) {
    super.update(dt);
    final destination = target;
    if (destination == null) return;
    final delta = destination - position;
    if (delta.length < 2 || game.reducedMotion) {
      position = destination;
      target = null;
      return;
    }
    position += delta.normalized() * math.min(delta.length, dt * 180);
  }

  @override
  void render(Canvas canvas) {
    final p = Paint()..color = const Color(0xFFFFD166);
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), 12, p);
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2 - 10),
      8,
      Paint()..color = const Color(0xFFF3A35A),
    );
    canvas.drawCircle(
      Offset(size.x / 2 - 3, size.y / 2 - 11),
      1.5,
      Paint()..color = const Color(0xFF17212A),
    );
    canvas.drawCircle(
      Offset(size.x / 2 + 3, size.y / 2 - 11),
      1.5,
      Paint()..color = const Color(0xFF17212A),
    );
  }
}
