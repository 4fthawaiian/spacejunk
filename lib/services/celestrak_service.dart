/// Service for fetching live orbital data from CelesTrak.
///
/// CelesTrak provides TLE (Two-Line Element) data for thousands of
/// tracked objects in space — satellites, debris, rocket bodies, etc.
///
/// Data source priority:
///   1. CelesTrak direct + CORS proxies (client-initiated, live data)
///   2. /api/tle.json (self-hosted cache, same-origin, always reachable)
///   3. Procedural simulation in the caller (always works)
///
/// API: https://celestrak.org/NORAD/elements/gp.php?GROUP={group}&FORMAT=json
library;

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'sgp4.dart';
import '../models/debris_data.dart';
import '../models/satcat_record.dart';
import '../models/constellation.dart' as constellation;

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

  /// SATCAT metadata, embedded when served from the self-hosted cache.
  final SatcatRecord? satcat;

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
    this.satcat,
  });

  /// Parse from CelesTrak JSON (or enriched cache JSON).
  ///
  /// When the JSON includes a nested "satcat" object (from the self-hosted
  /// cache), it is parsed into a [SatcatRecord]. Direct CelesTrak responses
  /// lack this field and [satcat] will be null.
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
    } else if (upper.contains('ISS') || upper.contains('TIANHE') ||
        upper.contains('NAUKA') || upper.contains('CSS')) {
      type = 'station';
    }

    // Parse embedded SATCAT metadata if present (from self-hosted cache)
    SatcatRecord? satcat;
    if (json['satcat'] is Map<String, dynamic>) {
      satcat = SatcatRecord.fromJson(
        json['satcat'] as Map<String, dynamic>,
      );
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
      satcat: satcat,
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

  /// Where the data came from: 'cache', 'live', or 'procedural'.
  String dataSource;

  CelestrakFetchResult({
    required this.objects,
    required this.propagators,
    required this.particles,
    required this.timestamp,
    this.dataSource = 'live',
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

  /// Self-hosted cached TLE endpoint (bundled at CI build time,
  /// refreshed by server cron). No CORS issues on web; mobile uses absolute URL.
  static const String _selfHostedUrl = kIsWeb
      ? '/api/tle.json'
      : 'https://spacejunk.4ft.me/api/tle.json';

  /// Groups to fetch. Each returns a JSON array of orbital element sets.
  /// Note: "rocket-body" is not a valid CelesTrak group (objects are
  /// identified by name parsing instead).
  static const List<String> defaultGroups = [
    'stations',
    'visual',
    'last-30-days',
    'amateur',
    'cubesat',
    'active',
    'science',
    'geo',
    'gps-ops',
  ];

  CelestrakState _state = CelestrakState.initial;
  String? _error;
  CelestrakFetchResult? _lastResult;
  DateTime? _lastFetch;

  CelestrakState get state => _state;
  String? get error => _error;
  CelestrakFetchResult? get lastResult => _lastResult;
  DateTime? get lastFetch => _lastFetch;

  /// Max time to spend trying Celestrak before falling back.
  static const Duration _globalTimeout = Duration(seconds: 15);

  /// Per-group timeout for Celestrak HTTP calls.
  static const Duration _groupTimeout = Duration(seconds: 5);

  /// Fetch orbital data, trying the self-hosted cache first, then CelesTrak.
  ///
  /// Sources tried in order:
  ///   1. Self-hosted cache (same-origin on web, absolute URL on mobile)
  ///   2. CelesTrak direct + CORS proxies (client-initiated, live data)
  ///   3. Caller falls back to procedural data
  Future<CelestrakFetchResult> fetch({
    List<String>? groups,
    bool forceRefresh = false,
  }) async {
    groups ??= defaultGroups;

    // Rate limit: don't re-fetch more than once per 30 minutes unless forced
    if (!forceRefresh &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!).inMinutes < 30) {
      return _lastResult!;
    }

    _state = CelestrakState.loading;
    _error = null;

    // 1. Try the self-hosted cache first (works on all platforms now).
    try {
      final cacheResult = await _fetchFromCache();
      if (cacheResult != null && cacheResult.objects.isNotEmpty) {
        cacheResult.dataSource = 'cache';
        _lastResult = cacheResult;
        _lastFetch = DateTime.now();
        _state = CelestrakState.loaded;
        return cacheResult;
      }
    } catch (_) {
      // Cache unavailable — fall through to Celestrak
    }

    // 2. Try CelesTrak directly (live data via CORS proxies).
    // Short timeout so we don't keep the user waiting.
    try {
      final result = await _fetchFromCelestrak(groups)
          .timeout(const Duration(seconds: 10));
      _lastResult = result;
      _lastFetch = DateTime.now();
      _state = CelestrakState.loaded;
      return result;
    } catch (_) {
      // Celestrak unreachable — fall through
    }

    // Nothing worked — caller will use procedural fallback
    _state = CelestrakState.error;
    _error = 'Live data unavailable — showing simulated orbits';
    throw CelestrakException('No data from Celestrak or cache');
  }

  /// Fetch from the same-origin cached TLE endpoint (web only).
  Future<CelestrakFetchResult?> _fetchFromCache() async {
    try {
      final response = await http
          .get(Uri.parse(_selfHostedUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return null;

      final List<dynamic> jsonList = json.decode(response.body);
      if (jsonList.isEmpty) return null;

      final objects = jsonList
          .map((item) => CelestrakObject.fromJson(item as Map<String, dynamic>))
          .where((obj) => obj.noradId != 0)
          .toList();

      if (objects.isEmpty) return null;

      return _processObjects(objects);
    } catch (_) {
      return null;
    }
  }

  /// Fetch from CelesTrak group endpoints (direct + CORS proxies).
  /// Tries groups concurrently and returns on the first successful one,
  /// so we get data as fast as possible.
  Future<CelestrakFetchResult> _fetchFromCelestrak(
      List<String> groups) async {
    // Try groups concurrently, complete on first success
    final results = await Future.wait(
      groups.map((group) => _fetchSingleGroup(group)),
      eagerError: false,
    );

    final allObjects = <CelestrakObject>[];
    final seenIds = <int>{};

    for (final result in results) {
      if (result == null) continue;
      for (final obj in result) {
        if (seenIds.add(obj.noradId)) {
          allObjects.add(obj);
        }
      }
    }

    if (allObjects.isEmpty) {
      throw CelestrakException('No objects fetched from any group');
    }

    return _processObjects(allObjects);
  }

  /// Fetch a single group, returning its objects or null on failure.
  Future<List<CelestrakObject>?> _fetchSingleGroup(String group) async {
    try {
      final url = '$_baseUrl?GROUP=$group&FORMAT=json';

      http.Response response;
      try {
        response = await http.get(Uri.parse(url))
            .timeout(_groupTimeout);
      } catch (_) {
        response = await _fetchWithProxies(url);
      }

      if (response.statusCode != 200) {
        response = await _fetchWithProxies(url);
      }

      if (response.statusCode != 200) return null;

      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList
          .map((item) => CelestrakObject.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
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

        final constId = constellation.identifyConstellation(obj.name.toUpperCase());

        particles.add(DebrisParticle(
          x: modelX,
          y: modelY,
          z: modelZ,
          altitude: alt,
          shell: shell,
          color: color,
          size: size * (0.7 + Random(obj.noradId).nextDouble() * 0.6),
          name: obj.name,
          noradId: obj.noradId,
          satcat: obj.satcat,
          constellation: constId == 'other' ? null : constId,
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

  // ── SATCAT metadata (on-demand fallback) ──────────────────────────────

  /// In-memory cache for SATCAT records fetched on-demand.
  static final Map<int, SatcatRecord> _satcatCache = {};
  static final Set<int> _satcatLoading = {};

  /// Look up SATCAT metadata for a NORAD ID.
  ///
  /// Returns the record from:
  ///   1. The current result's [DebrisParticle.satcat] if populated
  ///   2. The on-demand cache (from a previous [fetchSatcatForNorad] call)
  ///   3. null if unavailable
  SatcatRecord? getSatcat(int noradId) => _satcatCache[noradId];

  /// Fetch SATCAT metadata for a single NORAD ID on-demand.
  ///
  /// Results are cached in memory. This is a fallback when the self-hosted
  /// cache hasn't been enriched with SATCAT data yet.
  Future<SatcatRecord?> fetchSatcatForNorad(int noradId) async {
    if (_satcatCache.containsKey(noradId)) return _satcatCache[noradId];
    if (_satcatLoading.contains(noradId)) return null;

    _satcatLoading.add(noradId);
    try {
      final url =
          'https://celestrak.org/satcat/records.php?CATNR=$noradId&FORMAT=JSON';
      http.Response response;

      try {
        response = await http.get(Uri.parse(url)).timeout(
          const Duration(seconds: 10),
        );
      } catch (_) {
        response = await _fetchWithProxies(url);
      }

      if (response.statusCode != 200) {
        response = await _fetchWithProxies(url);
      }
      if (response.statusCode != 200) return null;

      final List<dynamic> jsonList = json.decode(response.body);
      if (jsonList.isEmpty) return null;

      final record = SatcatRecord.fromJson(
        jsonList[0] as Map<String, dynamic>,
      );
      _satcatCache[noradId] = record;
      return record;
    } catch (_) {
      return null;
    } finally {
      _satcatLoading.remove(noradId);
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
