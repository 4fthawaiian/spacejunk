#!/usr/bin/env node
/**
 * fetch-tle.mjs — Fetches TLE + SATCAT data from CelesTrak and writes enriched JSON.
 *
 * Used in CI/CD to bundle a live TLE snapshot with the app at build time,
 * so the app always has data even if CelesTrak is unreachable from the client.
 * Each TLE object gains a "satcat" field with country, launch date, type, RCS, etc.
 *
 * Usage:
 *   node scripts/fetch-tle.mjs                         # stdout
 *   node scripts/fetch-tle.mjs --output path.json       # write to file
 *   node scripts/fetch-tle.mjs --groups stations,visual  # custom groups
 *
 * Dependencies: none (uses Node 18+ native fetch)
 */

const CELESTRAK_BASE = 'https://celestrak.org/NORAD/elements/gp.php';
const SATCAT_CSV_URL = 'https://celestrak.org/pub/satcat.csv';
const DEFAULT_GROUPS = [
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

// SATCAT fields to embed into each TLE object.
const SATCAT_FIELDS = [
  'OWNER',
  'LAUNCH_DATE',
  'OBJECT_TYPE',
  'OPS_STATUS_CODE',
  'RCS',
  'LAUNCH_SITE',
  'DECAY_DATE',
  'ORBIT_TYPE',
];

function usage() {
  console.error(`
Usage:
  node scripts/fetch-tle.mjs [options]

Options:
  --output <path>    Write merged JSON to file (default: stdout)
  --groups <list>    Comma-separated group names (default: all)
  --timeout <sec>    Per-group fetch timeout in seconds (default: 15)
  --help             Show this message
`);
  process.exit(1);
}

async function fetchGroup(group, timeoutMs) {
  const url = `${CELESTRAK_BASE}?GROUP=${encodeURIComponent(group)}&FORMAT=json`;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const res = await fetch(url, { signal: controller.signal });
    if (!res.ok) {
      console.error(`  ⚠ ${group}: HTTP ${res.status}`);
      return [];
    }
    const text = await res.text();
    if (!text || text.trim() === '') {
      console.error(`  ⚠ ${group}: empty response`);
      return [];
    }
    const data = JSON.parse(text);
    if (!Array.isArray(data)) {
      console.error(`  ⚠ ${group}: response is not an array`);
      return [];
    }
    console.error(`  ✓ ${group}: ${data.length} objects`);
    return data;
  } catch (err) {
    if (err.name === 'AbortError') {
      console.error(`  ⚠ ${group}: timeout after ${timeoutMs}ms`);
    } else {
      console.error(`  ✗ ${group}: ${err.message}`);
    }
    return [];
  } finally {
    clearTimeout(timer);
  }
}

function mergeGroups(arrays) {
  const seen = new Set();
  const merged = [];

  for (const arr of arrays) {
    for (const obj of arr) {
      const id = obj.NORAD_CAT_ID;
      // Skip invalid entries
      if (id == null || id === 0) continue;
      if (!seen.has(id)) {
        seen.add(id);
        merged.push(obj);
      }
    }
  }

  return merged;
}

/**
 * Download and parse the SATCAT CSV, return a Map<NORAD_CAT_ID, satcat_fields>.
 */
async function loadSatcat() {
  console.error(`\n📖 Loading SATCAT catalog from ${SATCAT_CSV_URL}...`);

  let csvText;
  try {
    const res = await fetch(SATCAT_CSV_URL, { signal: AbortSignal.timeout(60_000) });
    if (!res.ok) {
      console.error(`  ⚠ SATCAT: HTTP ${res.status}`);
      return new Map();
    }
    csvText = await res.text();
  } catch (err) {
    console.error(`  ✗ SATCAT: ${err.message}`);
    return new Map();
  }

  const map = new Map();
  const lines = csvText.split('\n');
  if (lines.length < 2) return map;

  // Parse header
  const header = parseCsvLine(lines[0]);
  const fieldIndices = {};
  for (let i = 0; i < header.length; i++) {
    fieldIndices[header[i]] = i;
  }

  let count = 0;
  for (let i = 1; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line) continue;

    try {
      const fields = parseCsvLine(line);
      const noradIdx = fieldIndices['NORAD_CAT_ID'];
      if (noradIdx == null || noradIdx >= fields.length) continue;
      const norad = parseInt(fields[noradIdx], 10);
      if (!norad || norad <= 0) continue;

      const satcat = {};
      for (const key of SATCAT_FIELDS) {
        const idx = fieldIndices[key];
        if (idx != null && idx < fields.length) {
          let val = fields[idx] || '';
          if (key === 'RCS' && val) {
            const num = parseFloat(val);
            if (!isNaN(num)) val = num;
          }
          satcat[key] = val;
        }
      }
      map.set(norad, satcat);
      count++;
    } catch (_) {
      // skip malformed lines
    }
  }

  console.error(`  ✓ ${count} SATCAT records loaded`);
  return map;
}

