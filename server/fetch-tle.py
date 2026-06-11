#!/usr/bin/env python3
"""Fetch TLE + SATCAT metadata from Celestrak, merge, and cache for SpaceJunk.

Runs via cron on server.4ft.me every 30 minutes.
Outputs enriched JSON to /opt/junk/api/tle.json (served by nginx at /api/tle.json).
Each TLE object gains a "satcat" field with country, launch date, type, RCS, etc.
"""
import csv
import io
import json
import os
import subprocess
import sys
import tempfile

# All valid CelesTrak groups
GROUPS = [
    "stations", "visual", "last-30-days", "amateur",
    "cubesat", "active", "science", "geo",
    "gps-ops", "sbas", "nnss", "dmc", "tle-new", "resource",
]
OUTPUT = "/opt/junk/api/tle.json"
SATCAT_CSV_URL = "https://celestrak.org/pub/satcat.csv"

# SATCAT fields to embed into each TLE object.
SATCAT_FIELDS = [
    "OWNER",           # country / org code (e.g. US, CIS, PRC, ISS)
    "LAUNCH_DATE",     # ISO date (e.g. 1998-11-20)
    "OBJECT_TYPE",     # PAY, R/B, DEB, UNK
    "OPS_STATUS_CODE", # + = active, D = dead, etc.
    "RCS",             # radar cross section (m²)
    "LAUNCH_SITE",     # launch site code (e.g. TYMSC, AFETR)
    "DECAY_DATE",      # re-entry date (empty = still on orbit)
    "ORBIT_TYPE",      # ORB, DOC, IMP, etc.
]


def fetch_group(group, tmpdir):
    """Fetch a single group from Celestrak, return list of objects."""
    url = f"https://celestrak.org/NORAD/elements/gp.php?GROUP={group}&FORMAT=json"
    outpath = os.path.join(tmpdir, f"{group}.json")

    try:
        subprocess.run(
            ["curl", "-sf", "--connect-timeout", "20", "--max-time", "45",
             url, "-o", outpath],
            check=True, capture_output=True, timeout=60
        )
        with open(outpath) as f:
            data = json.load(f)
        print(f"  ✓ {group}: {len(data)} objects")
        return data
    except subprocess.CalledProcessError:
        print(f"  ✗ {group}: fetch failed (may be rate-limited)")
        return []
    except (json.JSONDecodeError, ValueError):
        try:
            with open(outpath) as f:
                content = f.read(300)
            if "not updated" in content.lower():
                print(f"  ∼ {group}: not yet updated (rate-limited)")
            else:
                print(f"  ✗ {group}: invalid response: {content[:100]}")
        except Exception:
            print(f"  ✗ {group}: invalid JSON")
        return []
    except Exception as e:
        print(f"  ✗ {group}: {e}")
        return []


def load_satcat():
    """Download SATCAT CSV and return a dict keyed by NORAD_CAT_ID (int).

    Each value is a dict of the fields we care about:
      OWNER, LAUNCH_DATE, OBJECT_TYPE, OPS_STATUS_CODE, RCS,
      LAUNCH_SITE, DECAY_DATE, ORBIT_TYPE
    """
    print(f"\nFetching SATCAT catalog from {SATCAT_CSV_URL}...")
    try:
        result = subprocess.run(
            ["curl", "-sf", "--connect-timeout", "20", "--max-time", "60",
             SATCAT_CSV_URL],
            check=True, capture_output=True, timeout=90
        )
        csv_text = result.stdout.decode("utf-8")
    except subprocess.CalledProcessError as e:
        print(f"  ✗ SATCAT fetch failed: {e}")
        return {}
    except Exception as e:
        print(f"  ✗ SATCAT fetch error: {e}")
        return {}

    reader = csv.DictReader(io.StringIO(csv_text))
    lookup = {}
    count = 0
    for row in reader:
        try:
            norad = int(row.get("NORAD_CAT_ID", "0"))
        except (ValueError, TypeError):
            continue
        if norad <= 0:
            continue

        satcat = {}
        for field in SATCAT_FIELDS:
            val = row.get(field, "") or ""
            # Convert RCS to float when possible
            if field == "RCS" and val:
                try:
                    satcat[field] = float(val)
                except ValueError:
                    pass
                else:
                    continue
            satcat[field] = val
        lookup[norad] = satcat
        count += 1

    print(f"  ✓ {count} SATCAT records loaded")
    return lookup


def enrich_tle_with_satcat(tle_objects, satcat_lookup):
    """Embed SATCAT metadata into each matching TLE object."""
    enriched = 0
    for obj in tle_objects:
        norad = obj.get("NORAD_CAT_ID")
        if norad and norad in satcat_lookup:
            obj["satcat"] = satcat_lookup[norad]
            enriched += 1
    print(f"  ✓ Enriched {enriched}/{len(tle_objects)} objects with SATCAT metadata")
    return tle_objects


def main():
    tmpdir = tempfile.mkdtemp(prefix="tle-fetch-")
    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)

    print(f"[{__file__}] Fetching TLE groups from Celestrak...")

    seen = set()
    merged = []

    for group in GROUPS:
        arr = fetch_group(group, tmpdir)
        for item in arr:
            nid = item.get("NORAD_CAT_ID")
            if nid is not None and nid != 0 and nid not in seen:
                seen.add(nid)
                merged.append(item)

    # Cleanup temp files
    for f in os.listdir(tmpdir):
        os.remove(os.path.join(tmpdir, f))
    os.rmdir(tmpdir)

    print(f"\nTotal unique TLE objects: {len(merged)}")

    if len(merged) == 0:
        print("WARNING: No TLE objects fetched - writing empty snapshot")
        with open(OUTPUT, "w") as f:
            json.dump([], f)
        return

    # Fetch and merge SATCAT metadata
    satcat_lookup = load_satcat()
    if satcat_lookup:
        merged = enrich_tle_with_satcat(merged, satcat_lookup)
    else:
        print("  ∼ SATCAT unavailable — TLE data written without enrichment")

    with open(OUTPUT, "w") as f:
        json.dump(merged, f, indent=2)

    size = os.path.getsize(OUTPUT)
    print(f"\nWritten to {OUTPUT} ({size} bytes)")


if __name__ == "__main__":
    main()
