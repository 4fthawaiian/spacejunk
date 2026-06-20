#!/usr/bin/env python3
"""
generate-test-tle.py — Generates a test TLE cache for visual snapshot testing.

Produces a realistic-looking set of orbital objects across all shells
(LEO, MEO, GEO, Debris, Station) so that screenshots look representative
of the real app. Output is written to build/web/api/tle.json.

Usage:
    python3 scripts/generate-test-tle.py
"""

import json
import math
import os
import random
import sys

random.seed(42)


def make_object(norad, name, mean_motion, ecc, inc, raan, argp, ma,
                owner='US', obj_type='PAYLOAD', launch_date='2020-01-01',
                rcs=None):
    """Create a TLE-like object dict with SATCAT enrichment."""
    return {
        'OBJECT_NAME': name,
        'OBJECT_ID': f'2020-{norad % 1000:03d}A',
        'EPOCH': '2026-06-21T12:00:00.000000',
        'MEAN_MOTION': round(mean_motion, 8),
        'ECCENTRICITY': round(ecc, 8),
        'INCLINATION': round(inc, 4),
        'RA_OF_ASC_NODE': round(raan, 4),
        'ARG_OF_PERICENTER': round(argp, 4),
        'MEAN_ANOMALY': round(ma, 4),
        'EPHEMERIS_TYPE': 0,
        'CLASSIFICATION_TYPE': 'U',
        'NORAD_CAT_ID': norad,
        'ELEMENT_SET_NO': 999,
        'REV_AT_EPOCH': 0,
        'BSTAR': 1.0e-4,
        'MEAN_MOTION_DOT': 0.0,
        'MEAN_MOTION_DDOT': 0.0,
        'satcat': {
            'OWNER': owner,
            'LAUNCH_DATE': launch_date,
            'OBJECT_TYPE': obj_type,
            'OPS_STATUS_CODE': '+' if obj_type == 'PAYLOAD' else '',
            'RCS': rcs,
        },
    }


