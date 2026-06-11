import 'dart:math';

import 'satcat_record.dart';

/// Represents a single piece of space debris with orbital parameters.
class DebrisParticle {
  final double x, y, z; // Cartesian position (scaled)
  final double altitude; // km
  final String shell; // 'LEO', 'MEO', 'GEO', 'Debris', 'Station'
  final int color; // ARGB color
  final double size; // visual size
  final String? name; // Real-world name (from CelesTrak) or null

  /// NORAD catalog ID, 0 for procedural particles.
  final int noradId;

  /// Rich SATCAT metadata, set when served from the self-hosted cache.
  final SatcatRecord? satcat;

  DebrisParticle({
    required this.x,
    required this.y,
    required this.z,
    required this.altitude,
    required this.shell,
    required this.color,
    required this.size,
    this.name,
    this.noradId = 0,
    this.satcat,
  });
}

/// Generates realistic space debris distribution.
class DebrisGenerator {
  static const double earthRadius = 6371.0; // km
  static const double scaleFactor = 1.0 / 12000.0; // scale to fit on canvas

  /// Convert altitude to model units (distance from center)
  static double altitudeToRadius(double altKm) {
    return (earthRadius + altKm) * scaleFactor;
  }

  /// Generate a population of debris particles.
  static List<DebrisParticle> generate() {
    final rng = Random(42); // fixed seed for reproducibility
    final particles = <DebrisParticle>[];

    // Shell definitions: [label, minAlt, maxAlt, count, color, baseSize]
    final shells = [
      _Shell('LEO', 200, 2000, 9000, 0xFFFF6B35, 0.8),
      _Shell('MEO', 2000, 35786, 2000, 0xFFF7C948, 1.0),
      _Shell('GEO', 35786, 42000, 800, 0xFF4FC3F7, 1.2),
      _Shell('Debris', 200, 40000, 4000, 0xFFEF5350, 0.6),
      _Shell('Station', 400, 420, 8, 0xFFFFD740, 2.0), // ISS + visiting vehicles
    ];

    for (final shell in shells) {
      for (int i = 0; i < shell.count; i++) {
        final alt = shell.minAlt + rng.nextDouble() * (shell.maxAlt - shell.minAlt);
        final r = altitudeToRadius(alt);

        // Inclination (degrees)
        double incl;
        if (shell.label == 'LEO') {
          // Two main populations: ISS-type (51.6°) and sun-sync (97-99°)
          incl = rng.nextDouble() < 0.5
              ? 50.0 + rng.nextDouble() * 20.0
              : 80.0 + rng.nextDouble() * 20.0;
        } else if (shell.label == 'GEO') {
          incl = rng.nextDouble() * 5.0; // near equatorial
        } else {
          incl = acos(2.0 * rng.nextDouble() - 1.0) * 180.0 / pi;
        }

        final raan = rng.nextDouble() * 2.0 * pi;
        final argLat = rng.nextDouble() * 2.0 * pi;
        final inclRad = incl * pi / 180.0;

        // Convert orbital elements to Cartesian (circular orbit approximation)
        final x = r * (cos(raan) * cos(argLat) - sin(raan) * sin(argLat) * cos(inclRad));
        final y = r * sin(argLat) * sin(inclRad);
        final z = r * (sin(raan) * cos(argLat) + cos(raan) * sin(argLat) * cos(inclRad));

        // Color variation
        final baseColor = shell.color;
        final rnd = (rng.nextDouble() - 0.5) * 30;
        final alpha = (baseColor >> 24) & 0xFF;
        final red = ((baseColor >> 16) & 0xFF) + rnd.toInt();
        final green = ((baseColor >> 8) & 0xFF) + rnd.toInt();
        final blue = (baseColor & 0xFF) + rnd.toInt();
        final color = (alpha << 24) |
            (red.clamp(0, 255) << 16) |
            (green.clamp(0, 255) << 8) |
            (blue.clamp(0, 255));

        final name = shell.label == 'Station'
            ? _stationNames[_stationIndex++ % _stationNames.length]
            : null;
        particles.add(DebrisParticle(
          x: x,
          y: y,
          z: z,
          altitude: alt,
          shell: shell.label,
          color: color,
          size: shell.baseSize * (0.6 + rng.nextDouble() * 0.8),
          name: name,
        ));
      }
    }

    return particles;
  }
}

class _Shell {
  final String label;
  final double minAlt;
  final double maxAlt;
  final int count;
  final int color;
  final double baseSize;
  _Shell(this.label, this.minAlt, this.maxAlt, this.count, this.color, this.baseSize);
}

/// Station names used for procedural station particles.
int _stationIndex = 0;
const _stationNames = [
  'ISS (Simulation)',
  'CSS Tiangong (Simulation)',
  'Mir (Simulation)',
  'Skylab (Simulation)',
  'Gateway PPU (Simulation)',
  'Salyut (Simulation)',
  'Tianhe Core (Simulation)',
  'Mengtian Lab (Simulation)',
  'Wentian Lab (Simulation)',
  'Node-1 Unity (Simulation)',
  'Node-2 Harmony (Simulation)',
  'Node-3 Tranquility (Simulation)',
  'Columbus Lab (Simulation)',
  'Kibo Lab (Simulation)',
  'Nauka Lab (Simulation)',
];
