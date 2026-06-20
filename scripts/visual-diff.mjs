#!/usr/bin/env node
/**
 * visual-diff.mjs — Compares current screenshots against reference baselines.
 *
 * For each screenshot in snapshots/current/, this script:
 *   1. Looks for a matching reference image in snapshots/reference/
 *   2. If found, compares them pixel-by-pixel using pixelmatch
 *   3. Generates a diff image (mismatched pixels highlighted in red)
 *   4. Reports mismatch percentage
 *   5. Outputs an HTML report
 *
 * Usage:
 *   node scripts/visual-diff.mjs              # compare current vs reference
 *   node scripts/visual-diff.mjs --update     # promote current → reference (new baseline)
 *   node scripts/visual-diff.mjs --threshold 0.5  # set mismatch threshold (default 0.5%)
 *
 * Typical workflow:
 *   flutter build web --wasm
 *   node scripts/snapshots.mjs                # take fresh screenshots
 *   node scripts/visual-diff.mjs              # compare vs baseline
 *   # If changes are intentional:
 *   node scripts/visual-diff.mjs --update     # accept as new baseline
 *   git add snapshots/reference/ && git commit -m "update visual baselines"
 *
 * Dependencies: playwright, pixelmatch, pngjs (see package.json)
 */

import pixelmatch from 'pixelmatch';
import { PNG } from 'pngjs';
import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync } from 'fs';
import { resolve, dirname, basename } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, '..');
const CURRENT_DIR = resolve(ROOT, 'snapshots/current');
const REFERENCE_DIR = resolve(ROOT, 'snapshots/reference');
const DIFF_DIR = resolve(ROOT, 'snapshots/diff');
const REPORT_FILE = resolve(ROOT, 'snapshots/report.html');

const DEFAULT_THRESHOLD = 0.5; // % of mismatched pixels allowed

// ─── Helpers ─────────────────────────────────────────────────────────────────

function loadPNG(filepath) {
  const data = readFileSync(filepath);
  return PNG.sync.read(data);
}

function formatPct(value) {
  return `${(value * 100).toFixed(2)}%`;
}

function severity(pct) {
  if (pct === 0) return 'pass';
  if (pct < 0.01) return 'pass';
  if (pct < 0.1) return 'warn';
  if (pct < 1.0) return 'fail';
  return 'critical';
}