/** Simple RFC 4180 CSV line parser. */
function parseCsvLine(line) {
  const result = [];
  let buf = '';
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (inQuotes) {
      if (ch === '"') {
        if (i + 1 < line.length && line[i + 1] === '"') {
          buf += '"';
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        buf += ch;
      }
    } else {
      if (ch === '"') {
        inQuotes = true;
      } else if (ch === ',') {
        result.push(buf.trim());
        buf = '';
      } else {
        buf += ch;
      }
    }
  }
  result.push(buf.trim());
  return result;
}

/** Embed SATCAT metadata into merged TLE objects. */
function enrichWithSatcat(objects, satcatMap) {
  let enriched = 0;
  for (const obj of objects) {
    const id = obj.NORAD_CAT_ID;
    if (id && satcatMap.has(id)) {
      obj.satcat = satcatMap.get(id);
      enriched++;
    }
  }
  console.error(`  ✓ Enriched ${enriched}/${objects.length} objects with SATCAT metadata`);
  return objects;
}

async function main() {
  const args = process.argv.slice(2);
  let outputPath = null;
  let groups = DEFAULT_GROUPS;
  let timeoutSec = 15;

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--output':
        outputPath = args[++i];
        if (!outputPath) usage();
        break;
      case '--groups':
        groups = args[++i]?.split(',').map((s) => s.trim()).filter(Boolean);
        if (!groups || groups.length === 0) usage();
        break;
      case '--timeout':
        timeoutSec = parseInt(args[++i], 10);
        if (isNaN(timeoutSec) || timeoutSec < 1) usage();
        break;
      case '--help':
        usage();
        break;
      default:
        console.error(`Unknown option: ${args[i]}`);
        usage();
    }
  }

  console.error(`\n🌍 Fetching TLE data from CelesTrak...`);
  console.error(`   Groups: ${groups.join(', ')}`);
  console.error(`   Timeout: ${timeoutSec}s per group\n`);

  const timeoutMs = timeoutSec * 1000;
  const results = await Promise.all(
    groups.map((g) => fetchGroup(g, timeoutMs)),
  );

  const merged = mergeGroups(results);
  const totalFetched = results.reduce((sum, arr) => sum + arr.length, 0);

  console.error(`\n📊 Summary:`);
  console.error(`   Fetched: ${totalFetched} objects across ${groups.length} groups`);
  console.error(`   After dedup: ${merged.length} unique objects`);

  // Enrich with SATCAT metadata
  if (merged.length > 0) {
    const satcatMap = await loadSatcat();
    if (satcatMap.size > 0) {
      enrichWithSatcat(merged, satcatMap);
    }
  }

  const json = JSON.stringify(merged, null, 2);

  if (outputPath) {
    const fs = await import('fs');
    const dir = outputPath.substring(0, outputPath.lastIndexOf('/'));
    if (dir && dir !== outputPath) {
      fs.mkdirSync(dir, { recursive: true });
    }
    fs.writeFileSync(outputPath, json, 'utf-8');
    console.error(`   Written to: ${outputPath}`);
  } else {
    console.log(json);
  }

  // Exit with error code if we got nothing
  if (merged.length === 0) {
    console.error(`\n❌ ERROR: No objects fetched from any group.`);
    process.exit(1);
  }

  console.error(`\n✅ Done.\n`);
}

main().catch((err) => {
  console.error(`\n❌ Fatal: ${err.message}`);
  process.exit(1);
});
