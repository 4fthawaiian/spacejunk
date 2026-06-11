/// Constellation grouping definitions for SpaceJunk.
///
/// Identifies satellite constellations/groups from object names
/// (no additional CelesTrak fetches needed — works with cached data).
library;

/// A named constellation or satellite group that users can filter by.
class ConstellationGroup {
  final String id;
  final String label;
  final int color;
  final List<String> namePatterns;

  const ConstellationGroup({
    required this.id,
    required this.label,
    required this.color,
    required this.namePatterns,
  });
}

/// All known constellation groups, ordered roughly by prominence.
const List<ConstellationGroup> constellationGroups = [
  ConstellationGroup(
    id: 'starlink',
    label: 'Starlink',
    color: 0xFFB0BEC5,
    namePatterns: ['STARLINK'],
  ),
  ConstellationGroup(
    id: 'oneweb',
    label: 'OneWeb',
    color: 0xFF7E57C2,
    namePatterns: ['ONEWEB'],
  ),
  ConstellationGroup(
    id: 'hulianwang',
    label: 'Hulianwang',
    color: 0xFFEF5350,
    namePatterns: ['HULIANWANG'],
  ),
  ConstellationGroup(
    id: 'iridium',
    label: 'Iridium',
    color: 0xFF26A69A,
    namePatterns: ['IRIDIUM'],
  ),
  ConstellationGroup(
    id: 'flock',
    label: 'Flock / Planet',
    color: 0xFF66BB6A,
    namePatterns: ['FLOCK', 'DOVE', 'SKYSAT'],
  ),
  ConstellationGroup(
    id: 'gps',
    label: 'GPS',
    color: 0xFF5C6BC0,
    namePatterns: ['NAVSTAR'],
  ),
  ConstellationGroup(
    id: 'glonass',
    label: 'Glonass',
    color: 0xFFEF5350,
    namePatterns: ['GLONASS', 'GLObalnss'],
  ),
  ConstellationGroup(
    id: 'galileo',
    label: 'Galileo',
    color: 0xFF42A5F5,
    namePatterns: ['GALILEO'],
  ),
  ConstellationGroup(
    id: 'beidou',
    label: 'BeiDou',
    color: 0xFFFFCA28,
    namePatterns: ['BEIDOU'],
  ),
  ConstellationGroup(
    id: 'globalstar',
    label: 'Globalstar',
    color: 0xFF29B6F6,
    namePatterns: ['GLOBALSTAR'],
  ),
  ConstellationGroup(
    id: 'orbcomm',
    label: 'Orbcomm',
    color: 0xFF78909C,
    namePatterns: ['ORBCOMM'],
  ),
  ConstellationGroup(
    id: 'eutelsat',
    label: 'Eutelsat',
    color: 0xFF4DB6AC,
    namePatterns: ['EUTELSAT'],
  ),
  ConstellationGroup(
    id: 'intelsat',
    label: 'Intelsat',
    color: 0xFF7986CB,
    namePatterns: ['INTELSAT'],
  ),
  ConstellationGroup(
    id: 'ses',
    label: 'SES',
    color: 0xFF90A4AE,
    namePatterns: ['SES-'],
  ),
  ConstellationGroup(
    id: 'o3b',
    label: 'O3b',
    color: 0xFF4DD0E1,
    namePatterns: ['O3B'],
  ),
  ConstellationGroup(
    id: 'inmarsat',
    label: 'Inmarsat',
    color: 0xFF00796B,
    namePatterns: ['INMARSAT'],
  ),
  ConstellationGroup(
    id: 'noaa',
    label: 'NOAA / GOES',
    color: 0xFF4FC3F7,
    namePatterns: ['NOAA', 'GOES'],
  ),
  ConstellationGroup(
    id: 'hubble',
    label: 'Hubble',
    color: 0xFF7B1FA2,
    namePatterns: ['HUBBLE'],
  ),
  ConstellationGroup(
    id: 'landsat',
    label: 'Landsat',
    color: 0xFF558B2F,
    namePatterns: ['LANDSAT'],
  ),
  ConstellationGroup(
    id: 'gonets',
    label: 'Gonets',
    color: 0xFFFF7043,
    namePatterns: ['GONETS'],
  ),
];

/// Map from constellation ID to its group definition.
Map<String, ConstellationGroup> get constellationById =>
    {for (final g in constellationGroups) g.id: g};

/// Identify the constellation ID for a satellite given its name.
///
/// Returns the constellation [id] if a match is found, or `'other'` if none
/// of the known patterns matched.
String identifyConstellation(String nameUpper) {
  for (final group in constellationGroups) {
    for (final pattern in group.namePatterns) {
      if (nameUpper.contains(pattern)) {
        return group.id;
      }
    }
  }
  return 'other';
}

/// Human-readable label for a constellation ID (or 'other').
String constellationLabel(String id) {
  if (id == 'other') return 'Other';
  return constellationById[id]?.label ?? id;
}

/// Display color for a constellation ID.
int constellationColor(String id) {
  return constellationById[id]?.color ?? 0xFF888888;
}

/// All recognized constellation IDs (excluding 'other').
Set<String> get knownConstellationIds =>
    constellationGroups.map((g) => g.id).toSet();
