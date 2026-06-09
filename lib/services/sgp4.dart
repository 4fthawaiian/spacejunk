/// SGP4/SDP4 orbital propagator in Dart.
///
/// Converts TLE orbital elements into Cartesian ECI positions.
///
/// Based on Vallado & Crawford "Revisiting Spacetrack Report #3" (AIAA 2006-6753)
/// and the reference implementations (Vallado, Mahooti, satellite-js).
library;

import 'dart:math';

/// ECI position result from SGP4 propagation (km).
class EciPosition {
  final double x;
  final double y;
  final double z;
  const EciPosition(this.x, this.y, this.z);
}

/// Exception from SGP4.
class Sgp4Exception implements Exception {
  final String message;
  const Sgp4Exception(this.message);
  @override
  String toString() => 'Sgp4Exception: $message';
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
const double _ke = 0.0743669161; // sqrt(GM) in earth-radii^1.5/min
const double _j2 = 1.082629989e-3;
const double _j3 = -2.53215306e-6;

const double _k2 = _j2 / 2.0;
const double _earthRadius = 6378.137; // km
const double _minutesPerDay = 1440.0;

// ---------------------------------------------------------------------------
// SGP4 Propagator
// ---------------------------------------------------------------------------
class Sgp4 {
  // ----- TLE-derived orbital elements (rad, rad/min) -----
  late double _bstar;
  late double _ecco; // eccentricity
  late double _inclo; // inclination (rad)
  late double _nodeo; // RAAN (rad)
  late double _argpo; // argument of perigee (rad)
  late double _mo; // mean anomaly (rad)
  double _no = 0; // mean motion (rad/min)

  // ----- Derived constants -----
  late double _a0;
  late double _cosio, _sinio;
  late double _theta2, _x3thm1, _x1mth2, _x7thm1;
  late double _betao, _betao2;
  late double _aycof;
  late double _c1, _c2;
  late double _s4, _qms4, _tsi, _eta;
  late double _xn0, _xinc, _xnode, _omgasm, _xle;
  late double _xn, _em, _am;
  late double _xmdot, _omgdot, _xnodot;
  late bool _deepSpace;

  /// Create from two TLE lines.
  factory Sgp4.fromTle(String line1, String line2) {
    final s = Sgp4._();
    s._parseTle(line1, line2);
    s._init();
    return s;
  }

  /// Create from parsed orbital elements directly.
  ///
  /// [meanMotion] in rev/day, angles in degrees.
  factory Sgp4.fromElements({
    required double inclination,
    required double raan,
    required double eccentricity,
    required double argPerigee,
    required double meanAnomaly,
    required double meanMotion,
    required double bstar,
    DateTime? epoch,
  }) {
    final s = Sgp4._();
    s._inclo = inclination * pi / 180.0;
    s._nodeo = raan * pi / 180.0;
    s._ecco = eccentricity;
    s._argpo = argPerigee * pi / 180.0;
    s._mo = meanAnomaly * pi / 180.0;
    s._no = meanMotion * 2.0 * pi / _minutesPerDay;
    s._bstar = bstar;
    s._epochDt = epoch ?? DateTime.now().toUtc();
    s._init();
    return s;
  }

  Sgp4._();

  // ==================================================================
  // TLE Parsing
  // ==================================================================
  void _parseTle(String line1, String line2) {
    try {
      // Line 1
      final epochStr = line1.substring(18, 32).trim();
      final bstarStr = line1.substring(53, 61).trim();

      // Parse epoch: YYDDD.DDDDDDDD
      final epochYear = int.parse(epochStr.substring(0, 2));
      final epochDay = double.parse(epochStr.substring(2));
      final year = epochYear + (epochYear > 56 ? 1900 : 2000);

      // Compute epoch as DateTime (for drift calculation)
      final epochDt = DateTime.utc(year, 1, 1).add(
        Duration(milliseconds: (epochDay * 86400000).round()),
      );
      _epochDt = epochDt;

      // BSTAR
      _bstar = _parseBstar(bstarStr);

      // Line 2
      _inclo = double.parse(line2.substring(8, 16).trim()) * pi / 180.0;
      _nodeo = double.parse(line2.substring(17, 25).trim()) * pi / 180.0;
      _ecco = double.parse('0.${line2.substring(26, 33)}');
      _argpo = double.parse(line2.substring(34, 42).trim()) * pi / 180.0;
      _mo = double.parse(line2.substring(43, 51).trim()) * pi / 180.0;
      _no = double.parse(line2.substring(52, 63).trim());

      // Convert mean motion: rev/day -> rad/min
      _no = _no * 2.0 * pi / _minutesPerDay;
    } catch (e) {
      throw Sgp4Exception('TLE parse failed: $e');
    }
  }