function severityColor(sev) {
  switch (sev) {
    case 'pass': return '#22c55e';
    case 'warn': return '#eab308';
    case 'fail': return '#f97316';
    case 'critical': return '#ef4444';
    default: return '#888';
  }
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  const args = process.argv.slice(2);
  const isUpdate = args.includes('--update');
  let thresholdPct = DEFAULT_THRESHOLD;

  const thresholdIdx = args.indexOf('--threshold');
  if (thresholdIdx >= 0 && thresholdIdx + 1 < args.length) {
    thresholdPct = parseFloat(args[thresholdIdx + 1]);
    if (isNaN(thresholdPct)) {
      console.error('❌ Invalid threshold value');
      process.exit(1);
    }
  }

  console.error(`\n🔍 SpaceJunk Visual Diff\n`);

  if (isUpdate) {
    console.error(`  💡 --update mode: promoting current → reference\n`);
  } else {
    console.error(`  Threshold: ${thresholdPct}% mismatched pixels\n`);
  }

  // Check that current screenshots exist
  if (!existsSync(CURRENT_DIR)) {
    console.error(`❌ No current screenshots found at ${CURRENT_DIR}`);
    console.error(`   Run 'node scripts/snapshots.mjs' first\n`);
    process.exit(1);
  }

  const currentFiles = readdirSync(CURRENT_DIR)
    .filter((f) => f.endsWith('.png'))
    .sort();

  if (currentFiles.length === 0) {
    console.error(`❌ No PNG screenshots found in ${CURRENT_DIR}\n`);
    process.exit(1);
  }

  console.error(`  📁 Found ${currentFiles.length} current screenshots\n`);

  // Create directories
  mkdirSync(DIFF_DIR, { recursive: true });
  mkdirSync(REFERENCE_DIR, { recursive: true });

  const results = [];

  for (const file of currentFiles) {
    const currentPath = resolve(CURRENT_DIR, file);
    const referencePath = resolve(REFERENCE_DIR, file);
    const diffPath = resolve(DIFF_DIR, file);

    if (isUpdate) {
      // Promote current → reference
      const data = readFileSync(currentPath);
      writeFileSync(referencePath, data);
      console.error(`  ✅ ${file} → reference updated`);
      results.push({
        file,
        status: 'updated',
        mismatch: 0,
        severity: 'pass',
      });
      continue;
    }

    // Check if reference exists
    if (!existsSync(referencePath)) {
      console.error(`  ⚠️  ${file}: NO REFERENCE — skipping (use --update to set baseline)`);
      results.push({
        file,
        status: 'no-reference',
        mismatch: null,
        severity: 'warn',
      });
      continue;
    }

    // Compare
    try {
      const current = loadPNG(currentPath);
      const reference = loadPNG(referencePath);

      if (current.width !== reference.width || current.height !== reference.height) {
        console.error(`  ❌ ${file}: DIMENSION MISMATCH (current: ${current.width}×${current.height}, ref: ${reference.width}×${reference.height})`);
        results.push({
          file,
          status: 'dimension-mismatch',
          mismatch: null,
          severity: 'critical',
        });
        continue;
      }

      const diff = new PNG({ width: current.width, height: current.height });
      const mismatchedPixels = pixelmatch(
        reference.data,
        current.data,
        diff.data,
        current.width,
        current.height,
        { threshold: 0.1, diffColor: [255, 0, 0, 255] }, // red for mismatches
      );

      const totalPixels = current.width * current.height;
      const mismatchPct = mismatchedPixels / totalPixels;

      // Save diff image
      writeFileSync(diffPath, PNG.sync.write(diff));

      const sev = severity(mismatchPct);
      const status = mismatchPct <= (thresholdPct / 100) ? 'pass' : 'fail';
      const icon = status === 'pass' ? '✅' : '❌';

      console.error(`  ${icon} ${file}: ${formatPct(mismatchPct)} mismatched (${severityText(sev)})`);

      results.push({
        file,
        status,
        mismatch: mismatchPct,
        mismatchFormatted: formatPct(mismatchPct),
        severity: sev,
        diffFile: file,
      });
    } catch (err) {
      console.error(`  ❌ ${file}: ERROR — ${err.message}`);
      results.push({
        file,
        status: 'error',
        mismatch: null,
        severity: 'critical',
        error: err.message,
      });
    }
  }

  // Generate HTML report
  generateReport(results);

  const passCount = results.filter((r) => r.status === 'pass' || r.status === 'updated' || r.status === 'no-reference').length;
  const failCount = results.filter((r) => r.status === 'fail').length;
  const errorCount = results.filter((r) => r.status === 'error' || r.status === 'dimension-mismatch').length;

  console.error(`\n  ─────────────────────────────────────────`);
  console.error(`  📊 Results: ${passCount} passed, ${failCount} failed, ${errorCount} errors`);
  console.error(`  📄 Report: ${REPORT_FILE}`);

  if (isUpdate) {
    console.error(`\n  ✅ Reference baselines updated — don't forget to commit:`);
    console.error(`     git add snapshots/reference/ && git commit -m "update visual baselines"\n`);
  } else if (failCount > 0) {
    console.error(`\n  ❌ ${failCount} screenshot(s) exceeded the ${thresholdPct}% threshold.`);
    console.error(`     Review diffs in snapshots/diff/ and the HTML report.`);
    console.error(`     If changes are intentional, run: node scripts/visual-diff.mjs --update\n`);
  }

  // Exit with code if any failures
  if (failCount > 0 || errorCount > 0) {
    process.exit(1);
  }
}

function severityText(sev) {
  switch (sev) {
    case 'pass': return 'perfect';
    case 'warn': return 'very minor';
    case 'fail': return 'notable';
    case 'critical': return 'major';
    default: return 'unknown';
  }
}

