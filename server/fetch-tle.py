#!/usr/bin/env python3
"""Fetch and merge TLE groups from Celestrak for SpaceJunk.

Runs via cron on server.4ft.me every 30 minutes.
Outputs merged JSON to /opt/junk/api/tle.json (served by nginx at /api/tle.json).
"""
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
        # Check if it's a Celestrak "not updated" message
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

    print(f"\nTotal unique objects: {len(merged)}")

    # Always write the file, even if empty (so the app gets an empty array
    # rather than a 404 if everything fails)
    with open(OUTPUT, "w") as f:
        json.dump(merged, f, indent=2)

    size = os.path.getsize(OUTPUT)
    print(f"Written to {OUTPUT} ({size} bytes)")

    if len(merged) == 0:
        print("WARNING: No objects fetched - empty snapshot written")
        # Don't exit(1) - we want cron to keep running


if __name__ == "__main__":
    main()
