/// Read URL query parameters from the page URL (web only).
///
/// On native platforms [Uri.base.queryParameters] returns an empty map,
/// which is harmless — the app just uses default state.
library;

/// All valid decade start years for URL param validation.
const _allDecades = {1960, 1970, 1980, 1990, 2000, 2010, 2020};

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

  /// Country owner codes to show (e.g. ['US', 'PRC', 'RUSS']).
  /// When non-empty, only objects owned by these countries are shown
  /// (plus objects without country data, which pass through).
  final Set<String> countries;

  /// Launch decades to show (e.g. {1960, 1990, 2020}).
  /// When non-empty, only objects launched in these decades are shown.
  final Set<int> decades;

  /// Whether to show the first-visit info dialog. When true, the info
  /// dialog is suppressed even on first load (for screenshot/embed mode).
  final bool noInfo;

  /// Whether to force isolation mode (hide non-constellation objects).
  bool get isolation => constellations.isNotEmpty;

  UrlFilterConfig({
    this.constellations = const {},
    this.hideShells = const {},
    this.zoom,
    this.historicalOffsetDays,
    this.countries = const {},
    this.decades = const {},
    this.noInfo = false,
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

  // Countries: CSV of owner codes to SHOW (additive isolation)
  Set<String> countries = {};
  if (params.containsKey('countries')) {
    final raw = params['countries']!;
    countries = raw
        .split(',')
        .map((s) => s.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  // Decades: CSV of decade start years (e.g. "1960,1990,2020")
  Set<int> decades = {};
  if (params.containsKey('decades')) {
    final raw = params['decades']!;
    decades = raw
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .where((d) => d != null && _allDecades.contains(d))
        .cast<int>()
        .toSet();
  }

  // Suppress info dialog (for screenshot/embed mode)
  final noInfo = params.containsKey('noInfo');

  return UrlFilterConfig(
    constellations: constellations,
    hideShells: hideShells,
    zoom: zoom,
    historicalOffsetDays: time,
    countries: countries,
    decades: decades,
    noInfo: noInfo,
  );
}
