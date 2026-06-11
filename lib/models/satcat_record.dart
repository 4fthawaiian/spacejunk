/// Richer metadata from CelesTrak's satellite catalogue (SATCAT).
///
/// Fetched from https://celestrak.org/pub/satcat.csv and embedded into
/// the self-hosted TLE cache, or fetched on-demand per NORAD ID via
/// https://celestrak.org/satcat/records.php?CATNR={id}&FORMAT=JSON
library;

/// One record from the CelesTrak SATCAT — the extended metadata catalogue.
class SatcatRecord {
  final String objectName;
  final String objectId; // International designator (COSPAR ID)
  final int noradCatId;
  final String objectType; // PAY, R/B, DEB, UNK
  final String opsStatusCode;
  final String owner; // country / org code
  final String launchDate; // ISO 8601 date
  final String launchSite;
  final String decayDate; // empty if still on orbit
  final double? period; // minutes
  final double? inclination; // degrees
  final double? apogee; // km
  final double? perigee; // km
  final double? rcs; // m² radar cross section
  final String dataStatusCode;
  final String orbitCenter;
  final String orbitType;

  const SatcatRecord({
    required this.objectName,
    required this.objectId,
    required this.noradCatId,
    required this.objectType,
    required this.opsStatusCode,
    required this.owner,
    required this.launchDate,
    required this.launchSite,
    required this.decayDate,
    this.period,
    this.inclination,
    this.apogee,
    this.perigee,
    this.rcs,
    required this.dataStatusCode,
    required this.orbitCenter,
    required this.orbitType,
  });

  /// Human-readable object type label.
  String get objectTypeLabel {
    switch (objectType) {
      case 'PAY':
        return 'Payload';
      case 'R/B':
        return 'Rocket Body';
      case 'DEB':
        return 'Debris';
      case 'UNK':
        return 'Unknown';
      default:
        return objectType;
    }
  }

  /// Whether this object is currently on orbit (not decayed).
  bool get isOnOrbit => decayDate.isEmpty;

  /// Whether this object is operational.
  bool get isOperational => opsStatusCode == '+';

  /// Radar cross-section label for display.
  String get rcsLabel {
    if (rcs == null) return 'N/A';
    final v = rcs!;
    if (v < 0.01) return '${v.toStringAsFixed(4)} m²';
    if (v < 0.1) return '${v.toStringAsFixed(3)} m²';
    if (v < 1) return '${v.toStringAsFixed(2)} m²';
    if (v < 10) return '${v.toStringAsFixed(1)} m²';
    return '${v.toStringAsFixed(0)} m²';
  }

  /// Parse from CelesTrak SATCAT JSON object (or nested "satcat" in cache).
  factory SatcatRecord.fromJson(Map<String, dynamic> json) {
    return SatcatRecord(
      objectName: json['OBJECT_NAME'] as String? ?? '',
      objectId: json['OBJECT_ID'] as String? ?? '',
      noradCatId: json['NORAD_CAT_ID'] as int? ?? 0,
      objectType: json['OBJECT_TYPE'] as String? ?? 'UNK',
      opsStatusCode: json['OPS_STATUS_CODE'] as String? ?? '',
      owner: json['OWNER'] as String? ?? 'UNK',
      launchDate: json['LAUNCH_DATE'] as String? ?? '',
      launchSite: json['LAUNCH_SITE'] as String? ?? '',
      decayDate: json['DECAY_DATE'] as String? ?? '',
      period: _toDouble(json['PERIOD']),
      inclination: _toDouble(json['INCLINATION']),
      apogee: _toDouble(json['APOGEE']),
      perigee: _toDouble(json['PERIGEE']),
      rcs: _toDouble(json['RCS']),
      dataStatusCode: json['DATA_STATUS_CODE'] as String? ?? '',
      orbitCenter: json['ORBIT_CENTER'] as String? ?? '',
      orbitType: json['ORBIT_TYPE'] as String? ?? '',
    );
  }

  /// Parse from a row of the SATCAT CSV (satcat.csv).
  factory SatcatRecord.fromCsvRow(Map<String, String> fields) {
    double? parseDouble(String? s) {
      if (s == null || s.isEmpty || s == 'N/A') return null;
      return double.tryParse(s);
    }

    return SatcatRecord(
      objectName: fields['OBJECT_NAME'] ?? '',
      objectId: fields['OBJECT_ID'] ?? '',
      noradCatId: int.tryParse(fields['NORAD_CAT_ID'] ?? '0') ?? 0,
      objectType: fields['OBJECT_TYPE'] ?? 'UNK',
      opsStatusCode: fields['OPS_STATUS_CODE'] ?? '',
      owner: fields['OWNER'] ?? 'UNK',
      launchDate: fields['LAUNCH_DATE'] ?? '',
      launchSite: fields['LAUNCH_SITE'] ?? '',
      decayDate: fields['DECAY_DATE'] ?? '',
      period: parseDouble(fields['PERIOD']),
      inclination: parseDouble(fields['INCLINATION']),
      apogee: parseDouble(fields['APOGEE']),
      perigee: parseDouble(fields['PERIGEE']),
      rcs: parseDouble(fields['RCS']),
      dataStatusCode: fields['DATA_STATUS_CODE'] ?? '',
      orbitCenter: fields['ORBIT_CENTER'] ?? '',
      orbitType: fields['ORBIT_TYPE'] ?? '',
    );
  }

  /// Safely convert a JSON value to double, accepting num, String, or null.
  /// Catches cases where SATCAT embeds empty strings (e.g., RCS="").
  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
    return null;
  }

  @override
  String toString() =>
      'SatcatRecord($noradCatId, $owner, $launchDate, $objectType)';
}
