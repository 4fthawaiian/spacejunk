/// Service for fetching live orbital data from CelesTrak.
///
/// CelesTrak provides TLE (Two-Line Element) data for thousands of
/// tracked objects in space — satellites, debris, rocket bodies, etc.
/// No API key required.
///
/// API: https://celestrak.org/NORAD/elements/gp.php?GROUP={group}&FORMAT=json
library;

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'sgp4.dart';
import '../models/debris_data.dart';

/// Orbital data for a single object from CelesTrak.
class CelestrakObject {
  final String name;
  final int noradId;
  final String objectId;
  final String epoch;
  final double meanMotion; // rev/day
  final double eccentricity;
  final double inclination; // deg
  final double raan; // deg
  final double argPerigee; // deg
  final double meanAnomaly; // deg
  final double bstar;
  final String objectType; // inferred

  CelestrakObject({
    required this.name,
    required this.noradId,
    required this.objectId,
    required this.epoch,
    required this.meanMotion,
    required this.eccentricity,
    required this.inclination,
    required this.raan,
    required this.argPerigee,
    required this.meanAnomaly,
    required this.bstar,
    required this.objectType,
  });

  /// Parse from CelesTrak JSON object.
  factory CelestrakObject.fromJson(Map<String, dynamic> json) {
    final name = json['OBJECT_NAME'] as String? ?? 'Unknown';
    final noradId = json['NORAD_CAT_ID'] as int? ?? 0;

    // Infer object type from name
    String type = 'satellite';
    final upper = name.toUpperCase();
    if (upper.contains('DEB') || upper.contains('DEBRIS')) {
      type = 'debris';
    } else if (upper.contains('R/B') || upper.contains('ROCKET')) {
      type = 'rocket_body';
    } else if (upper.contains('ISS') || upper.contains('TIANHE') || upper.contains('NAUKA') || upper.contains('CSS')) {
      type = 'station';
    }

    return CelestrakObject(
      name: name,
      noradId: noradId,
      objectId: json['OBJECT_ID'] as String? ?? '',
      epoch: json['EPOCH'] as String? ?? '',
      meanMotion: (json['MEAN_MOTION'] as num?)?.toDouble() ?? 0,
      eccentricity: (json['ECCENTRICITY'] as num?)?.toDouble() ?? 0,
      inclination: (json['INCLINATION'] as num?)?.toDouble() ?? 0,
      raan: (json['RA_OF_ASC_NODE'] as num?)?.toDouble() ?? 0,
      argPerigee: (json['ARG_OF_PERICENTER'] as num?)?.toDouble() ?? 0,
      meanAnomaly: (json['MEAN_ANOMALY'] as num?)?.toDouble() ?? 0,
      bstar: (json['BSTAR'] as num?)?.toDouble() ?? 0,
      objectType: type,
    );
  }
}

/// Service state
enum CelestrakState { initial, loading, loaded, error }

/// Result from a CelesTrak fetch operation.
class CelestrakFetchResult {
  final List<CelestrakObject> objects;
  final List<Sgp4> propagators;
  final List<DebrisParticle> particles;
  final DateTime timestamp;

  CelestrakFetchResult({
    required this.objects,
    required this.propagators,
    required this.particles,
    required this.timestamp,
  });
}

/// Service for fetching and processing orbital data from CelesTrak.
class CelestrakService {
  static const String _baseUrl = 'https://celestrak.org/NORAD/elements/gp.php';

  /// CORS proxies for web platforms where CelesTrak doesn't send CORS headers.
  /// Tried in order until one works.
  static const List<String> _corsProxies = [
    'https://corsproxy.io/?url=',
    'https://api.allorigins.win/raw?url=',
    'https://corsproxy.org/?url=',
  ];

  /// Groups to fetch. Each returns a JSON array of orbital element sets.
  static const List<String> defaultGroups = [
    'stations',
    'visual',
    'last-30-days',
    'amateur',
    'cubesat',
    'active',
    'rocket-body',
  ];

  CelestrakState _state = CelestrakState.initial;
  String? _error;
  CelestrakFetchResult? _lastResult;
  DateTime? _lastFetch;

  CelestrakState get state => _state;
  String? get error => _error;
  CelestrakFetchResult? get lastResult => _lastResult;
  DateTime? get lastFetch => _lastFetch;

  /// Fetch orbital data from CelesTrak.
  ///
  /// Fetches the specified [groups] (or all default groups) and processes
  /// the orbital data into propagatable SGP4 instances + DebrisParticles.
  Future<CelestrakFetchResult> fetch({
    List<String>? groups,
    bool forceRefresh = false,
  }) async {
    groups ??= defaultGroups;

    // Rate limit: don't fetch more than once per 30 minutes unless forced
    if (!forceRefresh &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!).inMinutes < 30) {
      return _lastResult!;
    }

    _state = CelestrakState.loading;
    _error = null;

