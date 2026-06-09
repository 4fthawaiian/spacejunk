import 'dart:math';
import 'package:flutter/material.dart';
import '../models/debris_data.dart';

/// 3D space debris painter with proper perspective projection.
class SpaceDebrisPainter extends CustomPainter {
  final List<DebrisParticle> particles;
  final double rotationX;
  final double rotationY;
  final double zoom;
  final double time;
  final bool showStars;

  SpaceDebrisPainter({
    required this.particles,
    required this.rotationX,
    required this.rotationY,
    required this.zoom,
    required this.time,
    this.showStars = true,
  });

  // Pre-allocated reusable values
  final List<double> _scratch3 = [0, 0, 0];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final cx = size.width / 2;
    final cy = size.height / 2;
    final baseScale = min(size.width, size.height) * 0.38;
    final scale = baseScale * zoom;

    // 1. Starfield background
    if (showStars) _drawStars(canvas, size);

    // 2. Orbital rings (behind everything)
    _drawOrbitalRings(canvas, cx, cy, scale);

    // 3. Debris particles
    _drawDebris(canvas, cx, cy, scale, size);

    // 4. Earth (on top, hides objects behind it)
    _drawEarth(canvas, cx, cy, scale);

    // 5. Station markers (on top of everything)
    _drawStations(canvas, cx, cy, scale, size);