function generateReport(results) {
  const rows = results.map((r) => {
    const color = severityColor(r.severity);
    const statusIcon = r.status === 'pass' ? '✅' : r.status === 'fail' ? '❌' : r.status === 'updated' ? '🔄' : r.status === 'no-reference' ? '⚪' : '💥';
    const diffCol = r.diffFile
      ? `<td><a href="diff/${r.diffFile}"><img src="diff/${r.diffFile}" style="max-width:200px;border:1px solid #333" /></a></td>`
      : '<td>—</td>';
    const refCol = r.status !== 'no-reference' && r.status !== 'updated'
      ? `<td><a href="reference/${r.file}"><img src="reference/${r.file}" style="max-width:200px;border:1px solid #333" /></a></td>`
      : '<td>—</td>';
    const curCol = `<td><a href="current/${r.file}"><img src="current/${r.file}" style="max-width:200px;border:1px solid #333" /></a></td>`;

    return `<tr>
      <td>${statusIcon}</td>
      <td style="color:${color};font-weight:bold">${r.file}</td>
      <td style="color:${color}">${r.mismatchFormatted ?? r.status}</td>
      <td style="color:${color}">${r.severity}</td>
      ${refCol}
      ${curCol}
      ${diffCol}
    </tr>`;
  }).join('\n');

  const pass = results.filter((r) => r.status === 'pass').length;
  const fail = results.filter((r) => r.status === 'fail').length;
  const other = results.filter((r) => r.status !== 'pass' && r.status !== 'fail').length;

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>SpaceJunk — Visual Diff Report</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #0a0a0f;
      color: #e0e0e0;
      padding: 2rem;
    }
    h1 { font-size: 1.8rem; margin-bottom: 0.5rem; color: #f0f0f0; }
    h1 span { color: #a78bfa; }
    .summary {
      display: flex; gap: 1rem; margin: 1.5rem 0;
    }
    .stat {
      background: #1a1a2e;
      border-radius: 8px;
      padding: 1rem 1.5rem;
      text-align: center;
      min-width: 120px;
    }
    .stat .num { font-size: 2rem; font-weight: bold; }
    .stat .label { font-size: 0.8rem; color: #888; text-transform: uppercase; }
    .stat.pass .num { color: #22c55e; }
    .stat.fail .num { color: #ef4444; }
    .stat.other .num { color: #eab308; }
    table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 1.5rem;
      font-size: 0.9rem;
    }
    th {
      text-align: left;
      padding: 0.75rem 0.5rem;
      border-bottom: 2px solid #333;
      color: #888;
      text-transform: uppercase;
      font-size: 0.75rem;
      letter-spacing: 0.05em;
    }
    td {
      padding: 0.75rem 0.5rem;
      border-bottom: 1px solid #222;
      vertical-align: middle;
    }
    tr:hover { background: #111122; }
    img { border-radius: 4px; }
    a { color: inherit; text-decoration: none; }
    .footer { margin-top: 2rem; color: #555; font-size: 0.8rem; }
  </style>
</head>
<body>
  <h1>🛰️ <span>SpaceJunk</span> — Visual Snapshot Report</h1>
  <p style="color:#888">Generated ${new Date().toISOString().replace('T', ' ').slice(0, 19)} UTC</p>

  <div class="summary">
    <div class="stat pass">
      <div class="num">${pass}</div>
      <div class="label">Passed</div>
    </div>
    <div class="stat fail">
      <div class="num">${fail}</div>
      <div class="label">Failed</div>
    </div>
    <div class="stat other">
      <div class="num">${other}</div>
      <div class="label">Other</div>
    </div>
  </div>

  <table>
    <thead>
      <tr>
        <th></th>
        <th>Scenario</th>
        <th>Diff</th>
        <th>Severity</th>
        <th>Reference</th>
        <th>Current</th>
        <th>Diff</th>
      </tr>
    </thead>
    <tbody>
      ${rows}
    </tbody>
  </table>

  <div class="footer">
    <p>Reference: <code>snapshots/reference/</code> &nbsp;|&nbsp; Current: <code>snapshots/current/</code> &nbsp;|&nbsp; Diff: <code>snapshots/diff/</code></p>
    <p>To accept current as new baseline: <code>node scripts/visual-diff.mjs --update</code></p>
  </div>
</body>
</html>`;

  writeFileSync(REPORT_FILE, html);
}

main().catch((err) => {
  console.error(`\n❌ Fatal: ${err.message}`);
  process.exit(1);
});