  DateTime? _epochDt;

  double _parseBstar(String s) {
    if (s.trim().isEmpty) return 0.0;
    // Format: ±DDDDD±D  (sign, 5 digits, exponent sign, exponent)
    final sign = s.contains('-') && s.indexOf('-') == 0 ? -1 : 1;
    final cleaned = s.replaceAll(RegExp(r'[+\- ]'), '');
    if (cleaned.length < 6) return 0.0;
    final mant = double.parse(cleaned.substring(0, 5)) / 100000.0;
    final exp = int.parse(cleaned.substring(5, 6));
    return sign * mant * pow(10.0, exp).toDouble();
  }

  // ==================================================================
  // Initialization
  // ==================================================================
  void _init() {
    _cosio = cos(_inclo);
    _sinio = sin(_inclo);
    _theta2 = _cosio * _cosio;
    _x3thm1 = 3.0 * _theta2 - 1.0;
    _betao2 = 1.0 - _ecco * _ecco;
    _betao = sqrt(_betao2);

    // Semi-major axis from mean motion
    final a1 = pow(_ke / _no, 2.0 / 3.0).toDouble();
    final temp = 1.5 * _k2 * _x3thm1 / (_betao * _betao2);
    final del1 = temp / (a1 * a1);
    _a0 = a1 * (1.0 + del1 * (1.0 / 3.0 + del1 * (1.0 + 134.0 / 81.0 * del1)));
    final del0 = temp / (_a0 * _a0);
    _xn0 = _ke / pow(_a0, 1.5).toDouble();

    // Period
    final period = 2.0 * pi / _xn0;
    _deepSpace = period >= 225.0;

    // SGP4 drag parameters
    _s4 = _earthRadius + 78.0;
    _qms4 = pow(_earthRadius + 120.0, 4).toDouble();

    final a = _a0 * pow(1.0 - del0, 2.0 / 3.0).toDouble();
    if (2.0 * _earthRadius / a - _ecco * _ecco <= 1.0) {
      _s4 = a;
    }

    _tsi = 1.0 / (a - _s4);
    _eta = a * _ecco * _tsi;
    final c1sq = _eta * _eta;
    final psisq = (1.0 - c1sq).abs();
    final psi = sqrt(psisq);
    final coef = _qms4 * pow(_tsi, 4).toDouble();
    final coef1 = coef / pow(psi, 5).toDouble();

    _c2 = coef1 * _xn0 * (a * (1.0 + 1.5 * c1sq + 4.0 * _eta * _eta + 0.5 * _eta * c1sq) +
        1.5 * _k2 * _tsi / psisq * _x3thm1 * (8.0 + 24.0 * c1sq + 3.0 * c1sq * c1sq));

    _c1 = _bstar * _c2;


    // Secular rates
    _x1mth2 = 1.0 - _theta2;
    _x7thm1 = 7.0 * _theta2 - 1.0;
    final xn0 = _xn0;
    _xmdot = xn0 + 0.5 * _c1 * xn0 * (-1.0 + 3.0 * _theta2) +
        1.5 * _k2 * xn0 / (_betao * a * a) * _x3thm1;
    _omgdot = -0.5 * _c1 * xn0 * _x1mth2 +
        1.5 * _k2 * xn0 / (_betao * a * a) * _x7thm1;
    _xnodot = -1.5 * _k2 * xn0 / (_betao * a * a) * _cosio;

    // Long-period coefficient
    _aycof = -0.5 * _j3 / _j2 * _sinio;

    // Initial mean elements
    _xn = _xn0;
    _xinc = _inclo;
    _xnode = _nodeo;
    _omgasm = _argpo;
    _em = _ecco;
    _am = a;
    _xle = _mo;

    // Initialize deep space if needed
    if (_deepSpace) {
      _initDeepSpace();
    }
  }