    try {
      final allObjects = <CelestrakObject>[];
      final seenIds = <int>{};

      // Fetch each group — try direct first, then CORS proxies
      for (final group in groups) {
        try {
          final url = '$_baseUrl?GROUP=$group&FORMAT=json';
          http.Response response;

          // Try direct fetch first
          try {
            response = await http.get(Uri.parse(url)).timeout(
              const Duration(seconds: 10),
            );
          } catch (_) {
            // Direct failed, try each CORS proxy in order
            response = await _fetchWithProxies(url);
          }

          if (response.statusCode != 200) {
            // Try proxies if direct returned non-200
            response = await _fetchWithProxies(url);
          }

          if (response.statusCode != 200) continue;

          final List<dynamic> jsonList = json.decode(response.body);
          for (final item in jsonList) {
            final obj = CelestrakObject.fromJson(item as Map<String, dynamic>);
            if (seenIds.add(obj.noradId)) {
              allObjects.add(obj);
            }
          }
        } catch (e) {
          continue;
        }
      }

      if (allObjects.isEmpty) {
        throw CelestrakException('No objects fetched from any group');
      }

      // Create propagators and particles
      final result = _processObjects(allObjects);

      _lastResult = result;
      _lastFetch = DateTime.now();
      _state = CelestrakState.loaded;

      return result;
    } catch (e) {
      _state = CelestrakState.error;
      _error = e.toString();
      rethrow;
    }
  }

  /// Process CelesTrak objects into SGP4 propagators and DebrisParticles.
  CelestrakFetchResult _processObjects(List<CelestrakObject> objects) {
    final propagators = <Sgp4>[];
    final particles = <DebrisParticle>[];

    // Earth radius in km
    const rEarth = 6378.137;
    // Scale factor for visualization: 1 model unit ≈ 12000 km
    const scaleFactor = 1.0 / 12000.0;

    for (final obj in objects) {
      // Skip objects with invalid mean motion
      if (obj.meanMotion <= 0 || obj.meanMotion > 20) continue;

      try {
        // Parse epoch
        DateTime? epochDt;
        try {
          epochDt = DateTime.parse(obj.epoch);
        } catch (_) {
          // If epoch parsing fails, use current time (no drift)
        }

        // Create propagator directly from elements
        final sgp4 = Sgp4.fromElements(
          inclination: obj.inclination,
          raan: obj.raan,
          eccentricity: obj.eccentricity,
          argPerigee: obj.argPerigee,
          meanAnomaly: obj.meanAnomaly,
          meanMotion: obj.meanMotion,
          bstar: obj.bstar,
          epoch: epochDt,
        );
        propagators.add(sgp4);

        // Propagate to current time
        EciPosition pos;
        if (epochDt != null) {
          final diff = DateTime.now().toUtc().difference(epochDt);
          final minutes = diff.inMinutes.toDouble() + diff.inSeconds / 60.0;
          pos = sgp4.propagate(minutes);
        } else {
          pos = sgp4.propagate(0);
        }

        // Compute altitude
        final dist = sqrt(pos.x * pos.x + pos.y * pos.y + pos.z * pos.z);
        final alt = dist - rEarth;

        // Map to visualization coordinates
        final modelX = pos.x * scaleFactor;
        final modelY = pos.y * scaleFactor;
        final modelZ = pos.z * scaleFactor;

        // Color + shell based on altitude and type
        final color = _objectColor(obj, alt);
        final size = _objectSize(obj);

        String shell;
        if (obj.objectType == 'station') {
          shell = 'Station';
        } else if (obj.objectType == 'debris') {
          shell = 'Debris';
        } else if (obj.objectType == 'rocket_body') {
          shell = 'Rocket-Body';
        } else if (alt < 2000) {
          shell = 'LEO';
        } else if (alt < 35786) {
          shell = 'MEO';
        } else {
          shell = 'GEO';
        }

        particles.add(DebrisParticle(
          x: modelX,
          y: modelY,
          z: modelZ,
          altitude: alt,
          shell: shell,
          color: color,
          size: size * (0.7 + Random(obj.noradId).nextDouble() * 0.6),
          name: obj.name,
        ));
      } catch (e) {
        // Skip objects that fail to propagate
        continue;
      }
    }

    return CelestrakFetchResult(
      objects: objects,
      propagators: propagators,
      particles: particles,
      timestamp: DateTime.now(),
    );
  }

  /// Determine particle color based on object type and altitude.
  int _objectColor(CelestrakObject obj, double alt) {
    switch (obj.objectType) {
      case 'station':
        return 0xFFFFD740; // warm gold
      case 'debris':
        return 0xFFEF5350; // red
      case 'rocket_body':
        return 0xFFFFAB40; // orange
      default:
        // Color by altitude
        if (alt < 2000) return 0xFFFF6B35; // LEO orange
        if (alt < 35786) return 0xFFF7C948; // MEO yellow
        return 0xFF4FC3F7; // GEO cyan
    }
  }

  /// Determine base size based on object type.
  double _objectSize(CelestrakObject obj) {
    switch (obj.objectType) {
      case 'station':
        return 1.5;
      case 'debris':
        return 0.5;
      case 'rocket_body':
        return 1.0;
      default:
        return 0.7;
    }
  }

  /// Try each CORS proxy in order until one returns a successful response.
  Future<http.Response> _fetchWithProxies(String rawUrl) async {
    final encodedUrl = Uri.encodeComponent(rawUrl);
    for (final proxy in _corsProxies) {
      try {
        final response = await http.get(
          Uri.parse('$proxy$encodedUrl'),
        ).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) return response;
      } catch (_) {
        continue;
      }
    }
    throw CelestrakException('All CORS proxies failed');
  }
}

class CelestrakException implements Exception {
  final String message;
  const CelestrakException(this.message);
  @override
  String toString() => 'CelestrakException: $message';
}