    canvas.restore();
  }

  // ------------------------------------------------------------------
  // Starfield
  // ------------------------------------------------------------------
  void _drawStars(Canvas canvas, Size size) {
    final rng = Random(12345);
    final twinkle = sin(time * 0.7) * 0.15;

    for (int i = 0; i < 300; i++) {
      final rx = rng.nextDouble() * size.width;
      final ry = rng.nextDouble() * size.height;
      final brightness = 0.15 + rng.nextDouble() * 0.7;
      final twinkleOffset = sin(time * (1.0 + rng.nextDouble() * 2.0) + rng.nextDouble() * 6.28) * 0.12;
      final opacity = (brightness + twinkle * twinkleOffset).clamp(0.05, 0.9);

      canvas.drawCircle(
        Offset(rx, ry),
        0.3 + rng.nextDouble() * 1.0,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }
  }

  // ------------------------------------------------------------------
  // Earth
  // ------------------------------------------------------------------
  void _drawEarth(Canvas canvas, double cx, double cy, double scale) {
    final r = 0.53 * scale;

    // Outer glow
    canvas.drawCircle(
      Offset(cx, cy),
      r * 2.8,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF4FC3F7).withValues(alpha: 0.08),
            const Color(0xFF4FC3F7).withValues(alpha: 0.02),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 2.8)),
    );

    // Planet body — ocean gradient
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..shader = RadialGradient(
          colors: const [
            Color(0xFF1a6b4a),
            Color(0xFF0d4a6a),
            Color(0xFF071a2e),
          ],
          stops: const [0.2, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
    );

    // Continent blobs (slightly animated rotation via time)
    final angleOffset = time * 0.1;
    final continentPaint = Paint()
      ..color = const Color(0xFF2d7a3a).withValues(alpha: 0.25);
    final continentPaint2 = Paint()
      ..color = const Color(0xFF3a8a4a).withValues(alpha: 0.12);

    // Simplified continent shapes — rotated slightly with time
    final continents = [
      // North America
      _Continent(angle: 0.0 + angleOffset, dist: 0.35, dx: -0.15, dy: -0.10, w: 0.30, h: 0.22),
      // South America
      _Continent(angle: 0.1 + angleOffset, dist: 0.30, dx: 0.10, dy: 0.20, w: 0.15, h: 0.30),
      // Europe/Africa
      _Continent(angle: 1.8 + angleOffset, dist: 0.25, dx: -0.05, dy: -0.05, w: 0.20, h: 0.45),
      // Asia
      _Continent(angle: 2.5 + angleOffset, dist: 0.35, dx: 0.10, dy: -0.20, w: 0.35, h: 0.25),
      // Australia
      _Continent(angle: 2.8 + angleOffset, dist: 0.38, dx: 0.20, dy: 0.30, w: 0.18, h: 0.12),
    ];

    for (final c in continents) {
      final cosA = cos(c.angle);
      final sinA = sin(c.angle);
      // Rotate the continent position around the globe
      final xo = (c.dx * cosA - c.dy * sinA) * r;
      final yo = (c.dx * sinA + c.dy * cosA) * r;

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + xo, cy + yo),
          width: c.w * r,
          height: c.h * r,
        ),
        (c.w > 0.25) ? continentPaint : continentPaint2,
      );
    }

    // Atmosphere rim
    canvas.drawCircle(
      Offset(cx, cy),
      r * 1.015,
      Paint()
        ..color = const Color(0xFF4FC3F7).withValues(alpha: 0.06 + sin(time * 0.5) * 0.02)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Specular highlight (sun reflection)
    canvas.drawCircle(
      Offset(cx - r * 0.3, cy - r * 0.3),
      r * 0.4,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.04),
            Colors.transparent,
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(
          center: Offset(cx - r * 0.3, cy - r * 0.3),
          radius: r * 0.4,
        )),
    );
  }

  // ------------------------------------------------------------------
  // 3D rotation (X then Y)
  // ------------------------------------------------------------------
  void _rotate3(double x, double y, double z, List<double> out) {
    final cosX = cos(rotationX);
    final sinX = sin(rotationX);
    final y1 = y * cosX - z * sinX;
    final z1 = y * sinX + z * cosX;

    final cosY = cos(rotationY);
    final sinY = sin(rotationY);
    out[0] = x * cosY + z1 * sinY;
    out[1] = y1;
    out[2] = -x * sinY + z1 * cosY;
  }

  // ------------------------------------------------------------------
  // Orbital rings
  // ------------------------------------------------------------------
  void _drawOrbitalRings(Canvas canvas, double cx, double cy, double scale) {
    final rings = [
      (alt: 400.0,  color: const Color(0x44FF6B35), width: 0.8),
      (alt: 20200.0, color: const Color(0x44F7C948), width: 0.7),
      (alt: 35786.0, color: const Color(0x444FC3F7), width: 0.7),
    ];

    for (final ring in rings) {
      final r = DebrisGenerator.altitudeToRadius(ring.alt);
      _drawRing(canvas, cx, cy, scale, r, ring.color, ring.width, 96);
    }

    // Inclined rings
    _drawRingInclined(canvas, cx, cy, scale, 800, 51.6, const Color(0x22FF6B35), 0.5, 64);
    _drawRingInclined(canvas, cx, cy, scale, 600, 97.5, const Color(0x22FF6B35), 0.5, 64);
  }

  void _drawRing(
    Canvas canvas, double cx, double cy, double scale,
    double r, Color color, double width, int segments,
  ) {
    final path = Path();
    for (int i = 0; i <= segments; i++) {
      final theta = (i / segments) * 2.0 * pi;
      _rotate3(r * cos(theta), 0.0, r * sin(theta), _scratch3);
      final sx = cx + _scratch3[0] * scale;
      final sy = cy - _scratch3[1] * scale;
      if (i == 0) {
        path.moveTo(sx, sy);
      } else {
        path.lineTo(sx, sy);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  void _drawRingInclined(
    Canvas canvas, double cx, double cy, double scale,
    double altKm, double inclDeg, Color color, double width, int segments,
  ) {
    final r = DebrisGenerator.altitudeToRadius(altKm);
    final incl = inclDeg * pi / 180.0;
    final path = Path();

    for (int i = 0; i <= segments; i++) {
      final theta = (i / segments) * 2.0 * pi;
      final x = r * cos(theta);
      final y = r * sin(theta) * sin(incl);
      final z = r * sin(theta) * cos(incl);
      _rotate3(x, y, z, _scratch3);
      final sx = cx + _scratch3[0] * scale;
      final sy = cy - _scratch3[1] * scale;
      if (i == 0) {
        path.moveTo(sx, sy);
      } else {
        path.lineTo(sx, sy);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  // ------------------------------------------------------------------
  // Debris rendering
  // ------------------------------------------------------------------
  void _drawDebris(Canvas canvas, double cx, double cy, double scale, Size canvasSize) {
    final count = particles.length;
    if (count == 0) return;

    // Project all particles (stations drawn separately, on top)
    final List<_Projected> projected = [];
    for (int i = 0; i < count; i++) {
      final p = particles[i];
      if (p.shell == 'Station') continue;
      _rotate3(p.x, p.y, p.z, _scratch3);
      projected.add(_Projected(
        sx: cx + _scratch3[0] * scale,
        sy: cy - _scratch3[1] * scale,
        sz: _scratch3[2],
        color: p.color,
        size: p.size,
        altitude: p.altitude,
        shell: p.shell,
      ));
    }

    // Sort by depth (far to near) — painter's algorithm
    projected.sort((a, b) => a.sz.compareTo(b.sz));

    // Clip debris to avoid drawing way off screen
    final bounds = Rect.fromLTWH(-50, -50, canvasSize.width + 100, canvasSize.height + 100);

    final paint = Paint();
    for (final pp in projected) {
      if (!bounds.contains(Offset(pp.sx, pp.sy))) continue;

      // Depth factor: 0 (far) → 1 (near)
      final depthFactor = ((pp.sz + 2.0) / 3.5).clamp(0.0, 1.0);
      final baseOpacity = 0.25 + 0.7 * depthFactor;

      final color = Color(pp.color);
      paint.color = color.withValues(alpha: baseOpacity * 0.9);

      // Size attenuation with depth
      final sizeFactor = 2.0 / (2.0 + pp.sz * 0.5);
      final drawSize = (pp.size * sizeFactor * (0.8 + 0.2 * sin(time * 2.0 + pp.sz * 10.0))).clamp(0.3, 3.5);

      canvas.drawCircle(Offset(pp.sx, pp.sy), drawSize, paint);

      // Glow for nearby/bright objects
      if (drawSize > 1.2 && pp.sz > -0.5) {
        paint.color = color.withValues(alpha: baseOpacity * 0.15);
        canvas.drawCircle(Offset(pp.sx, pp.sy), drawSize * 2.5, paint);
      }
    }
  }

  // ------------------------------------------------------------------
  // Stations — drawn on top of Earth so they always pop
  // ------------------------------------------------------------------
  void _drawStations(Canvas canvas, double cx, double cy, double scale, Size canvasSize) {
    final paint = Paint();
    final bounds = Rect.fromLTWH(-50, -50, canvasSize.width + 100, canvasSize.height + 100);
    const gold = Color(0xFFFFD740);

    for (final p in particles) {
      if (p.shell != 'Station') continue;

      _rotate3(p.x, p.y, p.z, _scratch3);
      final sx = cx + _scratch3[0] * scale;
      final sy = cy - _scratch3[1] * scale;
      final sz = _scratch3[2];
      if (!bounds.contains(Offset(sx, sy))) continue;

      final depthFactor = ((sz + 2.0) / 3.5).clamp(0.0, 1.0);
      final opacity = (0.7 + 0.3 * depthFactor).clamp(0.0, 1.0);

      // ---- White outer glow ----
      paint.color = Colors.white.withValues(alpha: opacity * 0.06);
      canvas.drawCircle(Offset(sx, sy), 24.0, paint);

      // ---- Gold glow ----
      paint.color = gold.withValues(alpha: opacity * 0.15);
      canvas.drawCircle(Offset(sx, sy), 16.0, paint);

      // ---- Outer ring (stroke) ----
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 1.8;
      paint.color = gold.withValues(alpha: opacity * 0.6);
      canvas.drawCircle(Offset(sx, sy), 10.0, paint);
      paint.style = PaintingStyle.fill;

      // ---- Crosshair ----
      paint.strokeWidth = 1.5;
      paint.color = gold.withValues(alpha: opacity * 0.5);
      final ch = 14.0;
      canvas.drawLine(Offset(sx - ch, sy), Offset(sx + ch, sy), paint);
      canvas.drawLine(Offset(sx, sy - ch), Offset(sx, sy + ch), paint);

      // ---- Gold core dot ----
      paint.strokeWidth = 1.0;
      paint.color = gold.withValues(alpha: opacity);
      canvas.drawCircle(Offset(sx, sy), 5.0, paint);

      // ---- White center ----
      paint.color = Colors.white.withValues(alpha: opacity * 0.9);
      canvas.drawCircle(Offset(sx, sy), 2.5, paint);
    }
  }

  @override
  bool shouldRepaint(SpaceDebrisPainter old) =>
      old.rotationX != rotationX ||
      old.rotationY != rotationY ||
      old.zoom != zoom ||
      old.time != time ||
      old.showStars != showStars;
}

// ------------------------------------------------------------------
// Helper classes
// ------------------------------------------------------------------
class _Projected {
  final double sx, sy, sz;
  final int color;
  final double size;
  final double altitude;
  final String shell;
  _Projected({
    required this.sx,
    required this.sy,
    required this.sz,
    required this.color,
    required this.size,
    required this.altitude,
    required this.shell,
  });
}

class _Continent {
  final double angle;
  final double dist;
  final double dx, dy;
  final double w, h;
  _Continent({
    required this.angle,
    required this.dist,
    required this.dx,
    required this.dy,
    required this.w,
    required this.h,
  });
}