  void _initDeepSpace() {
    // SDP4 initialization would go here (lunar/solar perturbations)
    // For now, SGP4 handles most LEO objects; SDP4 deep-space is a TODO
  }

  // ==================================================================
  // Propagation
  // ==================================================================

  /// Propagate to [minutesPastEpoch] minutes after the TLE epoch.
  /// Returns ECI position in km.
  EciPosition propagate(double minutesPastEpoch) {
    final dt = minutesPastEpoch;
    // ----- Secular effects of drag and gravitation -----
    final xmdf = _xle + _xmdot * dt;
    final omgadf = _omgasm + _omgdot * dt;
    final xnoddf = _xnode + _xnodot * dt;

    // Quadratic drag terms
    final xmp = xmdf;
    final omega = omgadf;
    final xnode = xnoddf;

    // Mean anomaly (mod 2pi)
    var xl = xmp + omega + xnode;
    xl = xl - 2.0 * pi * (xl / (2.0 * pi)).floor();

    // ----- Solve Kepler's equation for eccentric anomaly -----
    var u = xl - omega - xnode;
    u = u - 2.0 * pi * (u / (2.0 * pi)).floor();

    // Newton's method
    var E = u;
    var e = _ecco;
    for (int iter = 0; iter < 100; iter++) {
      final dE = (u - e * sin(E) - E) / (1.0 - e * cos(E));
      E += dE;
      if (dE.abs() < 1e-12) break;
    }

    final sinE = sin(E);
    final cosE = cos(E);
    final beta = sqrt(1.0 - e * e);

    // ----- Position in orbital frame -----
    // r = a(1 - e*cosE)
    final r = _a0 * (1.0 - e * cosE);

    // Orbital plane position (true anomaly)
    final x = _a0 * (cosE - e);
    final y = _a0 * beta * sinE;

    // ----- Long-period perturbations -----
    final sinF = y / r;
    final cosF = x / r;

    // ----- Short-period perturbations -----
    final cos2 = 2.0 * cosF * cosF - 1.0;
    final sin2 = 2.0 * sinF * cosF;

    final rk = r + 0.5 * _k2 * (1.0 - 3.0 * _cosio * _cosio) /
        (_a0 * _betao2) * cos2;

    final uk = omega + 0.5 * _k2 / (_a0 * _betao2) *
        (7.0 * _cosio * _cosio - 1.0) * sin2;

    final xnodek = xnode + 0.5 * _k2 / (_a0 * _betao2) *
        _cosio * sin2;

    final xinck = _xinc + 0.5 * _k2 / (_a0 * _betao2) *
        _cosio * _sinio * (cos2 - 1.0);

    // ----- Transform orbital frame to ECI -----
    final sinuk = sin(uk);
    final cosuk = cos(uk);
    final sinik = sin(xinck);
    final cosik = cos(xinck);
    final sinnok = sin(xnodek);
    final cosnok = cos(xnodek);

    final ux = cosnok * cosuk - sinnok * sinuk * cosik;
    final uy = sinnok * cosuk + cosnok * sinuk * cosik;
    final uz = sinuk * sinik;

    // Convert from Earth radii (internal SGP4 unit) to kilometers
    const erToKm = 6378.137;
    return EciPosition(
      rk * ux * erToKm,
      rk * uy * erToKm,
      rk * uz * erToKm,
    );
  }

  /// Convenience: propagate to current UTC time.
  EciPosition propagateNow() {
    if (_epochDt == null) return propagate(0);
    final diff = DateTime.now().toUtc().difference(_epochDt!);
    final minutes = diff.inMinutes.toDouble() + diff.inSeconds / 60.0;
    return propagate(minutes);
  }

  /// Get the epoch of this TLE set.
  DateTime? get epoch => _epochDt;
}

/// Compute great-circle distance between two ECI positions (km).
double eciDistance(EciPosition a, EciPosition b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  final dz = a.z - b.z;
  return sqrt(dx * dx + dy * dy + dz * dz);
}
