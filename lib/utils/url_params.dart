/// Read URL query parameters from the page URL (web only).
///
/// On native platforms [Uri.base.queryParameters] returns an empty map,
/// which is harmless — the app just uses default state.
library;

/// Parsed URL filter configuration.
class UrlFilterConfig {
  /// Constellation IDs to show (e.g. ['starlink', 'gps']).
  /// When non-empty, only these constellations are visible.
  final Set<String> constellations;

  /// Shells to hide (e.g. ['Debris', 'Station']).
  final Set<String> hideShells;

  /// Initial zoom level (0.4–2.5), null if not specified.
  final double? zoom;

  /// Initial time offset in days (-365..+365), null if not specified.
  final double? historicalOffsetDays;

  /// Whether to force isolation mode (hide non-constellation objects).
  bool get isolation => constellations.isNotEmpty;

  UrlFilterConfig({
    this.constellations = const {},
    this.hideShells = const {},
    this.zoom,
    this.historicalOffsetDays,
  });
}

/// Parse URL query parameters into a [UrlFilterConfig].
UrlFilterConfig parseUrlParams() {
  final params = Uri.base.queryParameters;

  // Constellations: CSV of constellation IDs to SHOW
  Set<String> constellations = {};
  if (params.containsKey('constellations')) {
    final raw = params['constellations']!;
    constellations = raw
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  // Hide shells: CSV of shell names to HIDE
  Set<String> hideShells = {};
  if (params.containsKey('hideShells')) {
    final raw = params['hideShells']!;
    hideShells = raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  // Zoom level
  double? zoom;
  if (params.containsKey('zoom')) {
    zoom = double.tryParse(params['zoom']!);
    if (zoom != null) zoom = zoom.clamp(0.4, 2.5);
  }

  // Historical time offset in days
  double? time;
  if (params.containsKey('time')) {
    time = double.tryParse(params['time']!);
    if (time != null) time = time.clamp(-365, 365);
  }

  return UrlFilterConfig(
    constellations: constellations,
    hideShells: hideShells,
    zoom: zoom,
    historicalOffsetDays: time,
  );
}