def main():
    objects = []

    # ── ISS ─────────────────────────────────────────────────────────────────
    objects.append(make_object(
        25544, 'ISS (ZARYA)',
        mean_motion=15.49162374, ecc=0.00058814, inc=51.6361,
        raan=333.6061, argp=172.368, ma=187.7399,
        owner='ISS', obj_type='PAYLOAD', launch_date='1998-11-20', rcs=2500.0,
    ))

    # ── Starlink constellation (a bunch of LEO satellites) ────────────────
    for i in range(60):
        norad = 44000 + i
        plane = random.uniform(0, 360)
        objects.append(make_object(
            norad, f'STARLINK-{i+1}',
            mean_motion=random.uniform(15.0, 15.4),
            ecc=random.uniform(0.0001, 0.0003),
            inc=random.uniform(53.0, 53.2),
            raan=(plane + random.uniform(-0.5, 0.5)) % 360,
            argp=random.uniform(0, 360),
            ma=random.uniform(0, 360),
            owner='US', obj_type='PAYLOAD', launch_date='2024-01-01', rcs=0.5,
        ))

    # ── GPS constellation (MEO) ───────────────────────────────────────────
    for i in range(15):
        norad = 45000 + i
        objects.append(make_object(
            norad, f'GPS-BIIR-{i+1}',
            mean_motion=random.uniform(2.0, 2.1),
            ecc=random.uniform(0.001, 0.005),
            inc=random.uniform(55.0, 56.0),
            raan=random.uniform(0, 360),
            argp=random.uniform(0, 360),
            ma=random.uniform(0, 360),
            owner='US', obj_type='PAYLOAD', launch_date='2020-06-01', rcs=10.0,
        ))

    # ── GEO satellites ────────────────────────────────────────────────────
    for i in range(20):
        norad = 46000 + i
        objects.append(make_object(
            norad, f'GEO-COM-{i+1}',
            mean_motion=random.uniform(0.95, 1.02),
            ecc=random.uniform(0.0001, 0.001),
            inc=random.uniform(0, 5),
            raan=random.uniform(0, 360),
            argp=random.uniform(0, 360),
            ma=random.uniform(0, 360),
            owner=random.choice(['US', 'CH', 'ESA', 'CIS']),
            obj_type='PAYLOAD', launch_date='2022-03-15', rcs=20.0,
        ))

    # ── USSPACECOM / TLE-new (mixed) ─────────────────────────────────────
    for i in range(40):
        norad = 47000 + i
        shell = random.choices(['LEO', 'LEO', 'MEO', 'GEO', 'Debris'],
                               weights=[50, 30, 10, 5, 5])[0]
        if shell == 'LEO':
            mm = random.uniform(12.0, 16.0)
            ecc = random.uniform(0, 0.01)
            inc = random.uniform(0, 100)
        elif shell == 'MEO':
            mm = random.uniform(4.0, 6.0)
            ecc = random.uniform(0, 0.005)
            inc = random.uniform(0, 60)
        elif shell == 'GEO':
            mm = random.uniform(0.9, 1.1)
            ecc = random.uniform(0, 0.003)
            inc = random.uniform(0, 15)
        else:  # Debris
            mm = random.uniform(10.0, 15.0)
            ecc = random.uniform(0.001, 0.02)
            inc = random.uniform(0, 110)

        obj_type = random.choices(
            ['PAYLOAD', 'PAYLOAD', 'ROCKET BODY', 'DEBRIS'],
            weights=[55, 20, 10, 15],
        )[0]

        objects.append(make_object(
            norad, f'OBJ-{norad}',
            mean_motion=mm, ecc=ecc, inc=inc,
            raan=random.uniform(0, 360),
            argp=random.uniform(0, 360),
            ma=random.uniform(0, 360),
            owner=random.choice(['US', 'CIS', 'CH', 'ESA', 'JPN', 'IND']),
            obj_type=obj_type,
            launch_date=f'202{random.randint(0,6)}-{random.randint(1,12):02d}-{random.randint(1,28):02d}',
            rcs=random.choice([0.1, 0.5, 1.0, 5.0, 10.0, None]),
        ))

    # ── Amateur radio / cubesat / science (LEO, higher inclinations) ─────
    for i in range(30):
        norad = 48000 + i
        objects.append(make_object(
            norad, f'CUBESAT-{i+1}',
            mean_motion=random.uniform(14.0, 15.8),
            ecc=random.uniform(0, 0.005),
            inc=random.uniform(0, 100),
            raan=random.uniform(0, 360),
            argp=random.uniform(0, 360),
            ma=random.uniform(0, 360),
            owner=random.choice(['US', 'ESA', 'JPN', 'CH']),
            obj_type='PAYLOAD', launch_date='2023-01-01', rcs=0.1,
        ))

    # ── Station (ISS-like orbits) ─────────────────────────────────────────
    for i in range(5):
        norad = 49000 + i
        objects.append(make_object(
            norad, f'STATION-MOD-{i+1}',
            mean_motion=random.uniform(15.0, 15.6),
            ecc=random.uniform(0.0001, 0.001),
            inc=random.uniform(50.0, 52.0),
            raan=random.uniform(0, 360),
            argp=random.uniform(0, 360),
            ma=random.uniform(0, 360),
            owner='ISS', obj_type='PAYLOAD', launch_date='2021-01-01', rcs=500.0,
        ))

    # ── Rocket bodies (various orbits) ────────────────────────────────────
    for i in range(20):
        norad = 50000 + i
        shell = random.choices(['LEO', 'MEO', 'GEO'], weights=[70, 20, 10])[0]
        if shell == 'LEO':
            mm = random.uniform(12.0, 16.0)
            inc = random.uniform(0, 100)
        elif shell == 'MEO':
            mm = random.uniform(4.0, 6.0)
            inc = random.uniform(0, 60)
        else:
            mm = random.uniform(0.9, 1.1)
            inc = random.uniform(0, 10)

        objects.append(make_object(
            norad, f'R/B-{norad}',
            mean_motion=mm, ecc=random.uniform(0.001, 0.01), inc=inc,
            raan=random.uniform(0, 360),
            argp=random.uniform(0, 360),
            ma=random.uniform(0, 360),
            owner=random.choice(['US', 'CIS', 'CH', 'ESA']),
            obj_type='ROCKET BODY', launch_date='2020-01-01', rcs=15.0,
        ))

    # Write output
    output_dir = os.path.join(os.path.dirname(os.path.dirname(
        os.path.abspath(__file__))), 'build', 'web', 'api')
    os.makedirs(output_dir, exist_ok=True)
    output_path = os.path.join(output_dir, 'tle.json')

    with open(output_path, 'w') as f:
        json.dump(objects, f, indent=2)

    print(f'✅ Generated {len(objects)} test objects → {output_path}', file=sys.stderr)
    print(f'   File size: {os.path.getsize(output_path) / 1024:.0f} KB', file=sys.stderr)


if __name__ == '__main__':
    main()
